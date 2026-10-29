import XCTest
@testable import LumaCleanup

final class LumaCleanupPackageTests: XCTestCase {
    func testCatalogNotEmpty() {
        XCTAssertFalse(CleanupRuleCatalog.allRules().isEmpty)
    }

    func testStaleAppVersionRuleLivesInCleaner() {
        let general = CleanupRuleCatalog.generalRules()
        let stale = general.first { $0.id == "stale-app-versions" }
        XCTAssertEqual(stale?.category, "General")
        XCTAssertEqual(stale?.riskLevel, .caution)
        XCTAssertEqual(general.first { $0.id == "google-updater-cache" }?.category, "General")
        XCTAssertFalse(CleanupRuleCatalog.developerRules().contains { $0.id == "stale-app-versions" })
    }
}

final class StaleAppVersionFinderTests: XCTestCase {
    func testKeepsNewestInstalledAndroidStudioAndDropsTheRest() {
        let names = [
            "AndroidStudio4.1", "AndroidStudio4.2", "AndroidStudio2020.3", "AndroidStudio2021.2",
            "AndroidStudio2022.3", "AndroidStudio2024.2", "AndroidStudio2024.3", "AndroidStudio2024.3.2",
            "AndroidStudio2025.1.1", "AndroidStudio2025.1.3", "AndroidStudio2025.2.3",
            "AndroidStudio2025.3.1", "AndroidStudio2025.3.2", "AndroidStudio2025.3.3",
            "Chrome", "Chrome for Testing", "GoogleUpdater", "Toolbox", "Daemon", "Phpstorm"
        ]
        let stale = StaleAppVersionFinder.staleNames(
            folderNames: names,
            installed: [InstalledProductVersion(productKey: "androidstudio", version: [2025, 3])]
        )
        XCTAssertFalse(stale.contains("AndroidStudio2025.3.3"))
        XCTAssertTrue(stale.contains("AndroidStudio2025.3.2"))
        XCTAssertTrue(stale.contains("AndroidStudio4.1"))
        XCTAssertEqual(stale.filter { $0.hasPrefix("AndroidStudio") }.count, 13)
        XCTAssertFalse(stale.contains("Chrome"))
        XCTAssertFalse(stale.contains("GoogleUpdater"))
        XCTAssertFalse(stale.contains("Phpstorm"))
    }

    func testKeepsPhpStormReleaseAndListsRemovedApps() {
        let stale = StaleAppVersionFinder.staleNames(
            folderNames: ["PhpStorm2026.1", "PhpStorm2026.2", "DataGrip2021.1", "CodeWithMeGuest211.7142.44"],
            installed: [InstalledProductVersion(productKey: "phpstorm", version: [2026, 2, 3])]
        )
        XCTAssertEqual(stale, ["CodeWithMeGuest211.7142.44", "DataGrip2021.1", "PhpStorm2026.1"])
    }

    func testKeepsOneFolderPerInstalledMajor() {
        let stale = StaleAppVersionFinder.staleNames(
            folderNames: ["AndroidStudio2024.3.1", "AndroidStudio2024.3.2", "AndroidStudio2025.3.3"],
            installed: [
                InstalledProductVersion(productKey: "androidstudio", version: [2024, 3]),
                InstalledProductVersion(productKey: "androidstudio", version: [2025, 3])
            ]
        )
        XCTAssertEqual(stale, ["AndroidStudio2024.3.1"])
    }

    func testProductKeyStripsTrailingVersionFromAppName() {
        XCTAssertEqual(StaleAppVersionFinder.productKey(from: "Android Studio"), "androidstudio")
        XCTAssertEqual(StaleAppVersionFinder.productKey(from: "Adobe Photoshop 2025"), "adobephotoshop")
        XCTAssertEqual(StaleAppVersionFinder.productKey(from: "PhpStorm"), "phpstorm")
    }

    func testYearFoldersAndHyphenatedNames() {
        let stale = StaleAppVersionFinder.staleNames(
            folderNames: ["Adobe Photoshop 2024", "Adobe Photoshop 2025", "SoapUI-5.7.2", "Profile 1"],
            installed: [InstalledProductVersion(productKey: "adobephotoshop", version: [2025])]
        )
        XCTAssertEqual(stale, ["Adobe Photoshop 2024", "SoapUI-5.7.2"])
    }

    func testKeepsNewestWhenInstalledVersionMatchesNothing() {
        let stale = StaleAppVersionFinder.staleNames(
            folderNames: ["Tool1.0", "Tool2.4"],
            installed: [InstalledProductVersion(productKey: "tool", version: [9, 9])]
        )
        XCTAssertEqual(stale, ["Tool1.0"])
    }

    func testStaleFolderURLsSkipCurrentVersionAndUpdaterPayload() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let google = home.appendingPathComponent("Library/Application Support/Google", isDirectory: true)
        let jets = home.appendingPathComponent("Library/Application Support/JetBrains", isDirectory: true)
        for name in ["AndroidStudio2024.1", "AndroidStudio2025.3.3"] {
            try fm.createDirectory(at: google.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        try fm.createDirectory(at: google.appendingPathComponent("GoogleUpdater/152.0.7933.0"), withIntermediateDirectories: true)
        try fm.createDirectory(at: google.appendingPathComponent("Chrome"), withIntermediateDirectories: true)
        try fm.createDirectory(at: jets.appendingPathComponent("PhpStorm2026.1"), withIntermediateDirectories: true)
        try fm.createDirectory(at: jets.appendingPathComponent("PhpStorm2026.2"), withIntermediateDirectories: true)
        try fm.createDirectory(at: jets.appendingPathComponent("DataGrip2021.1"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: home) }

        let names = Set(
            StaleAppVersionFinder.staleFolderURLs(
                home: home,
                installed: [
                    InstalledProductVersion(productKey: "androidstudio", version: [2025, 3]),
                    InstalledProductVersion(productKey: "phpstorm", version: [2026, 2, 3])
                ]
            ).map(\.lastPathComponent)
        )
        XCTAssertEqual(names, ["AndroidStudio2024.1", "DataGrip2021.1", "PhpStorm2026.1"])
    }

    func testReadsInstalledAppVersionFromPlist() throws {
        let fm = FileManager.default
        let app = fm.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("Android Studio.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try fm.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleName": "Android Studio",
            "CFBundleShortVersionString": "2025.3"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        defer { try? fm.removeItem(at: app.deletingLastPathComponent()) }

        XCTAssertEqual(
            StaleAppVersionFinder.products(in: app),
            [InstalledProductVersion(productKey: "androidstudio", version: [2025, 3])]
        )
    }
}
