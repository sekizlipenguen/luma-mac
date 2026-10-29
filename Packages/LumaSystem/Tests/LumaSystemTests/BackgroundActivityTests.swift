import XCTest
import LumaCore
@testable import LumaSystem

final class BackgroundActivityTests: XCTestCase {
    private let dump = """
    Records for UID 501

     #1:
                     Name: mariadbd-safe
                     Type: legacy agent (0x10008)
               Identifier: 8.homebrew.mxcl.mariadb
                      URL: /Users/501/Library/LaunchAgents/homebrew.mxcl.mariadb.plist
          Executable Path: /opt/homebrew/opt/mariadb/bin/mariadbd-safe
        Parent Identifier: Unknown Developer

     #2:
                     Name: dnsmasq
                     Type: legacy daemon (0x10010)
               Identifier: 16.sh.brew.dnsmasq
                      URL: /Library/LaunchDaemons/sh.brew.dnsmasq.plist
          Executable Path: /opt/homebrew/opt/dnsmasq/sbin/dnsmasq
        Parent Identifier: Unknown Developer

     #3:
                     Name: Cursor
                     Type: app (0x2)
               Identifier: 2.com.todesktop.230313mzl4w4u92
                      URL: /Applications/Cursor.app
        Bundle Identifier: com.todesktop.230313mzl4w4u92

     #4:
                     Name: Cursor - background tasks
                     Type: background tasks (0x2000)
               Identifier: 8192.com.todesktop.230313mzl4w4u92
                 Last Use: 2026-10-28 01:32:16+03:00
        Parent Identifier: 2.com.todesktop.230313mzl4w4u92

     #5:
                     Name: Luma
                     Type: legacy agent (0x10008)
               Identifier: 8.dev.luma.app.schedule
                      URL: /Users/501/Library/LaunchAgents/dev.luma.app.schedule.plist
          Executable Path: /Applications/Luma.app

     #6:
                     Name: ChatGPT
                     Type: app (0x2)
               Identifier: 2.com.openai.codex
                      URL: /Applications/ChatGPT.app
        Bundle Identifier: com.openai.codex

     #7:
                     Name: ChatGPT - background tasks
                     Type: background tasks (0x2000)
               Identifier: 8192.com.openai.codex
                 Last Use: 2026-10-27 20:50:43+03:00
        Parent Identifier: 2.com.openai.codex

     #8:
                     Name: true
                     Type: agent (0x8)
               Identifier: 8.com.todesktop.230313mzl4w4u92.BackgroundActivityCheck
                      URL: Contents/Library/LaunchAgents/check.plist
          Executable Path: /usr/bin/true
        Parent Identifier: 2.com.todesktop.230313mzl4w4u92
    """

    func testParsesBTMAndShowsOnlyRunningActivity() {
        let home = "/Users/tester"
        let items = BackgroundTaskDump.parse(dump, uid: 501, home: home)
        XCTAssertEqual(items.first { $0.name == "mariadbd-safe" }?.url, "\(home)/Library/LaunchAgents/homebrew.mxcl.mariadb.plist")
        XCTAssertEqual(BackgroundTaskDump.launchLabel(from: "8.homebrew.mxcl.mariadb"), "homebrew.mxcl.mariadb")

        let now = ISO8601DateFormatter().date(from: "2026-10-28T01:32:20+03:00")!
        let rows = BackgroundTaskDump.displayRows(
            items,
            launchJobs: ["homebrew.mxcl.mariadb": 3710],
            executables: ["/opt/homebrew/opt/dnsmasq/sbin/dnsmasq": 820],
            runningBundles: ["com.todesktop.230313mzl4w4u92"],
            now: now,
            home: home,
            ownBundleIdentifier: "dev.luma.app",
            ownApplicationPath: "/Applications/Luma.app"
        )
        XCTAssertEqual(rows.map(\.name), ["Cursor", "dnsmasq", "mariadbd-safe"])
        XCTAssertEqual(rows.first { $0.name == "mariadbd-safe" }?.canStop, true)
        XCTAssertEqual(rows.first { $0.name == "dnsmasq" }?.canStop, false)
        XCTAssertEqual(rows.first { $0.name == "Cursor" }?.canStop, false)
        XCTAssertFalse(rows.contains(where: { $0.name == "Luma" || $0.name == "ChatGPT" }))
    }

    func testLaunchPlistsDoNotNeedSfltoolAndSkipAppleAndSelf() {
        let home = "/Users/tester"
        let plists = [
            BackgroundTaskDump.launchPlist(
                from: ["Label": "homebrew.mxcl.mariadb", "ProgramArguments": ["/opt/homebrew/opt/mariadb/bin/mariadbd-safe"]],
                path: "\(home)/Library/LaunchAgents/homebrew.mxcl.mariadb.plist",
                isUser: true
            ),
            BackgroundTaskDump.launchPlist(
                from: ["Label": "sh.brew.dnsmasq", "Program": "/opt/homebrew/opt/dnsmasq/sbin/dnsmasq"],
                path: "/Library/LaunchDaemons/sh.brew.dnsmasq.plist",
                isUser: false
            ),
            BackgroundTaskDump.launchPlist(
                from: ["Label": "com.apple.spotlight", "Program": "/usr/libexec/spotlight"],
                path: "/Library/LaunchAgents/com.apple.spotlight.plist",
                isUser: false
            ),
            BackgroundTaskDump.launchPlist(
                from: ["Label": "dev.luma.app.schedule", "Program": "/Applications/Luma.app"],
                path: "\(home)/Library/LaunchAgents/dev.luma.app.schedule.plist",
                isUser: true
            )
        ].compactMap { $0 }

        XCTAssertEqual(Set(plists.map(\.label)), ["homebrew.mxcl.mariadb", "sh.brew.dnsmasq", "dev.luma.app.schedule"])

        let rows = BackgroundTaskDump.rows(
            from: plists,
            launchJobs: ["homebrew.mxcl.mariadb": 3710],
            executables: ["/opt/homebrew/opt/dnsmasq/sbin/dnsmasq": 820],
            home: home,
            ownBundleIdentifier: "dev.luma.app",
            ownApplicationPath: "/Applications/Luma.app"
        )
        XCTAssertEqual(rows.map(\.name), ["dnsmasq", "mariadbd-safe"])
        XCTAssertEqual(rows.first { $0.name == "mariadbd-safe" }?.canStop, true)
        XCTAssertEqual(rows.first { $0.name == "dnsmasq" }?.canStop, false)
    }
}
