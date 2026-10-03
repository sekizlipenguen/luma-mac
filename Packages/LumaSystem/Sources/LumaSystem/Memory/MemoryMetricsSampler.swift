import Darwin
import Dispatch
import Foundation
import LumaCore

/// Samples VM statistics via `host_statistics64` and optional dispatch memory-pressure source.
public final class MemoryMetricsSampler: MemoryMetricsProviding, @unchecked Sendable {
    private let pressureLock = NSLock()
    private var lastPressure: MemoryPressureLevel = .unknown
    private var pressureSourceKind: MemoryPressureSource = .unavailable
    private var pressureSource: DispatchSourceMemoryPressure?

    public init() {
        startPressureMonitoring()
    }

    deinit {
        pressureSource?.cancel()
    }

    public func sample() async throws -> MemoryMetrics {
        try await Task.detached(priority: .utility) { [self] in
            try self.sampleSync()
        }.value
    }

    private func startPressureMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let event = source.data
            let level: MemoryPressureLevel
            if event.contains(.critical) {
                level = .critical
            } else if event.contains(.warning) {
                level = .warning
            } else {
                level = .normal
            }
            self.pressureLock.lock()
            self.lastPressure = level
            self.pressureSourceKind = .dispatchSource
            self.pressureLock.unlock()
        }
        source.resume()
        pressureSource = source
        pressureLock.lock()
        pressureSourceKind = .dispatchSource
        lastPressure = .normal
        pressureLock.unlock()
    }

    private func sampleSync() throws -> MemoryMetrics {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else {
            throw LumaError.ioFailure("host_statistics64 failed: \(kr)")
        }

        let pageSize = UInt64(getpagesize())
        let total = ProcessInfo.processInfo.physicalMemory

        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        let speculative = UInt64(stats.speculative_count) * pageSize
        let purgeable = UInt64(stats.purgeable_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize

        let swap = readSwapUsage()

        pressureLock.lock()
        var pressure = lastPressure
        var source = pressureSourceKind
        pressureLock.unlock()

        if source == .unavailable || pressure == .unknown {
            // Honest estimate from free+purgeable ratio — labeled as estimated.
            let reclaimable = Double(free + purgeable)
            let ratio = total > 0 ? reclaimable / Double(total) : 1
            if ratio < 0.05 {
                pressure = .critical
            } else if ratio < 0.12 {
                pressure = .warning
            } else {
                pressure = .normal
            }
            source = .estimatedFromVMStats
        }

        return MemoryMetrics(
            totalBytes: total,
            activeBytes: active,
            inactiveBytes: inactive,
            wiredBytes: wired,
            compressedBytes: compressed,
            freeBytes: free,
            purgeableBytes: purgeable,
            speculativeBytes: speculative,
            swapUsedBytes: swap.used,
            swapTotalBytes: swap.total,
            pressure: pressure,
            pressureSource: source
        )
    }

    private func readSwapUsage() -> (used: UInt64, total: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard result == 0 else { return (0, 0) }
        return (UInt64(usage.xsu_used), UInt64(usage.xsu_total))
    }
}
