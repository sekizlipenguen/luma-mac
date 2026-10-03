import XCTest
@testable import LumaUI

final class LumaUIPackageTests: XCTestCase {
    func testModuleVersion() {
        XCTAssertFalse(LumaUIModule.version.isEmpty)
    }
}
