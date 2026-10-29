import Foundation
import Observation
import LumaCore
import LumaSystem

@Observable
@MainActor
final class BackgroundAppsViewModel {
    private let sampler = BackgroundActivitySampler()
    var apps: [BackgroundApp] = []
    var message: String?
    var isQuitting = false
    var hasLoaded = false

    /// Runs inside the view `.task` so leaving the page cancels polling.
    func monitor() async {
        await refresh()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { break }
            await refresh()
        }
    }

    func refresh() async {
        apps = await sampler.snapshot()
        hasLoaded = true
    }

    func quit(_ targets: [BackgroundApp]) {
        guard !isQuitting, !targets.isEmpty else { return }
        isQuitting = true
        Task {
            let result = await sampler.stop(targets)
            if result.declined > 0 || result.unavailable > 0, result.requested == 0 {
                message = LumaL10n.string("This app has exited or cannot be quit from Luma.")
            } else if result.declined > 0 {
                message = LumaL10n.format(
                    "%lld background items could not be stopped.",
                    Int64(result.declined + result.unavailable)
                )
            } else {
                message = LumaL10n.format(
                    "Stopped %lld background services.",
                    Int64(result.requested)
                )
            }
            isQuitting = false
            await refresh()
        }
    }
}
