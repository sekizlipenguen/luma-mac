import Foundation
import LumaCore

/// Thermal sampling. Public SMC access is unreliable on Apple Silicon — report Unavailable honestly.
public struct ThermalSampler: ThermalMetricsProviding {
    public init() {}

    public func sample() async throws -> ThermalMetrics {
        // Intentionally no fake temperatures. IOKit AppleSMC keys are undocumented and often blocked.
        .unavailable
    }
}
