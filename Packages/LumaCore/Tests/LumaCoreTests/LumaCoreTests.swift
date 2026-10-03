import XCTest
@testable import LumaCore

final class LumaCorePackageTests: XCTestCase {
    func testDestinations() {
        XCTAssertFalse(AppDestination.allCases.isEmpty)
    }
}
