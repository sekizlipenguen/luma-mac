import Foundation

public enum EmulatorPlatform: String, Sendable { case iOS, android }

public struct RunningEmulator: Sendable, Equatable, Identifiable {
    public var id: String { "\(platform.rawValue):\(deviceID)" }
    public let deviceID: String
    public let name: String
    public let runtime: String
    public let platform: EmulatorPlatform
    public let isOnline: Bool

    public init(deviceID: String, name: String, runtime: String, platform: EmulatorPlatform, isOnline: Bool = true) {
        self.deviceID = deviceID
        self.name = name
        self.runtime = runtime
        self.platform = platform
        self.isOnline = isOnline
    }
}

public struct EmulatorSnapshot: Sendable {
    public let devices: [RunningEmulator]
    public let notes: [String]

    public init(devices: [RunningEmulator], notes: [String] = []) {
        self.devices = devices
        self.notes = notes
    }
}

public enum EmulatorStopResult: Sendable { case stopped, alreadyStopped }

public protocol EmulatorManaging: Sendable {
    func snapshot() async -> EmulatorSnapshot
    func stop(_ device: RunningEmulator) async throws -> EmulatorStopResult
}
