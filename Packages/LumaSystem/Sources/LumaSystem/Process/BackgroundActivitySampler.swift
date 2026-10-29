import Darwin
import Foundation
import LumaCore

/// Running LaunchAgents / LaunchDaemons from disk + `launchctl list`. Never calls `sfltool`.
public actor BackgroundActivitySampler {
    public init() {}

    public func snapshot() async -> [BackgroundApp] {
        let home = NSHomeDirectory()
        let plists = Self.scanPlists(home: home)
        let jobs = Self.launchctlJobs()
        let executables = Self.runningExecutables()
        return BackgroundTaskDump.rows(
            from: plists,
            launchJobs: jobs,
            executables: executables,
            home: home,
            ownBundleIdentifier: Bundle.main.bundleIdentifier,
            ownApplicationPath: Bundle.main.bundleURL.resolvingSymlinksInPath().path
        )
    }

    public func stop(_ apps: [BackgroundApp]) async -> BackgroundAppQuitAllResult {
        var requested = 0
        var declined = 0
        var unavailable = 0
        let uid = getuid()
        let homeAgents = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents")
        var seen = Set<String>()
        for app in apps {
            for job in app.stopJobs where seen.insert(job.label).inserted {
                guard job.plistPath.hasPrefix(homeAgents), job.plistPath.hasSuffix(".plist") else {
                    unavailable += 1
                    continue
                }
                let ok = Self.bootout(label: job.label, uid: uid)
                if ok { requested += 1 } else { declined += 1 }
            }
        }
        return BackgroundAppQuitAllResult(requested: requested, declined: declined, unavailable: unavailable)
    }

    // MARK: - Catalog

    nonisolated static func scanPlists(home: String) -> [BackgroundTaskDump.LaunchPlist] {
        let dirs: [(String, Bool)] = [
            ("\(home)/Library/LaunchAgents", true),
            ("/Library/LaunchAgents", false),
            ("/Library/LaunchDaemons", false)
        ]
        var items: [BackgroundTaskDump.LaunchPlist] = []
        for (dir, isUser) in dirs {
            let url = URL(fileURLWithPath: dir)
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            ) else { continue }
            for file in files where file.pathExtension == "plist" {
                guard let dict = NSDictionary(contentsOf: file) as? [String: Any],
                      let item = BackgroundTaskDump.launchPlist(from: dict, path: file.path, isUser: isUser)
                else { continue }
                items.append(item)
            }
        }
        return items
    }

    nonisolated static func launchctlJobs() -> [String: Int32] {
        guard let output = try? run("/bin/launchctl", ["list"], timeout: 4, maxBytes: 1_048_576) else { return [:] }
        var jobs: [String: Int32] = [:]
        for line in output.split(whereSeparator: \.isNewline).dropFirst() {
            let parts = line.split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 3 else { continue }
            let label = parts[2]
            if let pid = Int32(parts[0]), pid > 0 {
                jobs[label] = pid
            }
        }
        return jobs
    }

    nonisolated static func runningExecutables() -> [String: Int32] {
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return [:] }
        let count = Int(byteCount) / MemoryLayout<pid_t>.size + 128
        var pids = [pid_t](repeating: 0, count: count)
        let filled = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(count * MemoryLayout<pid_t>.size))
        guard filled > 0 else { return [:] }
        var map: [String: Int32] = [:]
        var pathBuffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) * 2)
        for pid in pids.prefix(Int(filled) / MemoryLayout<pid_t>.size) where pid > 0 {
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            if pathLength > 0 {
                let path = String(decoding: pathBuffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
                let standardized = (path as NSString).standardizingPath
                if map[standardized] == nil { map[standardized] = pid }
                if map[path] == nil { map[path] = pid }
                let base = (standardized as NSString).lastPathComponent
                if map[base] == nil { map[base] = pid }
            }
            let nameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            if nameLength > 0 {
                let name = String(decoding: nameBuffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
                if map[name] == nil { map[name] = pid }
            }
        }
        return map
    }

    nonisolated static func bootout(label: String, uid: uid_t) -> Bool {
        guard !label.isEmpty, !label.hasPrefix("com.apple.") else { return false }
        return (try? run("/bin/launchctl", ["bootout", "gui/\(uid)/\(label)"], timeout: 6, maxBytes: 16_384)) != nil
    }

    private nonisolated static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval, maxBytes: Int) throws -> String {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("luma-launchd-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let outputURL = folder.appendingPathComponent("output")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: outputURL)
        defer { try? output.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while process.isRunning {
            if Task.isCancelled || ProcessInfo.processInfo.systemUptime > deadline {
                process.terminate()
                throw LumaError.unavailable(reason: "Timed out reading background app activity.")
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard process.terminationStatus == 0 else {
            throw LumaError.unavailable(reason: "Background app activity is unavailable.")
        }
        let input = try FileHandle(forReadingFrom: outputURL)
        defer { try? input.close() }
        let data = try input.read(upToCount: maxBytes) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
