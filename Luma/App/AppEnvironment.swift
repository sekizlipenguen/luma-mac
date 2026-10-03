import Foundation
import LumaApps
import LumaCleanup
import LumaCore
import LumaStartup
import LumaStorage
import LumaSupport
import LumaSystem

/// Composition root — wires real services for production.
@MainActor
public final class AppEnvironment: ObservableObject {
    public let paths: LumaPaths
    public let networkSampler: NetworkMetricsSampler
    public let metrics: SystemMetricsService
    public let emulators: EmulatorService
    public let diskHealth: DiskHealthSampler
    public let storageScanner: StorageScanner
    public let largeFileFinder: LargeFileFinder
    public let duplicateFinder: DuplicateFinder
    public let cleanupEngine: CleanupEngine
    public let history: OperationHistoryStore
    public let appInventory: AppInventory
    public let residueScanner: AppResidueScanner
    public let uninstallSession: UninstallSession
    public let startupStore: StartupItemStore
    public let preferencesStore: PreferencesStore
    public let permissionGate: PermissionGate
    public let scheduleManager: ScheduleManager

    @Published public var preferences: LumaPreferences

    public init() throws {
        let paths = try LumaPaths.default()
        self.paths = paths
        let history = OperationHistoryStore(directory: paths.operationsLogDirectory)
        self.history = history
        let networkSampler = NetworkMetricsSampler()
        self.networkSampler = networkSampler
        self.metrics = SystemMetricsService(network: networkSampler)
        self.emulators = EmulatorService()
        self.diskHealth = DiskHealthSampler()
        self.storageScanner = StorageScanner()
        self.largeFileFinder = LargeFileFinder()
        self.duplicateFinder = DuplicateFinder()
        self.cleanupEngine = CleanupEngine(history: history)
        self.appInventory = AppInventory()
        self.residueScanner = AppResidueScanner()
        self.uninstallSession = UninstallSession()
        self.startupStore = StartupItemStore()
        let prefsStore = PreferencesStore(fileURL: paths.preferencesFile)
        self.preferencesStore = prefsStore
        self.preferences = (try? prefsStore.load()) ?? .default
        self.permissionGate = .shared
        self.scheduleManager = ScheduleManager(preferencesStore: prefsStore)
        permissionGate.refreshFullDiskAccessProbe()
    }

    public func savePreferences() {
        preferencesStore.save(preferences)
        scheduleManager.apply(preferences)
    }
}

public struct PreferencesStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> LumaPreferences {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(LumaPreferences.self, from: data)
    }

    public func save(_ preferences: LumaPreferences) {
        do {
            let data = try JSONEncoder().encode(preferences)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            LumaLog.general.error("Failed to save preferences: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Installs/removes a user LaunchAgent for scheduled maintenance when enabled.
public final class ScheduleManager: @unchecked Sendable {
    private let preferencesStore: PreferencesStore
    private let label = "dev.luma.app.schedule"

    public init(preferencesStore: PreferencesStore) {
        self.preferencesStore = preferencesStore
    }

    public func apply(_ preferences: LumaPreferences) {
        let agentURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
        if preferences.weeklyCleanupEnabled || preferences.monthlyCleanupEnabled {
            let interval: Int = preferences.weeklyCleanupEnabled ? 7 * 24 * 3600 : 30 * 24 * 3600
            let programArguments = [
                "/usr/bin/open",
                "-b",
                "dev.luma.app",
                "--args",
                "--scheduled-cleanup"
            ]
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": programArguments,
                "StartInterval": interval,
                "RunAtLoad": false
            ]
            do {
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try FileManager.default.createDirectory(
                    at: agentURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: agentURL, options: .atomic)
            } catch {
                LumaLog.general.error("Schedule write failed: \(error.localizedDescription, privacy: .public)")
            }
        } else if FileManager.default.fileExists(atPath: agentURL.path) {
            try? FileManager.default.removeItem(at: agentURL)
        }
        _ = preferencesStore
    }
}
