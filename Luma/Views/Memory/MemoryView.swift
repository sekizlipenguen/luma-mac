import AppKit
import SwiftUI
import LumaCore
import LumaSupport
import LumaUI

struct MemoryView: View {
    @Bindable var model: MemoryViewModel
    @State private var quitTarget: ProcessMemoryInfo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                honestyBanner

                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                if let note = model.quitMessage {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let memory = model.memory {
                    compositionCard(memory)
                    pressureRow(memory)

                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            breakdownCard(memory)
                            swapCard(memory)
                        }
                    }

                    appsCard(memory)
                } else {
                    ProgressView("Sampling memory…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(20)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Memory")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .task { model.start() }
        .confirmationDialog(
            LumaL10n.format("Quit %@?", quitTarget?.name ?? ""),
            isPresented: Binding(
                get: { quitTarget != nil },
                set: { if !$0 { quitTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Quit App", role: .destructive) {
                if let target = quitTarget {
                    model.quit(target)
                }
                quitTarget = nil
            }
            Button("Cancel", role: .cancel) { quitTarget = nil }
        } message: {
            Text("This closes the app for real — the honest way to free its RAM. Luma never fakes a system-wide RAM clean.")
        }
    }

    // MARK: - Banner

    private var honestyBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.title3)
                .foregroundStyle(LumaTheme.memory)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("No fake RAM cleaning")
                    .font(.headline)
                Text("Luma does not “clean” RAM. macOS uses free, inactive, compressed, and purgeable memory deliberately. Closing apps is the honest way to relieve pressure.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                .fill(LumaTheme.memory.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius, style: .continuous)
                        .strokeBorder(LumaTheme.memory.opacity(0.22), lineWidth: 1)
                }
        }
    }

    // MARK: - Composition

    private func compositionCard(_ memory: MemoryMetrics) -> some View {
        let slices = compositionSlices(memory)
        let used = memory.usedBytes
        let total = max(memory.totalBytes, 1)
        let usedRatio = min(Double(used) / Double(total), 1)

        return MetricCard(title: "Memory map", systemImage: "memorychip", accent: LumaTheme.memory) {
            HStack(alignment: .firstTextBaseline) {
                Text(ByteFormatters.string(for: used))
                    .font(.largeTitle.monospacedDigit().weight(.semibold))
                Text(LumaL10n.format("of %@", ByteFormatters.string(for: memory.totalBytes)))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(PercentFormatters.string(usedRatio))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(pressureTint(memory.pressure))
            }

            // Stacked composition bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(slices) { slice in
                        let width = max(geo.size.width * slice.ratio, slice.ratio > 0.004 ? 3 : 0)
                        if width > 0 {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(slice.color)
                                .frame(width: width)
                        }
                    }
                }
            }
            .frame(height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.quaternary.opacity(0.35))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(slices) { slice in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(slice.color)
                            .frame(width: 8, height: 8)
                        Text(slice.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(slice.label)
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                }
            }
        }
    }

    private func pressureRow(_ memory: MemoryMetrics) -> some View {
        HStack(spacing: 12) {
            pressureChip(
                title: "Pressure",
                value: memory.pressure.rawValue,
                tint: pressureTint(memory.pressure)
            )
            pressureChip(
                title: "Source",
                value: memory.pressureSource.rawValue,
                tint: .secondary
            )
            Spacer(minLength: 0)
        }
    }

    private func pressureChip(title: LocalizedStringKey, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func breakdownCard(_ memory: MemoryMetrics) -> some View {
        MetricCard(title: "Breakdown", systemImage: "chart.bar.fill", accent: LumaTheme.cpu) {
            detailRow("Active", memory.activeBytes, LumaTheme.cpu)
            detailRow("Wired", memory.wiredBytes, Color(red: 0.55, green: 0.45, blue: 0.95))
            detailRow("Compressed", memory.compressedBytes, LumaTheme.battery)
            detailRow("Inactive", memory.inactiveBytes, Color(red: 0.45, green: 0.72, blue: 0.85))
            detailRow("Purgeable", memory.purgeableBytes, LumaTheme.storage)
            detailRow("Free", memory.freeBytes, Color.secondary.opacity(0.55))
        }
    }

    private func swapCard(_ memory: MemoryMetrics) -> some View {
        let swapRatio = memory.swapTotalBytes > 0
            ? Double(memory.swapUsedBytes) / Double(memory.swapTotalBytes)
            : 0
        return MetricCard(title: "Swap", systemImage: "externaldrive.fill", accent: LumaTheme.thermal) {
            Text(ByteFormatters.string(for: memory.swapUsedBytes))
                .font(.title.monospacedDigit().weight(.semibold))
            if memory.swapTotalBytes > 0 {
                ProgressView(value: swapRatio.isFinite ? min(max(swapRatio, 0), 1) : 0)
                    .tint(LumaTheme.thermal)
                    .controlSize(.small)
                Text(LumaL10n.format("of %@ total", ByteFormatters.string(for: memory.swapTotalBytes)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No swap reported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Swap grows when pressure is high. Quitting large apps is better than hoping for a magic clean.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func appsCard(_ memory: MemoryMetrics) -> some View {
        let maxBytes = model.processes.map(\.residentBytes).max() ?? 1
        return MetricCard(title: "Apps to consider closing", systemImage: "app.badge.checkmark", accent: LumaTheme.battery) {
            if memory.pressure == .normal {
                Label("Pressure is normal — no action required.", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(LumaTheme.network)
            } else {
                Text(LumaL10n.format("Pressure is %@. Quit large apps below to free real memory.", memory.pressure.rawValue))
                    .font(.callout)
                    .foregroundStyle(pressureTint(memory.pressure))
            }

            if model.processes.isEmpty {
                Text("No process samples yet")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(model.processes.prefix(12)) { proc in
                        processRow(proc, maxBytes: maxBytes)
                        if proc.id != model.processes.prefix(12).last?.id {
                            Divider().opacity(0.35)
                        }
                    }
                }
            }
        }
    }

    private func processRow(_ proc: ProcessMemoryInfo, maxBytes: UInt64) -> some View {
        let bar = maxBytes > 0 ? Double(proc.residentBytes) / Double(maxBytes) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(proc.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text("PID \(proc.pid)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                Text(ByteFormatters.string(for: proc.residentBytes))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                if model.canQuit(proc) {
                    Button("Quit") {
                        quitTarget = proc
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(LumaTheme.thermal)
                }
            }
            ProgressView(value: bar.isFinite ? min(max(bar, 0), 1) : 0)
                .tint(LumaTheme.memory.opacity(0.75))
                .controlSize(.mini)
        }
    }

    private func detailRow(_ title: LocalizedStringKey, _ bytes: UInt64, _ tint: Color) -> some View {
        HStack {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(title)
            Spacer()
            Text(ByteFormatters.string(for: bytes))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    // MARK: - Helpers

    private struct Slice: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let bytes: UInt64
        let color: Color
        let total: UInt64

        var ratio: Double {
            guard total > 0 else { return 0 }
            return Double(bytes) / Double(total)
        }

        var label: String { ByteFormatters.string(for: bytes) }
    }

    private func compositionSlices(_ memory: MemoryMetrics) -> [Slice] {
        let total = max(memory.totalBytes, 1)
        // Visual order: wired → active → compressed → inactive → free(+speculative leftovers as free-ish)
        return [
            Slice(id: "wired", title: "Wired", bytes: memory.wiredBytes, color: Color(red: 0.55, green: 0.45, blue: 0.95), total: total),
            Slice(id: "active", title: "Active", bytes: memory.activeBytes, color: LumaTheme.cpu, total: total),
            Slice(id: "compressed", title: "Compressed", bytes: memory.compressedBytes, color: LumaTheme.battery, total: total),
            Slice(id: "inactive", title: "Inactive", bytes: memory.inactiveBytes, color: Color(red: 0.45, green: 0.72, blue: 0.85), total: total),
            Slice(id: "free", title: "Free", bytes: memory.freeBytes + memory.purgeableBytes, color: Color.secondary.opacity(0.45), total: total)
        ]
    }

    private func pressureTint(_ pressure: MemoryPressureLevel) -> Color {
        switch pressure {
        case .normal: LumaTheme.network
        case .warning: LumaTheme.battery
        case .critical: LumaTheme.thermal
        case .unknown: .secondary
        }
    }
}
