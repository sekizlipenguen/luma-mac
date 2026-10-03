import AppKit
import Darwin
import Foundation
import LumaCore

/// Real process CPU deltas; grouping happens before any display limit is applied.
public actor CPUProcessSampler {
    struct Counter: Sendable {
        let process: CPUProcessInfo
        let cpuNanoseconds: Double
        let uptime: Double
    }

    private var previous: [Int32: Counter] = [:]

    public init() {}

    public func sample() async -> [CPUProcessGroup] {
        let raw = await Task.detached(priority: .utility) { Self.readCounters() }.value
        // Launch Services knows the original bundle even for macOS code-signing clones.
        let applications = await MainActor.run {
            Dictionary(NSWorkspace.shared.runningApplications.compactMap { app -> (Int32, String)? in
                guard let path = app.bundleURL?.resolvingSymlinksInPath().path, path.hasSuffix(".app") else { return nil }
                return (app.processIdentifier, path)
            }, uniquingKeysWith: { _, new in new })
        }
        let measured = raw.map { counter in
            let process = Self.measured(counter, previous: previous[counter.process.pid])
            return CPUProcessInfo(pid: process.pid, parentPID: process.parentPID, userID: process.userID,
                                  startedAt: process.startedAt, name: process.name, executablePath: process.executablePath,
                                  cpuPercent: process.cpuPercent, applicationPath: applications[process.pid])
        }
        previous = Dictionary(raw.map { ($0.process.pid, $0) }, uniquingKeysWith: { _, new in new })
        return Self.group(measured)
    }

    static func measured(_ current: Counter, previous: Counter?) -> CPUProcessInfo {
        let process = current.process
        var percent: Double?
        if let previous, previous.process.id == process.id,
           current.uptime > previous.uptime, current.cpuNanoseconds >= previous.cpuNanoseconds {
            let value = (current.cpuNanoseconds - previous.cpuNanoseconds)
                / 1_000_000_000 / (current.uptime - previous.uptime) * 100
            if value.isFinite { percent = value }
        }
        return CPUProcessInfo(pid: process.pid, parentPID: process.parentPID, userID: process.userID,
                              startedAt: process.startedAt, name: process.name,
                              executablePath: process.executablePath, cpuPercent: percent, applicationPath: process.applicationPath)
    }

    /// Outermost .app includes embedded helper bundles; names alone never establish ownership.
    public nonisolated static func applicationPath(for executablePath: String) -> String? {
        guard executablePath.hasPrefix("/") else { return nil }
        let components = URL(fileURLWithPath: executablePath).standardized.pathComponents
        guard let index = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        return NSString.path(withComponents: Array(components.prefix(index + 1)))
    }

    static func group(_ processes: [CPUProcessInfo]) -> [CPUProcessGroup] {
        let byPID = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { _, new in new })
        func owningApplication(_ process: CPUProcessInfo) -> String? {
            var current = process
            var seen = Set<Int32>()
            while seen.insert(current.pid).inserted {
                if let path = current.applicationPath ?? applicationPath(for: current.executablePath) { return path }
                guard current.parentPID > 1, let parent = byPID[current.parentPID],
                      parent.userID == process.userID else { return nil }
                current = parent
            }
            return nil
        }
        var members: [String: [CPUProcessInfo]] = [:]
        var paths: [String: String] = [:]
        for process in processes {
            let path = owningApplication(process)
            // Keep different users and independent standalone processes separate.
            let key = path.map { "app:\(process.userID):\($0)" } ?? "process:\(process.id)"
            members[key, default: []].append(process)
            paths[key] = path
        }
        return members.map { key, values in
            let path = paths[key]
            let sorted = values.sorted {
                if $0.cpuPercent != $1.cpuPercent { return ($0.cpuPercent ?? -1) > ($1.cpuPercent ?? -1) }
                return $0.pid < $1.pid
            }
            let name = path.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
                ?? sorted.first?.name ?? key
            return CPUProcessGroup(id: key, name: name, applicationPath: path, processes: sorted)
        }.sorted {
            if $0.cpuPercent != $1.cpuPercent { return ($0.cpuPercent ?? -1) > ($1.cpuPercent ?? -1) }
            return $0.id < $1.id
        }
    }

    public nonisolated static func isCurrentProcess(_ process: CPUProcessInfo) -> Bool {
        guard let current = readCounter(process.pid)?.process else { return false }
        return current.id == process.id && current.userID == process.userID
            && current.executablePath == process.executablePath
    }

    private nonisolated static func readCounters() -> [Counter] {
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return [] }
        // Leave room for processes created between the sizing and enumeration calls.
        let count = Int(byteCount) / MemoryLayout<pid_t>.size + 128
        var pids = [pid_t](repeating: 0, count: count)
        let filled = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(count * MemoryLayout<pid_t>.size))
        guard filled > 0 else { return [] }
        return pids.prefix(Int(filled) / MemoryLayout<pid_t>.size).filter { $0 > 0 }.compactMap(readCounter)
    }

    nonisolated static func readCounter(_ pid: pid_t) -> Counter? {
        var usage = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
            }
        }
        guard result == 0 else { return nil }
        var bsd = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, size) == size else { return nil }
        var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let pathLength = proc_pidpath(pid, &path, UInt32(path.count))
        let executablePath = pathLength > 0 ? decodeCString(path) : ""
        var name = [CChar](repeating: 0, count: Int(MAXCOMLEN) * 2)
        let nameLength = proc_name(pid, &name, UInt32(name.count))
        let process = CPUProcessInfo(
            pid: pid, parentPID: Int32(bsd.pbi_ppid), userID: bsd.pbi_uid,
            startedAt: usage.ri_proc_start_abstime,
            name: nameLength > 0 ? decodeCString(name) : "pid \(pid)",
            executablePath: executablePath, cpuPercent: nil
        )
        // XNU fill_task_rusage returns Mach absolute time, whose scale differs on ARM and Intel.
        var timebase = mach_timebase_info_data_t()
        guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom > 0 else { return nil }
        let nanoseconds = (Double(usage.ri_user_time) + Double(usage.ri_system_time))
            * Double(timebase.numer) / Double(timebase.denom)
        return Counter(process: process, cpuNanoseconds: nanoseconds,
                       uptime: ProcessInfo.processInfo.systemUptime)
    }

    private nonisolated static func decodeCString(_ characters: [CChar]) -> String {
        String(decoding: characters.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
