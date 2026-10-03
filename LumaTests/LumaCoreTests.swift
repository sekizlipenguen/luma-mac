import XCTest
@testable import LumaCore
@testable import LumaSupport
@testable import LumaCleanup
@testable import LumaStorage

final class PathSafetyTests: XCTestCase {
    func testDeniesSystemPaths() {
        XCTAssertTrue(PathSafety.isDenied("/System/Library"))
        XCTAssertTrue(PathSafety.isDenied("/usr/bin/ls"))
        XCTAssertTrue(PathSafety.isDenied(NSHomeDirectory() + "/.ssh/id_rsa"))
        XCTAssertTrue(PathSafety.isDenied(NSHomeDirectory() + "/Library/Mail"))
        XCTAssertFalse(PathSafety.blocksScan(NSHomeDirectory() + "/Library/Mail"))
        XCTAssertTrue(PathSafety.blocksScan("/System/Library"))
    }

    func testAllowsUserCaches() {
        XCTAssertFalse(PathSafety.isDenied(NSHomeDirectory() + "/Library/Caches/com.example"))
    }
}

final class CleanupDryRunTests: XCTestCase {
    func testDryRunDoesNotDelete() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let file = temp.appendingPathComponent("keep.txt")
        try Data("hello".utf8).write(to: file)

        let rule = PathCleanupRule(
            id: "test-temp",
            title: "Test",
            explanation: "test",
            category: "Test",
            pathProviders: { [file] }
        )
        let result = try await rule.execute(mode: .dryRun)
        XCTAssertEqual(result.recoveredBytes, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        try? FileManager.default.removeItem(at: temp)
    }
}

final class StorageClassifierTests: XCTestCase {
    func testClassifiesXcode() {
        XCTAssertEqual(
            StorageClassifier.classify(path: "/Users/x/Library/Developer/Xcode/DerivedData/Foo"),
            .xcode
        )
    }

    func testClassifiesNode() {
        XCTAssertEqual(StorageClassifier.classify(path: "/Users/x/.npm/_cacache"), .node)
    }

    func testClassifiesPhotosAndAppSupport() {
        XCTAssertEqual(
            StorageClassifier.classify(path: "/Users/x/Pictures/Photos Library.photoslibrary"),
            .photos
        )
        XCTAssertEqual(
            StorageClassifier.classify(path: "/Users/x/Library/Application Support/Google"),
            .appSupport
        )
        XCTAssertEqual(
            StorageClassifier.classify(path: "/Users/x/Library/Containers/com.apple.Safari"),
            .containers
        )
        XCTAssertEqual(
            StorageClassifier.classify(path: "/Users/x/Movies/Holiday"),
            .movies
        )
    }
}

final class DuplicateHashTests: XCTestCase {
    func testSameContentSameHash() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let a = dir.appendingPathComponent("a.bin")
        let b = dir.appendingPathComponent("b.bin")
        let payload = Data(repeating: 0xAB, count: 8192)
        try payload.write(to: a)
        try payload.write(to: b)
        let ha = try FileHasher.sha256Hex(of: a)
        let hb = try FileHasher.sha256Hex(of: b)
        XCTAssertEqual(ha, hb)
        try? FileManager.default.removeItem(at: dir)
    }
}

final class DestinationIntegrityTests: XCTestCase {
    func testEighteenDestinationsGroupedWithoutOverlap() {
        XCTAssertEqual(AppDestination.allCases.count, 18)
        let grouped = AppDestination.SidebarSection.allCases.flatMap(\.destinations)
        XCTAssertEqual(Set(grouped).count, grouped.count, "Sidebar sections should not overlap")
        XCTAssertEqual(Set(grouped), Set(AppDestination.allCases))
    }

    func testSidebarSectionTitlesNonEmpty() {
        for section in AppDestination.SidebarSection.allCases {
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertFalse(section.destinations.isEmpty)
        }
    }
}

final class NumericSafetyTests: XCTestCase {
    func testSaturatingDeltaOnReset() {
        XCTAssertEqual(NumericSafety.saturatingDelta(10, 5), 5)
        XCTAssertEqual(NumericSafety.saturatingDelta(5, 10), 0)
        XCTAssertEqual(NumericSafety.saturatingDelta(UInt64.max, UInt64.max - 1), 1)
    }

    func testUint64FromNonNegativeDoesNotTrap() {
        XCTAssertEqual(NumericSafety.uint64(fromNonNegative: .nan), 0)
        XCTAssertEqual(NumericSafety.uint64(fromNonNegative: .infinity), 0)
        XCTAssertEqual(NumericSafety.uint64(fromNonNegative: -1), 0)
        XCTAssertEqual(NumericSafety.uint64(fromNonNegative: 1024), 1024)
        // Former crash path: wrapping counter ≈ UInt64.max as Double.
        let huge = Double(UInt64.max)
        XCTAssertNoThrow(_ = NumericSafety.uint64(fromNonNegative: huge))
    }

    func testRateStringDoesNotTrapOnPoison() {
        XCTAssertEqual(ByteFormatters.rateString(bytesPerSecond: .nan), "— B/s")
        XCTAssertEqual(ByteFormatters.rateString(bytesPerSecond: .infinity), "— B/s")
        XCTAssertNoThrow(_ = ByteFormatters.rateString(bytesPerSecond: Double(UInt64.max)))
        XCTAssertTrue(ByteFormatters.rateString(bytesPerSecond: 512).contains("B/s"))
    }

    func testPercentAndEnergyTolerateNonFinite() {
        XCTAssertEqual(PercentFormatters.string(.nan), "0%")
        XCTAssertEqual(PercentFormatters.fromZeroToHundred(.infinity), "—%")
        XCTAssertFalse(EnergyFormatters.string(milliwatts: .nan, lifetimeJoules: .infinity).isEmpty)
    }

    func testDiskUsedBytesDoesNotWrap() {
        let volume = DiskVolumeMetrics(
            path: "/",
            name: "Disk",
            totalBytes: 100,
            freeBytes: 150,
            fileSystem: "apfs"
        )
        XCTAssertEqual(volume.usedBytes, 0)
    }
}

final class LumaDeepLinkTests: XCTestCase {
    func testParsesFolderSizeURL() throws {
        let url = try XCTUnwrap(LumaDeepLink.folderSizeURL(paths: ["/Users/a/Movies", "/tmp/x"]))
        XCTAssertEqual(LumaDeepLink.parse(url), .folderSize(paths: ["/Users/a/Movies", "/tmp/x"]))
    }

    func testRejectsOtherSchemes() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/folder-size?path=/tmp"))
        XCTAssertNil(LumaDeepLink.parse(url))
    }
}
