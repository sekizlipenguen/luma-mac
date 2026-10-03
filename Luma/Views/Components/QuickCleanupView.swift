import SwiftUI
import LumaCore
import LumaSupport
import LumaUI

/// Quick actions for menu bar — allowlisted dry-run only entry point.
struct QuickCleanupView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var messageKey = "Quick cleanup runs Dry Run estimates only from the menu bar. Confirm full cleanup in the main window."
    @State private var dynamicMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let dynamicMessage {
                Text(dynamicMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(LocalizedStringKey(messageKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Estimate User Caches") {
                Task {
                    let estimates = try? await env.cleanupEngine.estimate(ruleIDs: ["user-caches"])
                    if let est = estimates?["user-caches"] {
                        dynamicMessage = LumaL10n.format(
                            "User Caches ≈ %@",
                            ByteFormatters.string(for: est.estimatedBytes)
                        )
                    }
                }
            }
        }
        .padding()
    }
}
