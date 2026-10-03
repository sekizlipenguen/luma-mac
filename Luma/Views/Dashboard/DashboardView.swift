import SwiftUI
import LumaCore
import LumaSupport
import LumaUI

struct DashboardView: View {
    var model: DashboardViewModel
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                permissionBanner

                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                }

                if let snap = model.snapshot {
                    metricsGrid(snap)
                    processColumns(snap)
                    recommendations(snap)
                } else {
                    VStack(spacing: 12) {
                        ProgressView("Reading system metrics…")
                        Text("Local APIs only — Full Disk Access is not required for this screen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await model.refresh(quick: true) }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(20)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh(quick: true) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .task {
            model.start()
        }
    }

    // MARK: - Metrics

    @ViewBuilder
    private func metricsGrid(_ snap: SystemSnapshot) -> some View {
        // Fixed 2-column Grid — avoids adaptive LazyVGrid layout thrash.
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                cpuCard(snap)
                memoryCard(snap)
            }
            GridRow {
                storageCard(snap)
                networkCard(snap)
            }
            GridRow {
                batteryCard(snap)
                thermalCard(snap)
            }
        }
    }

    private func cpuCard(_ snap: SystemSnapshot) -> some View {
        MetricCard(title: "CPU", systemImage: "cpu", accent: LumaTheme.cpu) {
            ProgressMetricView(
                value: snap.cpu.overallUsage,
                label: PercentFormatters.string(snap.cpu.overallUsage),
                tint: LumaTheme.cpu
            )
            Text(
                "Load \(String(format: "%.2f / %.2f / %.2f", snap.cpu.loadAverage.0, snap.cpu.loadAverage.1, snap.cpu.loadAverage.2))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func memoryCard(_ snap: SystemSnapshot) -> some View {
        let ratio = snap.memory.totalBytes > 0
            ? Double(snap.memory.usedBytes) / Double(snap.memory.totalBytes)
            : 0
        let tint: Color = {
            switch snap.memory.pressure {
            case .critical: .red
            case .warning: .orange
            default: LumaTheme.memory
            }
        }()
        return MetricCard(title: "Memory", systemImage: "memorychip", accent: tint) {
            ProgressMetricView(
                value: ratio,
                label: ByteFormatters.string(for: snap.memory.usedBytes),
                tint: tint
            )
            Text(LumaL10n.format("Pressure: %@", snap.memory.pressure.rawValue))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(LumaL10n.format(
                "Compressed %@ · Swap %@",
                ByteFormatters.string(for: snap.memory.compressedBytes),
                ByteFormatters.string(for: snap.memory.swapUsedBytes)
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func storageCard(_ snap: SystemSnapshot) -> some View {
        if let volume = snap.volumes.first(where: { $0.path == "/" }) ?? snap.volumes.first {
            let ratio = volume.totalBytes > 0
                ? Double(volume.usedBytes) / Double(volume.totalBytes)
                : 0
            MetricCard(title: "Storage", systemImage: "internaldrive", accent: LumaTheme.storage) {
                ProgressMetricView(
                    value: ratio,
                    label: LumaL10n.format("%@ used", ByteFormatters.string(for: volume.usedBytes)),
                    tint: LumaTheme.storage
                )
                Text(LumaL10n.format(
                    "%@ free of %@",
                    ByteFormatters.string(for: volume.freeBytes),
                    ByteFormatters.string(for: volume.totalBytes)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else {
            MetricCard(title: "Storage", systemImage: "internaldrive", accent: LumaTheme.storage) {
                Text("Unavailable")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func networkCard(_ snap: SystemSnapshot) -> some View {
        MetricCard(title: "Network", systemImage: "network", accent: LumaTheme.network) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("↓")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LumaTheme.network)
                    Text(ByteFormatters.rateString(bytesPerSecond: snap.network.bytesInPerSecond))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("↑")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(ByteFormatters.rateString(bytesPerSecond: snap.network.bytesOutPerSecond))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func batteryCard(_ snap: SystemSnapshot) -> some View {
        MetricCard(title: "Battery", systemImage: batterySymbol(snap.battery), accent: LumaTheme.battery) {
            if snap.battery.isPresent {
                let percent = snap.battery.currentCapacityPercent.map { Double($0) / 100.0 } ?? 0
                ProgressMetricView(
                    value: percent,
                    label: "\(snap.battery.currentCapacityPercent.map(String.init) ?? "—")%",
                    tint: batteryTint(snap.battery)
                )
                HStack(spacing: 8) {
                    Text(snap.battery.isCharging ? "Charging" : "On battery")
                    if let minutes = snap.battery.timeRemainingMinutes, minutes > 0 {
                        Text("·")
                        Text(timeRemainingLabel(minutes: minutes, charging: snap.battery.isCharging))
                    }
                    if let health = snap.battery.healthPercent {
                        Text("·")
                        Text(LumaL10n.format("Health %lld%%", health))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            } else {
                Text("No battery (desktop)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Energy impact below still uses process energy counters.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func thermalCard(_ snap: SystemSnapshot) -> some View {
        MetricCard(title: "Temperature", systemImage: "thermometer.medium", accent: LumaTheme.thermal) {
            if let celsius = snap.thermal.cpuCelsius {
                Text(String(format: "%.0f°C", celsius))
                    .font(.title2.monospacedDigit().weight(.semibold))
            } else if let reason = snap.thermal.unavailableReason {
                Text(LocalizedStringKey(reason))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Unavailable")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Process lists

    @ViewBuilder
    private func processColumns(_ snap: SystemSnapshot) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                memoryProcessesCard(snap)
                energyProcessesCard(snap)
            }
        }
    }

    private func memoryProcessesCard(_ snap: SystemSnapshot) -> some View {
        let maxBytes = snap.topProcesses.first?.residentBytes ?? 1
        return MetricCard(title: "Top Processes (memory)", systemImage: "memorychip", accent: LumaTheme.memory) {
            if snap.topProcesses.isEmpty {
                Text("No process data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(snap.topProcesses.prefix(8)) { proc in
                        ProcessRow(
                            name: proc.name,
                            value: ByteFormatters.string(for: proc.residentBytes),
                            bar: Double(proc.residentBytes) / Double(max(maxBytes, 1))
                        )
                    }
                }
            }
        }
    }

    private func energyProcessesCard(_ snap: SystemSnapshot) -> some View {
        let maxScore = snap.topEnergyProcesses.first?.rankScore ?? 1
        return MetricCard(
            title: "Battery Hogs",
            systemImage: "bolt.fill",
            accent: LumaTheme.battery
        ) {
            Text("From process energy counters (ri_energy_nj). Not App Store Energy Impact.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)

            if snap.topEnergyProcesses.isEmpty {
                Text("Sampling… power rates appear after the next refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(snap.topEnergyProcesses.prefix(8)) { proc in
                        ProcessRow(
                            name: proc.name,
                            value: EnergyFormatters.string(
                                milliwatts: proc.milliwatts,
                                lifetimeJoules: proc.lifetimeJoules
                            ),
                            bar: proc.rankScore / max(maxScore, 0.0001)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Banner / recommendations

    @ViewBuilder
    private var permissionBanner: some View {
        if !env.permissionGate.lastProbeSucceeded {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Full Disk Access recommended")
                        .font(.headline)
                    Text(env.permissionGate.lastProbeDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open System Settings") {
                        env.permissionGate.openFullDiskAccessSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                Spacer()
            }
            .padding()
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func recommendations(_ snap: SystemSnapshot) -> some View {
        MetricCard(title: "Recommendations", systemImage: "lightbulb", accent: .yellow) {
            VStack(alignment: .leading, spacing: 6) {
                if snap.memory.pressure == .warning || snap.memory.pressure == .critical {
                    Text(LumaL10n.format(
                        "Memory pressure is %@. Consider quitting the largest apps listed above. Luma never fakes RAM cleaning.",
                        snap.memory.pressure.rawValue
                    ))
                } else {
                    Text("Memory pressure looks normal. Cached/inactive memory is managed by macOS and is not waste.")
                }
                if snap.battery.isPresent, !snap.battery.isCharging,
                   let top = snap.topEnergyProcesses.first
                {
                    Text(LumaL10n.format(
                        "Highest energy right now: %@ (%@).",
                        top.name,
                        EnergyFormatters.string(milliwatts: top.milliwatts, lifetimeJoules: top.lifetimeJoules)
                    ))
                }
            }
            .font(.callout)
        }
    }

    // MARK: - Helpers

    private func batterySymbol(_ battery: BatteryMetrics) -> String {
        guard battery.isPresent, let percent = battery.currentCapacityPercent else {
            return "battery.100"
        }
        if battery.isCharging { return "battery.100.bolt" }
        switch percent {
        case 0..<15: return "battery.0"
        case 15..<40: return "battery.25"
        case 40..<70: return "battery.50"
        case 70..<90: return "battery.75"
        default: return "battery.100"
        }
    }

    private func batteryTint(_ battery: BatteryMetrics) -> Color {
        if battery.isCharging { return LumaTheme.network }
        guard let percent = battery.currentCapacityPercent else { return LumaTheme.battery }
        if percent <= 15 { return .red }
        if percent <= 30 { return .orange }
        return LumaTheme.battery
    }

    private func timeRemainingLabel(minutes: Int, charging: Bool) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        let time: String
        if hours > 0 {
            time = LumaL10n.format("%lldh %lldm", hours, mins)
        } else {
            time = LumaL10n.format("%lldm", mins)
        }
        return charging
            ? LumaL10n.format("%@ to full", time)
            : LumaL10n.format("%@ left", time)
    }
}
