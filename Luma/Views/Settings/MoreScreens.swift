import AppKit
import SwiftUI
import UserNotifications
import LumaCore
import LumaSupport
import LumaSystem
import LumaUI

struct DiskHealthView: View {
    @Bindable var model: DiskHealthViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let health = model.health {
                    MetricCard(title: "Volume", systemImage: "internaldrive") {
                        LabeledContent("Path", value: health.volumePath)
                        LabeledContent("Filesystem", value: health.fileSystem)
                        LabeledContent("Medium", value: health.mediumType ?? "—")
                        LabeledContent("SMART") {
                            if let status = health.smartStatus {
                                Text(LocalizedStringKey(status))
                            } else {
                                Text("Not reported")
                            }
                        }
                        LabeledContent("Temperature") {
                            if let c = health.temperatureCelsius {
                                Text(String(format: "%.1f°C", c))
                            } else {
                                Text("Not available")
                            }
                        }
                        LabeledContent("Wear") {
                            if let w = health.wearLevelPercent {
                                Text(String(format: "%.0f%%", w))
                            } else {
                                Text("Not available")
                            }
                        }
                        Text(LocalizedStringKey(health.sourceDescription))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let reason = health.unavailableReason {
                            Text(LocalizedStringKey(reason)).font(.caption).foregroundStyle(.orange)
                        }
                    }
                } else {
                    ProgressView("Reading diskutil…")
                }
            }
            .padding()
        }
        .navigationTitle("Disk Health")
        .task { await model.refresh() }
        .toolbar {
            Button("Refresh") { Task { await model.refresh() } }
        }
    }
}

struct SecurityView: View {
    @Bindable var model: SecurityViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                honestyBanner

