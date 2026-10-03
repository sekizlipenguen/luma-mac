import Foundation

/// One registered `.app` path discovered during Mac Care scans.
public struct MacCareAppHit: Sendable, Equatable, Identifiable, Hashable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let bundleIdentifier: String?
    public let exists: Bool
    /// True when this path is the currently running Luma bundle (if any).
    public let isRunningApp: Bool
    /// True when path is under `/Applications` or `~/Applications` (preferred install).
    public let isInApplications: Bool
    /// Xcode DerivedData / Build/Products / UITest Runner — typical Launchpad ghosts.
    public let isDevLeftover: Bool

    public init(
        path: String,
        name: String,
        bundleIdentifier: String?,
        exists: Bool,
        isRunningApp: Bool,
        isInApplications: Bool,
        isDevLeftover: Bool
    ) {
        self.path = path
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.exists = exists
        self.isRunningApp = isRunningApp
        self.isInApplications = isInApplications
        self.isDevLeftover = isDevLeftover
    }
}

/// Apps that share a name or bundle id across multiple paths (Spotlight / Launchpad ghosts).
public struct MacCareDuplicateGroup: Sendable, Equatable, Identifiable {
    public var id: String { key }
    public let key: String
    public let kind: Kind
    public let hits: [MacCareAppHit]

    public enum Kind: String, Sendable, Equatable {
        case bundleIdentifier
        case displayName
    }

    public init(key: String, kind: Kind, hits: [MacCareAppHit]) {
        self.key = key
        self.kind = kind
        self.hits = hits
    }
}

public struct MacCareScanReport: Sendable, Equatable {
    public let groups: [MacCareDuplicateGroup]
    /// Dev/build leftovers even when they are not part of a duplicate group (e.g. UITests-Runner alone).
    public let leftovers: [MacCareAppHit]
    public let scannedAt: Date
    public let note: String

    public var duplicatePathCount: Int {
        groups.reduce(0) { $0 + $1.hits.count }
    }

    public var hasIssues: Bool {
        !groups.isEmpty || !leftovers.isEmpty
    }

    public init(
        groups: [MacCareDuplicateGroup],
        leftovers: [MacCareAppHit] = [],
        scannedAt: Date = .now,
        note: String
    ) {
        self.groups = groups
        self.leftovers = leftovers
        self.scannedAt = scannedAt
        self.note = note
    }
}

public struct MacCareActionStep: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let succeeded: Bool
    public let detail: String?

    public init(id: String, title: String, succeeded: Bool, detail: String? = nil) {
        self.id = id
        self.title = title
        self.succeeded = succeeded
        self.detail = detail
    }
}

public struct MacCareActionReport: Sendable, Equatable {
    public let steps: [MacCareActionStep]
    public let completedAt: Date
    public let cancelled: Bool

    public init(steps: [MacCareActionStep], completedAt: Date = .now, cancelled: Bool = false) {
        self.steps = steps
        self.completedAt = completedAt
        self.cancelled = cancelled
    }
}

