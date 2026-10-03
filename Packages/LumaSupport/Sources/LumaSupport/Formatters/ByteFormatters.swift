import Foundation
import LumaCore

/// Byte count formatting helpers.
public enum ByteFormatters {
    public static func string(for bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        // Unit names follow Locale.current (kept in sync via AppLanguage.applyBundleLanguagePreference).
        return formatter.string(fromByteCount: Int64(clamping: bytes))
    }

    public static func string(for bytes: Int64) -> String {
        string(for: UInt64(max(0, bytes)))
    }

    public static func rateString(bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite else { return "— B/s" }
        // Network rates use decimal (SI) units — closer to Activity Monitor / ISP feel.
        var value = Swift.abs(bytesPerSecond)
        let units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
        var unit = 0
        while value >= 1000, unit < units.count - 1 {
            value /= 1000
            unit += 1
        }
        if unit == 0 {
            return String(format: "%.0f %@", value, units[unit] as CVarArg)
        }
        if value >= 100 {
            return String(format: "%.0f %@", value, units[unit] as CVarArg)
        }
        return String(format: "%.1f %@", value, units[unit] as CVarArg)
    }
}

public enum PercentFormatters {
    public static func string(_ value: Double, fractionDigits: Int = 0) -> String {
        let clamped = NumericSafety.unitInterval(value)
        return String(format: "%.\(fractionDigits)f%%", clamped * 100)
    }

    public static func fromZeroToHundred(_ value: Double, fractionDigits: Int = 0) -> String {
        guard value.isFinite else { return "—%" }
        let clamped = min(max(value, 0), 100)
        return String(format: "%.\(fractionDigits)f%%", clamped)
    }
}

public enum EnergyFormatters {
    /// Formats instantaneous power (milliwatts) or falls back to lifetime joules.
    public static func string(milliwatts: Double?, lifetimeJoules: Double) -> String {
        if let milliwatts, milliwatts.isFinite, milliwatts > 0 {
            if milliwatts >= 1000 {
                return String(format: "%.1f W", milliwatts / 1000.0)
            }
            if milliwatts >= 10 {
                return String(format: "%.0f mW", milliwatts)
            }
            return String(format: "%.1f mW", milliwatts)
        }
        let joules = NumericSafety.finiteOrZero(lifetimeJoules)
        if joules >= 1000 {
            return String(format: "%.1f kJ", joules / 1000.0)
        }
        if joules >= 1 {
            return String(format: "%.1f J", joules)
        }
        return String(format: "%.0f mJ", joules * 1000.0)
    }
}
