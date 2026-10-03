import Foundation

/// Errors surfaced by Luma. Never invent values — report honest failures.
public enum LumaError: Error, Sendable, LocalizedError, Equatable {
    case permissionDenied(String)
    case pathUnavailable(String)
    case cancelled
    case unsupportedHardware(String)
    case ioFailure(String)
    case unavailable(reason: String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let detail):
            return "Permission denied: \(detail)"
        case .pathUnavailable(let path):
            return "Path unavailable: \(path)"
        case .cancelled:
            return "Operation cancelled"
        case .unsupportedHardware(let detail):
            return "Unsupported on this Mac: \(detail)"
        case .ioFailure(let detail):
            return "I/O failure: \(detail)"
        case .unavailable(let reason):
            return reason
        }
    }
}
