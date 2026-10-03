import Foundation
import LumaCore
import LumaSupport

public struct StorageNode: Sendable, Equatable, Identifiable {
    public var id: String { path }
    public var path: String
    public var name: String
    public var byteCount: UInt64
    public var isDirectory: Bool
    public var category: StorageCategory
    public var children: [StorageNode]

    public init(
        path: String,
        name: String,
        byteCount: UInt64,
        isDirectory: Bool,
        category: StorageCategory,
        children: [StorageNode] = []
    ) {
        self.path = path
        self.name = name
        self.byteCount = byteCount
        self.isDirectory = isDirectory
        self.category = category
        self.children = children
    }
}

public enum StorageCategory: String, Sendable, CaseIterable, Codable {
    case applications
    case caches
    case downloads
    case developer
    case docker
    case xcode
    case simulator
    case android
    case flutter
    case reactNative
    case node
    case homebrew
    case documents
    case photos
    case movies
    case music
    case desktop
    case iCloud
    case mail
    case messages
    case appSupport
    case containers
    case virtualMachines
    case other
    /// Residual disk used outside the folder walk (macOS, other users, snapshots…).
    case system

    public var title: String {
        switch self {
        case .applications: LumaL10n.string("Applications")
        case .caches: LumaL10n.string("Caches")
        case .downloads: LumaL10n.string("Downloads")
        case .developer: LumaL10n.string("Developer")
        case .docker: LumaL10n.string("Docker")
        case .xcode: LumaL10n.string("Xcode")
        case .simulator: LumaL10n.string("Simulator")
        case .android: LumaL10n.string("Android Studio")
        case .flutter: LumaL10n.string("Flutter")
        case .reactNative: LumaL10n.string("React Native")
        case .node: LumaL10n.string("Node")
        case .homebrew: LumaL10n.string("Homebrew")
        case .documents: LumaL10n.string("Documents")
        case .photos: LumaL10n.string("Photos")
        case .movies: LumaL10n.string("Movies")
        case .music: LumaL10n.string("Music")
        case .desktop: LumaL10n.string("Desktop")
        case .iCloud: LumaL10n.string("iCloud")
        case .mail: LumaL10n.string("Mail")
        case .messages: LumaL10n.string("Messages")
        case .appSupport: LumaL10n.string("Application Support")
        case .containers: LumaL10n.string("App Containers")
        case .virtualMachines: LumaL10n.string("Virtual Machines")
        case .other: LumaL10n.string("Other")
        case .system: LumaL10n.string("Not scanned (disk remainder)")
        }
    }

    /// These buckets should show their large children — the parent name is not the answer.
    public var revealsLargeChildren: Bool {
        switch self {
        case .other, .appSupport, .containers, .photos, .iCloud, .mail, .messages, .virtualMachines, .documents:
            true
        default:
            false
        }
    }
}

public enum StorageClassifier {
    public static func classify(path: String) -> StorageCategory {
        let p = URL(fileURLWithPath: path).standardizedFileURL.path.lowercased()
        func folder(_ name: String) -> Bool {
            p.hasSuffix("/\(name)") || p.contains("/\(name)/")
        }

        if p.contains("/library/developer/xcode/deriveddata") || p.contains("/library/developer/xcode/archives") {
            return .xcode
        }
        if p.contains("/library/developer/coresimulator") || p.contains("/coresimulator") {
            return .simulator
        }
        if p.contains("/.docker") || p.contains("/library/containers/com.docker") {
            return .docker
        }
        if p.contains("/.gradle") || p.contains("/.android") || p.contains("/androidstudio") {
            return .android
        }
        if p.contains("/.pub-cache") || folder("flutter") {
            return .flutter
        }
        if p.contains("/.metro") || p.contains("react-native") {
            return .reactNative
        }
        if p.contains("/.npm") || p.contains("/.pnpm") || p.contains("/.yarn") || p.contains("/.bun") || p.contains("/node_modules") {
            return .node
        }
        if p.contains("/homebrew") || p.contains("/opt/homebrew") || p.contains("/.cache/homebrew") {
            return .homebrew
        }
        if p.contains("/library/developer") {
            return .developer
        }
        if p.hasSuffix("/applications") || p.contains("/applications/") {
            return .applications
        }
        if p.contains("/library/caches") {
            return .caches
        }
        if folder("downloads") {
            return .downloads
        }
        if p.contains(".photoslibrary") || folder("pictures") || folder("photos") {
            return .photos
        }
        if folder("movies") {
            return .movies
        }
        if folder("music") || p.contains("/itunes") {
            return .music
        }
        if folder("desktop") {
            return .desktop
        }
        if p.contains("/mobile documents") || folder("icloud drive") {
            return .iCloud
        }
        if p.contains("/library/mail") {
            return .mail
        }
        if p.contains("/library/messages") {
            return .messages
        }
        if p.contains("/library/application support") {
            return .appSupport
        }
        if p.contains("/library/containers") || p.contains("/library/group containers") {
            return .containers
        }
        if p.contains("/parallels") || p.contains("/utm") || folder("virtual machines")
            || p.contains(".utm") || p.contains("vmware") || p.contains("virtualbox") {
            return .virtualMachines
        }
        if folder("documents") {
            return .documents
        }
        return .other
    }
}

