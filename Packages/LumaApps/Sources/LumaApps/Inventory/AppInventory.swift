import AppKit
import Foundation
import LumaCore
import LumaSupport

public struct InstalledApp: Sendable, Equatable, Identifiable {
    public var id: String { bundleURL.path }
    public var name: String
    public var bundleIdentifier: String?
    public var bundleURL: URL
    public var version: String?
    public var byteCount: UInt64?

    public init(name: String, bundleIdentifier: String?, bundleURL: URL, version: String?, byteCount: UInt64?) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.bundleURL = bundleURL
        self.version = version
        self.byteCount = byteCount
    }
}

public struct AppResidueItem: Sendable, Equatable, Identifiable {
    public var id: String { url.path }
    public var kind: String
    public var url: URL
    public var byteCount: UInt64

    public init(kind: String, url: URL, byteCount: UInt64) {
        self.kind = kind
        self.url = url
        self.byteCount = byteCount
    }
}

public struct AppResidueReport: Sendable, Equatable {
    public var app: InstalledApp
    public var items: [AppResidueItem]

    public init(app: InstalledApp, items: [AppResidueItem]) {
        self.app = app
        self.items = items
    }

    public var totalBytes: UInt64 {
        items.reduce(0) { $0 + $1.byteCount }
    }
}

public actor AppInventory {
    public init() {}

    public func listInstalledApps() async throws -> [InstalledApp] {
        try await Task.detached(priority: .utility) {
            try Self.scan()
        }.value
    }

    /// Measures each `.app` bundle (allocated size). Call from a cancellable task; updates stream per app.
    public func measureAppSizes(
        bundleURLs: [URL],
        onUpdate: @Sendable @escaping (String, UInt64) -> Void
    ) async throws {
        try await Task.detached(priority: .utility) {
            for url in bundleURLs {
                try Task.checkCancellation()
                let path = url.standardizedFileURL.path
                let size = (try? FileIO.measureSize(at: url)) ?? 0
                onUpdate(path, size)
            }
        }.value
    }

    private static func scan() throws -> [InstalledApp] {
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/System/Applications")
        ]
        var apps: [InstalledApp] = []
        var seen = Set<String>()

        for root in roots {
            guard FileIO.directoryExists(root) else { continue }
            let contents: [URL]
            do {
                contents = try FileManager.default.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
            } catch {
                // One root failing (permissions) must not wipe the whole list.
                continue
            }

            for url in contents {
                // Resolve aliases / localized wrappers to real .app bundles when possible.
                let appURL = resolvedApplicationURL(url)
                guard appURL.pathExtension.lowercased() == "app" else { continue }
                let key = appURL.standardizedFileURL.path
                guard seen.insert(key).inserted else { continue }

                let bundle = Bundle(url: appURL)
                let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? appURL.deletingPathExtension().lastPathComponent
                let bid = bundle?.bundleIdentifier
                let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

                // Never deep-measure during listing — Xcode-sized apps freeze the screen for minutes.
                apps.append(
                    InstalledApp(
                        name: name,
                        bundleIdentifier: bid,
                        bundleURL: appURL,
                        version: version,
                        byteCount: nil
                    )
                )
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Prefer a real `.app` bundle URL (follows packages / localized folders when needed).
    private static func resolvedApplicationURL(_ url: URL) -> URL {
        if url.pathExtension.lowercased() == "app" { return url }
        // e.g. "Something.app" missing extension edge cases already handled by caller.
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return url
        }
        // Some vendors ship folders that contain a nested .app — pick the first one.
        if let nested = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).first(where: { $0.pathExtension.lowercased() == "app" }) {
            return nested
        }
        return url
    }
}

public actor AppResidueScanner {
    public init() {}

    public func scan(app: InstalledApp) async throws -> AppResidueReport {
        try await Task.detached(priority: .utility) {
            try Self.scanSync(app: app)
        }.value
    }

    private static func scanSync(app: InstalledApp) throws -> AppResidueReport {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let bid = app.bundleIdentifier
        let name = app.bundleURL.deletingPathExtension().lastPathComponent
        var candidates: [(String, URL)] = [
            ("Application", app.bundleURL)
        ]

        if let bid {
            candidates += [
                ("Caches", home.appendingPathComponent("Library/Caches/\(bid)")),
                ("Preferences", home.appendingPathComponent("Library/Preferences/\(bid).plist")),
                ("Application Support", home.appendingPathComponent("Library/Application Support/\(bid)")),
                ("Containers", home.appendingPathComponent("Library/Containers/\(bid)")),
                ("Group Containers", home.appendingPathComponent("Library/Group Containers")),
                ("Saved State", home.appendingPathComponent("Library/Saved Application State/\(bid).savedState")),
                ("Logs", home.appendingPathComponent("Library/Logs/\(bid)")),
                ("LaunchAgents", home.appendingPathComponent("Library/LaunchAgents/\(bid).plist"))
            ]
        }

        candidates += [
            ("Caches (name)", home.appendingPathComponent("Library/Caches/\(name)")),
            ("Application Support (name)", home.appendingPathComponent("Library/Application Support/\(name)")),
            ("Logs (name)", home.appendingPathComponent("Library/Logs/\(name)"))
        ]

        var items: [AppResidueItem] = []
        for (kind, url) in candidates {
            if kind == "Group Containers", let bid {
                // Scan group containers for suffix match
                if let children = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                    for child in children where child.lastPathComponent.contains(bid) {
                        let size = (try? FileIO.measureSize(at: child)) ?? 0
                        items.append(AppResidueItem(kind: kind, url: child, byteCount: size))
                    }
                }
                continue
            }
            guard FileIO.fileExists(url) || FileIO.directoryExists(url) else { continue }
            let size = (try? FileIO.measureSize(at: url)) ?? 0
            items.append(AppResidueItem(kind: kind, url: url, byteCount: size))
        }
        return AppResidueReport(app: app, items: items)
    }
}

public actor UninstallSession {
    public init() {}

    public func uninstall(items: [AppResidueItem], mode: CleanupExecutionMode) async throws -> CleanupResult {
        let started = Date()
        guard mode != .dryRun else {
            let bytes = items.reduce(UInt64(0)) { $0 + $1.byteCount }
            return CleanupResult(
                ruleID: "app-uninstall",
                mode: .dryRun,
                estimatedBytes: bytes,
                recoveredBytes: 0,
                movedToTrash: [],
                deletedPaths: [],
                failedPaths: [],
                startedAt: started,
                finishedAt: .now
            )
        }

        var moved: [String] = []
        var deleted: [String] = []
        var failed: [String] = []
        var recovered: UInt64 = 0

        for item in items {
            do {
                try PathSafety.assertSafeForDeletion(item.url.path)
                if mode == .trash {
                    try await MainActor.run { try FileIO.moveToTrash(item.url) }
                    moved.append(item.url.path)
                } else {
                    try FileIO.removePermanently(item.url)
                    deleted.append(item.url.path)
                }
                recovered += item.byteCount
            } catch {
                failed.append(item.url.path)
            }
        }

        return CleanupResult(
            ruleID: "app-uninstall",
            mode: mode,
            estimatedBytes: items.reduce(0) { $0 + $1.byteCount },
            recoveredBytes: recovered,
            movedToTrash: moved,
            deletedPaths: deleted,
            failedPaths: failed,
            startedAt: started,
            finishedAt: .now
        )
    }
}
