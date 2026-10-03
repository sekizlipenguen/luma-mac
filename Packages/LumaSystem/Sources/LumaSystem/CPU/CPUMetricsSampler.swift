import Darwin
import Foundation
import LumaCore

/// Samples CPU usage via Mach `host_processor_info` tick deltas.
public final class CPUMetricsSampler: CPUMetricsProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var previousTicks: [Tick]? 

    private struct Tick {
        var user: UInt32
        var system: UInt32
        var idle: UInt32
        var nice: UInt32

        var total: UInt64 {
            UInt64(user) + UInt64(system) + UInt64(idle) + UInt64(nice)
        }

        var busy: UInt64 {
            UInt64(user) + UInt64(system) + UInt64(nice)
        }
    }

    public init() {}

    public func sample() async throws -> CPUMetrics {
        try await Task.detached(priority: .utility) { [self] in
            try self.sampleSync()
        }.value
    }

    private func sampleSync() throws -> CPUMetrics {
        var cpuCount: natural_t = 0
        var cpuInfoArray: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfoArray,
            &cpuInfoCount
        )
        guard result == KERN_SUCCESS, let cpuInfoArray else {
            throw LumaError.ioFailure("host_processor_info failed: \(result)")
        }
        defer {
            let size = vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfoArray), size)
        }

        let loadInfo = UnsafePointer(cpuInfoArray).withMemoryRebound(
            to: processor_cpu_load_info.self,
            capacity: Int(cpuCount)
        ) { $0 }

        var current: [Tick] = []
        current.reserveCapacity(Int(cpuCount))
        for i in 0..<Int(cpuCount) {
            let info = loadInfo[i]
            current.append(
                Tick(
                    user: info.cpu_ticks.0,
                    system: info.cpu_ticks.1,
                    idle: info.cpu_ticks.2,
                    nice: info.cpu_ticks.3
                )
            )
        }

        lock.lock()
        let previous = previousTicks
        previousTicks = current
        lock.unlock()

        var perCore: [Double] = Array(repeating: 0, count: current.count)
        var totalBusy: UInt64 = 0
        var totalAll: UInt64 = 0

        if let previous, previous.count == current.count {
            for i in 0..<current.count {
                let busy = current[i].busy >= previous[i].busy
                    ? current[i].busy - previous[i].busy
                    : 0
                let all = current[i].total >= previous[i].total
                    ? current[i].total - previous[i].total
                    : 0
                let usage = all > 0 ? Double(busy) / Double(all) : 0
                perCore[i] = min(max(usage, 0), 1)
                totalBusy += busy
                totalAll += all
            }
        }

        let overall = totalAll > 0 ? min(max(Double(totalBusy) / Double(totalAll), 0), 1) : 0
        var loads: [Double] = [0, 0, 0]
        getloadavg(&loads, 3)

        return CPUMetrics(
            overallUsage: overall,
            perCoreUsage: perCore,
            loadAverage: (loads[0], loads[1], loads[2])
        )
    }
}
