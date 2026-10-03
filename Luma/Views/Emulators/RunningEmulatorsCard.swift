import SwiftUI
import LumaCore
import LumaUI

struct RunningEmulatorsCard: View {
    var model: EmulatorsViewModel
    @State private var stopTargets: [RunningEmulator] = []

    var body: some View {
        MetricCard(title: "Running Simulators & Emulators", systemImage: "iphone.gen3", accent: LumaTheme.cpu) {
            HStack(alignment: .top) {
                Text("Shut down virtual devices and their processes without deleting device data.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button("Refresh") { Task { await model.refresh() } }
                    .controlSize(.small).disabled(model.isRefreshing || !model.stoppingIDs.isEmpty)
                    .accessibilityIdentifier("emulators.refresh")
                if model.devices.contains(where: \.isOnline) {
                    Button("Stop All Emulators") { stopTargets = model.devices.filter(\.isOnline) }
                        .controlSize(.small).disabled(!model.stoppingIDs.isEmpty)
                        .accessibilityIdentifier("emulators.stopAll")
                }
            }
            if !model.hasLoaded {
                ProgressView("Checking running virtual devices…")
            } else if model.devices.isEmpty {
                Text(model.notes.isEmpty ? "No running simulators or emulators." : "No running virtual devices found in the available tools.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(model.devices) { device in
                HStack(spacing: 12) {
                    Image(systemName: device.platform == .iOS ? "iphone" : "apps.iphone")
                        .foregroundStyle(LumaTheme.cpu)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.name).font(.body.weight(.semibold)).lineLimit(1)
                        Text("\(device.runtime) · \(device.deviceID)")
                            .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if model.stoppingIDs.contains(device.id) {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(device.isOnline ? "Running" : "Offline").font(.caption).foregroundStyle(.secondary)
                        Button("Stop Emulator") { stopTargets = [device] }
                            .buttonStyle(.bordered).controlSize(.small).tint(LumaTheme.thermal)
                            .disabled(!device.isOnline || !model.stoppingIDs.isEmpty)
                            .accessibilityIdentifier("emulators.stop.\(device.id)")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("emulators.device.\(device.id)")
            }
            ForEach(model.notes, id: \.self) { note in
                Text(LocalizedStringKey(note)).font(.caption).foregroundStyle(.secondary)
            }
            if let message = model.message {
                Text(message).font(.callout).accessibilityIdentifier("emulators.message")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("emulators.card")
        .task { await model.monitor() }
        .confirmationDialog(
            stopTargets.count == 1
                ? LumaL10n.format("Stop %@?", stopTargets.first?.name ?? "")
                : LumaL10n.string("Stop the listed emulators?"),
            isPresented: Binding(get: { !stopTargets.isEmpty }, set: { if !$0 { stopTargets = [] } }),
            titleVisibility: .visible
        ) {
            Button("Stop Emulator", role: .destructive) {
                let targets = stopTargets
                stopTargets = []
                Task { await model.stop(targets) }
            }
            Button("Cancel", role: .cancel) { stopTargets = [] }
        } message: {
            Text("Stops the selected virtual devices and interrupts tests running on them. Device data is kept; Xcode and Android Studio stay open.")
        }
    }
}
