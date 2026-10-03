import SwiftUI
import LumaCore
import LumaUI

struct CPUProcessesCard: View {
    var model: DashboardViewModel
    let groups: [CPUProcessGroup]
    @State private var search = ""
    @State private var showAll = false
    @State private var expanded = Set<String>()
    @State private var quitTarget: CPUProcessGroup?

    private var filteredGroups: [CPUProcessGroup] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return groups }
        return groups.filter { group in
            group.name.localizedCaseInsensitiveContains(query)
                || group.processes.contains {
                    $0.name.localizedCaseInsensitiveContains(query) || String($0.pid).contains(query)
                }
        }
    }

    var body: some View {
        let filtered = filteredGroups
        let visible = showAll || !search.isEmpty ? filtered : Array(filtered.prefix(12))
        MetricCard(title: "CPU Processes by App", systemImage: "cpu", accent: LumaTheme.cpu) {
            Text("App totals include helper processes. 100% CPU equals one fully busy core.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Search CPU processes", text: $search)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("cpu.search")
            if let message = model.cpuQuitMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("cpu.quitMessage")
            }
            if groups.isEmpty {
                Text("CPU process data is unavailable.")
                    .foregroundStyle(.secondary)
            } else if visible.isEmpty {
                Text("No matching CPU processes.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(visible) { group in
                        groupRow(group)
                        Divider().opacity(0.35)
                    }
                }
            }
            if filtered.count > 12 && search.isEmpty {
                Button(showAll ? "Show fewer CPU groups" : "Show all CPU groups") { showAll.toggle() }
                    .accessibilityIdentifier("cpu.showAll")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cpu.groups")
        .confirmationDialog(
            LumaL10n.format("Quit %@?", quitTarget?.name ?? ""),
            isPresented: Binding(get: { quitTarget != nil }, set: { if !$0 { quitTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Quit App", role: .destructive) {
                if let target = quitTarget { model.quitCPUGroup(target) }
                quitTarget = nil
            }
            Button("Cancel", role: .cancel) { quitTarget = nil }
        } message: {
            Text("Sends a normal quit request to this app and lets it close its helpers. The app may ask you to save your work.")
        }
    }

    private func groupRow(_ group: CPUProcessGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    if !expanded.insert(group.id).inserted { expanded.remove(group.id) }
                } label: {
                    Image(systemName: expanded.contains(group.id) ? "chevron.down" : "chevron.right")
                        .frame(width: 18, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LumaL10n.format("Show processes for %@", group.name))
                .accessibilityIdentifier("cpu.expand.\(group.id)")
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name).font(.body.weight(.semibold)).lineLimit(1)
                    Text(LumaL10n.format("%lld processes", group.processes.count))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text((group.cpuPercent != nil && group.hasPendingSamples ? "≥ " : "") + cpuLabel(group.cpuPercent))
                    .font(.callout.monospacedDigit())
                    .accessibilityIdentifier("cpu.total.\(group.id)")
                if model.canQuitCPUGroup(group) {
                    Button("Quit") { quitTarget = group }
                        .buttonStyle(.bordered).controlSize(.small).tint(LumaTheme.thermal)
                        .accessibilityIdentifier("cpu.quit.\(group.id)")
                } else {
                    Text("Read only").font(.caption).foregroundStyle(.secondary)
                }
            }
            if expanded.contains(group.id) {
                ForEach(group.processes) { process in
                    HStack(spacing: 10) {
                        Text(process.name).lineLimit(1)
                        Text("PID \(process.pid)").foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(cpuLabel(process.cpuPercent)).monospacedDigit()
                    }
                    .font(.caption)
                    .padding(.leading, 28)
                    .accessibilityIdentifier("cpu.process.\(process.id)")
                }
            }
        }
    }

    private func cpuLabel(_ percent: Double?) -> String {
        guard let percent else { return LumaL10n.string("Sampling…") }
        return String(format: "%.1f%%", locale: AppLanguage.preferredLocale, percent)
    }
}
