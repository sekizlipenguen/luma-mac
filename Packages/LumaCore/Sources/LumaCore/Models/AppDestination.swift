import Foundation

/// Sidebar destinations for the main window.
public enum AppDestination: String, CaseIterable, Identifiable, Sendable, Hashable {
    case dashboard
    case cpuProcesses
    case memory
    case network
    case storage
    case cleaner
    case developer
    case emulators
    case apps
    case startup
    case duplicates
    case largeFiles
    case diskHealth
    case security
    case care
    case schedule
    case history
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: LumaL10n.string("Dashboard")
        case .cpuProcesses: LumaL10n.string("CPU Processes")
        case .memory: LumaL10n.string("Memory")
        case .network: LumaL10n.string("Network")
        case .storage: LumaL10n.string("Storage")
        case .cleaner: LumaL10n.string("Cleaner")
        case .developer: LumaL10n.string("Developer")
        case .emulators: LumaL10n.string("Simulators")
        case .apps: LumaL10n.string("Apps")
        case .startup: LumaL10n.string("Startup")
        case .duplicates: LumaL10n.string("Duplicates")
        case .largeFiles: LumaL10n.string("Large Files")
        case .diskHealth: LumaL10n.string("Disk Health")
        case .security: LumaL10n.string("Security")
        case .care: LumaL10n.string("Mac Care")
        case .schedule: LumaL10n.string("Schedule")
        case .history: LumaL10n.string("History")
        case .settings: LumaL10n.string("Settings")
        }
    }

    public var systemImage: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.33percent"
        case .cpuProcesses: "cpu"
        case .memory: "memorychip"
        case .network: "network"
        case .storage: "externaldrive"
        case .cleaner: "trash"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .emulators: "iphone.gen3"
        case .apps: "app.badge"
        case .startup: "power"
        case .duplicates: "doc.on.doc"
        case .largeFiles: "doc.badge.ellipsis"
        case .diskHealth: "heart.text.square"
        case .security: "lock.shield"
        case .care: "wrench.and.screwdriver"
        case .schedule: "calendar"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }

    /// Sidebar grouping — keeps a long destination list scannable.
    public enum SidebarSection: String, CaseIterable, Identifiable, Sendable {
        case monitor
        case maintenance
        case system

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .monitor: LumaL10n.string("Monitor")
            case .maintenance: LumaL10n.string("Maintenance")
            case .system: LumaL10n.string("System")
            }
        }

        public var destinations: [AppDestination] {
            switch self {
            case .monitor: [.dashboard, .cpuProcesses, .memory, .network, .storage]
            case .maintenance: [.cleaner, .developer, .emulators, .apps, .startup, .duplicates, .largeFiles]
            case .system: [.diskHealth, .security, .care, .schedule, .history, .settings]
            }
        }
    }
}
