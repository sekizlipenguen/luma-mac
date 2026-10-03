import XCTest
import LumaCore
@testable import LumaSystem

final class EmulatorTests: XCTestCase {
    private let uuid = "00000000-0000-0000-0000-000000000001"

    private var booted: String {
        """
        {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-6":[
        {"udid":"\(uuid)","name":"Test Device","state":"Booted","isAvailable":true},
        {"udid":"00000000-0000-0000-0000-000000000002","name":"Stopped","state":"Shutdown"},
        {"udid":"00000000-0000-0000-0000-000000000003","name":"Unavailable","state":"Booted","isAvailable":false}]}}
        """
    }

    func testIOSOnlyIncludesAvailableBootedDevices() throws {
        let devices = try EmulatorService.parseIOS(booted)
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices.first?.name, "Test Device")
        XCTAssertEqual(devices.first?.runtime, "iOS-18-6")
        XCTAssertThrowsError(try EmulatorService.parseIOS("broken JSON"))
    }

    func testAndroidExcludesPhysicalPhonesAndRemoteConnections() {
        let devices = EmulatorService.parseAndroid("""
        List of devices attached
        emulator-5554 device product:sdk model:Virtual
        emulator-5556 offline
        R58PHONE device product:phone
        192.168.1.10:5555 device
        emulator-5555 device
        """)
        XCTAssertEqual(devices.map(\.deviceID), ["emulator-5554", "emulator-5556"])
        XCTAssertTrue(devices[0].isOnline)
        XCTAssertFalse(devices[1].isOnline)
    }

    func testIdentifiersRejectAllShellSyntaxAndPhysicalDeviceIDs() {
        for value in ["all", "booted", "--help", "emulator-5554;kill", "emulator-5554\n", "emulator--5554", "R58PHONE"] {
            XCTAssertFalse(EmulatorService.isValidID(value, platform: .iOS))
            XCTAssertFalse(EmulatorService.isValidID(value, platform: .android))
        }
        XCTAssertTrue(EmulatorService.isValidID(uuid, platform: .iOS))
        XCTAssertTrue(EmulatorService.isValidID("emulator-5554", platform: .android))
    }

    func testIOSShutdownIsDeviceScopedAndVerified() async throws {
        let fixture = ToolFixture(outputs: [booted, "", "{\"devices\":{}}"])
        let service = EmulatorService(adbPath: nil) { executable, args in await fixture.run(executable, args) }
        let device = try XCTUnwrap(try EmulatorService.parseIOS(booted).first)
        let result = try await service.stop(device)
        guard case .stopped = result else { return XCTFail("Expected verified shutdown") }
        let commands = await fixture.commands
        XCTAssertEqual(commands.map(\.0), Array(repeating: "/usr/bin/xcrun", count: 3))
        XCTAssertEqual(commands[1].1, ["simctl", "shutdown", uuid])
        XCTAssertFalse(commands.contains { $0.1.contains("all") || $0.1.contains("erase") || $0.1.contains("delete") })
    }

    func testRemainingBootedDeviceDoesNotReportSuccess() async throws {
        let fixture = ToolFixture(outputs: [booted, "", booted])
        let service = EmulatorService(adbPath: nil) { executable, args in await fixture.run(executable, args) }
        let device = try XCTUnwrap(try EmulatorService.parseIOS(booted).first)
        do { _ = try await service.stop(device); XCTFail("Still booted cannot pass") } catch { }
    }

    func testAndroidShutdownUsesOnlySelectedEmulator() async throws {
        let fixture = ToolFixture(outputs: ["emulator-5554 device\nR58PHONE device", "OK", "R58PHONE device"])
        let service = EmulatorService(adbPath: "/sdk/adb") { executable, args in await fixture.run(executable, args) }
        let device = RunningEmulator(deviceID: "emulator-5554", name: "Test", runtime: "Android", platform: .android)
        _ = try await service.stop(device)
        let commands = await fixture.commands
        XCTAssertEqual(commands[1].1, ["-s", "emulator-5554", "emu", "kill"])
        XCTAssertFalse(commands.contains { $0.1.contains("R58PHONE") })
    }

    func testInvalidAndOfflineDevicesNeverReceiveShutdown() async throws {
        let fixture = ToolFixture(outputs: ["emulator-5554 offline"])
        let service = EmulatorService(adbPath: "/sdk/adb") { executable, args in await fixture.run(executable, args) }
        let invalid = RunningEmulator(deviceID: "R58PHONE", name: "Phone", runtime: "Android", platform: .android)
        do { _ = try await service.stop(invalid); XCTFail("Must reject physical devices") } catch { }
        let before = await fixture.commands
        XCTAssertTrue(before.isEmpty)
        let offline = RunningEmulator(deviceID: "emulator-5554", name: "Test", runtime: "Android", platform: .android)
        do { _ = try await service.stop(offline); XCTFail("Must reject offline devices") } catch { }
        let commands = await fixture.commands
        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands[0].1, ["devices", "-l"])
    }
}

private actor ToolFixture {
    private var outputs: [String]
    private(set) var commands: [(String, [String])] = []
    init(outputs: [String]) { self.outputs = outputs }
    func run(_ executable: String, _ args: [String]) -> String {
        commands.append((executable, args))
        return outputs.isEmpty ? "" : outputs.removeFirst()
    }
}
