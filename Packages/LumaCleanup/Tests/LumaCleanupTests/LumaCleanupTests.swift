import XCTest
@testable import LumaCleanup

final class LumaCleanupPackageTests: XCTestCase {
    func testCatalogNotEmpty() {
        XCTAssertFalse(CleanupRuleCatalog.allRules().isEmpty)
    }
}
