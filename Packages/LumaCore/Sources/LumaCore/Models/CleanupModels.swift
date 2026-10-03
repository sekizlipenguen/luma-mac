import Foundation

/// Risk classification for cleanup operations.
public enum CleanupRiskLevel: String, Sendable, Codable, CaseIterable {
    case safe
    case caution
    case advanced
}

/// How a cleanup operation should mutate the filesystem.
public enum CleanupExecutionMode: String, Sendable, Codable {
    /// Measure only — no filesystem changes.
    case dryRun
    /// Move items to Trash (supports Undo while still in Trash).
    case trash
    /// Permanent delete — no undo.
    case delete
}

public struct CleanupPreviewItem: Sendable, Equatable, Identifiable, Codable {
    public var id: String { path }
    public var path: String
    public var byteCount: UInt64
    public var explanation: String

    public init(path: String, byteCount: UInt64, explanation: String) {
        self.path = path
        self.byteCount = byteCount
        self.explanation = explanation
    }
}

public struct CleanupEstimate: Sendable, Equatable, Codable {
    public var itemCount: Int
    public var estimatedBytes: UInt64
    public var items: [CleanupPreviewItem]

    public init(itemCount: Int, estimatedBytes: UInt64, items: [CleanupPreviewItem]) {
        self.itemCount = itemCount
        self.estimatedBytes = estimatedBytes
        self.items = items
    }

    public static let empty = CleanupEstimate(itemCount: 0, estimatedBytes: 0, items: [])
}

public struct CleanupResult: Sendable, Equatable, Codable {
    public var ruleID: String
    public var mode: CleanupExecutionMode
    public var estimatedBytes: UInt64
    public var recoveredBytes: UInt64
    public var movedToTrash: [String]
    public var deletedPaths: [String]
    public var failedPaths: [String]
    public var startedAt: Date
    public var finishedAt: Date

    public init(
        ruleID: String,
        mode: CleanupExecutionMode,
        estimatedBytes: UInt64,
        recoveredBytes: UInt64,
        movedToTrash: [String],
        deletedPaths: [String],
        failedPaths: [String],
        startedAt: Date,
        finishedAt: Date
    ) {
        self.ruleID = ruleID
        self.mode = mode
        self.estimatedBytes = estimatedBytes
        self.recoveredBytes = recoveredBytes
        self.movedToTrash = movedToTrash
        self.deletedPaths = deletedPaths
        self.failedPaths = failedPaths
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public struct OperationLogEntry: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var timestamp: Date
    public var ruleID: String
    public var ruleTitle: String
    public var mode: CleanupExecutionMode
    public var estimatedBytes: UInt64
    public var recoveredBytes: UInt64
    public var paths: [String]
    public var notes: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        ruleID: String,
        ruleTitle: String,
        mode: CleanupExecutionMode,
        estimatedBytes: UInt64,
        recoveredBytes: UInt64,
        paths: [String],
        notes: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.ruleID = ruleID
        self.ruleTitle = ruleTitle
        self.mode = mode
        self.estimatedBytes = estimatedBytes
        self.recoveredBytes = recoveredBytes
        self.paths = paths
        self.notes = notes
    }
}
