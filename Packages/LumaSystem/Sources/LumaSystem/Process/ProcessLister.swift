import Darwin
import Foundation
import LumaCore

/// Lists processes by resident memory and energy using `proc_listpids` / `proc_pidinfo` / `proc_pid_rusage`.
public actor ProcessLister: ProcessListingProviding {
    private struct EnergySample {
        var nanojoules: UInt64
        var date: Date
    }

    private var previousEnergy: [pid_t: EnergySample] = [:]

    public init() {}

    public func topMemoryConsumers(limit: Int) async throws -> [ProcessMemoryInfo] {
        try await Task.detached(priority: .utility) {
            try Self.listMemory(limit: limit)
        }.value
    }

    public func topEnergyConsumers(limit: Int) async throws -> [ProcessEnergyInfo] {
        let now = Date()
        let raw = try await Task.detached(priority: .utility) {
            Self.listEnergyRaw()
        }.value

        var results: [ProcessEnergyInfo] = []
        results.reserveCapacity(raw.count)
        var nextPrevious: [pid_t: EnergySample] = [:]
        nextPrevious.reserveCapacity(raw.count)

        for item in raw {
            nextPrevious[item.pid] = EnergySample(nanojoules: item.nanojoules, date: now)
            let lifetimeJoules = Double(item.nanojoules) / 1_000_000_000.0
            var milliwatts: Double?
            if let prior = previousEnergy[item.pid] {
                let dt = now.timeIntervalSince(prior.date)
                if dt >= 0.35, item.nanojoules >= prior.nanojoules {
                    let deltaNJ = Double(item.nanojoules - prior.nanojoules)
                    // nanojoules / s = nanowatts; / 1e6 = milliwatts
                    milliwatts = deltaNJ / dt / 1_000_000.0
                    if let mw = milliwatts, !mw.isFinite || mw < 0 {
                        milliwatts = nil
                    }
                }
            }
            let rank = milliwatts ?? lifetimeJoules
            guard rank > 0 else { continue }
            results.append(
                ProcessEnergyInfo(
                    pid: item.pid,
                    name: item.name,
                    milliwatts: milliwatts,
                    lifetimeJoules: lifetimeJoules,
                    rankScore: rank
                )
            )
        }

        previousEnergy = nextPrevious
        results.sort { $0.rankScore > $1.rankScore }
        if results.count > limit {
            results = Array(results.prefix(limit))
        }
        return results
    }

    private static func listMemory(limit: Int) throws -> [ProcessMemoryInfo] {
        let pids = allPIDs()
        var results: [ProcessMemoryInfo] = []
        results.reserveCapacity(min(limit * 2, pids.count))

        for pid in pids {
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            let st = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
            guard st == size else { continue }

            results.append(
                ProcessMemoryInfo(
                    pid: pid,
                    name: processName(pid),
                    bundleIdentifier: nil,
                    residentBytes: UInt64(info.pti_resident_size)
                )
            )
        }

        results.sort { $0.residentBytes > $1.residentBytes }
        if results.count > limit {
            results = Array(results.prefix(limit))
        }
        return results
    }

    private struct RawEnergy {
        var pid: pid_t
        var name: String
        var nanojoules: UInt64
    }

    private static func listEnergyRaw() -> [RawEnergy] {
        let pids = allPIDs()
        var results: [RawEnergy] = []
        results.reserveCapacity(min(256, pids.count))

        for pid in pids {
            guard let nj = energyNanojoules(pid), nj > 0 else { continue }
            results.append(RawEnergy(pid: pid, name: processName(pid), nanojoules: nj))
        }
        return results
    }

    private static func energyNanojoules(_ pid: pid_t) -> UInt64? {
        var info = rusage_info_v6()
        let ret = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V6, $0)
            }
        }
        guard ret == 0 else { return nil }
        // Prefer cumulative nanojoules; fall back to billed energy units when nj is zero.
        if info.ri_energy_nj > 0 { return info.ri_energy_nj }
        if info.ri_billed_energy > 0 { return info.ri_billed_energy }
        return nil
    }

    private static func allPIDs() -> [pid_t] {
        let numberOfBytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard numberOfBytes > 0 else { return [] }
        let count = min(Int(numberOfBytes) / MemoryLayout<pid_t>.size, 4_096)
        var pids = [pid_t](repeating: 0, count: count)
        let bufferBytes = Int32(count * MemoryLayout<pid_t>.size)
        let filled = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, bufferBytes)
        guard filled > 0 else { return [] }
        let actualCount = Int(filled) / MemoryLayout<pid_t>.size
        return pids.prefix(actualCount).filter { $0 > 0 }
    }

    private static func processName(_ pid: pid_t) -> String {
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) * 2)
        let nameLen = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        return nameLen > 0 ? String(cString: nameBuffer) : "pid \(pid)"
    }
}
