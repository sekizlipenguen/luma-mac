import AppKit
import Foundation
import Observation
import LumaCleanup
import LumaCore
import LumaStorage
import LumaSupport
import LumaSystem

@Observable
@MainActor
final class StorageViewModel {
    private let scanner: StorageScanner
    private let disk = DiskMetricsSampler()
    var result: StorageScanResult?
    var volume: DiskVolumeMetrics?
    var scope: StorageScanScope = .knownLocations
    var isScanning = false
    var progressLabel = ""
    var progressFraction = 0.0
    var errorMessage: String?
    var folderSort: SizeNameSort = .size
    /// Breadcrumb stack while drilling into largest folders (empty = scan results).
    var drillStack: [StorageNode] = []
    var drillChildren: [StorageNode] = []
    var isLoadingDrill = false
    var drillProgressName = ""
    var drillError: String?
    private var task: Task<Void, Never>?
    private var drillTask: Task<Void, Never>?

    init(scanner: StorageScanner) {
        self.scanner = scanner
    }

    /// Collapse nested noise (e.g. Devices under CoreSimulator) while keeping scan roots and Applications children.
    var displayFolders: [StorageNode] {
        if !drillStack.isEmpty {
            return folderSort.sortedBrowserItems(drillChildren)
        }
        guard let result else { return [] }
        let rootPaths = Set(result.roots.map(\.path))
        let sorted = result.largestFolders.sorted { $0.byteCount > $1.byteCount }
        var kept: [StorageNode] = []
        for node in sorted {
            let shouldSkip = kept.contains { parent in
                guard node.path.hasPrefix(parent.path + "/") else { return false }
                if rootPaths.contains(node.path) { return false }
                let parentIsApps = parent.path == "/Applications"
                    || parent.path.hasSuffix("/Applications")
                if parentIsApps { return false }
                if parent.category.revealsLargeChildren { return false }
                return true
            }
            if shouldSkip { continue }
            kept.append(node)
            if kept.count >= 40 { break }
        }
        return folderSort.sortedFolders(kept)
    }

    /// Folders that landed in Other — this is the list to open, not a mystery blob.
    var otherFolders: [StorageNode] {
        guard drillStack.isEmpty, let result else { return [] }
        return result.largestFolders
            .filter { $0.category == .other && $0.byteCount >= 40 * 1024 * 1024 }
            .sorted { $0.byteCount > $1.byteCount }
            .prefix(16)
            .map { $0 }
    }

    var drillParent: StorageNode? { drillStack.last }

    var isDrilling: Bool { !drillStack.isEmpty }

    var browseFolderCount: Int { drillChildren.filter(\.isDirectory).count }

    var browseFileCount: Int { drillChildren.filter { !$0.isDirectory }.count }

    var totalBytes: UInt64 {
        result?.categories.reduce(0) { $0 + $1.byteCount } ?? 0
    }

    /// Folder-walk categories plus residual disk used (System, other users, outside scope).
    var breakdownCategories: [StorageCategorySummary] {
        guard let result else { return [] }
        var cats = result.categories
        if let volume {
            let residual = volume.usedBytes > totalBytes ? volume.usedBytes - totalBytes : 0
            if residual > 1_048_576 {
                cats.append(
                    StorageCategorySummary(category: .system, byteCount: residual, pathCount: 0)
                )
                cats.sort { $0.byteCount > $1.byteCount }
            }
        }
        return cats
    }

    var breakdownTotalBytes: UInt64 {
        breakdownCategories.reduce(0) { $0 + $1.byteCount }
    }

    func refreshVolume() {
        Task {
            volume = await disk.sampleRootVolume()
        }
    }

    func scan() {
        task?.cancel()
        drillTask?.cancel()
        resetDrill()
        let scope = scope
        task = Task {
            isScanning = true
            errorMessage = nil
            result = nil
            progressLabel = LumaL10n.string("Starting…")
            progressFraction = 0
            async let volumeSample = disk.sampleRootVolume()
            do {
                let scanResult = try await scanner.scan(scope: scope) { [weak self] update in
                    Task { @MainActor in
                        guard let self else { return }
                        self.progressLabel = update.label
                        self.progressFraction = update.fractionComplete
                        self.result = update.snapshot
                    }
                }
                result = scanResult
                progressFraction = 1
                volume = await volumeSample
            } catch is CancellationError {
                // Abandon in-progress map — show the start card again (toolbar Scan / Scan now).
                result = nil
                errorMessage = nil
                progressFraction = 0
                volume = await volumeSample
            } catch {
                errorMessage = error.localizedDescription
                volume = await volumeSample
            }
            isScanning = false
        }
    }

    func cancel() {
        task?.cancel()
    }

    func resetDrill() {
        drillTask?.cancel()
        drillStack = []
        drillChildren = []
        isLoadingDrill = false
        drillProgressName = ""
        drillError = nil
    }

