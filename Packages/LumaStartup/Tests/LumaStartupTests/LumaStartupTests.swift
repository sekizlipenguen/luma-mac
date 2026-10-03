import XCTest
@testable import LumaStartup

final class LumaStartupPackageTests: XCTestCase {
    func testModuleVersion() {
        XCTAssertFalse(LumaStartupModule.version.isEmpty)
    }
}
