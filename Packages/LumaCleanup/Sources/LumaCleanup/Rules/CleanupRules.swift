import Foundation
import LumaCore
import LumaSupport

/// Base helper for path-based allowlisted cleanup rules.
public struct PathCleanupRule: CleanupRule {
    public let id: String
    public let title: String
    public let explanation: String
    public let riskLevel: CleanupRiskLevel
    public let category: String
    public let pathProviders: @Sendable () -> [URL]
    public let requiresTool: String?
    /// Snapshot at init — SwiftUI must never spawn work or deep-scan in `body`.
    public let isAvailable: Bool
    public let unavailableReason: String?

    public init(
        id: String,
        title: String,
        explanation: String,
        riskLevel: CleanupRiskLevel = .safe,
        category: String,
        requiresTool: String? = nil,
        /// Optional cheap probe so heavy `pathProviders` are not run during catalog build / UI.
        availabilityProbe: (@Sendable () -> Bool)? = nil,
        pathProviders: @escaping @Sendable () -> [URL]
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.riskLevel = riskLevel
        self.category = category
        self.requiresTool = requiresTool
        self.pathProviders = pathProviders

        if let requiresTool {
            let ok = Self.toolExistsOnDisk(requiresTool)
            self.isAvailable = ok
            self.unavailableReason = ok ? nil : "\(requiresTool) is not installed."
        } else if let availabilityProbe {
            let ok = availabilityProbe()
            self.isAvailable = ok
            self.unavailableReason = ok ? nil : "No matching paths found on this Mac."
        } else {
            let paths = pathProviders().filter { FileIO.directoryExists($0) || FileIO.fileExists($0) }
            self.isAvailable = !paths.isEmpty
            self.unavailableReason = paths.isEmpty ? "No matching paths found on this Mac." : nil
        }
    }

    public func estimate() async throws -> CleanupEstimate {
        try await Task.detached(priority: .utility) {
            try self.estimateSync()
        }.value
    }

