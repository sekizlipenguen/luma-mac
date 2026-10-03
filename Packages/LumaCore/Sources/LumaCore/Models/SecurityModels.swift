import Foundation

/// Outcome of one honest security hygiene check (not antivirus scoring).
public enum SecurityCheckState: String, Sendable, Equatable {
    /// Enabled / expected good state.
    case ok
    /// Disabled or worth user attention (not “infected”).
    case attention
    /// Could not determine honestly.
    case unknown
    /// Informational only (no good/bad judgment).
    case info
}

/// One row on the Security hygiene panel.
public struct SecurityCheckItem: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var detail: String
    public var state: SecurityCheckState
    /// How Luma obtained this (tool / API) — shown for honesty.
    public var source: String
    /// Optional System Settings deep link.
    public var settingsURLString: String?

    public init(
        id: String,
        title: String,
        summary: String,
        detail: String,
        state: SecurityCheckState,
        source: String,
        settingsURLString: String? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.detail = detail
        self.state = state
        self.source = source
        self.settingsURLString = settingsURLString
    }
}

/// Snapshot for the Security screen — status only, never a malware verdict.
public struct SecuritySnapshot: Sendable, Equatable {
    public var checks: [SecurityCheckItem]
    public var sampledAt: Date
    public var honestyNote: String

    public init(checks: [SecurityCheckItem], sampledAt: Date = .now, honestyNote: String) {
        self.checks = checks
        self.sampledAt = sampledAt
        self.honestyNote = honestyNote
    }

    public var attentionCount: Int {
        checks.filter { $0.state == .attention }.count
    }

    public var unknownCount: Int {
        checks.filter { $0.state == .unknown }.count
    }
}
