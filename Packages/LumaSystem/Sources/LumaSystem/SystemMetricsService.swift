import Foundation
import LumaCore
import LumaSupport

/// Aggregates real system samplers into a single `SystemSnapshot`.
/// Each subsystem is isolated so one slow/failing sample cannot block the dashboard forever.
public actor SystemMetricsService: SystemMetricsProviding {
    private let cpu: CPUMetricsSampler
    private let memory: MemoryMetricsSampler
    private let disk: DiskMetricsSampler
    private let battery: BatteryMetricsSampler
    private let network: NetworkMetricsSampler
    private let processes: ProcessLister
    private let thermal: ThermalSampler
    private let cpuProcesses: CPUProcessSampler

    public init(
        cpu: CPUMetricsSampler = CPUMetricsSampler(),
        memory: MemoryMetricsSampler = MemoryMetricsSampler(),
        disk: DiskMetricsSampler = DiskMetricsSampler(),
        battery: BatteryMetricsSampler = BatteryMetricsSampler(),
        network: NetworkMetricsSampler = NetworkMetricsSampler(),
        processes: ProcessLister = ProcessLister(),
        thermal: ThermalSampler = ThermalSampler(),
        cpuProcesses: CPUProcessSampler = CPUProcessSampler()
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.battery = battery
        self.network = network
        self.processes = processes
        self.thermal = thermal
        self.cpuProcesses = cpuProcesses
    }

    public func snapshot() async throws -> SystemSnapshot {
        // Warm CPU for a meaningful delta, without waiting on other subsystems.
        _ = try? await cpu.sample()
        try? await Task.sleep(nanoseconds: 150_000_000)
        return try await quickSnapshot()
    }

    public func quickSnapshot() async throws -> SystemSnapshot {
        // Sequential + best-effort: never use unbounded parallel async-lets that can stall together.
        let cpuValue = (try? await cpu.sample()) ?? CPUMetrics(overallUsage: 0, perCoreUsage: [], loadAverage: (0, 0, 0))
        let memoryValue = (try? await memory.sample()) ?? MemoryMetrics(
            totalBytes: ProcessInfo.processInfo.physicalMemory,
            activeBytes: 0,
            inactiveBytes: 0,
            wiredBytes: 0,
            compressedBytes: 0,
            freeBytes: 0,
            purgeableBytes: 0,
            speculativeBytes: 0,
            swapUsedBytes: 0,
            swapTotalBytes: 0,
            pressure: .unknown,
            pressureSource: .unavailable
        )

        var volumes: [DiskVolumeMetrics] = []
        if let root = await disk.sampleRootVolume() {
            volumes = [root]
        } else {
            volumes = (try? await disk.sampleVolumes()) ?? []
        }

        let batteryValue = (try? await battery.sample()) ?? .desktopNoBattery
        let networkValue = (try? await network.sample()) ?? NetworkMetrics(
            bytesInPerSecond: 0,
            bytesOutPerSecond: 0,
            totalBytesIn: 0,
            totalBytesOut: 0
        )

        // Process listing is nicest-to-have; cap time so it cannot freeze the UI.
        let top: [ProcessMemoryInfo]
        do {
            top = try await withTimeout(seconds: 1.5) {
                try await self.processes.topMemoryConsumers(limit: 10)
            }
        } catch {
            top = []
        }

        let topEnergy: [ProcessEnergyInfo]
        do {
            topEnergy = try await withTimeout(seconds: 1.5) {
                try await self.processes.topEnergyConsumers(limit: 10)
            }
        } catch {
            topEnergy = []
        }

        let thermalValue = (try? await thermal.sample()) ?? .unavailable
        let cpuGroups = await cpuProcesses.sample()

        return SystemSnapshot(
            cpu: cpuValue,
            memory: memoryValue,
            volumes: volumes,
            battery: batteryValue,
            network: networkValue,
            topProcesses: top,
            topEnergyProcesses: topEnergy,
            cpuProcessGroups: cpuGroups,
            thermal: thermalValue
        )
    }
}

private func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw LumaError.unavailable(reason: "Timed out after \(seconds)s")
        }
        guard let first = try await group.next() else {
            throw LumaError.unavailable(reason: "Timeout produced no result")
        }
        group.cancelAll()
        return first
    }
}
