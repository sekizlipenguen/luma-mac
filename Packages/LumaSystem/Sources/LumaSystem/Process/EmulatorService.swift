import Foundation
import LumaCore

/// Device-scoped shutdown through developer tools; never erases devices or kills host services.
public actor EmulatorService: EmulatorManaging {
    typealias Runner = @Sendable (String, [String]) async throws -> String
    private let adbPath: String?
    private let runTool: Runner

    public init() {
        runTool = Self.run
        let environment = ProcessInfo.processInfo.environment
        let roots = [environment["ANDROID_HOME"], environment["ANDROID_SDK_ROOT"],
                     NSHomeDirectory() + "/Library/Android/sdk"].compactMap { $0 }
        adbPath = roots.map { $0 + "/platform-tools/adb" }
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    init(adbPath: String?, runner: @escaping Runner) {
        self.adbPath = adbPath
        self.runTool = runner
    }

    public func snapshot() async -> EmulatorSnapshot {
        var devices: [RunningEmulator] = []
        var notes: [String] = []
        do {
            let output = try await runTool("/usr/bin/xcrun", ["simctl", "list", "devices", "booted", "--json"])
            devices += try Self.parseIOS(output)
        } catch {
            notes.append("iOS simulator status is unavailable. Check that Xcode is installed and configured.")
        }
        if let adbPath {
            do {
                let output = try await runTool(adbPath, ["devices", "-l"])
                for device in Self.parseAndroid(output) {
                    var name = device.name
                    if device.isOnline,
                       let output = try? await runTool(adbPath, ["-s", device.deviceID, "emu", "avd", "name"]) {
                        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
                        name = lines.first(where: { !$0.isEmpty && $0 != "OK" }) ?? name
                    }
                    devices.append(RunningEmulator(deviceID: device.deviceID, name: name, runtime: device.runtime,
                                                   platform: .android, isOnline: device.isOnline))
                }
            } catch {
                notes.append("Android emulator status is unavailable. Check the Android SDK connection.")
            }
        } else {
            notes.append("Android SDK adb was not found. Android emulator status is unavailable.")
        }
        return EmulatorSnapshot(devices: devices.sorted { $0.id < $1.id }, notes: notes)
    }

    public func stop(_ device: RunningEmulator) async throws -> EmulatorStopResult {
        guard Self.isValidID(device.deviceID, platform: device.platform) else {
            throw LumaError.unavailable(reason: "Invalid emulator identifier.")
        }
        let active: [RunningEmulator]
        switch device.platform {
        case .iOS:
            let output = try await runTool("/usr/bin/xcrun", ["simctl", "list", "devices", "booted", "--json"])
            active = try Self.parseIOS(output)
        case .android:
            guard let adbPath else { throw LumaError.unavailable(reason: "Android SDK adb was not found.") }
            active = Self.parseAndroid(try await runTool(adbPath, ["devices", "-l"]))
        }
        guard let current = active.first(where: { $0.id == device.id }) else { return .alreadyStopped }
        guard current.isOnline else {
            throw LumaError.unavailable(reason: "This emulator is offline. Close it from the development tools.")
        }
        switch device.platform {
        case .iOS:
            _ = try await runTool("/usr/bin/xcrun", ["simctl", "shutdown", device.deviceID])
            let output = try await runTool("/usr/bin/xcrun", ["simctl", "list", "devices", "booted", "--json"])
            guard try !Self.parseIOS(output).contains(where: { $0.id == device.id }) else {
                throw LumaError.unavailable(reason: "The emulator is still running. Refresh and try again.")
            }
        case .android:
            guard let adbPath else { throw LumaError.unavailable(reason: "Android SDK adb was not found.") }
            _ = try await runTool(adbPath, ["-s", device.deviceID, "emu", "kill"])
            var exited = false
            for _ in 0..<5 {
                let output = try await runTool(adbPath, ["devices", "-l"])
                if !Self.parseAndroid(output).contains(where: { $0.id == device.id }) { exited = true; break }
                try await Task.sleep(for: .milliseconds(300))
            }
            guard exited else { throw LumaError.unavailable(reason: "The emulator is still running. Refresh and try again.") }
        }
        return .stopped
    }

    private struct IOSList: Decodable {
        struct Device: Decodable {
            let udid: String
            let name: String
            let state: String
            let isAvailable: Bool?
        }
        let devices: [String: [Device]]
    }

    nonisolated static func parseIOS(_ output: String) throws -> [RunningEmulator] {
        let list = try JSONDecoder().decode(IOSList.self, from: Data(output.utf8))
        return list.devices.flatMap { runtime, devices in
            devices.filter { $0.state == "Booted" && $0.isAvailable != false && isValidID($0.udid, platform: .iOS) }
                .map { RunningEmulator(deviceID: $0.udid, name: $0.name,
                                       runtime: runtime.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: ""),
                                       platform: .iOS) }
        }
    }

    nonisolated static func parseAndroid(_ output: String) -> [RunningEmulator] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 2, isValidID(parts[0], platform: .android) else { return nil }
            return RunningEmulator(deviceID: parts[0], name: parts[0], runtime: "Android",
                                   platform: .android, isOnline: parts[1] == "device")
        }
    }

    nonisolated static func isValidID(_ id: String, platform: EmulatorPlatform) -> Bool {
        switch platform {
        case .iOS: return UUID(uuidString: id) != nil
        case .android:
            guard id.hasPrefix("emulator-") else { return false }
            let suffix = id.dropFirst("emulator-".count)
            guard !suffix.isEmpty, suffix.allSatisfy({ $0.isASCII && $0.isNumber }), let port = Int(suffix) else { return false }
            return (5554...65534).contains(port) && port.isMultiple(of: 2)
        }
    }

    private nonisolated static func run(_ executable: String, _ arguments: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            try runSync(executable, arguments)
        }.value
    }

    private nonisolated static func runSync(_ executable: String, _ arguments: [String]) throws -> String {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("luma-emulators-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let outputURL = folder.appendingPathComponent("output")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: outputURL)
        defer { try? output.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let deadline = ProcessInfo.processInfo.systemUptime + 12
        while process.isRunning {
            if Task.isCancelled || ProcessInfo.processInfo.systemUptime > deadline {
                process.terminate()
                throw LumaError.unavailable(reason: "Emulator command timed out. Refresh and try again.")
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard process.terminationStatus == 0 else {
            throw LumaError.unavailable(reason: "The development tool could not complete the emulator command.")
        }
        let input = try FileHandle(forReadingFrom: outputURL)
        defer { try? input.close() }
        let data = try input.read(upToCount: 1_048_576) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