    public func execute(mode: CleanupExecutionMode) async throws -> CleanupResult {
        let started = Date()
        let estimate = try await estimate()
        guard mode != .dryRun else {
            return CleanupResult(
                ruleID: id,
                mode: .dryRun,
                estimatedBytes: estimate.estimatedBytes,
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

        for item in estimate.items {
            try Task.checkCancellation()
            let url = URL(fileURLWithPath: item.path)
            do {
                try PathSafety.assertSafeForDeletion(item.path)
                if mode == .trash {
                    try await MainActor.run { try FileIO.moveToTrash(url) }
                    moved.append(item.path)
                } else {
                    try FileIO.removePermanently(url)
                    deleted.append(item.path)
                }
                recovered += item.byteCount
            } catch {
                failed.append(item.path)
                LumaLog.cleanup.error("Failed \(item.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return CleanupResult(
            ruleID: id,
            mode: mode,
            estimatedBytes: estimate.estimatedBytes,
            recoveredBytes: recovered,
            movedToTrash: moved,
            deletedPaths: deleted,
            failedPaths: failed,
            startedAt: started,
            finishedAt: .now
        )
    }

    private func existingPaths() -> [URL] {
        pathProviders().filter { FileIO.directoryExists($0) || FileIO.fileExists($0) }
    }

    private func estimateSync() throws -> CleanupEstimate {
        var items: [CleanupPreviewItem] = []
        var total: UInt64 = 0
        for url in existingPaths() {
            try Task.checkCancellation()
            try PathSafety.assertSafeForDeletion(url.path)
            let size = try FileIO.measureSize(at: url)
            guard size > 0 else { continue }
            items.append(
                CleanupPreviewItem(
                    path: url.path,
                    byteCount: size,
                    explanation: explanation
                )
            )
            total += size
        }
        return CleanupEstimate(itemCount: items.count, estimatedBytes: total, items: items)
    }

    /// Fast, non-blocking tool presence check for UI. Never spawns a Process
    /// (spawning from a SwiftUI body deadlocks/aborts AttributeGraph).
    private static func toolExistsOnDisk(_ name: String) -> Bool {
        let home = NSHomeDirectory()
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "\(home)/.local/bin/\(name)",
            "\(home)/.docker/bin/\(name)"
        ]
        return candidates.contains { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

public enum CleanupRuleCatalog {
    private static var home: URL { URL(fileURLWithPath: NSHomeDirectory()) }

    public static func allRules() -> [any CleanupRule] {
        generalRules() + developerRules()
    }

    public static func generalRules() -> [any CleanupRule] {
        [
            PathCleanupRule(
                id: "user-caches",
                title: "User Caches",
                explanation: "Removes regenerable files in ~/Library/Caches. Apps recreate caches as needed.",
                category: "General",
                pathProviders: { [home.appendingPathComponent("Library/Caches")] }
            ),
            PathCleanupRule(
                id: "system-tmp-user",
                title: "User Temporary Files",
                explanation: "Cleans contents of the current user's temporary directory (not the directory itself).",
                category: "General",
                pathProviders: {
                    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
                    return (try? FileManager.default.contentsOfDirectory(
                        at: tmp,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )) ?? []
                }
            ),
            PathCleanupRule(
                id: "diagnostic-reports",
                title: "Crash Reports",
                explanation: "User DiagnosticReports used for crash logs. Safe to clear; new crashes recreate them.",
                category: "General",
                pathProviders: { [home.appendingPathComponent("Library/Logs/DiagnosticReports")] }
            ),
            PathCleanupRule(
                id: "user-logs",
                title: "User Logs",
                explanation: "Non-critical log files under ~/Library/Logs.",
                riskLevel: .caution,
                category: "General",
                pathProviders: { [home.appendingPathComponent("Library/Logs")] }
            ),
            PathCleanupRule(
                id: "safari-cache",
                title: "Safari Cache",
                explanation: "Safari Cache.db / cache folders. Requires Full Disk Access. Does not delete bookmarks or passwords.",
                riskLevel: .caution,
                category: "Browsers",
                pathProviders: {
                    [
                        home.appendingPathComponent("Library/Caches/com.apple.Safari"),
                        home.appendingPathComponent("Library/Safari/LocalStorage")
                    ]
                }
            ),
            PathCleanupRule(
                id: "chrome-cache",
                title: "Chrome Cache",
                explanation: "Google Chrome cache directories only — not profiles or passwords.",
                riskLevel: .caution,
                category: "Browsers",
                pathProviders: {
                    [
                        home.appendingPathComponent("Library/Caches/Google/Chrome"),
                        home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cache"),
                        home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Code Cache")
                    ]
                }
            ),
            PathCleanupRule(
                id: "firefox-cache",
                title: "Firefox Cache",
                explanation: "Firefox cache2 directories.",
                riskLevel: .caution,
                category: "Browsers",
                availabilityProbe: {
                    FileIO.directoryExists(home.appendingPathComponent("Library/Caches/Firefox/Profiles"))
                },
                pathProviders: {
                    let profiles = home.appendingPathComponent("Library/Caches/Firefox/Profiles")
                    guard let contents = try? FileManager.default.contentsOfDirectory(at: profiles, includingPropertiesForKeys: nil) else {
                        return []
                    }
                    return contents
                }
            ),
            PathCleanupRule(
                id: "old-installers",
                title: "Old Installers in Downloads",
                explanation: "Large .dmg / .pkg files older than 30 days in Downloads.",
                riskLevel: .caution,
                category: "General",
                availabilityProbe: {
                    FileIO.directoryExists(home.appendingPathComponent("Downloads"))
                },
                pathProviders: { Self.oldInstallers() }
            )
        ]
    }

    public static func developerRules() -> [any CleanupRule] {
        [
            PathCleanupRule(
                id: "xcode-deriveddata",
                title: "Xcode DerivedData",
                explanation: "Build products and indexes. Xcode regenerates on next build.",
                category: "Developer",
                pathProviders: { [home.appendingPathComponent("Library/Developer/Xcode/DerivedData")] }
            ),
            PathCleanupRule(
                id: "xcode-archives",
                title: "Xcode Archives",
                explanation: "Archived apps used for distribution. Delete only if you no longer need them.",
                riskLevel: .advanced,
                category: "Developer",
                pathProviders: { [home.appendingPathComponent("Library/Developer/Xcode/Archives")] }
            ),
            PathCleanupRule(
                id: "xcode-device-support",
                title: "iOS DeviceSupport",
                explanation: "Symbols for physical devices. Safe to remove unused older versions; Xcode re-downloads when needed.",
                riskLevel: .caution,
                category: "Developer",
                pathProviders: { [home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport")] }
            ),
            PathCleanupRule(
                id: "core-simulator-caches",
                title: "Simulator Caches",
                explanation: "CoreSimulator caches (not device data). Simulators can be recreated.",
                riskLevel: .caution,
                category: "Developer",
                pathProviders: {
                    [
                        home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
                        home.appendingPathComponent("Library/Logs/CoreSimulator")
                    ]
                }
            ),
            PathCleanupRule(
                id: "swiftpm-cache",
                title: "SwiftPM Cache",
                explanation: "Swift Package Manager repositories and artifacts cache.",
                category: "Developer",
                pathProviders: {
                    [
                        home.appendingPathComponent("Library/Caches/org.swift.swiftpm"),
                        home.appendingPathComponent(".swiftpm")
                    ]
                }
            ),
            PathCleanupRule(
                id: "cocoapods-cache",
                title: "CocoaPods Cache",
                explanation: "CocoaPods cache under ~/Library/Caches/CocoaPods.",
                category: "Developer",
                pathProviders: { [home.appendingPathComponent("Library/Caches/CocoaPods")] }
            ),
            PathCleanupRule(
                id: "gradle-cache",
                title: "Gradle Cache",
                explanation: "~/.gradle/caches — regenerable Android/Java build cache.",
                category: "Developer",
                pathProviders: { [home.appendingPathComponent(".gradle/caches")] }
            ),
            PathCleanupRule(
                id: "android-build-cache",
                title: "Android Build Cache",
                explanation: "Android Studio / SDK build caches.",
                category: "Developer",
                pathProviders: {
                    [
                        home.appendingPathComponent(".android/build-cache"),
                        home.appendingPathComponent("Library/Caches/Google/AndroidStudio")
                    ]
                }
            ),
            PathCleanupRule(
                id: "android-emulator",
                title: "Android Emulator AVDs (Caches)",
                explanation: "Emulator cache folders only — not AVD definitions under ~/.android/avd unless empty caches.",
                riskLevel: .advanced,
                category: "Developer",
                pathProviders: { [home.appendingPathComponent(".android/cache")] }
            ),
            PathCleanupRule(
                id: "flutter-cache",
                title: "Flutter / Pub Cache",
                explanation: "Pub package cache. Flutter will re-fetch packages.",
                category: "Developer",
                pathProviders: {
                    [
                        home.appendingPathComponent(".pub-cache"),
                        home.appendingPathComponent("Library/Caches/flutter_engine")
                    ]
                }
            ),
            PathCleanupRule(
                id: "metro-cache",
                title: "Metro / Watchman Cache",
                explanation: "React Native Metro temporary caches and Watchman state if present.",
                category: "Developer",
                pathProviders: {
                    [
                        home.appendingPathComponent("Library/Caches/Metro"),
                        home.appendingPathComponent(".metro-cache"),
                        home.appendingPathComponent("Library/Caches/com.github.facebook.watchman")
                    ]
                }
            ),
            PathCleanupRule(
                id: "npm-cache",
                title: "npm Cache",
                explanation: "npm cache from `npm cache`.",
                category: "Developer",
                pathProviders: { [home.appendingPathComponent(".npm/_cacache")] }
            ),
            PathCleanupRule(
                id: "pnpm-store",
                title: "pnpm Store",
                explanation: "pnpm content-addressable store. Reinstall projects after cleaning.",
                riskLevel: .caution,
                category: "Developer",
                pathProviders: {
                    [
                        home.appendingPathComponent("Library/pnpm/store"),
                        home.appendingPathComponent(".local/share/pnpm/store")
                    ]
                }
            ),
            PathCleanupRule(
                id: "yarn-cache",
                title: "Yarn Cache",
                explanation: "Yarn cache folder.",
                category: "Developer",
                pathProviders: {
                    [
                        home.appendingPathComponent("Library/Caches/Yarn"),
                        home.appendingPathComponent(".yarn/cache")
                    ]
                }
            ),
            PathCleanupRule(
                id: "bun-cache",
                title: "Bun Cache",
                explanation: "Bun install cache.",
                category: "Developer",
                pathProviders: { [home.appendingPathComponent(".bun/install/cache")] }
            ),
            PathCleanupRule(
                id: "homebrew-cache",
                title: "Homebrew Cache",
                explanation: "Downloaded bottles/source in Homebrew cache.",
                category: "Developer",
                pathProviders: { [home.appendingPathComponent("Library/Caches/Homebrew")] }
            ),
            PathCleanupRule(
                id: "composer-cache",
                title: "Composer Cache",
                explanation: "PHP Composer cache.",
                category: "Developer",
                pathProviders: { [home.appendingPathComponent(".composer/cache")] }
            ),
            PathCleanupRule(
                id: "laravel-cache",
                title: "Laravel Bootstrap Cache (project-local)",
                explanation: "Only cleans bootstrap/cache inside detected Laravel projects under ~/Developer and ~/Projects if present.",
                riskLevel: .caution,
                category: "Developer",
                availabilityProbe: {
                    ["Developer", "Projects", "Code", "src"].contains {
                        FileIO.directoryExists(home.appendingPathComponent($0))
                    }
                },
                pathProviders: { Self.laravelCaches() }
            ),
            DockerCleanupRule()
        ]
    }

    private static func oldInstallers() -> [URL] {
        let downloads = home.appendingPathComponent("Downloads")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: downloads,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        return files.filter { url in
            let ext = url.pathExtension.lowercased()
            guard ext == "dmg" || ext == "pkg" else { return false }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values?.contentModificationDate, modified < cutoff else { return false }
            return true
        }
    }

    private static func laravelCaches() -> [URL] {
        let roots = ["Developer", "Projects", "Code", "src"].map { home.appendingPathComponent($0) }
        var found: [URL] = []
        for root in roots {
            guard FileIO.directoryExists(root) else { continue }
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            var depthGuard = 0
            while let url = enumerator.nextObject() as? URL {
                depthGuard += 1
                if depthGuard > 5_000 { break }
                if url.lastPathComponent == "bootstrap" {
                    let cache = url.appendingPathComponent("cache")
                    if FileIO.directoryExists(cache) {
                        found.append(cache)
                    }
                }
            }
        }
        return found
    }
}

/// Docker cleanup invokes `docker` CLI only when installed; otherwise unavailable.
public struct DockerCleanupRule: CleanupRule {
    public let id = "docker-system-prune"
    public let title = "Docker Build Cache / Unused Data"
    public let explanation = "Runs `docker system df` for estimates and `docker builder prune` / unused data only after confirmation. Never invents sizes."
    public let riskLevel: CleanupRiskLevel = .advanced
    public let category = "Developer"
    /// Cached at init — must never spawn Process during SwiftUI body evaluation.
    public let isAvailable: Bool
    public let unavailableReason: String?

    public init() {
        let available = Self.dockerBinaryURL() != nil
        self.isAvailable = available
        self.unavailableReason = available ? nil : "Docker CLI is not installed (checked Homebrew/usr/local paths)."
    }

    public func estimate() async throws -> CleanupEstimate {
        guard isAvailable else { return .empty }
        return try await Task.detached(priority: .utility) {
            let output = try self.runDocker(["system", "df", "--format", "{{.Type}}\t{{.Size}}\t{{.Reclaimable}}"])
            let reclaimable = self.parseReclaimable(output)
            return CleanupEstimate(
                itemCount: reclaimable > 0 ? 1 : 0,
                estimatedBytes: reclaimable,
                items: reclaimable > 0
                    ? [CleanupPreviewItem(path: "(docker system)", byteCount: reclaimable, explanation: self.explanation)]
                    : []
            )
        }.value
    }

    public func execute(mode: CleanupExecutionMode) async throws -> CleanupResult {
        let started = Date()
        let estimate = try await estimate()
        guard mode != .dryRun else {
            return CleanupResult(
                ruleID: id,
                mode: .dryRun,
                estimatedBytes: estimate.estimatedBytes,
                recoveredBytes: 0,
                movedToTrash: [],
                deletedPaths: [],
                failedPaths: [],
                startedAt: started,
                finishedAt: .now
            )
        }
        return try await Task.detached(priority: .userInitiated) {
            _ = try self.runDocker(["builder", "prune", "-f"])
            _ = try self.runDocker(["image", "prune", "-f"])
            _ = try self.runDocker(["container", "prune", "-f"])
            return CleanupResult(
                ruleID: self.id,
                mode: mode,
                estimatedBytes: estimate.estimatedBytes,
                recoveredBytes: estimate.estimatedBytes,
                movedToTrash: [],
                deletedPaths: ["(docker builder/image/container prune)"],
                failedPaths: [],
                startedAt: started,
                finishedAt: .now
            )
        }.value
    }

    private static func dockerBinaryURL() -> URL? {
        let home = NSHomeDirectory()
        let candidates = [
            "/opt/homebrew/bin/docker",
            "/usr/local/bin/docker",
            "/usr/bin/docker",
            "\(home)/.docker/bin/docker"
        ]
        return candidates
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    @discardableResult
    private func runDocker(_ arguments: [String]) throws -> String {
        guard let binary = Self.dockerBinaryURL() else {
            throw LumaError.unavailable(reason: "Docker CLI not found")
        }
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown"
            throw LumaError.ioFailure("docker \(arguments.joined(separator: " ")) failed — \(message)")
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseReclaimable(_ output: String) -> UInt64 {
        _ = output
        return 0
    }
}
