import Foundation
import IOKit.ps
import LumaCore

/// Battery metrics via IOKit power sources. Desktops report `isPresent = false`.
public struct BatteryMetricsSampler: BatteryMetricsProviding {
    public init() {}

    public func sample() async throws -> BatteryMetrics {
        try await Task.detached(priority: .utility) {
            Self.sampleSync()
        }.value
    }

    private static func sampleSync() -> BatteryMetrics {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              !list.isEmpty
        else {
            return .desktopNoBattery
        }

        for source in list {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any]
            else { continue }

            let type = description[kIOPSTypeKey] as? String
            guard type == kIOPSInternalBatteryType else { continue }

            let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            let current = description[kIOPSCurrentCapacityKey] as? Int
            let max = description[kIOPSMaxCapacityKey] as? Int
            let design = description["DesignCapacity"] as? Int
            let cycles = description["CycleCount"] as? Int
            let timeToEmpty = description[kIOPSTimeToEmptyKey] as? Int
            let timeToFull = description[kIOPSTimeToFullChargeKey] as? Int
            let remaining: Int?
            if isCharging {
                remaining = (timeToFull ?? -1) > 0 ? timeToFull : nil
            } else {
                remaining = (timeToEmpty ?? -1) > 0 ? timeToEmpty : nil
            }

            var health: Int?
            if let max, let design, design > 0 {
                let computed = Int((Double(max) / Double(design) * 100.0).rounded())
                // Implausible IOKit values — omit rather than show nonsense.
                health = (0...200).contains(computed) ? computed : nil
            }

            return BatteryMetrics(
                isPresent: true,
                isCharging: isCharging,
                currentCapacityPercent: current,
                designCapacityMilliAmpHours: design,
                maxCapacityMilliAmpHours: max,
                cycleCount: cycles,
                timeRemainingMinutes: remaining,
                healthPercent: health
            )
        }
        return .desktopNoBattery
    }
}
