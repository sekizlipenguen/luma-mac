import AppKit
import SwiftUI
import LumaSupport
import LumaUI

struct FolderSizePanel: View {
    @Bindable var session: FolderSizeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Folder size")
                .font(.headline)
            Text("Totals include files inside the folder (allocated size). Large folders take a while — same walk as Storage.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if session.rows.isEmpty {
                Text("Select a folder in Finder, then use Quick Actions / Services → Folder size in Luma.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(session.rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            Text(abbreviatedHome(row.path))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                        Spacer(minLength: 8)
                        if row.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else if let error = row.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        } else if let bytes = row.bytes {
                            Text(ByteFormatters.string(for: bytes))
                                .font(.title3.monospacedDigit().weight(.semibold))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 420, idealWidth: 460, maxWidth: 560)
    }

    private func abbreviatedHome(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
