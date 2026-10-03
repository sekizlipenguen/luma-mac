import SwiftUI
import LumaCore

/// Uses the session's existing metrics model so navigation does not create a second sampler loop.
struct CPUProcessesView: View {
    var model: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                if let snapshot = model.snapshot {
                    CPUProcessesCard(model: model, groups: snapshot.cpuProcessGroups)
                } else {
                    ProgressView("Reading system metrics…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(20)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("CPU Processes")
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
    }
}
