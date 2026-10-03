import Foundation

/// Safe numeric helpers for metrics that can wrap, reset, or go non-finite.
public enum NumericSafety {
    /// Counter delta that treats resets as zero instead of wrapping to `UInt64.max`.
    public static func saturatingDelta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }

    public static func finiteOrZero(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    /// Clamp to `[0, 1]`, mapping non-finite to `0`.
    public static func unitInterval(_ value: Double) -> Double {
        let v = finiteOrZero(value)
        return min(max(v, 0), 1)
    }

    /// Convert a non-negative finite Double to `UInt64` without trapping on huge/NaN/Inf.
    public static func uint64(fromNonNegative value: Double) -> UInt64 {
        guard value.isFinite, value > 0 else { return 0 }
        // `Double(UInt64.max)` rounds to 2^64, so compare against the largest Double
        // that is still <= UInt64.max (2^64 - 2048 for this magnitude).
        let maxSafe = Double(sign: .plus, exponent: 64, significand: 1) // 2^64
        if value >= maxSafe { return UInt64.max }
        return UInt64(value)
    }
}