/// Honest macOS hygiene: duplicate Spotlight / Launch Services entries, Launchpad DB, icon cache.
///
/// Does **not** invent “boost” scores. Actions are allowlisted shell/CoreServices tools;
/// privileged ones ask for an admin password via `osascript`.
public enum MacCareService {
    public enum CareError: Error, LocalizedError, Sendable {
        case cancelled
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case .cancelled: "Authentication cancelled"
            case .failed(let message): message
            }
        }
    }

    // MARK: - Diagnose

    /// Finds duplicate registrations and Xcode/UITest leftovers that clutter Launchpad / Spotlight.
    public static func scanDuplicateApps(
        runningBundleURL: URL? = Bundle.main.bundleURL,
        runningBundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) async -> MacCareScanReport {
        await Task.detached(priority: .utility) {
            scanDuplicateAppsSync(
                runningBundleURL: runningBundleURL,
                runningBundleIdentifier: runningBundleIdentifier
            )
        }.value
    }

    nonisolated private static func scanDuplicateAppsSync(
        runningBundleURL: URL?,
        runningBundleIdentifier: String?
    ) -> MacCareScanReport {
        var byPath: [String: MacCareAppHit] = [:]
        let runningPath = runningBundleURL?.standardizedFileURL.path

        for url in candidateAppURLs(runningBundleIdentifier: runningBundleIdentifier) {
            let path = url.standardizedFileURL.path
            guard byPath[path] == nil else { continue }
            guard isMacOSAppBundle(at: url) else { continue }
            byPath[path] = makeHit(at: url, runningPath: runningPath, fallbackBundleID: nil)
        }

        // Every Spotlight path for the running app’s bundle id (classic “two Lumas”).
        if let bid = runningBundleIdentifier, !bid.isEmpty {
            for path in mdfindBundleIdentifier(bid) {
                guard byPath[path] == nil else { continue }
                let url = URL(fileURLWithPath: path)
                guard isMacOSAppBundle(at: url) else { continue }
                byPath[path] = makeHit(
                    at: url,
                    runningPath: runningPath,
                    fallbackBundleID: bid
                )
            }
        }

        let hits = Array(byPath.values)
        var groups: [MacCareDuplicateGroup] = []

        let byBundle = Dictionary(grouping: hits.filter { ($0.bundleIdentifier ?? "").isEmpty == false }) {
            $0.bundleIdentifier!.lowercased()
        }
        for (key, list) in byBundle where list.count > 1 {
            groups.append(
                MacCareDuplicateGroup(
                    key: key,
                    kind: .bundleIdentifier,
                    hits: list.sorted { $0.path < $1.path }
                )
            )
        }

        let byName = Dictionary(grouping: hits) { $0.name.lowercased() }
        for (key, list) in byName where list.count > 1 {
            let paths = Set(list.map(\.path))
            let already = groups.contains { Set($0.hits.map(\.path)) == paths }
            if already { continue }
            groups.append(
                MacCareDuplicateGroup(
                    key: key,
                    kind: .displayName,
                    hits: list.sorted { $0.path < $1.path }
                )
            )
        }

        groups.sort { lhs, rhs in
            if lhs.hits.count != rhs.hits.count { return lhs.hits.count > rhs.hits.count }
            return lhs.key < rhs.key
        }

        let leftovers = hits
            .filter(\.isDevLeftover)
            .sorted { $0.path < $1.path }

        return MacCareScanReport(
            groups: groups,
            leftovers: leftovers,
            note: "Spotlight lists every .app it can see. Unregister alone is not enough while DerivedData still has Luma.app. Luma moves those leftovers to Trash, unregisters them, and keeps /Applications/Luma.app. Xcode recreates build products on the next build."
        )
    }

    nonisolated private static func makeHit(
        at url: URL,
        runningPath: String?,
        fallbackBundleID: String?
    ) -> MacCareAppHit {
        let path = url.standardizedFileURL.path
        let info = readAppInfo(at: url)
        return MacCareAppHit(
            path: path,
            name: info.name,
            bundleIdentifier: info.bundleID ?? fallbackBundleID,
            exists: FileManager.default.fileExists(atPath: path),
            isRunningApp: runningPath == path,
            isInApplications: isApplicationsInstall(path),
            isDevLeftover: isDevBuildPath(path) || isUITestRunnerName(info.name) || isUITestRunnerName(url.deletingPathExtension().lastPathComponent)
        )
    }

    // MARK: - Actions

    /// Unregisters paths, moves leftover `.app` bundles to Trash (Spotlight indexes files that still exist),
    /// resets Launchpad when possible, re-registers the keep path (usually `/Applications/Luma.app`).
    public static func hideFromLaunchpad(
        paths: [String],
        keepRegisteredPath: String? = "/Applications/Luma.app"
    ) async throws -> MacCareActionReport {
        try await Task.detached(priority: .userInitiated) {
            try hideFromLaunchpadSync(paths: paths, keepRegisteredPath: keepRegisteredPath)
        }.value
    }

    /// Unregisters selected paths from Launch Services (`lsregister -u`). Missing files are fine — that is the ghost case.
    public static func unregister(paths: [String]) async throws -> MacCareActionReport {
        try await Task.detached(priority: .userInitiated) {
            try unregisterSync(paths: paths, resetLaunchpad: false, keepRegisteredPath: nil)
        }.value
    }

    /// Full Launch Services rebuild — fixes stubborn Spotlight duplicates. Restarts Dock afterward.
    public static func rebuildLaunchServices() async throws -> MacCareActionReport {
        try await Task.detached(priority: .userInitiated) {
            try rebuildLaunchServicesSync()
        }.value
    }

    /// Deletes the user Launchpad SQLite DBs and relaunches Dock (icons reshuffle).
    public static func resetLaunchpad() async throws -> MacCareActionReport {
        try await Task.detached(priority: .userInitiated) {
            try resetLaunchpadSync()
        }.value
    }

    /// Clears the system icon services store (admin password) and relaunches Dock / Finder.
    public static func flushIconCache() async throws -> MacCareActionReport {
        try await Task.detached(priority: .userInitiated) {
            try flushIconCacheSync()
        }.value
    }

    /// Path heuristics shared with tests.
    public static func isDevBuildPath(_ path: String) -> Bool {
        path.contains("/DerivedData/")
            || path.contains("/Build/Products/")
            || path.hasSuffix("-Runner.app")
            || path.contains("UITests-Runner")
    }

    public static func isApplicationsInstall(_ path: String) -> Bool {
        if path.hasPrefix("/Applications/") { return true }
        let homeApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .path
        return path.hasPrefix(homeApps + "/")
    }

    /// iPhone / Simulator / watchOS / etc. product folders — not Launchpad Mac apps.
    public static func isNonMacOSBuildPath(_ path: String) -> Bool {
        let markers = [
            "iphonesimulator", "iphoneos",
            "appletvsimulator", "appletvos",
            "watchsimulator", "watchos",
            "xrsimulator", "xros"
        ]
        let lower = path.lowercased()
        return markers.contains { lower.contains($0) }
    }

    /// True when the bundle looks like a macOS `.app` (has Contents/MacOS and is not an iOS product).
    public static func isMacOSAppBundle(at url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        if isNonMacOSBuildPath(path) { return false }
        let contents = url.appendingPathComponent("Contents", isDirectory: true)
        let macosExec = contents.appendingPathComponent("MacOS", isDirectory: true)
        // iOS apps often lack Contents/MacOS; some wrappers still have Contents — require MacOS dir.
        guard FileManager.default.fileExists(atPath: macosExec.path) else { return false }
        let plistURL = contents.appendingPathComponent("Info.plist")
        if let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] {
            if let platform = dict["DTPlatformName"] as? String {
                let p = platform.lowercased()
                if p.contains("iphone") || p.contains("appletv") || p.contains("watch") || p == "xros" {
                    return false
                }
            }
            if let platforms = dict["CFBundleSupportedPlatforms"] as? [String] {
                let lower = platforms.map { $0.lowercased() }
                let mac = lower.contains { $0.contains("macos") }
                let ios = lower.contains { $0.contains("iphone") || $0.contains("ios") }
                if ios && !mac { return false }
            }
        }
        return true
    }

    // MARK: - Sync helpers

    nonisolated private static func hideFromLaunchpadSync(
        paths: [String],
        keepRegisteredPath: String?
    ) throws -> MacCareActionReport {
        let lsregister = lsregisterPath()
        guard let lsregister else {
            throw CareError.failed("lsregister not found on this Mac")
        }

        var steps: [MacCareActionStep] = []
        let keep = keepRegisteredPath.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        let uniquePaths = Array(Set(paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path }))
            .filter { path in
                if let keep, path == keep { return false }
                if isApplicationsInstall(path) && !isDevBuildPath(path) { return false }
                return true
            }
            .sorted()

        // 1) Unregister while files still exist (best chance for lsregister -u).
        for path in uniquePaths {
            if isNonMacOSBuildPath(path) || !isMacOSAppBundle(at: URL(fileURLWithPath: path)) {
                // Still try to remove from disk index if it's a leftover simulator path under DerivedData — skip.
                steps.append(
                    MacCareActionStep(
                        id: "skip-\(path)",
                        title: "Skipped (not a Mac app)",
                        succeeded: true,
                        detail: path
                    )
                )
                continue
            }
            let (status, _, stderr) = runCapture(lsregister, ["-u", path])
            let isKnownSkip = stderr.contains("-10814") || stderr.contains("10814")
            steps.append(
                MacCareActionStep(
                    id: "unreg-\(path)",
                    title: isKnownSkip ? "Skipped (not a Mac app)" : "Unregister",
                    succeeded: status == 0 || isKnownSkip,
                    detail: path
                )
            )
        }

        // 2) Move leftovers to Trash — Spotlight keeps showing apps that still exist on disk.
        for path in uniquePaths {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                steps.append(
                    MacCareActionStep(
                        id: "trash-missing-\(path)",
                        title: "Already gone",
                        succeeded: true,
                        detail: path
                    )
                )
                continue
            }
            if isNonMacOSBuildPath(path) { continue }
            do {
                var resulting: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
                let trashedPath = (resulting as URL?)?.path
                if let trashedPath {
                    _ = runCapture(lsregister, ["-u", trashedPath])
                }
                steps.append(
                    MacCareActionStep(
                        id: "trash-\(path)",
                        title: "Move to Trash",
                        succeeded: true,
                        detail: trashedPath.map { "\(path) → \($0)" } ?? path
                    )
                )
            } catch {
                steps.append(
                    MacCareActionStep(
                        id: "trash-\(path)",
                        title: "Move to Trash",
                        succeeded: false,
                        detail: "\(path) — \(error.localizedDescription)"
                    )
                )
            }
        }

        // 3) Launchpad DB (when present on this macOS) + Dock restart.
        let pad = try resetLaunchpadSync()
        steps.append(contentsOf: pad.steps)

        // 4) Keep the real install registered.
        if let keep, FileManager.default.fileExists(atPath: keep) {
            let (status, _, stderr) = runCapture(lsregister, ["-f", "-R", "-trusted", keep])
            steps.append(
                MacCareActionStep(
                    id: "keep",
                    title: "Keep real install registered",
                    succeeded: status == 0,
                    detail: status == 0 ? keep : (stderr.isEmpty ? keep : stderr)
                )
            )
        }

        return MacCareActionReport(steps: steps)
    }

    nonisolated private static func unregisterSync(
        paths: [String],
        resetLaunchpad: Bool,
        keepRegisteredPath: String?
    ) throws -> MacCareActionReport {
        let lsregister = lsregisterPath()
        guard let lsregister else {
            throw CareError.failed("lsregister not found on this Mac")
        }
        var steps: [MacCareActionStep] = []
        let uniquePaths = Array(Set(paths)).sorted()
        for path in uniquePaths {
            // iOS / Simulator bundles are not Launch Services citizens — skip quietly.
            if isNonMacOSBuildPath(path) || !isMacOSAppBundle(at: URL(fileURLWithPath: path)) {
                steps.append(
                    MacCareActionStep(
                        id: path,
                        title: "Skipped (not a Mac app)",
                        succeeded: true,
                        detail: path
                    )
                )
                continue
            }
            let (status, _, stderr) = runCapture(lsregister, ["-u", path])
            // -10814 = kLSApplicationNotFoundErr (often simulator / non-Mac bundles).
            let isKnownSkip = stderr.contains("-10814") || stderr.contains("10814")
            let ok = status == 0 || isKnownSkip
            steps.append(
                MacCareActionStep(
                    id: path,
                    title: isKnownSkip ? "Skipped (not a Mac app)" : "Unregister",
                    succeeded: ok,
                    detail: ok ? path : (stderr.isEmpty ? path : "\(path) — \(stderr)")
                )
            )
        }

        if resetLaunchpad {
            let pad = try resetLaunchpadSync()
            steps.append(contentsOf: pad.steps)
        } else {
            _ = runCapture("/usr/bin/killall", ["Dock"])
            steps.append(
                MacCareActionStep(
                    id: "dock",
                    title: "Restart Dock",
                    succeeded: true,
                    detail: "Helps Launchpad / Spotlight refresh"
                )
            )
        }

        if let keep = keepRegisteredPath,
           FileManager.default.fileExists(atPath: keep)
        {
            let (status, _, stderr) = runCapture(lsregister, ["-f", "-R", "-trusted", keep])
            steps.append(
                MacCareActionStep(
                    id: "keep",
                    title: "Keep real install registered",
                    succeeded: status == 0,
                    detail: status == 0 ? keep : (stderr.isEmpty ? keep : stderr)
                )
            )
        }

        return MacCareActionReport(steps: steps)
    }

    nonisolated private static func rebuildLaunchServicesSync() throws -> MacCareActionReport {
        let lsregister = lsregisterPath()
        guard let lsregister else {
            throw CareError.failed("lsregister not found on this Mac")
        }
        let script = """
        #!/bin/bash
        echo LUMA_STEP:ls
        \(shellSingleQuoted(lsregister)) -kill -r -domain local -domain system -domain user
        echo LUMA_OK:ls
        /usr/bin/killall Dock 2>/dev/null || true
        echo LUMA_OK:dock
        echo LUMA_DONE
        """
        let (status, stdout, stderr) = try runPrivilegedScriptFile(script)
        if status != 0 {
            throw mapAuthError(status: status, stdout: stdout, stderr: stderr)
        }
        return MacCareActionReport(steps: [
            MacCareActionStep(
                id: "ls",
                title: "Rebuild Launch Services",
                succeeded: stdout.contains("LUMA_OK:ls"),
                detail: "lsregister -kill -r"
            ),
            MacCareActionStep(
                id: "dock",
                title: "Restart Dock",
                succeeded: stdout.contains("LUMA_OK:dock"),
                detail: nil
            )
        ])
    }

    nonisolated private static func resetLaunchpadSync() throws -> MacCareActionReport {
        let support = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Dock", isDirectory: true)
        var removed = 0
        if let files = try? FileManager.default.contentsOfDirectory(
            at: support,
            includingPropertiesForKeys: nil
        ) {
            for file in files where file.pathExtension == "db" {
                try? FileManager.default.removeItem(at: file)
                removed += 1
            }
        }
        _ = runCapture("/usr/bin/killall", ["Dock"])
        return MacCareActionReport(steps: [
            MacCareActionStep(
                id: "db",
                title: "Reset Launchpad database",
                succeeded: true,
                detail: "Removed \(removed) Dock database file(s)"
            ),
            MacCareActionStep(
                id: "dock",
                title: "Restart Dock",
                succeeded: true,
                detail: "Launchpad icons will reshuffle"
            )
        ])
    }

    nonisolated private static func flushIconCacheSync() throws -> MacCareActionReport {
        let script = """
        #!/bin/bash
        echo LUMA_STEP:icons
        /bin/rm -rf /Library/Caches/com.apple.iconservices.store
        /usr/bin/find "$HOME/Library/Caches/com.apple.iconservices.store" -type f -delete 2>/dev/null || true
        echo LUMA_OK:icons
        /usr/bin/killall Dock 2>/dev/null || true
        /usr/bin/killall Finder 2>/dev/null || true
        echo LUMA_OK:restart
        echo LUMA_DONE
        """
        let (status, stdout, stderr) = try runPrivilegedScriptFile(script)
        if status != 0 {
            throw mapAuthError(status: status, stdout: stdout, stderr: stderr)
        }
        return MacCareActionReport(steps: [
            MacCareActionStep(
                id: "icons",
                title: "Flush icon cache",
                succeeded: stdout.contains("LUMA_OK:icons"),
                detail: "iconservices store"
            ),
            MacCareActionStep(
                id: "restart",
                title: "Restart Dock & Finder",
                succeeded: stdout.contains("LUMA_OK:restart"),
                detail: nil
            )
        ])
    }

    // MARK: - Discovery

    nonisolated private static func candidateAppURLs(runningBundleIdentifier: String?) -> [URL] {
        var urls: [URL] = []
        let fm = FileManager.default
        let roots: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
        ]

        for root in roots {
            guard fm.fileExists(atPath: root.path) else { continue }
            let isDerived = root.path.contains("DerivedData")
            if isDerived {
                if let enumerator = fm.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) {
                    var seen = 0
                    for case let url as URL in enumerator {
                        seen += 1
                        if seen > 80_000 { break }
                        guard url.pathExtension == "app" else { continue }
                        if isNonMacOSBuildPath(url.path) { continue }
                        let parts = url.path.split(separator: "/")
                        if parts.filter({ $0.hasSuffix(".app") }).count > 1 { continue }
                        urls.append(url)
                        enumerator.skipDescendants()
                    }
                }
            } else if let contents = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                urls.append(contentsOf: contents.filter { $0.pathExtension == "app" })
            }
        }

        // Project-local `build/Build/Products` (xcodebuild -derivedDataPath build).
        let projectBuild = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Care/
            .deletingLastPathComponent() // Network's sibling → Sources/LumaSystem
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // LumaSystem
            .deletingLastPathComponent() // Packages
            .appendingPathComponent("build/Build/Products", isDirectory: true)
        if fm.fileExists(atPath: projectBuild.path),
           let enumerator = fm.enumerator(at: projectBuild, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        {
            for case let url as URL in enumerator where url.pathExtension == "app" {
                if isNonMacOSBuildPath(url.path) { continue }
                let parts = url.path.split(separator: "/")
                if parts.filter({ $0.hasSuffix(".app") }).count > 1 { continue }
                urls.append(url)
                enumerator.skipDescendants()
            }
        }

        for name in ["Luma", "Luma.app"] {
            urls.append(contentsOf: mdfindDisplayName(name).map { URL(fileURLWithPath: $0) })
        }
        // UITest runners often appear as their own Launchpad tile.
        urls.append(contentsOf: mdfind("kMDItemFSName == '*UITests-Runner.app'c").map { URL(fileURLWithPath: $0) })
        urls.append(contentsOf: mdfind("kMDItemFSName == '*-Runner.app'c && kMDItemContentTypeTree == 'com.apple.application-bundle'").map { URL(fileURLWithPath: $0) })

        _ = runningBundleIdentifier
        return urls
    }

    nonisolated private static func isUITestRunnerName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("uitests-runner") || lower.hasSuffix("-runner")
    }

    nonisolated private static func mdfindBundleIdentifier(_ bundleID: String) -> [String] {
        let query = "kMDItemCFBundleIdentifier == '\(escapeMDFind(bundleID))'"
        return mdfind(query)
    }

    nonisolated private static func mdfindDisplayName(_ name: String) -> [String] {
        let base = name.replacingOccurrences(of: ".app", with: "")
        let query = "kMDItemDisplayName == '\(escapeMDFind(base))'cd && kMDItemContentTypeTree == 'com.apple.application-bundle'"
        return mdfind(query)
    }

    nonisolated private static func mdfind(_ query: String) -> [String] {
        let (status, stdout, _) = runCapture("/usr/bin/mdfind", [query])
        guard status == 0 else { return [] }
        return stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
            .filter { $0.hasSuffix(".app") }
    }

    nonisolated private static func escapeMDFind(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    nonisolated private static func readAppInfo(at url: URL) -> (name: String, bundleID: String?) {
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        let nameFromPath = url.deletingPathExtension().lastPathComponent
        guard let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] else {
            return (nameFromPath, nil)
        }
        let name = (dict["CFBundleDisplayName"] as? String)
            ?? (dict["CFBundleName"] as? String)
            ?? nameFromPath
        let bid = dict["CFBundleIdentifier"] as? String
        return (name, bid)
    }

    nonisolated private static func lsregisterPath() -> String? {
        let candidates = [
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
            "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    nonisolated private static func mapAuthError(status: Int32, stdout: String, stderr: String) -> CareError {
        let combined = (stderr + "\n" + stdout).trimmingCharacters(in: .whitespacesAndNewlines)
        if combined.localizedCaseInsensitiveContains("canceled")
            || combined.localizedCaseInsensitiveContains("cancelled")
            || combined.localizedCaseInsensitiveContains("(-128)")
        {
            return .cancelled
        }
        return .failed(combined.isEmpty ? "Action failed (status \(status))" : combined)
    }

    nonisolated private static func runPrivilegedScriptFile(_ shell: String) throws -> (Int32, String, String) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("luma-mac-care-\(UUID().uuidString).sh")
        try shell.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let appleScript = "do shell script \"/bin/bash \(shellSingleQuoted(url.path))\" with administrator privileges"
        return runCapture("/usr/bin/osascript", ["-e", appleScript])
    }

    nonisolated private static func runCapture(_ executable: String, _ arguments: [String]) -> (Int32, String, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, "", error.localizedDescription)
        }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        return (
            process.terminationStatus,
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
        )
    }

    nonisolated private static func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
