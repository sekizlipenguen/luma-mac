import XCTest
@testable import LumaSystem

final class LumaSystemPackageTests: XCTestCase {
    func testCPUSample() async throws {
        let sampler = CPUMetricsSampler()
        _ = try await sampler.sample()
        let second = try await sampler.sample()
        XCTAssertGreaterThanOrEqual(second.overallUsage, 0)
        XCTAssertLessThanOrEqual(second.overallUsage, 1)
    }

    func testEnergyConsumersSample() async throws {
        let lister = ProcessLister()
        _ = try await lister.topEnergyConsumers(limit: 5)
        try await Task.sleep(nanoseconds: 400_000_000)
        let second = try await lister.topEnergyConsumers(limit: 5)
        // Energy may be empty on some hosts; just ensure the API is callable.
        XCTAssertLessThanOrEqual(second.count, 5)
    }

    func testHardwarePortParsingFiltersVPNAndBridge() {
        let text = """
        Hardware Port: Wi-Fi
        Device: en0

        Hardware Port: Ethernet
        Device: en1

        Hardware Port: Thunderbolt Bridge
        Device: bridge0

        Hardware Port: VPN Tunnel
        Device: utun3
        """
        let ports = NetworkStackRefresher.parseHardwarePorts(text)
        XCTAssertEqual(ports.count, 4)
        let renewable = ports.filter { NetworkStackRefresher.isRenewableHardwarePort($0.port) }
        XCTAssertEqual(Set(renewable.map(\.port)), Set(["Wi-Fi", "Ethernet"]))
        XCTAssertTrue(NetworkStackRefresher.isWiFiHardwarePort("Wi-Fi"))
        XCTAssertFalse(NetworkStackRefresher.isWiFiHardwarePort("Ethernet"))
    }

    func testMacCareDuplicateGroupIdentities() {
        let hitA = MacCareAppHit(
            path: "/Applications/Luma.app",
            name: "Luma",
            bundleIdentifier: "dev.luma.app",
            exists: true,
            isRunningApp: true,
            isInApplications: true,
            isDevLeftover: false
        )
        let hitB = MacCareAppHit(
            path: "/tmp/Luma.app",
            name: "Luma",
            bundleIdentifier: "dev.luma.app",
            exists: false,
            isRunningApp: false,
            isInApplications: false,
            isDevLeftover: true
        )
        let group = MacCareDuplicateGroup(key: "dev.luma.app", kind: .bundleIdentifier, hits: [hitA, hitB])
        XCTAssertEqual(group.hits.count, 2)
        XCTAssertEqual(group.id, "dev.luma.app")
        let report = MacCareScanReport(groups: [group], leftovers: [hitB], note: "test")
        XCTAssertEqual(report.duplicatePathCount, 2)
        XCTAssertTrue(report.hasIssues)
        XCTAssertTrue(MacCareService.isDevBuildPath("/Users/x/Library/Developer/Xcode/DerivedData/Luma-abc/Build/Products/Debug/Luma.app"))
        XCTAssertTrue(MacCareService.isDevBuildPath("/tmp/LumaUITests-Runner.app"))
        XCTAssertFalse(MacCareService.isDevBuildPath("/Applications/Luma.app"))
        XCTAssertTrue(MacCareService.isApplicationsInstall("/Applications/Luma.app"))
        XCTAssertTrue(MacCareService.isNonMacOSBuildPath(
            "/Users/x/Library/Developer/Xcode/DerivedData/GratisBeauty-abc/Build/Products/Debug-iphonesimulator/GratisBeauty.app"
        ))
        XCTAssertFalse(MacCareService.isNonMacOSBuildPath(
            "/Users/x/Library/Developer/Xcode/DerivedData/Luma-abc/Build/Products/Debug/Luma.app"
        ))
    }
}
