import AppKit
import SwiftUI
import LumaCore
import LumaCleanup
import LumaSupport
import LumaSystem
import LumaUI

/// Plain container — NOT @Observable.
/// Nesting @Observable view-models inside an @Observable session made every
/// metrics tick rebuild NavigationSplitView and pegged CPU at ~100%.
@MainActor
final class AppSession {
    let dashboard: DashboardViewModel
    let emulators: EmulatorsViewModel
    let memory: MemoryViewModel
    let network: NetworkViewModel
    let storage: StorageViewModel
    let largeFiles: LargeFilesViewModel
    let duplicates: DuplicatesViewModel
    let cleaner: CleanerViewModel
    let developer: CleanerViewModel
    let apps: AppsViewModel
    let startup: StartupViewModel
    let diskHealth: DiskHealthViewModel
    let security: SecurityViewModel
    let care: MacCareViewModel
    let history: HistoryViewModel

    init(environment: AppEnvironment) {
        dashboard = DashboardViewModel(metrics: environment.metrics)
        emulators = EmulatorsViewModel(service: environment.emulators)
        dashboard.intervalSeconds = environment.preferences.metricsIntervalSeconds
        memory = MemoryViewModel(metrics: environment.metrics)
        network = NetworkViewModel(sampler: environment.networkSampler)
        network.intervalSeconds = environment.preferences.metricsIntervalSeconds
        storage = StorageViewModel(scanner: environment.storageScanner)
        largeFiles = LargeFilesViewModel(finder: environment.largeFileFinder)
        duplicates = DuplicatesViewModel(finder: environment.duplicateFinder)
        cleaner = CleanerViewModel(engine: environment.cleanupEngine, ruleFilter: { $0.category != "Developer" })
        developer = CleanerViewModel(engine: environment.cleanupEngine, ruleFilter: { $0.category == "Developer" })
        apps = AppsViewModel(
            inventory: environment.appInventory,
            residue: environment.residueScanner,
            uninstall: environment.uninstallSession
        )
        startup = StartupViewModel(store: environment.startupStore)
        diskHealth = DiskHealthViewModel(sampler: environment.diskHealth)
        security = SecurityViewModel(permissionGate: environment.permissionGate)
        care = MacCareViewModel()
        history = HistoryViewModel(history: environment.history)
    }
}

struct ContentView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var destination: AppDestination? = .dashboard
    @State private var session: AppSession?

    var body: some View {
        Group {
            if let session {
                mainShell(session: session)
            } else {
                ProgressView("Starting Luma…")
                    .frame(minWidth: 900, minHeight: 560)
                    .task {
                        let created = AppSession(environment: env)
                        session = created
                        created.dashboard.start()
                    }
            }
        }
    }

    @ViewBuilder
    private func mainShell(session: AppSession) -> some View {
        NavigationSplitView {
            sidebar
        } detail: {
            NavigationStack {
                detail(session: session)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 960, minHeight: 600)
        .onChange(of: env.preferences.metricsIntervalSeconds) { _, newValue in
            session.dashboard.intervalSeconds = newValue
            session.network.intervalSeconds = newValue
        }
        .accessibilityIdentifier("luma.main")
    }

    private var sidebar: some View {
        List(selection: $destination) {
            ForEach(AppDestination.SidebarSection.allCases) { section in
                Section {
                    ForEach(section.destinations) { item in
                        Label {
                            Text(item.title)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: item.systemImage)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .tag(item)
                        .accessibilityIdentifier("sidebar.\(item.rawValue)")
                    }
                } header: {
                    Text(section.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .navigationSplitViewColumnWidth(min: 168, ideal: 196, max: 228)
        .safeAreaInset(edge: .top, spacing: 0) {
            sidebarBrand
        }
        .background(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.22, blue: 0.38).opacity(0.35),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
        }
    }

    private var sidebarBrand: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 4, y: 1)

            VStack(alignment: .leading, spacing: 1) {
                Text("Luma")
                    .font(.headline.weight(.semibold))
                Text("macOS")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Luma")
    }

    @ViewBuilder
    private func detail(session: AppSession) -> some View {
        switch destination {
        case .dashboard, .none:
            DashboardView(model: session.dashboard)
                .accessibilityIdentifier("screen.dashboard")
        case .cpuProcesses:
            CPUProcessesView(model: session.dashboard)
                .accessibilityIdentifier("screen.cpuProcesses")
        case .memory:
            MemoryView(model: session.memory)
                .accessibilityIdentifier("screen.memory")
        case .network:
            NetworkView(model: session.network)
                .accessibilityIdentifier("screen.network")
        case .storage:
            StorageView(model: session.storage)
                .accessibilityIdentifier("screen.storage")
        case .cleaner:
            CleanerView(model: session.cleaner, developerMode: false)
                .accessibilityIdentifier("screen.cleaner")
        case .developer:
            CleanerView(model: session.developer, developerMode: true)
                .accessibilityIdentifier("screen.developer")
        case .emulators:
            EmulatorsView(model: session.emulators)
                .accessibilityIdentifier("screen.emulators")
        case .apps:
            AppsView(model: session.apps)
                .accessibilityIdentifier("screen.apps")
        case .startup:
            StartupView(model: session.startup)
                .accessibilityIdentifier("screen.startup")
        case .duplicates:
            DuplicatesView(model: session.duplicates)
                .accessibilityIdentifier("screen.duplicates")
        case .largeFiles:
            LargeFilesView(model: session.largeFiles)
                .accessibilityIdentifier("screen.largeFiles")
        case .diskHealth:
            DiskHealthView(model: session.diskHealth)
                .accessibilityIdentifier("screen.diskHealth")
        case .security:
            SecurityView(model: session.security)
                .accessibilityIdentifier("screen.security")
        case .care:
            MacCareView(model: session.care)
                .accessibilityIdentifier("screen.care")
        case .schedule:
            ScheduleView()
                .accessibilityIdentifier("screen.schedule")
        case .history:
            HistoryView(model: session.history)
                .accessibilityIdentifier("screen.history")
        case .settings:
            SettingsView()
                .accessibilityIdentifier("screen.settings")
        }
    }
}
