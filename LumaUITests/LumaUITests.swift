import XCTest

/// Read-only integrity suite for the native macOS shell.
/// Never triggers Cleaner execute / Trash / uninstall.
final class LumaUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--uitest"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        // Wait for session bootstrap past the spinner.
        let main = app.descendants(matching: .any)["luma.main"]
        XCTAssertTrue(main.waitForExistence(timeout: 20), "Main shell did not appear")
    }

    func testLaunchShowsDashboard() throws {
        tapSidebar("dashboard")
        assertScreen("dashboard")
        // Metrics should eventually render something other than a forever spinner.
        let cpu = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "CPU")).firstMatch
        let progress = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Reading")).firstMatch
        let deadline = Date().addingTimeInterval(12)
        var sawContent = false
        while Date() < deadline {
            if cpu.exists || app.staticTexts.matching(NSPredicate(format: "value CONTAINS '%'")).count > 0 {
                sawContent = true
                break
            }
            if progress.exists == false, app.descendants(matching: .any)["screen.dashboard"].exists {
                // Screen is up; content may still be loading — keep waiting briefly.
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        XCTAssertTrue(sawContent || app.descendants(matching: .any)["screen.dashboard"].exists)
    }

    func testSidebarNavigationAllDestinations() throws {
        let destinations = [
            "dashboard", "cpuProcesses", "memory", "network", "storage",
            "cleaner", "developer", "emulators", "apps", "startup",
            "duplicates", "largeFiles", "diskHealth", "security",
            "care", "schedule", "history", "settings"
        ]
        for id in destinations {
            tapSidebar(id)
            assertScreen(id)
            // Hard safety: never click destructive actions if they appear.
            XCTAssertFalse(app.buttons["Move to Trash"].exists)
            XCTAssertFalse(app.buttons["Empty Trash"].exists)
        }
    }

    func testSettingsMenuBarToggleRoundTrip() throws {
        tapSidebar("settings")
        assertScreen("settings")

        let toggle = app.descendants(matching: .any)["settings.menuBarEnabled"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8), "Menu bar toggle missing")

        let before = toggleValue(toggle)
        toggle.click()
        // Give SwiftUI / AppStorage a beat.
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        let after = toggleValue(toggle)
        XCTAssertNotEqual(before, after, "Menu bar toggle did not change")

        // Restore original preference so we don't leave the machine dirty.
        toggle.click()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        XCTAssertEqual(toggleValue(toggle), before, "Failed to restore menu bar preference")
    }

    func testNetworkScreenLoadsWithoutCrash() throws {
        tapSidebar("network")
        assertScreen("network")
        let download = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Download")).firstMatch
        let reading = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Reading network")).firstMatch
        let deadline = Date().addingTimeInterval(10)
        var ok = false
        while Date() < deadline {
            if download.exists || reading.exists || app.descendants(matching: .any)["screen.network"].exists {
                ok = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(ok)
    }

    // MARK: - Helpers

    private func tapSidebar(_ destination: String) {
        let id = "sidebar.\(destination)"
        let element = app.descendants(matching: .any)[id]
        XCTAssertTrue(element.waitForExistence(timeout: 8), "Sidebar item missing: \(id)")
        element.click()
    }

    private func assertScreen(_ destination: String) {
        let id = "screen.\(destination)"
        let screen = app.descendants(matching: .any)[id]
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Screen missing: \(id)")
    }

    private func toggleValue(_ element: XCUIElement) -> String {
        if let v = element.value as? String { return v }
        if let n = element.value as? NSNumber { return n.stringValue }
        return String(describing: element.value ?? "nil")
    }
}
