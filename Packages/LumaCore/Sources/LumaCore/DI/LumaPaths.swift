import Foundation

/// Composition-friendly environment values shared across features.
public struct LumaPaths: Sendable {
    public var applicationSupport: URL
    public var operationsLogDirectory: URL
    public var preferencesFile: URL

    public init(applicationSupport: URL) {
        self.applicationSupport = applicationSupport
        self.operationsLogDirectory = applicationSupport.appending(path: "Operations", directoryHint: .isDirectory)
        self.preferencesFile = applicationSupport.appending(path: "preferences.json")
    }

    public static func `default`(fileManager: FileManager = .default) throws -> LumaPaths {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: "Luma", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        let paths = LumaPaths(applicationSupport: base)
        try fileManager.createDirectory(at: paths.operationsLogDirectory, withIntermediateDirectories: true)
        return paths
    }
}

/// User-facing preferences persisted locally (no telemetry).
public struct LumaPreferences: Sendable, Codable, Equatable {
    public var menuBarEnabled: Bool
    public var menuBarHideDock: Bool
    public var metricsIntervalSeconds: Double
    public var weeklyCleanupEnabled: Bool
    public var monthlyCleanupEnabled: Bool
    public var notifyOnCleanup: Bool
    public var defaultCleanupMode: CleanupExecutionMode
    public var languageCode: String

    public init(
        menuBarEnabled: Bool = false,
        menuBarHideDock: Bool = false,
        metricsIntervalSeconds: Double = 2.0,
        weeklyCleanupEnabled: Bool = false,
        monthlyCleanupEnabled: Bool = false,
        notifyOnCleanup: Bool = true,
        defaultCleanupMode: CleanupExecutionMode = .trash,
        languageCode: String = AppLanguage.system.rawValue
    ) {
        self.menuBarEnabled = menuBarEnabled
        self.menuBarHideDock = menuBarHideDock
        self.metricsIntervalSeconds = metricsIntervalSeconds
        self.weeklyCleanupEnabled = weeklyCleanupEnabled
        self.monthlyCleanupEnabled = monthlyCleanupEnabled
        self.notifyOnCleanup = notifyOnCleanup
        self.defaultCleanupMode = defaultCleanupMode
        self.languageCode = languageCode
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        menuBarEnabled = try c.decodeIfPresent(Bool.self, forKey: .menuBarEnabled) ?? false
        menuBarHideDock = try c.decodeIfPresent(Bool.self, forKey: .menuBarHideDock) ?? false
        metricsIntervalSeconds = try c.decodeIfPresent(Double.self, forKey: .metricsIntervalSeconds) ?? 2.0
        weeklyCleanupEnabled = try c.decodeIfPresent(Bool.self, forKey: .weeklyCleanupEnabled) ?? false
        monthlyCleanupEnabled = try c.decodeIfPresent(Bool.self, forKey: .monthlyCleanupEnabled) ?? false
        notifyOnCleanup = try c.decodeIfPresent(Bool.self, forKey: .notifyOnCleanup) ?? true
        defaultCleanupMode = try c.decodeIfPresent(CleanupExecutionMode.self, forKey: .defaultCleanupMode) ?? .trash
        languageCode = try c.decodeIfPresent(String.self, forKey: .languageCode) ?? AppLanguage.system.rawValue
    }

    public static let `default` = LumaPreferences()
}
