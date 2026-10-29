import Foundation

public struct BackgroundStopJob: Sendable, Equatable {
    public let label: String
    public let plistPath: String

    public init(label: String, plistPath: String) {
        self.label = label
        self.plistPath = plistPath
    }
}

public enum BackgroundActivityKind: String, Sendable, Equatable {
    case app
    case agent
    case daemon
    case backgroundTasks
    case developer
    case other
}

/// One row in Background App Activity — the same list System Settings shows.
public struct BackgroundApp: Sendable, Equatable, Identifiable {
    public var id: String { identifier }
    public let identifier: String
    public let name: String
    public let kind: BackgroundActivityKind
    public let bundleIdentifier: String?
    public let iconPath: String?
    public let detail: String
    public let pid: Int32?
    public let isRunning: Bool
    public let stopJobs: [BackgroundStopJob]

    public var canStop: Bool { !stopJobs.isEmpty }

    public init(
        identifier: String,
        name: String,
        kind: BackgroundActivityKind,
        bundleIdentifier: String?,
        iconPath: String?,
        detail: String,
        pid: Int32?,
        isRunning: Bool,
        stopJobs: [BackgroundStopJob]
    ) {
        self.identifier = identifier
        self.name = name
        self.kind = kind
        self.bundleIdentifier = bundleIdentifier
        self.iconPath = iconPath
        self.detail = detail
        self.pid = pid
        self.isRunning = isRunning
        self.stopJobs = stopJobs
    }
}

public struct BackgroundAppQuitAllResult: Sendable, Equatable {
    public let requested: Int
    public let declined: Int
    public let unavailable: Int

    public init(requested: Int, declined: Int, unavailable: Int) {
        self.requested = requested
        self.declined = declined
        self.unavailable = unavailable
    }
}