    /// Open a folder inside Luma’s browser (not macOS Finder). Files are listed; only the reveal button opens Finder.
    func drill(into node: StorageNode) {
        guard !isScanning else { return }
        guard isDrillableDirectory(node) else { return }
        drillTask?.cancel()
        drillStack.append(node)
        drillChildren = []
        drillError = nil
        drillProgressName = ""
        isLoadingDrill = true
        loadDrillChildren(of: node)
    }

    func drillBack() {
        guard !drillStack.isEmpty else { return }
        drillStack.removeLast()
        if let parent = drillStack.last {
            drillChildren = []
            isLoadingDrill = true
            loadDrillChildren(of: parent)
        } else {
            drillChildren = []
            isLoadingDrill = false
            drillProgressName = ""
            drillError = nil
        }
    }

    func drillToRoot() {
        resetDrill()
    }

    /// Jump to a breadcrumb segment (`0` = first opened folder).
    func drillToIndex(_ index: Int) {
        guard index >= 0, index < drillStack.count else { return }
        if index == drillStack.count - 1 { return }
        drillStack = Array(drillStack.prefix(index + 1))
        guard let parent = drillStack.last else { return }
        drillChildren = []
        isLoadingDrill = true
        loadDrillChildren(of: parent)
    }

    private func loadDrillChildren(of node: StorageNode) {
        drillTask?.cancel()
        drillError = nil
        drillProgressName = ""
        isLoadingDrill = true
        let url = URL(fileURLWithPath: node.path)
        drillTask = Task {
            do {
                let kids = try await StorageFolderBrowser.listContents(of: url) { [weak self] partial, currentName in
                    Task { @MainActor in
                        guard let self, !Task.isCancelled else { return }
                        self.drillChildren = partial
                        self.drillProgressName = currentName
                    }
                }
                guard !Task.isCancelled else { return }
                drillChildren = kids
                drillProgressName = ""
            } catch is CancellationError {
                // keep partial list
            } catch {
                drillError = error.localizedDescription
            }
            isLoadingDrill = false
        }
    }

