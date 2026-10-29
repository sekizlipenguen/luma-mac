import SwiftUI
import LumaApps
import LumaCleanup
import LumaCore
import LumaSupport
import LumaStartup
import LumaUI

struct CleanerView: View {
    @Bindable var model: CleanerViewModel
    var developerMode: Bool = false

    private var displayedRules: [any CleanupRule] {
        model.rules
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    Text(developerMode
                         ? LumaL10n.string("Each developer cache is optional. Preview with Dry Run before moving to Trash.")
                         : LumaL10n.string("Allowlisted cleanups only. Default action moves to Trash so you can Undo from Finder."))
                        .foregroundStyle(.secondary)
                }
                Section(LumaL10n.string("Rules")) {
                    ForEach(displayedRules, id: \.id) { rule in
                        Toggle(isOn: Binding(
                            get: { model.selected.contains(rule.id) },
                            set: { on in
                                if on { model.selected.insert(rule.id) } else { model.selected.remove(rule.id) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(LumaL10n.string(rule.title))
                                    if !rule.isAvailable {
                                        Text(LumaL10n.string("Unavailable"))
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.quaternary, in: Capsule())
                                    }
                                    Spacer()
                                    Text(LumaL10n.string(rule.riskLevel.rawValue))
                                        .font(.caption)
                                        .foregroundStyle(riskColor(rule.riskLevel))
                                }
                                Text(LumaL10n.string(rule.explanation))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let reason = rule.unavailableReason, !rule.isAvailable {
                                    Text(LumaL10n.string(reason)).font(.caption2).foregroundStyle(.orange)
                                }
                                if let estimate = model.estimates[rule.id] {
                                    Text(
                                        LumaL10n.format(
                                            "~%@ · %@",
                                            ByteFormatters.string(for: estimate.estimatedBytes),
                                            LumaL10n.itemCountLabel(estimate.itemCount)
                                        )
                                    )
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(!rule.isAvailable)
                    }
                }
                if !model.results.isEmpty {
                    Section(LumaL10n.string("Last results")) {
                        ForEach(Array(model.results.enumerated()), id: \.offset) { _, result in
                            VStack(alignment: .leading) {
                                Text(LumaL10n.format("%@ · %@", result.ruleID, result.mode.rawValue))
                                Text(LumaL10n.format(
                                    "Estimated %@ → recovered %@",
                                    ByteFormatters.string(for: result.estimatedBytes),
                                    ByteFormatters.string(for: result.recoveredBytes)
                                ))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            selectedTotalBar

            HStack {
                Button(LumaL10n.string("Dry Run")) {
                    Task { await model.run(mode: .dryRun) }
                }
                .disabled(model.selected.isEmpty || model.isWorking)
                Button(LumaL10n.string("Estimate")) {
                    Task { await model.estimateSelected() }
                }
                .disabled(model.selected.isEmpty || model.isWorking)
                Spacer()
                Button(LumaL10n.string("Move to Trash…")) {
                    model.pendingMode = .trash
                    model.showConfirm = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selected.isEmpty || model.isWorking)
            }
            .padding()
        }
        .navigationTitle(developerMode ? LumaL10n.string("Developer") : LumaL10n.string("Cleaner"))
        .confirmationDialog(
            LumaL10n.string("Move selected items to Trash?"),
            isPresented: $model.showConfirm,
            titleVisibility: .visible
        ) {
            Button(LumaL10n.string("Move to Trash"), role: .destructive) {
                Task { await model.run(mode: .trash) }
            }
            Button(LumaL10n.string("Cancel"), role: .cancel) {}
        } message: {
            let totals = model.selectedTotals
            if model.didEstimate, totals.rulesWithEstimate > 0 {
                Text(LumaL10n.format(
                    "About to free %@ · %@",
                    ByteFormatters.string(for: totals.bytes),
                    LumaL10n.itemCountLabel(totals.items)
                ))
            } else {
                Text(LumaL10n.string("You can restore from Trash. Permanent delete is not used by default."))
            }
        }
        .overlay {
            if model.isWorking { ProgressView().controlSize(.large) }
        }
    }

    @ViewBuilder
    private var selectedTotalBar: some View {
        let totals = model.selectedTotals
        let missing = model.selected.count - totals.rulesWithEstimate
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LumaL10n.string("Selected total"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(LumaL10n.format("%lld selected", Int64(model.selected.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if totals.rulesWithEstimate > 0 {
                Text(LumaL10n.format(
                    "Will free about %@ · %@",
                    ByteFormatters.string(for: totals.bytes),
                    LumaL10n.itemCountLabel(totals.items)
                ))
                .font(.title3.monospacedDigit().weight(.semibold))
                if missing > 0 {
                    Text(LumaL10n.format("Run Estimate for %lld more selected rule(s).", Int64(missing)))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } else if model.selected.isEmpty {
                Text(LumaL10n.string("Select rules, then tap Estimate."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(LumaL10n.string("Tap Estimate to calculate how much space the selection can free."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.background.secondary)
    }

    private func riskColor(_ level: CleanupRiskLevel) -> Color {
        switch level {
        case .safe: .green
        case .caution: .orange
        case .advanced: .red
        }
    }
}

struct AppsView: View {
    @Bindable var model: AppsViewModel
    @State private var confirm = false
    @State private var search = ""

    private var filteredApps: [InstalledApp] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return model.apps }
        return model.apps.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        // Avoid nesting NavigationSplitView inside the main sidebar split — macOS often
        // collapses the inner list to empty width.
        HStack(spacing: 0) {
            appList
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
            Divider()
            appDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Apps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.load() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
            }
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private var appList: some View {
        VStack(spacing: 0) {
            TextField("Search apps", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(10)

            if model.isLoading && model.apps.isEmpty {
                ProgressView("Loading apps…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.errorMessage, model.apps.isEmpty {
                ContentUnavailableView {
                    Label("Couldn’t load apps", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await model.load() } }
                }
            } else if filteredApps.isEmpty {
                ContentUnavailableView(
                    "No apps found",
                    systemImage: "app.badge",
                    description: Text("Checked /Applications, ~/Applications, and /System/Applications.")
                )
            } else {
                if model.isMeasuringSizes || model.measuredAppsTotalBytes > 0 {
                    HStack {
                        if model.isMeasuringSizes {
                            ProgressView()
                                .controlSize(.small)
                            Text("Measuring app sizes…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.measuredAppsTotalBytes > 0 {
                            Text(LumaL10n.format(
                                "Measured %@",
                                ByteFormatters.string(for: model.measuredAppsTotalBytes)
                            ))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                }

                List(filteredApps, selection: Binding(
                    get: { model.selected?.id },
                    set: { id in
                        if let app = model.apps.first(where: { $0.id == id }) {
                            Task { await model.select(app) }
                        }
                    }
                )) { app in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            Text(app.bundleIdentifier ?? app.bundleURL.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        appSizeLabel(for: app)
                    }
                    .tag(app.id)
                    .padding(.vertical, 2)
                }
                .listStyle(.sidebar)
            }
        }
    }

    @ViewBuilder
    private func appSizeLabel(for app: InstalledApp) -> some View {
        if let bytes = app.byteCount {
            Text(ByteFormatters.string(for: bytes))
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        } else if model.isMeasuringSizes {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)
        } else {
            Text("—")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var appDetail: some View {
        if model.isLoading, model.selected != nil, model.report == nil {
            ProgressView("Scanning related files…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let report = model.report {
            let totals = model.selectedResidueTotals
            VStack(spacing: 0) {
                selectedResidueSummary(totals: totals, appName: report.app.name)

                List {
                    Section {
                        LabeledContent("App", value: report.app.name)
                        if let version = report.app.version {
                            LabeledContent("Version", value: version)
                        }
                        if let bid = report.app.bundleIdentifier {
                            LabeledContent("Bundle ID", value: bid)
                        }
                        if let bytes = report.app.byteCount {
                            LabeledContent("App size") {
                                Text(ByteFormatters.string(for: bytes))
                                    .monospacedDigit()
                            }
                        }
                        LabeledContent("Path", value: report.app.bundleURL.path)
                    }
                    Section("Related files — select what to remove") {
                        ForEach(report.items) { item in
                            Toggle(isOn: Binding(
                                get: { model.selectedResidue.contains(item.id) },
                                set: { on in
                                    if on { model.selectedResidue.insert(item.id) }
                                    else { model.selectedResidue.remove(item.id) }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(LocalizedStringKey(item.kind))
                                        Text(":")
                                        Text(item.url.lastPathComponent)
                                    }
                                    Text(item.url.path).font(.caption2).foregroundStyle(.secondary)
                                    Text(ByteFormatters.string(for: item.byteCount)).font(.caption.monospacedDigit())
                                }
                            }
                        }
                    }
                }
                HStack {
                    Button("Dry Run") {
                        Task { await model.performUninstall(mode: .dryRun) }
                    }
                    .disabled(model.selectedResidue.isEmpty)
                    Spacer()
                    Button("Move Selected to Trash…", role: .destructive) {
                        confirm = true
                    }
                    .disabled(model.selectedResidue.isEmpty)
                }
                .padding()
                if let result = model.lastResult {
                    Text(LumaL10n.format(
                        "Last: recovered %@ (%@)",
                        ByteFormatters.string(for: result.recoveredBytes),
                        result.mode.rawValue
                    ))
                    .font(.caption)
                    .padding(.bottom)
                }
            }
            .confirmationDialog("Uninstall selected items?", isPresented: $confirm) {
                Button("Move to Trash", role: .destructive) {
                    Task { await model.performUninstall(mode: .trash) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(LumaL10n.format(
                    "About to free %@ · %@",
                    ByteFormatters.string(for: totals.bytes),
                    LumaL10n.itemCountLabel(totals.count)
                ))
            }
        } else {
            ContentUnavailableView(
                "Select an app",
                systemImage: "app.badge",
                description: Text("Review related files before removing anything.")
            )
        }
    }

    private func selectedResidueSummary(totals: (bytes: UInt64, count: Int), appName: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Selected total")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(appName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if totals.count > 0 {
                Text(LumaL10n.format(
                    "Will free about %@ · %@",
                    ByteFormatters.string(for: totals.bytes),
                    LumaL10n.itemCountLabel(totals.count)
                ))
                .font(.title3.monospacedDigit().weight(.semibold))
            } else {
                Text("Select related files to see how much will be removed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background.secondary)
    }
}

struct StartupView: View {
    @Bindable var model: StartupViewModel
    @State private var searchText = ""
    @State private var pendingItem: StartupItem?
    @State private var pendingEnabled = false

    private var userItems: [StartupItem] { model.items.filter(\.isMutable) }
    private var systemItems: [StartupItem] { model.items.filter { !$0.isMutable && $0.kind != "LoginItem" } }
    private var isBusy: Bool { model.isLoading || model.updatingID != nil }

    private func matching(_ items: [StartupItem]) -> [StartupItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? items : items.filter { $0.label.localizedStandardContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(LumaL10n.string("Search startup items"), text: $searchText)
                        .textFieldStyle(.plain)
                        .accessibilityIdentifier("startup.search")
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                            .accessibilityLabel(LumaL10n.string("Clear search"))
                            .accessibilityIdentifier("startup.clearSearch")
                    }
                }
                .padding(12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))

                if !model.hasLoaded {
                    ProgressView().frame(maxWidth: .infinity).padding(32)
                } else if matching(userItems).isEmpty && matching(systemItems).isEmpty {
                    ContentUnavailableView(
                        LumaL10n.string(searchText.isEmpty ? "No startup items found" : "No matching startup items"),
                        systemImage: "power"
                    )
                    .accessibilityIdentifier("startup.empty")
                } else {
                    if !matching(userItems).isEmpty {
                        itemSection(title: "User startup items", symbol: "person.crop.circle", items: matching(userItems))
                    }
                    if !matching(systemItems).isEmpty {
                        itemSection(title: "System services", symbol: "lock.shield", items: matching(systemItems))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Startup")
        .task { await model.load() }
        .confirmationDialog(
            pendingEnabled
                ? LumaL10n.format("Enable %@ at login?", pendingItem?.label ?? "")
                : LumaL10n.format("Disable %@ at login?", pendingItem?.label ?? ""),
            isPresented: Binding(get: { pendingItem != nil }, set: { if !$0 { pendingItem = nil } }),
            titleVisibility: .visible
        ) {
            Button(LumaL10n.string(pendingEnabled ? "Enable" : "Disable"), role: pendingEnabled ? nil : .destructive) {
                guard let item = pendingItem else { return }
                let enabled = pendingEnabled
                pendingItem = nil
                Task { await model.toggle(item, enabled: enabled) }
            }
            Button(LumaL10n.string("Cancel"), role: .cancel) { pendingItem = nil }
        } message: {
            Text(LumaL10n.string("Changes whether this item starts at login. Turning it off may stop its background service."))
        }
        .alert(LumaL10n.string("Could not update startup items"), isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "power")
                    .font(.title2.weight(.semibold)).foregroundStyle(LumaTheme.memory)
                    .frame(width: 44, height: 44)
                    .background(LumaTheme.memory.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(LumaL10n.string("Manage what starts with your Mac."))
                        .font(.title3.weight(.semibold))
                    Text(LumaL10n.string("User items can be switched on or off. System services are view-only."))
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if isBusy { ProgressView().controlSize(.small) }
                Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).font(.body.weight(.medium))
                    .help(LumaL10n.string("Refresh")).disabled(isBusy)
                    .accessibilityLabel(LumaL10n.string("Refresh"))
                    .accessibilityIdentifier("startup.refresh")
            }
            if model.hasLoaded {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { summaryBadges }
                    VStack(alignment: .leading, spacing: 8) { summaryBadges }
                }
            }
            if let loginItem = model.items.first(where: { $0.kind == "LoginItem" }) {
                HStack(spacing: 10) {
                    Text(LumaL10n.string("Manage other login items in System Settings."))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button(LumaL10n.string("Open Settings")) {
                        if let url = URL(string: loginItem.path) { NSWorkspace.shared.open(url) }
                    }
                    .controlSize(.small).accessibilityIdentifier("startup.openSettings")
                }
            }
        }
        .padding(18)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius)
                .strokeBorder(LumaTheme.memory.opacity(0.18), lineWidth: 1)
        }
    }

    @ViewBuilder private var summaryBadges: some View {
        badge(LumaL10n.format("%ld enabled", userItems.filter(\.isEnabled).count), color: LumaTheme.storage)
        badge(LumaL10n.format("%ld disabled", userItems.filter { !$0.isEnabled }.count), color: .secondary)
        badge(LumaL10n.format("%ld system services", systemItems.count), color: LumaTheme.memory)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text).font(.caption.weight(.medium)).monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.10), in: Capsule())
    }

    private func itemSection(title: String, symbol: String, items: [StartupItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(LumaL10n.string(title), systemImage: symbol)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text(String(items.count)).font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
            }
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    startupRow(item)
                    if index < items.count - 1 { Divider().padding(.leading, 62) }
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius)
                    .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
            }
        }
    }

    private func startupRow(_ item: StartupItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.isMutable ? "bolt.circle" : "lock.shield")
                .font(.title3).foregroundStyle(item.isMutable ? LumaTheme.memory : .secondary)
                .frame(width: 32, height: 32)
                .background((item.isMutable ? LumaTheme.memory : Color.secondary).opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.label).font(.body.weight(.medium)).lineLimit(1).truncationMode(.middle)
                    .help(item.label)
                Text(LumaL10n.string(item.kind))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if item.isMutable {
                badge(LumaL10n.string(item.isEnabled ? "Enabled" : "Disabled"), color: item.isEnabled ? LumaTheme.storage : .secondary)
                Toggle(LumaL10n.format("Enable %@ at login", item.label), isOn: Binding(
                    get: { item.isEnabled },
                    set: { enabled in
                        pendingEnabled = enabled
                        pendingItem = item
                    }
                ))
                .toggleStyle(.switch).controlSize(.small).tint(LumaTheme.storage).labelsHidden()
                .disabled(isBusy).accessibilityIdentifier("startup.toggle.\(item.label)")
            } else {
                badge(LumaL10n.string("Read-only"), color: .secondary)
                Button { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)]) } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
                .help(LumaL10n.string("Reveal in Finder"))
                .accessibilityLabel(LumaL10n.format("Reveal %@ in Finder", item.label))
                .accessibilityIdentifier("startup.reveal.\(item.label)")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("startup.item.\(item.label)")
    }
}

import AppKit
