import AppKit
import Foundation
import Observation
import LumaApps
import LumaCleanup
import LumaCore
import LumaStartup
import LumaSystem
import LumaSupport

@Observable
@MainActor
final class AppsViewModel {
    private let inventory: AppInventory
    private let residue: AppResidueScanner
    private let uninstall: UninstallSession

    var apps: [InstalledApp] = []
    var selected: InstalledApp?
    var report: AppResidueReport?
    var selectedResidue: Set<String> = []
    var isLoading = false
    var isMeasuringSizes = false
    var errorMessage: String?
    var lastResult: CleanupResult?
    private var measureTask: Task<Void, Never>?

    /// Sum of measured app bundle sizes (nil sizes excluded).
    var measuredAppsTotalBytes: UInt64 {
        apps.compactMap(\.byteCount).reduce(0, +)
    }

    /// Totals for currently checked residue items.
    var selectedResidueTotals: (bytes: UInt64, count: Int) {
        guard let report else { return (0, 0) }
        var bytes: UInt64 = 0
        var count = 0
        for item in report.items where selectedResidue.contains(item.id) {
            bytes += item.byteCount
            count += 1
        }
        return (bytes, count)
    }

    init(inventory: AppInventory, residue: AppResidueScanner, uninstall: UninstallSession) {
        self.inventory = inventory
        self.residue = residue
        self.uninstall = uninstall
    }

    func load() async {
        measureTask?.cancel()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            apps = try await inventory.listInstalledApps()
            startMeasuringSizes()
        } catch is CancellationError {
            // Navigating away mid-load — keep whatever we already have.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startMeasuringSizes() {
        measureTask?.cancel()
        let urls = apps.map(\.bundleURL)
        guard !urls.isEmpty else { return }
        isMeasuringSizes = true
        measureTask = Task {
            defer { isMeasuringSizes = false }
            do {
                try await inventory.measureAppSizes(bundleURLs: urls) { [weak self] path, bytes in
                    Task { @MainActor in
                        guard let self, !Task.isCancelled else { return }
                        guard let index = self.apps.firstIndex(where: { $0.bundleURL.path == path }) else { return }
                        self.apps[index].byteCount = bytes
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                // Size measurement is best-effort; keep the app list.
            }
        }
    }

    func select(_ app: InstalledApp) async {
        selected = app
        isLoading = true
        defer { isLoading = false }
        do {
            report = try await residue.scan(app: app)
            selectedResidue = Set(report?.items.map(\.id) ?? [])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performUninstall(mode: CleanupExecutionMode) async {
        guard let report else { return }
        let items = report.items.filter { selectedResidue.contains($0.id) }
        do {
            lastResult = try await uninstall.uninstall(items: items, mode: mode)
            if mode != .dryRun {
                await load()
                self.report = nil
                selected = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class StartupViewModel {
    private let store: StartupItemStore
    var items: [StartupItem] = []
    var errorMessage: String?
    var isLoading = false

    init(store: StartupItemStore) {
        self.store = store
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await store.listItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggle(_ item: StartupItem, enabled: Bool) async {
        do {
            try await store.setEnabled(item, enabled: enabled)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class DiskHealthViewModel {
    private let sampler: DiskHealthSampler
    private let disk: DiskMetricsSampler
    var health: DiskHealthMetrics?
    var volumes: [DiskVolumeMetrics] = []
    var errorMessage: String?

    init(sampler: DiskHealthSampler) {
        self.sampler = sampler
        self.disk = DiskMetricsSampler()
    }

    func refresh() async {
        do {
            volumes = try await disk.sampleVolumes()
            let path = volumes.first(where: { $0.path == "/" })?.path ?? volumes.first?.path ?? "/"
            health = try await sampler.sample(volumePath: path)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class SecurityViewModel {
    private let sampler = SecurityStatusSampler()
    private let permissionGate: PermissionGate

    var snapshot: SecuritySnapshot?
    var isLoading = false
    var errorMessage: String?

    init(permissionGate: PermissionGate) {
        self.permissionGate = permissionGate
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        permissionGate.refreshFullDiskAccessProbe()
        snapshot = await sampler.sample(
            fullDiskAccessGranted: permissionGate.lastProbeSucceeded,
            fullDiskAccessDetail: permissionGate.lastProbeDetail
        )
    }

    func openSettings(for check: SecurityCheckItem) {
        guard let string = check.settingsURLString, let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

@Observable
@MainActor
final class MacCareViewModel {
    var scan: MacCareScanReport?
    var isScanning = false
    var isWorking = false
    var selectedPaths: Set<String> = []
    var lastAction: MacCareActionReport?
    var errorMessage: String?

    /// Paths safe to hide: leftovers + duplicate copies that are not the running /Applications install.
    var hideablePaths: [String] {
        guard let scan else { return Array(selectedPaths).sorted() }
        var paths = Set(selectedPaths)
        for hit in scan.leftovers where !hit.isRunningApp && !hit.isInApplications {
            paths.insert(hit.path)
        }
        return paths.sorted()
    }

    func scanDuplicates() async {
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }
        let report = await MacCareService.scanDuplicateApps()
        scan = report
        var preselect = Set<String>()
        for hit in report.leftovers where !hit.isRunningApp {
            preselect.insert(hit.path)
        }
        for group in report.groups {
            for hit in group.hits where !hit.isRunningApp {
                if !hit.exists || !hit.isInApplications || hit.isDevLeftover {
                    preselect.insert(hit.path)
                }
            }
        }
        selectedPaths = preselect
    }

    func togglePath(_ path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.insert(path)
        }
    }

    /// Primary fix for “two Lumas + UITests-Runner” in Launchpad.
    func hideSelectedFromLaunchpad() async {
        let paths = hideablePaths
        guard !paths.isEmpty else { return }
        await runAction {
            try await MacCareService.hideFromLaunchpad(
                paths: paths,
                keepRegisteredPath: "/Applications/Luma.app"
            )
        }
        await scanDuplicates()
    }

    func unregisterSelected() async {
        let paths = Array(selectedPaths).sorted()
        guard !paths.isEmpty else { return }
        await runAction {
            try await MacCareService.unregister(paths: paths)
        }
        await scanDuplicates()
    }

    func rebuildLaunchServices() async {
        await runAction {
            try await MacCareService.rebuildLaunchServices()
        }
        await scanDuplicates()
    }

    func resetLaunchpad() async {
        await runAction {
            try await MacCareService.resetLaunchpad()
        }
    }

    func flushIconCache() async {
        await runAction {
            try await MacCareService.flushIconCache()
        }
    }

    private func runAction(_ work: () async throws -> MacCareActionReport) async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            lastAction = try await work()
        } catch let error as MacCareService.CareError {
            switch error {
            case .cancelled:
                lastAction = MacCareActionReport(steps: [], cancelled: true)
            case .failed(let message):
                errorMessage = message
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class HistoryViewModel {
    private let history: OperationHistoryStore
    var entries: [OperationLogEntry] = []
    var errorMessage: String?

    init(history: OperationHistoryStore) {
        self.history = history
    }

    func load() async {
        do {
            entries = try await history.recent(limit: 100)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