    func revealInFinder(_ node: StorageNode) {
        let url = URL(fileURLWithPath: node.path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        let isPackage = (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
        // Folders: open in Finder. Files / app packages: reveal (never launch / open-with).
        if isDir.boolValue && !isPackage {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func isDrillableDirectory(_ node: StorageNode) -> Bool {
        let url = URL(fileURLWithPath: node.path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        let isPackage = (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
        return !isPackage
    }
}

@Observable
@MainActor
final class LargeFilesViewModel {
    private let finder: LargeFileFinder
    var thresholdChoice: LargeFileThresholdChoice = .mb100
    /// Used when `thresholdChoice == .custom` (mebibytes).
    var customThresholdMB: Int = 250
    var scope: FileScanScope = .homeAndApps
    var hits: [LargeFileHit] = []
    var isScanning = false
    var hasScanned = false
    var filesExamined = 0
    var progressLabel = ""
    var progressFraction = 0.0
    var errorMessage: String?
    var sortMode: SizeNameSort = .size
    private var task: Task<Void, Never>?

    init(finder: LargeFileFinder) {
        self.finder = finder
    }

    var sortedHits: [LargeFileHit] {
        sortMode.sortedHits(hits)
    }

    var thresholdBytes: UInt64 {
        if let preset = thresholdChoice.preset {
            return preset.rawValue
        }
        return UInt64(max(1, customThresholdMB)) * 1024 * 1024
    }

    var thresholdTitle: String {
        if thresholdChoice == .custom {
            return LumaL10n.format("> %lld MB", Int64(max(1, customThresholdMB)))
        }
        return thresholdChoice.title
    }

    func selectThreshold(_ choice: LargeFileThresholdChoice) {
        thresholdChoice = choice
        if let preset = choice.preset {
            customThresholdMB = preset.mebibytes
        }
    }

    func scan() {
        task?.cancel()
        let roots = scope.roots()
        let minBytes = thresholdBytes

        task = Task {
            isScanning = true
            errorMessage = nil
            hits = []
            filesExamined = 0
            progressLabel = LumaL10n.string("Starting…")
            progressFraction = 0
            do {
                let result = try await finder.find(in: roots, minBytes: minBytes) { [weak self] update in
                    Task { @MainActor in
                        guard let self else { return }
                        self.progressLabel = update.label
                        self.progressFraction = update.fractionComplete
                        self.filesExamined = update.filesExamined
                        self.hits = update.previewHits
                    }
                }
                hits = result.hits
                filesExamined = result.filesExamined
                progressFraction = 1
                hasScanned = true
            } catch is CancellationError {
                errorMessage = nil
                progressFraction = 0
                if hits.isEmpty {
                    hasScanned = false
                } else {
                    hasScanned = true
                }
            } catch {
                errorMessage = error.localizedDescription
                hasScanned = true
            }
            isScanning = false
        }
    }

    func cancel() { task?.cancel() }
}

@Observable
@MainActor
final class DuplicatesViewModel {
    private let finder: DuplicateFinder
    var groups: [DuplicateGroup] = []
    var isScanning = false
    var hasScanned = false
    var progressLabel = ""
    var progressFraction = 0.0
    var errorMessage: String?
    var filesExamined = 0
    var filesAboveThreshold = 0
    var sizeCollisionBuckets = 0
    var minSizeChoice: DuplicateMinSizeChoice = .kb100
    /// Used when `minSizeChoice == .custom` (mebibytes; fractional OK, e.g. 0.1 ≈ 100 KB).
    var customMinMB: Double = 0.1
    var scope: FileScanScope = .homeAndApps
    var sortMode: DuplicateGroupSort = .reclaimable
    private var task: Task<Void, Never>?

    init(finder: DuplicateFinder) {
        self.finder = finder
    }

    var totalWastedBytes: UInt64 {
        groups.reduce(0) { $0 + $1.wastedBytes }
    }

    var sortedGroups: [DuplicateGroup] {
        sortMode.sorted(groups)
    }

    var minSizeBytes: UInt64 {
        if let preset = minSizeChoice.preset {
            return preset.rawValue
        }
        let mb = max(customMinMB, 0.01)
        return UInt64((mb * 1024.0 * 1024.0).rounded())
    }

    var minSizeTitle: String {
        if minSizeChoice == .custom {
            if customMinMB >= 1 {
                return LumaL10n.format("≥ %.1f MB", customMinMB)
            }
            let kb = Int((max(customMinMB, 0.01) * 1024.0).rounded())
            return LumaL10n.format("≥ %lld KB", Int64(max(kb, 1)))
        }
        return minSizeChoice.title
    }

    func selectMinSize(_ choice: DuplicateMinSizeChoice) {
        minSizeChoice = choice
        if let preset = choice.preset {
            customMinMB = preset.mebibytes
        }
    }

    func scan() {
        task?.cancel()
        let roots = scope.roots()
        let threshold = minSizeBytes

        task = Task {
            isScanning = true
            errorMessage = nil
            groups = []
            filesExamined = 0
            filesAboveThreshold = 0
            sizeCollisionBuckets = 0
            progressLabel = LumaL10n.string("Starting…")
            progressFraction = 0
            do {
                let result = try await finder.findDuplicates(in: roots, minBytes: threshold) { [weak self] update in
                    Task { @MainActor in
                        guard let self else { return }
                        self.progressLabel = update.label
                        self.progressFraction = update.fractionComplete
                        self.filesExamined = update.filesExamined
                        self.groups = update.previewGroups
                    }
                }
                groups = result.groups
                filesExamined = result.filesExamined
                filesAboveThreshold = result.filesAboveThreshold
                sizeCollisionBuckets = result.sizeCollisionBuckets
                progressFraction = 1
                hasScanned = true
            } catch is CancellationError {
                errorMessage = nil
                progressFraction = 0
                if groups.isEmpty {
                    hasScanned = false
                } else {
                    hasScanned = true
                }
            } catch {
                errorMessage = error.localizedDescription
                hasScanned = true
            }
            isScanning = false
        }
    }

    func cancel() { task?.cancel() }

    func trash(path: String) {
        do {
            try FileIO.moveToTrash(URL(fileURLWithPath: path))
            groups = groups.compactMap { group in
                var g = group
                g.paths.removeAll { $0 == path }
                return g.paths.count > 1 ? g : nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class CleanerViewModel {
    private let engine: CleanupEngine
    let rules: [any CleanupRule]
    var selected: Set<String> = []
    var estimates: [String: CleanupEstimate] = [:]
    var results: [CleanupResult] = []
    var isWorking = false
    var errorMessage: String?
    var showConfirm = false
    var pendingMode: CleanupExecutionMode = .trash
    /// True after the user runs Estimate at least once this session.
    var didEstimate = false

    init(engine: CleanupEngine, ruleFilter: (any CleanupRule) -> Bool) {
        self.engine = engine
        let all = CleanupRuleCatalog.allRules()
        self.rules = all.filter(ruleFilter)
        selected = Set(rules.filter(\.isAvailable).prefix(3).map(\.id))
    }

    var developerRules: [any CleanupRule] {
        CleanupRuleCatalog.developerRules()
    }

    /// Totals for currently selected rules that already have an estimate.
    var selectedTotals: (bytes: UInt64, items: Int, rulesWithEstimate: Int) {
        var bytes: UInt64 = 0
        var items = 0
        var rulesWithEstimate = 0
        for id in selected {
            guard let estimate = estimates[id] else { continue }
            bytes += estimate.estimatedBytes
            items += estimate.itemCount
            rulesWithEstimate += 1
        }
        return (bytes, items, rulesWithEstimate)
    }

    func estimateSelected() async {
        guard !selected.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let fresh = try await engine.estimate(ruleIDs: selected)
            for (id, estimate) in fresh {
                estimates[id] = estimate
            }
            // Drop stale estimates for rules no longer selected? Keep them for display.
            didEstimate = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func run(mode: CleanupExecutionMode) async {
        isWorking = true
        defer { isWorking = false }
        do {
            results = try await engine.execute(ruleIDs: selected, mode: mode)
            await estimateSelected()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
