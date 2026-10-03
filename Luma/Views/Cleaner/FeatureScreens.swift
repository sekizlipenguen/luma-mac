import SwiftUI
import LumaApps
import LumaCleanup
import LumaCore
import LumaSupport
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

    var body: some View {
        List {
            Section {
                Text("System LaunchDaemons are listed but not modified (SIP). User LaunchAgents can be toggled with confirmation via launchctl.")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.items) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.label)
                        Text(LumaL10n.format("%@ · %@", LumaL10n.string(item.kind), item.domain.rawValue))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let reason = item.unavailableReason {
                            Text(LocalizedStringKey(reason)).font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    if item.isMutable {
                        Toggle("Enabled", isOn: Binding(
                            get: { item.isEnabled },
                            set: { newValue in Task { await model.toggle(item, enabled: newValue) } }
                        ))
                        .labelsHidden()
                    } else if item.kind == "LoginItem" {
                        Button("Open Settings") {
                            if let url = URL(string: item.path) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    } else {
                        Button("Reveal") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                        }
                    }
                }
            }
        }
        .navigationTitle("Startup")
        .task { await model.load() }
        .overlay { if model.isLoading { ProgressView() } }
    }
}

import AppKit