public struct StorageCategorySummary: Sendable, Equatable, Identifiable {
    public var id: String { category.rawValue }
    public var category: StorageCategory
    public var byteCount: UInt64
    public var pathCount: Int

    public init(category: StorageCategory, byteCount: UInt64, pathCount: Int) {
        self.category = category
        self.byteCount = byteCount
        self.pathCount = pathCount
    }
}

public struct StorageScanResult: Sendable, Equatable {
    public var roots: [StorageNode]
    public var categories: [StorageCategorySummary]
    public var largestFolders: [StorageNode]
    public var scope: StorageScanScope
    public var scannedAt: Date

    public init(
        roots: [StorageNode],
        categories: [StorageCategorySummary],
        largestFolders: [StorageNode],
        scope: StorageScanScope = .knownLocations,
        scannedAt: Date = .now
    ) {
        self.roots = roots
        self.categories = categories
        self.largestFolders = largestFolders
        self.scope = scope
        self.scannedAt = scannedAt
    }
}

public enum StorageScanScope: String, Sendable, CaseIterable, Identifiable {
    case knownLocations
    case home

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .knownLocations: LumaL10n.string("Quick scan")
        case .home: LumaL10n.string("Full home folder")
        }
    }

    public var subtitle: String {
        switch self {
        case .knownLocations:
            LumaL10n.string("Caches, downloads, developer folders, and apps — faster, focuses on space you can reclaim.")
        case .home:
            LumaL10n.string("Documents, Desktop, and the rest of your home — fuller picture, takes longer.")
        }
    }
}

public struct StorageScanProgress: Sendable, Equatable {
    public var label: String
    public var snapshot: StorageScanResult
    /// 0...1 overall scan progress.
    public var fractionComplete: Double

    public init(label: String, snapshot: StorageScanResult, fractionComplete: Double) {
        self.label = label
        self.snapshot = snapshot
        self.fractionComplete = min(max(fractionComplete, 0), 1)
    }
}

