import XCTest
@testable import LumaApps

final class LumaAppsPackageTests: XCTestCase {
    func testModuleVersion() {
        XCTAssertFalse(LumaAppsModule.version.isEmpty)
    }
}
