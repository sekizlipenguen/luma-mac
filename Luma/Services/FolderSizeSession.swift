import Foundation
import Observation
import LumaCore
import LumaSupport

@Observable
@MainActor
final class FolderSizeSession {
    static let shared = FolderSizeSession()

    struct Row: Identifiable, Equatable {
        var id: String { path }
        var path: String
        var name: String
        var bytes: UInt64?
        var isLoading: Bool
        var errorMessage: String?
    }

    var rows: [Row] = []

    func enqueue(paths: [String]) {
        for raw in paths {
            let url = URL(fileURLWithPath: raw).standardizedFileURL
            let path = url.path
            if PathSafety.blocksScan(path) {
                upsert(
                    Row(
                        path: path,
                        name: url.lastPathComponent,
                        bytes: nil,
                        isLoading: false,
                        errorMessage: LumaL10n.string("System paths are not measured (same rule as Storage).")
                    )
                )
                continue
            }
            upsert(
                Row(
                    path: path,
                    name: url.lastPathComponent.isEmpty ? path : url.lastPathComponent,
                    bytes: nil,
                    isLoading: true,
                    errorMessage: nil
                )
            )
            measure(url)
        }
        NotificationCenter.default.post(name: .lumaOpenFolderSizeWindow, object: nil)
        LumaWindowRouter.shared.openFolderSizeWindow?()
    }

    private func measure(_ url: URL) {
        let path = url.path
        Task.detached(priority: .utility) {
            do {
                let bytes = try FileIO.measureSize(at: url)
                await MainActor.run {
                    FolderSizeSession.shared.finish(path: path, bytes: bytes, error: nil)
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    FolderSizeSession.shared.finish(
                        path: path,
                        bytes: nil,
                        error: error.localizedDescription
                    )
                }
            }
        }
    }

    private func upsert(_ row: Row) {
        if let index = rows.firstIndex(where: { $0.path == row.path }) {
            rows[index] = row
        } else {
            rows.insert(row, at: 0)
        }
    }

    private func finish(path: String, bytes: UInt64?, error: String?) {
        guard let index = rows.firstIndex(where: { $0.path == path }) else { return }
        rows[index].bytes = bytes
        rows[index].isLoading = false
        rows[index].errorMessage = error
    }
}

extension Notification.Name {
    static let lumaOpenFolderSizeWindow = Notification.Name("luma.openFolderSizeWindow")
}