/// Scans high-value or user-scoped locations. Whole-disk used/free comes from volume APIs, not folder walking.
public actor StorageScanner {
    public init() {}

    public func scan(
        scope: StorageScanScope,
        progress: (@Sendable (StorageScanProgress) -> Void)? = nil
    ) async throws -> StorageScanResult {
        switch scope {
        case .knownLocations:
            try await scanKnownLocations(progress: progress)
        case .home:
            try await scanHomeOverview(progress: progress)
        }
    }

    public func scanKnownLocations(progress: (@Sendable (StorageScanProgress) -> Void)? = nil) async throws -> StorageScanResult {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        // Avoid walking ~/Library/Developer as a whole — CoreSimulator/DerivedData are huge and
        // would be measured again as nested targets. Hit the heavy subfolders directly instead.
        let targets: [(URL, String)] = [
            (home.appendingPathComponent("Library/Caches"), "Caches"),
            (home.appendingPathComponent("Downloads"), "Downloads"),
            (home.appendingPathComponent("Library/Developer/Xcode/DerivedData"), "DerivedData"),
            (home.appendingPathComponent("Library/Developer/Xcode/Archives"), "Archives"),
            (home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"), "DeviceSupport"),
            (home.appendingPathComponent("Library/Developer/CoreSimulator"), "CoreSimulator"),
            (home.appendingPathComponent(".gradle"), "Gradle"),
            (home.appendingPathComponent(".npm"), "npm"),
            (home.appendingPathComponent(".docker"), "Docker"),
            (URL(fileURLWithPath: "/Applications"), "Applications"),
            (home.appendingPathComponent("Applications"), "User Applications")
        ]
        return try await measureTargets(targets, scope: .knownLocations, progress: progress)
    }

    public func scanHomeOverview(progress: (@Sendable (StorageScanProgress) -> Void)? = nil) async throws -> StorageScanResult {
        let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL
        var targets: [(URL, String)] = []

        let children = (try? FileIO.listImmediateChildren(at: home)) ?? []
        for child in children {
            try Task.checkCancellation()
            let name = child.lastPathComponent
            if PathSafety.blocksScan(child.path) { continue }
            if name == "Library" {
                // Measure every Library child (Mail, Photos, Application Support…) instead of a short allowlist.
                let libraryChildren = (try? FileIO.listImmediateChildren(at: child)) ?? []
                for libChild in libraryChildren {
                    if PathSafety.blocksScan(libChild.path) { continue }
                    targets.append((libChild, "Library/\(libChild.lastPathComponent)"))
                }
                continue
            }
            targets.append((child, name))
        }

        targets.append((URL(fileURLWithPath: "/Applications"), "Applications"))
        targets.append((URL(fileURLWithPath: "/opt/homebrew"), "Homebrew"))
        targets.append((home.appendingPathComponent(".docker"), "Docker"))
        targets.append((home.appendingPathComponent(".gradle"), "Gradle"))
        targets.append((home.appendingPathComponent(".npm"), "npm"))

        // Dedupe paths while keeping first label.
        var seen = Set<String>()
        let unique = targets.filter { seen.insert($0.0.standardizedFileURL.path).inserted }

        return try await measureTargets(unique, scope: .home, progress: progress)
    }

    private func measureTargets(
        _ targets: [(URL, String)],
        scope: StorageScanScope,
        progress: (@Sendable (StorageScanProgress) -> Void)?
    ) async throws -> StorageScanResult {
        var roots: [StorageNode] = []
        var measured: [(path: String, category: StorageCategory, bytes: UInt64)] = []
        var folders: [StorageNode] = []
        var seenFolderPaths = Set<String>()
        var lastPublish = Date.distantPast
        let totalTargets = max(targets.count, 1)
        var currentFraction = 0.0

        func publish(_ label: String, fraction: Double, force: Bool = false) {
            guard let progress else { return }
            let now = Date()
            guard force || now.timeIntervalSince(lastPublish) >= 0.15 else { return }
            lastPublish = now
            currentFraction = min(max(fraction, 0), 1)
            progress(
                StorageScanProgress(
                    label: label,
                    snapshot: Self.makeResult(
                        roots: roots,
                        measured: measured,
                        folders: folders,
                        scope: scope
                    ),
                    fractionComplete: currentFraction
                )
            )
        }

        publish(LumaL10n.string("Starting…"), fraction: 0, force: true)

        for (index, (url, label)) in targets.enumerated() {
            try Task.checkCancellation()
            let base = Double(index) / Double(totalTargets)
            let span = 1.0 / Double(totalTargets)
            publish(LumaL10n.format("Measuring %@", label), fraction: base, force: true)
            let rootURL = url.standardizedFileURL
            guard FileIO.directoryExists(rootURL) || FileIO.fileExists(rootURL) else {
                publish(LumaL10n.format("Measured %@", label), fraction: base + span, force: true)
                continue
            }
            do {
                let isApplicationsRoot = rootURL.path == "/Applications"
                    || rootURL.path.hasSuffix("/Applications")

                if isApplicationsRoot {
                    // Measure each app once; root size = sum (avoids walking Applications twice).
                    var sum: UInt64 = 0
                    let children = (try? FileIO.listImmediateChildren(at: rootURL)) ?? []
                    let appTotal = max(min(children.count, 80), 1)
                    var appsDone = 0
                    for child in children.prefix(80) {
                        try Task.checkCancellation()
                        var isDir: ObjCBool = false
                        guard FileManager.default.fileExists(atPath: child.path, isDirectory: &isDir) else {
                            continue
                        }
                        let childSize = (try? FileIO.measureSize(at: child)) ?? 0
                        sum += childSize
                        appsDone += 1
                        let local = Double(appsDone) / Double(appTotal)
                        let childPackage = (try? child.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
                        // .app bundles are listed for size, but not browsable (opaque packages).
                        if isDir.boolValue, childSize > 50 * 1024 * 1024,
                           seenFolderPaths.insert(child.standardizedFileURL.path).inserted {
                            folders.append(
                                StorageNode(
                                    path: child.standardizedFileURL.path,
                                    name: child.lastPathComponent,
                                    byteCount: childSize,
                                    isDirectory: !childPackage,
                                    category: .applications
                                )
                            )
                            publish(
                                LumaL10n.format("%@ · %lld apps", label, Int64(appsDone)),
                                fraction: base + span * local,
                                force: true
                            )
                        } else if appsDone % 5 == 0 {
                            publish(
                                LumaL10n.format("%@ · %lld apps", label, Int64(appsDone)),
                                fraction: base + span * local
                            )
                        }
                    }
                    let node = StorageNode(
                        path: rootURL.path,
                        name: label,
                        byteCount: sum,
                        isDirectory: true,
                        category: .applications
                    )
                    roots.append(node)
                    measured.append((rootURL.path, .applications, sum))
                    if seenFolderPaths.insert(rootURL.path).inserted {
                        folders.append(node)
                    }
                    publish(LumaL10n.format("Measured %@", label), fraction: base + span, force: true)
                    continue
                }

                let size = try FileIO.measureSize(at: rootURL)
                let category = StorageClassifier.classify(path: rootURL.path)
                var isDirFlag: ObjCBool = false
                _ = FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirFlag)
                let isPackage = (try? rootURL.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
                let node = StorageNode(
                    path: rootURL.path,
                    name: label,
                    byteCount: size,
                    isDirectory: isDirFlag.boolValue && isPackage != true,
                    category: category
                )
                roots.append(node)
                measured.append((rootURL.path, category, size))
                if seenFolderPaths.insert(rootURL.path).inserted {
                    folders.append(node)
                }
                publish(LumaL10n.format("Measured %@", label), fraction: base + span * 0.7, force: true)
                // For home overview, also surface large immediate children of big roots.
                if scope == .home, isDirFlag.boolValue, isPackage != true, size > 80 * 1024 * 1024 {
                    let kids = (try? FileIO.listImmediateChildren(at: rootURL)) ?? []
                    let kidTotal = max(min(kids.count, 80), 1)
                    var kidDone = 0
                    for child in kids.prefix(80) {
                        try Task.checkCancellation()
                        kidDone += 1
                        if PathSafety.blocksScan(child.path) { continue }
                        var isDir: ObjCBool = false
                        guard FileManager.default.fileExists(atPath: child.path, isDirectory: &isDir) else { continue }
                        let childPackage = (try? child.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
                        let childSize = (try? FileIO.measureSize(at: child)) ?? 0
                        guard childSize > 40 * 1024 * 1024,
                              seenFolderPaths.insert(child.standardizedFileURL.path).inserted else { continue }
                        folders.append(
                            StorageNode(
                                path: child.standardizedFileURL.path,
                                name: child.lastPathComponent,
                                byteCount: childSize,
                                isDirectory: isDir.boolValue && childPackage != true,
                                category: StorageClassifier.classify(path: child.path)
                            )
                        )
                        let local = 0.7 + 0.3 * (Double(kidDone) / Double(kidTotal))
                        publish(
                            LumaL10n.format("%@ / %@", label, child.lastPathComponent),
                            fraction: base + span * local,
                            force: true
                        )
                    }
                }
                publish(LumaL10n.format("Measured %@", label), fraction: base + span, force: true)
            } catch is CancellationError {
                throw LumaError.cancelled
            } catch {
                LumaLog.storage.error("Skip \(rootURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                publish(LumaL10n.format("Measured %@", label), fraction: base + span, force: true)
            }
        }

        let final = Self.makeResult(roots: roots, measured: measured, folders: folders, scope: scope)
        publish(LumaL10n.string("Finishing…"), fraction: 1, force: true)
        return final
    }

    nonisolated private static func makeResult(
        roots: [StorageNode],
        measured: [(path: String, category: StorageCategory, bytes: UInt64)],
        folders: [StorageNode],
        scope: StorageScanScope
    ) -> StorageScanResult {
        // Prefer deeper (more specific) roots for category totals so parent+child aren't double-counted.
        var categoryBytes: [StorageCategory: UInt64] = [:]
        var categoryCounts: [StorageCategory: Int] = [:]
        var claimedPaths: [String] = []
        for item in measured.sorted(by: { $0.path.count > $1.path.count }) {
            let coveredByChild = claimedPaths.contains { $0.hasPrefix(item.path + "/") }
            if coveredByChild { continue }
            claimedPaths.append(item.path)
            categoryBytes[item.category, default: 0] += item.bytes
            categoryCounts[item.category, default: 0] += 1
        }

        let categories = StorageCategory.allCases.compactMap { cat -> StorageCategorySummary? in
            guard cat != .system else { return nil }
            guard let bytes = categoryBytes[cat], bytes > 0 else { return nil }
            return StorageCategorySummary(category: cat, byteCount: bytes, pathCount: categoryCounts[cat, default: 0])
        }
        .sorted { $0.byteCount > $1.byteCount }

        let largest = folders.sorted { $0.byteCount > $1.byteCount }.prefix(80).map { $0 }
        return StorageScanResult(
            roots: roots,
            categories: categories,
            largestFolders: Array(largest),
            scope: scope
        )
    }
}

/// Lazy one-level listing for the in-app Storage folder browser (Finder-like).
public enum StorageFolderBrowser {
    /// Immediate children of `url`, measured with sizes. Streams partial results via `onUpdate`.
    public static func listContents(
        of url: URL,
        limit: Int = 500,
        onUpdate: (@Sendable ([StorageNode], String) -> Void)? = nil
    ) async throws -> [StorageNode] {
        try await Task(priority: .utility) {
            try measureChildrenSync(of: url, limit: limit, onUpdate: onUpdate)
        }.value
    }

    /// Compatibility alias — same as `listContents`.
    public static func topChildren(
        of url: URL,
        limit: Int = 500,
        progress: (@Sendable (String) -> Void)? = nil
    ) async throws -> [StorageNode] {
        try await listContents(of: url, limit: limit) { _, name in
            progress?(name)
        }
    }

    nonisolated private static func measureChildrenSync(
        of url: URL,
        limit: Int,
        onUpdate: (@Sendable ([StorageNode], String) -> Void)?
    ) throws -> [StorageNode] {
        try Task.checkCancellation()
        let root = url.standardizedFileURL
        guard FileIO.directoryExists(root) else { return [] }
        if PathSafety.blocksScan(root.path) { return [] }

        let children = try FileIO.listImmediateChildren(at: root)
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        var nodes: [StorageNode] = []
        nodes.reserveCapacity(min(children.count, limit))

        for child in children {
            try Task.checkCancellation()
            if nodes.count >= limit { break }
            if PathSafety.blocksScan(child.path) { continue }

            let name = child.lastPathComponent
            if name.hasPrefix(".") { continue }

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: child.path, isDirectory: &isDir) else {
                continue
            }

            // Packages (.app, .bundle) are opaque — size the bundle, don't enter.
            let values = try? child.resourceValues(forKeys: [.isPackageKey])
            let isPackage = values?.isPackage == true
            let treatAsDirectory = isDir.boolValue && !isPackage

            onUpdate?(nodes, name)
            let size = (try? FileIO.measureSize(at: child)) ?? 0

            nodes.append(
                StorageNode(
                    path: child.standardizedFileURL.path,
                    name: name,
                    byteCount: size,
                    isDirectory: treatAsDirectory,
                    category: StorageClassifier.classify(path: child.path)
                )
            )
            onUpdate?(nodes, name)
        }

        return nodes
    }
}
