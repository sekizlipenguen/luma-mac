import AppKit
import SwiftUI
import LumaCore
import LumaUI

struct BackgroundAppsView: View {
    var model: BackgroundAppsViewModel

    var body: some View {
        ScrollView {
            BackgroundAppsCard(model: model)
                .padding(20)
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Background Apps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(model.isQuitting)
            }
        }
        .task { await model.monitor() }
    }
}

struct BackgroundAppsCard: View {
    var model: BackgroundAppsViewModel
    @State private var search = ""
    @State private var quitTargets: [BackgroundApp] = []

    private var filtered: [BackgroundApp] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.apps }
        return model.apps.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
                || $0.detail.localizedCaseInsensitiveContains(query)
        }
    }

    private var stoppable: [BackgroundApp] {
        model.apps.filter(\.canStop)
    }

    var body: some View {
        let visible = filtered
        MetricCard(title: "Background App Activity", systemImage: "square.stack", accent: LumaTheme.cpu) {
            HStack(alignment: .top) {
                Text("Running LaunchAgents on this Mac. Luma never asks for an administrator password here. System daemons stay read-only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if !stoppable.isEmpty {
                    Button("Stop All") { quitTargets = stoppable }
                        .controlSize(.small)
                        .disabled(model.isQuitting)
                        .accessibilityIdentifier("backgroundApps.quitAll")
                }
            }
            TextField("Search background apps", text: $search)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("backgroundApps.search")
            if let message = model.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("backgroundApps.message")
            }
            if !model.hasLoaded {
                ProgressView("Reading running apps…")
            } else if model.apps.isEmpty {
                Text("No background apps are running.")
                    .foregroundStyle(.secondary)
            } else if visible.isEmpty {
                Text("No matching background apps.")
                    .foregroundStyle(.secondary)
            } else {
                Text(LumaL10n.format("%lld background apps", Int64(visible.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(visible) { app in
                        appRow(app)
                        Divider().opacity(0.35)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("backgroundApps.card")
        .confirmationDialog(
            quitTargets.count == 1
                ? LumaL10n.format("Stop %@?", quitTargets.first?.name ?? "")
                : LumaL10n.string("Stop all background items?"),
            isPresented: Binding(get: { !quitTargets.isEmpty }, set: { if !$0 { quitTargets = [] } }),
            titleVisibility: .visible
        ) {
            if quitTargets.count == 1 {
                Button("Stop", role: .destructive) {
                    let targets = quitTargets
                    quitTargets = []
                    model.quit(targets)
                }
            } else {
                Button("Stop All", role: .destructive) {
                    let targets = quitTargets
                    quitTargets = []
                    model.quit(targets)
                }
            }
            Button("Cancel", role: .cancel) { quitTargets = [] }
        } message: {
            Text(LumaL10n.format(
                "Unloads %lld user background services. System daemons and other apps' background tasks stay running.",
                Int64(quitTargets.count)
            ))
        }
    }

    private func appRow(_ app: BackgroundApp) -> some View {
        HStack(spacing: 10) {
            icon(for: app)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("Running in background")
                    if let pid = app.pid {
                        Text("PID \(pid)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if app.canStop {
                Button("Stop") { quitTargets = [app] }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(LumaTheme.thermal)
                    .disabled(model.isQuitting)
                    .accessibilityIdentifier("backgroundApps.quit.\(app.id)")
            } else {
                Text("Read only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("backgroundApps.row.\(app.id)")
    }

    @ViewBuilder
    private func icon(for app: BackgroundApp) -> some View {
        if let path = app.iconPath, FileManager.default.fileExists(atPath: path) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: "square.stack.3d.up")
                .frame(width: 28, height: 28)
                .foregroundStyle(LumaTheme.cpu)
        }
    }
}