                if let error = model.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if model.isLoading && model.snapshot == nil {
                    ProgressView("Checking built-in protections…")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if let snapshot = model.snapshot {
                    summaryCard(snapshot)
                    ForEach(snapshot.checks) { check in
                        checkCard(check)
                    }
                    Text(LocalizedStringKey(snapshot.honestyNote))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(LumaL10n.format(
                        "Last checked %@",
                        snapshot.sampledAt.formatted(date: .abbreviated, time: .shortened)
                    ))
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                }
            }
            .padding(20)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Security")
        .task { await model.refresh() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
            }
        }
    }

    private var honestyBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(LumaTheme.thermal)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("Security hygiene")
                    .font(.headline)
                Text("Shows FileVault, firewall, Gatekeeper, SIP, permissions, and quarantine flags from macOS tools. Not a virus scanner — Luma never invents a “clean” score.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                .fill(LumaTheme.thermal.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                        .strokeBorder(LumaTheme.thermal.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private func summaryCard(_ snapshot: SecuritySnapshot) -> some View {
        MetricCard(title: "At a glance", systemImage: "checklist", accent: LumaTheme.thermal) {
            HStack(spacing: 16) {
                labeledCount(
                    Int64(snapshot.checks.filter { $0.state == .ok }.count),
                    label: "OK",
                    tint: LumaTheme.network
                )
                labeledCount(
                    Int64(snapshot.attentionCount),
                    label: "Attention",
                    tint: LumaTheme.battery
                )
                labeledCount(
                    Int64(snapshot.unknownCount),
                    label: "Unknown",
                    tint: .secondary
                )
                Spacer(minLength: 0)
            }
        }
    }

    private func labeledCount(_ value: Int64, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title2.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
            Text(LocalizedStringKey(label))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func checkCard(_ check: SecurityCheckItem) -> some View {
        MetricCard(
            title: LocalizedStringKey(check.title),
            systemImage: icon(for: check.state),
            accent: tint(for: check.state)
        ) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(check.summary))
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 8)
                stateChip(check.state)
            }

            Text(LocalizedStringKey(check.detail))
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Text(LumaL10n.format("Source: %@", check.source))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)

            if check.settingsURLString != nil {
                Button {
                    model.openSettings(for: check)
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }

    private func stateChip(_ state: SecurityCheckState) -> some View {
        let (label, color): (LocalizedStringKey, Color) = {
            switch state {
            case .ok: ("OK", LumaTheme.network)
            case .attention: ("Attention", LumaTheme.battery)
            case .unknown: ("Unknown", .secondary)
            case .info: ("Info", LumaTheme.cpu)
            }
        }()
        return Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private func tint(for state: SecurityCheckState) -> Color {
        switch state {
        case .ok: LumaTheme.network
        case .attention: LumaTheme.battery
        case .unknown: .secondary
        case .info: LumaTheme.cpu
        }
    }

    private func icon(for state: SecurityCheckState) -> String {
        switch state {
        case .ok: "checkmark.shield.fill"
        case .attention: "exclamationmark.shield.fill"
        case .unknown: "questionmark.circle.fill"
        case .info: "info.circle.fill"
        }
    }
}

struct MacCareView: View {
    @Bindable var model: MacCareViewModel
    @State private var confirmRebuild = false
    @State private var confirmLaunchpad = false
    @State private var confirmIcons = false
    @State private var confirmUnregister = false
    @State private var confirmHideLaunchpad = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                honestyBanner

                if let error = model.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                leftoversCard
                duplicatesCard
                launchServicesCard
                launchpadCard
                iconCacheCard
                lastActionCard
            }
            .padding(20)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Mac Care")
        .task {
            if model.scan == nil {
                await model.scanDuplicates()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.scanDuplicates() }
                } label: {
                    Label("Scan again", systemImage: "arrow.clockwise")
                }
                .disabled(model.isScanning || model.isWorking)
            }
        }
        .confirmationDialog(
            "Remove leftovers from search?",
            isPresented: $confirmHideLaunchpad,
            titleVisibility: .visible
        ) {
            Button("Move leftovers to Trash", role: .destructive) {
                Task { await model.hideSelectedFromLaunchpad() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Spotlight keeps showing apps that still exist. This moves Xcode/DerivedData copies and UITest runners to Trash, unregisters them, and keeps /Applications/Luma.app. Xcode can recreate them on the next build.")
        }
        .confirmationDialog(
            "Unregister selected app paths?",
            isPresented: $confirmUnregister,
            titleVisibility: .visible
        ) {
            Button("Unregister from Launch Services", role: .destructive) {
                Task { await model.unregisterSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes Spotlight / Open With / Launchpad registrations for the selected paths. Does not delete the .app folders themselves.")
        }
        .confirmationDialog(
            "Rebuild Launch Services?",
            isPresented: $confirmRebuild,
            titleVisibility: .visible
        ) {
            Button("Rebuild Launch Services") {
                Task { await model.rebuildLaunchServices() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Rebuilds the system app database (admin password). Fixes stubborn duplicate search results. Dock restarts briefly.")
        }
        .confirmationDialog(
            "Reset Launchpad?",
            isPresented: $confirmLaunchpad,
            titleVisibility: .visible
        ) {
            Button("Reset Launchpad", role: .destructive) {
                Task { await model.resetLaunchpad() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes the Launchpad layout database and restarts Dock. Icons reshuffle to defaults — folders you made in Launchpad are lost.")
        }
        .confirmationDialog(
            "Flush icon cache?",
            isPresented: $confirmIcons,
            titleVisibility: .visible
        ) {
            Button("Flush icon cache") {
                Task { await model.flushIconCache() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears the iconservices store (admin password) and restarts Dock & Finder. Use when icons look wrong or stale.")
        }
    }

    private var honestyBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.title3)
                .foregroundStyle(LumaTheme.cpu)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("macOS hygiene — not magic boosts")
                    .font(.headline)
                Text("Two “Luma” tiles plus a UITests-Runner usually means one real /Applications install and Xcode build leftovers still on disk. Spotlight indexes those files — Luma moves them to Trash.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                .fill(LumaTheme.cpu.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                        .strokeBorder(LumaTheme.cpu.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private var leftoversCard: some View {
        MetricCard(title: "Launchpad / search leftovers", systemImage: "app.badge.checkmark", accent: LumaTheme.battery) {
            Text("Xcode DerivedData builds and UITest runners that appear next to your real app.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.isScanning && model.scan == nil {
                ProgressView("Scanning for leftovers…")
            } else if let scan = model.scan {
                if scan.leftovers.isEmpty {
                    Label("No Xcode / UITest leftovers found", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(LumaTheme.network)
                        .font(.callout.weight(.medium))
                } else {
                    Text(LumaL10n.format("%lld leftover apps", Int64(scan.leftovers.count)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(scan.leftovers) { hit in
                        duplicateHitRow(hit)
                    }

                    Button {
                        confirmHideLaunchpad = true
                    } label: {
                        Label("Remove leftovers from search", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LumaTheme.battery)
                    .disabled(model.hideablePaths.isEmpty || model.isWorking || model.isScanning)

                    Text("Moves leftovers to Trash (Spotlight indexes files that still exist). Keeps /Applications/Luma.app.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var duplicatesCard: some View {
        MetricCard(title: "Duplicate apps in search", systemImage: "doc.on.doc", accent: LumaTheme.storage) {
            Text("Same name or bundle ID registered at more than one path.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.isScanning && model.scan == nil {
                ProgressView("Scanning for duplicates…")
            } else if let scan = model.scan {
                if scan.groups.isEmpty {
                    Label("No duplicate app registrations found", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(LumaTheme.network)
                        .font(.callout.weight(.medium))
                } else {
                    Text(LumaL10n.format(
                        "%lld duplicate groups · %lld paths",
                        Int64(scan.groups.count),
                        Int64(scan.duplicatePathCount)
                    ))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    ForEach(scan.groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.kind == .bundleIdentifier
                                ? LumaL10n.format("Bundle ID %@", group.key)
                                : LumaL10n.format("Name %@", group.key))
                                .font(.subheadline.weight(.semibold))
                            ForEach(group.hits) { hit in
                                duplicateHitRow(hit)
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    HStack(spacing: 10) {
                        Button {
                            confirmHideLaunchpad = true
                        } label: {
                            Label("Remove selected from search", systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(LumaTheme.storage)
                        .disabled(model.hideablePaths.isEmpty || model.isWorking || model.isScanning)

                        Button {
                            confirmUnregister = true
                        } label: {
                            Label("Unregister only", systemImage: "link.badge.minus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.selectedPaths.isEmpty || model.isWorking || model.isScanning)
                    }
                }

                Text(LocalizedStringKey(scan.note))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func duplicateHitRow(_ hit: MacCareAppHit) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                model.togglePath(hit.path)
            } label: {
                Image(systemName: model.selectedPaths.contains(hit.path) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(model.selectedPaths.contains(hit.path) ? LumaTheme.storage : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(hit.isRunningApp || (hit.isInApplications && !hit.isDevLeftover))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(hit.name)
                        .font(.callout.weight(.medium))
                    if hit.isRunningApp {
                        chip("This Luma", tint: LumaTheme.network)
                    }
                    if hit.isInApplications && !hit.isDevLeftover {
                        chip("Real install", tint: LumaTheme.network)
                    }
                    if hit.isDevLeftover {
                        chip("Xcode leftover", tint: LumaTheme.battery)
                    }
                    if !hit.exists {
                        chip("Missing file", tint: .orange)
                    }
                }
                Text(hit.path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ title: LocalizedStringKey, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
    }

    private var launchServicesCard: some View {
        MetricCard(title: "Launch Services", systemImage: "arrow.triangle.2.circlepath", accent: LumaTheme.network) {
            Text("Nuclear option when unregistering stale paths is not enough — rebuilds the app database.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                confirmRebuild = true
            } label: {
                Label("Rebuild Launch Services", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
            .disabled(model.isWorking)
        }
    }

    private var launchpadCard: some View {
        MetricCard(title: "Launchpad", systemImage: "square.grid.3x3", accent: LumaTheme.battery) {
            Text("Ghost icons or a stuck Launchpad layout. Resets your Launchpad arrangement.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(role: .destructive) {
                confirmLaunchpad = true
            } label: {
                Label("Reset Launchpad", systemImage: "square.grid.3x3.fill")
            }
            .buttonStyle(.bordered)
            .disabled(model.isWorking)
        }
    }

    private var iconCacheCard: some View {
        MetricCard(title: "Icon cache", systemImage: "photo", accent: LumaTheme.memory) {
            Text("Wrong or blank icons after updates. Flushes iconservices and restarts Dock & Finder.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                confirmIcons = true
            } label: {
                Label("Flush icon cache", systemImage: "photo")
            }
            .buttonStyle(.bordered)
            .disabled(model.isWorking)
        }
    }

    @ViewBuilder
    private var lastActionCard: some View {
        if model.isWorking {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Working…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if let report = model.lastAction {
            MetricCard(title: "Last action", systemImage: "checkmark.circle", accent: .secondary) {
                if report.cancelled {
                    Text("Cancelled — no changes applied.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(report.steps) { step in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: step.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(step.succeeded ? LumaTheme.network : .red)
                                .font(.caption)
                            Text(LocalizedStringKey(step.title))
                                .font(.caption)
                            if let detail = step.detail {
                                Text(detail)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct HistoryView: View {
    @Bindable var model: HistoryViewModel

    var body: some View {
        List(model.entries) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(entry.ruleTitle)).font(.headline)
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(LumaL10n.format(
                    "Mode %@ · estimated %@ · recovered %@",
                    entry.mode.rawValue,
                    ByteFormatters.string(for: entry.estimatedBytes),
                    ByteFormatters.string(for: entry.recoveredBytes)
                ))
                    .font(.caption.monospacedDigit())
                if !entry.notes.isEmpty {
                    Text(LocalizedStringKey(entry.notes)).font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("History")
        .task { await model.load() }
        .overlay {
            if model.entries.isEmpty {
                ContentUnavailableView("No operations yet", systemImage: "clock", description: Text("Cleanup history is stored locally in Application Support."))
            }
        }
    }
}

struct ScheduleView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        Form {
            Section("Maintenance") {
                Toggle(
                    "Weekly cleanup reminder (LaunchAgent)",
                    isOn: Binding(
                        get: { env.preferences.weeklyCleanupEnabled },
                        set: { env.preferences.weeklyCleanupEnabled = $0; env.savePreferences() }
                    )
                )
                Toggle(
                    "Monthly cleanup reminder (LaunchAgent)",
                    isOn: Binding(
                        get: { env.preferences.monthlyCleanupEnabled },
                        set: { env.preferences.monthlyCleanupEnabled = $0; env.savePreferences() }
                    )
                )
                Toggle(
                    "Notify when scheduled cleanup opens Luma",
                    isOn: Binding(
                        get: { env.preferences.notifyOnCleanup },
                        set: { env.preferences.notifyOnCleanup = $0; env.savePreferences() }
                    )
                )
            }
            Section {
                Text("Scheduling installs a user LaunchAgent that opens Luma with --scheduled-cleanup. No cloud. Disable anytime.")
                    .foregroundStyle(.secondary)
                Button("Request Notification Permission") {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
            }
        }
        .navigationTitle("Schedule")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @AppStorage("luma.menuBarEnabled") private var menuBarEnabled = false
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.system.rawValue
    @State private var showProbeDetail = false

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    private var intervalBinding: Binding<Double> {
        Binding(
            get: { env.preferences.metricsIntervalSeconds },
            set: { env.preferences.metricsIntervalSeconds = $0; env.savePreferences() }
        )
    }

    private var hideDockBinding: Binding<Bool> {
        Binding(
            get: { env.preferences.menuBarHideDock },
            set: { newValue in
                env.preferences.menuBarHideDock = newValue
                env.savePreferences()
                if menuBarEnabled && newValue {
                    NSApp.setActivationPolicy(.accessory)
                } else {
                    NSApp.setActivationPolicy(.regular)
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                aboutCard
                languageCard
                permissionsCard
                finderSizeCard

                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        menuBarCard
                        metricsCard
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Settings")
        .accessibilityIdentifier("settings.root")
        .onAppear {
            menuBarEnabled = env.preferences.menuBarEnabled
            env.permissionGate.refreshFullDiskAccessProbe()
        }
        .onChange(of: languageCode) { _, newValue in
            env.preferences.languageCode = newValue
            env.savePreferences()
        }
    }

    // MARK: - Cards

    private var aboutCard: some View {
        MetricCard(title: "About", systemImage: "info.circle", accent: LumaTheme.cpu) {
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Luma")
                        .font(.title2.weight(.semibold))
                    Text(LumaL10n.format("Version %@", appVersion))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("dev.luma.app")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)
            }

            Text("Free to use. Source available; modifications require permission. No telemetry, no ads, no fake RAM cleaning.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var languageCard: some View {
        MetricCard(title: "Language", systemImage: "globe", accent: LumaTheme.memory) {
            Picker(selection: $languageCode) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.nativeName)
                        .tag(language.rawValue)
                }
            } label: {
                Text("Language")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 280, alignment: .leading)

            Text("Turkish is listed first among common languages. Changing language updates Luma everywhere immediately.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permissionsCard: some View {
        let granted = env.permissionGate.lastProbeSucceeded
        let accent: Color = granted ? LumaTheme.network : LumaTheme.thermal

        return MetricCard(title: "Permissions", systemImage: "lock.shield", accent: accent) {
            HStack(alignment: .center, spacing: 12) {
                statusBadge(
                    granted ? "Granted" : "Missing",
                    tint: accent,
                    systemImage: granted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                )
                Spacer(minLength: 0)
            }

            Text(
                granted
                    ? "Full Disk Access looks granted. Protected Library paths can be scanned."
                    : "Grant Full Disk Access so Luma can scan protected folders such as Safari Library. Without it, Luma still works but skips those paths."
            )
            .font(.callout)
            .foregroundStyle(.primary.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup(isExpanded: $showProbeDetail) {
                Text(env.permissionGate.lastProbeDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            } label: {
                Text("Technical details")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    env.permissionGate.openFullDiskAccessSettings()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .controlSize(.regular)

                Button {
                    env.permissionGate.refreshFullDiskAccessProbe()
                } label: {
                    Label("Re-check", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }

    private var finderSizeCard: some View {
        MetricCard(title: "Finder folder size", systemImage: "finder", accent: LumaTheme.storage) {
            Text("Luma cannot paint a GB label next to every folder in Finder’s list — Apple does not allow that. It can measure the folder you select.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Right-click a folder → Quick Actions / Services → Folder size in Luma. Or enable the Luma Finder extension (toolbar + context menu). Finder itself can Calculate all sizes in list view options.")
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open Login Items & Extensions", systemImage: "puzzlepiece.extension")
            }
            .buttonStyle(.bordered)
        }
    }

    private var menuBarCard: some View {
        MetricCard(title: "Menu Bar", systemImage: "menubar.rectangle", accent: LumaTheme.battery) {
            Toggle("Show menu bar extra", isOn: $menuBarEnabled)
                .accessibilityIdentifier("settings.menuBarEnabled")
                .onChange(of: menuBarEnabled) { _, newValue in
                    env.preferences.menuBarEnabled = newValue
                    env.savePreferences()
                    if !newValue {
                        NSApp.setActivationPolicy(.regular)
                    } else if env.preferences.menuBarHideDock {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }

            Toggle("Hide Dock icon when menu bar enabled", isOn: hideDockBinding)
                .accessibilityIdentifier("settings.menuBarHideDock")
                .disabled(!menuBarEnabled)

            Text("Keep Luma in the menu bar for quick access. Hiding the Dock icon turns Luma into an accessory app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var metricsCard: some View {
        MetricCard(title: "Metrics", systemImage: "gauge.with.dots.needle.33percent", accent: LumaTheme.storage) {
            HStack(alignment: .firstTextBaseline) {
                Text("Refresh interval")
                    .font(.callout)
                Spacer(minLength: 8)
                Text(LumaL10n.format("%.1f s", intervalBinding.wrappedValue))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(LumaTheme.storage)
            }

            Slider(value: intervalBinding, in: 0.5...5, step: 0.5) {
                Text("Refresh interval")
            } minimumValueLabel: {
                Text("0.5s")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("5s")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("settings.metricsInterval")

            Text("How often Dashboard, Memory, and Network refresh live readings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusBadge(_ title: LocalizedStringKey, tint: Color, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}
