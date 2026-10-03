import XCTest
@testable import LumaSupport

final class LumaSupportPackageTests: XCTestCase {
    func testByteFormatter() {
        XCTAssertFalse(ByteFormatters.string(for: UInt64(1024)).isEmpty)
    }
}
