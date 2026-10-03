import Foundation
import Observation
import LumaCore

@Observable
@MainActor
final class EmulatorsViewModel {
    private let service: any EmulatorManaging
    var devices: [RunningEmulator] = []
    var notes: [String] = []
    var isRefreshing = false
    var stoppingIDs = Set<String>()
    var message: String?
    var hasLoaded = false

    init(service: any EmulatorManaging) { self.service = service }

    func monitor() async {
        await refresh()
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(10)) } catch { break }
            await refresh()
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let snapshot = await service.snapshot()
        guard !Task.isCancelled else { return }
        devices = snapshot.devices
        notes = snapshot.notes
        hasLoaded = true
    }

    func stop(_ targets: [RunningEmulator]) async {
        guard stoppingIDs.isEmpty else { return }
        stoppingIDs = Set(targets.map(\.id))
        defer { stoppingIDs.removeAll() }
        var stopped = 0
        var failures: [String] = []
        for device in targets {
            do {
                _ = try await service.stop(device)
                stopped += 1
            } catch {
                let detail = (error as? LumaError).flatMap { error -> String? in
                    if case .unavailable(let reason) = error { return LumaL10n.string(reason) }
                    return nil
                } ?? error.localizedDescription
                failures.append("\(device.name): \(detail)")
            }
        }
        message = failures.isEmpty
            ? LumaL10n.format("%lld emulators stopped. Device data was preserved.", stopped)
            : failures.joined(separator: "\n")
        await refresh()
    }
}
