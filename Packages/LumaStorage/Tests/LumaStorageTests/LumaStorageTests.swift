import XCTest
@testable import LumaStorage

final class LumaStoragePackageTests: XCTestCase {
    func testClassifier() {
        XCTAssertEqual(StorageClassifier.classify(path: "/a/.docker"), .docker)
        XCTAssertEqual(StorageClassifier.classify(path: "/Users/a/Pictures"), .photos)
        XCTAssertEqual(StorageClassifier.classify(path: "/Users/a/Library/Mail"), .mail)
    }
}
