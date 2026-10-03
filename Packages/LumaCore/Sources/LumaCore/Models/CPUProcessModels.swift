import Foundation

/// CPU percentage follows Activity Monitor: one fully busy core is 100%.
public struct CPUProcessInfo: Sendable, Equatable, Identifiable {
    public var id: String { "\(pid)-\(startedAt)" }
    public let pid: Int32
    public let parentPID: Int32
    public let userID: UInt32
    public let startedAt: UInt64
    public let name: String
    public let executablePath: String
    public let applicationPath: String?
    /// Nil until two samples of the same process identity are available.
    public let cpuPercent: Double?

    public init(pid: Int32, parentPID: Int32, userID: UInt32, startedAt: UInt64,
                name: String, executablePath: String, cpuPercent: Double?, applicationPath: String? = nil) {
        self.pid = pid
        self.parentPID = parentPID
        self.userID = userID
        self.startedAt = startedAt
        self.name = name
        self.executablePath = executablePath
        self.applicationPath = applicationPath
        self.cpuPercent = cpuPercent
    }
}

public struct CPUProcessGroup: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let applicationPath: String?
    public let processes: [CPUProcessInfo]

    public init(id: String, name: String, applicationPath: String?, processes: [CPUProcessInfo]) {
        self.id = id
        self.name = name
        self.applicationPath = applicationPath
        self.processes = processes
    }

    public var cpuPercent: Double? {
        guard processes.contains(where: { $0.cpuPercent != nil }) else { return nil }
        return processes.reduce(0) { $0 + ($1.cpuPercent ?? 0) }
    }

    public var hasPendingSamples: Bool { processes.contains { $0.cpuPercent == nil } }
}
