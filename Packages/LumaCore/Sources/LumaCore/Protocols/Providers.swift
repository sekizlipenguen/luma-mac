import Foundation

/// Protocol for CPU metrics providers (real Mach sampling or tests).
public protocol CPUMetricsProviding: Sendable {
    func sample() async throws -> CPUMetrics
}

public protocol MemoryMetricsProviding: Sendable {
    func sample() async throws -> MemoryMetrics
}

public protocol DiskMetricsProviding: Sendable {
    func sampleVolumes() async throws -> [DiskVolumeMetrics]
}

public protocol BatteryMetricsProviding: Sendable {
    func sample() async throws -> BatteryMetrics
}

public protocol NetworkMetricsProviding: Sendable {
    func sample() async throws -> NetworkMetrics
    func sampleDetail() async throws -> NetworkDetailSnapshot
}

public protocol ProcessListingProviding: Sendable {
    func topMemoryConsumers(limit: Int) async throws -> [ProcessMemoryInfo]
    func topEnergyConsumers(limit: Int) async throws -> [ProcessEnergyInfo]
}

public protocol ThermalMetricsProviding: Sendable {
    func sample() async throws -> ThermalMetrics
}

public protocol DiskHealthProviding: Sendable {
    func sample(volumePath: String) async throws -> DiskHealthMetrics
}

public protocol SystemMetricsProviding: Sendable {
    func snapshot() async throws -> SystemSnapshot
}

/// Allowlisted cleanup rule contract.
public protocol CleanupRule: Sendable {
    var id: String { get }
    var title: String { get }
    var explanation: String { get }
    var riskLevel: CleanupRiskLevel { get }
    var category: String { get }
    var isAvailable: Bool { get }
    var unavailableReason: String? { get }

    func estimate() async throws -> CleanupEstimate
    func execute(mode: CleanupExecutionMode) async throws -> CleanupResult
}

public protocol CleanupEngineProviding: Sendable {
    var rules: [any CleanupRule] { get }
    func estimate(ruleIDs: Set<String>) async throws -> [String: CleanupEstimate]
    func execute(ruleIDs: Set<String>, mode: CleanupExecutionMode) async throws -> [CleanupResult]
}

public protocol OperationHistoryProviding: Sendable {
    func append(_ entry: OperationLogEntry) async throws
    func recent(limit: Int) async throws -> [OperationLogEntry]
}
