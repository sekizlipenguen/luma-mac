import AppKit
import Foundation
import Observation
import LumaCore
import LumaSystem
import LumaSupport

@Observable
@MainActor
final class DashboardViewModel {
    private let metrics: SystemMetricsService
    private var loopTask: Task<Void, Never>?

    var snapshot: SystemSnapshot?
    var cpuHistory: [Double] = []
    var memoryHistory: [Double] = []
    var errorMessage: String?
    var isLoading = false
    var intervalSeconds: Double = 1
    var cpuQuitMessage: String?

    init(metrics: SystemMetricsService) {
        self.metrics = metrics
    }

    func start() {
        // Always ensure a live loop. Previous NavigationSplitView disappear
        // handlers cancelled the task and left the UI on a forever spinner.
        loopTask?.cancel()
        isLoading = snapshot == nil
        loopTask = Task { [weak self] in
            await self?.refresh(quick: true)
            while let self, !Task.isCancelled {
                let ns = UInt64(max(self.intervalSeconds, 0.5) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                guard !Task.isCancelled else { break }
                await self.refresh(quick: true)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func canQuitCPUGroup(_ group: CPUProcessGroup) -> Bool {
        CPUApplicationControl.canQuit(group)
    }

    func quitCPUGroup(_ group: CPUProcessGroup) {
        switch CPUApplicationControl.quit(group) {
        case .requested:
            cpuQuitMessage = LumaL10n.format("Asked %@ to quit. CPU usage updates after it exits.", group.name)
        case .unavailable:
            cpuQuitMessage = LumaL10n.string("This app has exited or cannot be quit from Luma.")
        case .declined:
            cpuQuitMessage = LumaL10n.format("%@ did not accept the quit request. Check the app for unsaved work.", group.name)
        }
        Task { await refresh(quick: true) }
    }

    func refresh(quick: Bool) async {
        // Keep the spinner only for the first paint; never block the UI loop on failure.
        if snapshot == nil { isLoading = true }
        do {
            let snap = quick ? try await metrics.quickSnapshot() : try await metrics.snapshot()
            guard !Task.isCancelled else { return }
            if snapshot != snap {
                snapshot = snap
            }
            let cpu = snap.cpu.overallUsage
            if abs((cpuHistory.last ?? -1) - cpu) > 0.001 {
                cpuHistory.append(cpu)
                if cpuHistory.count > 60 { cpuHistory.removeFirst(cpuHistory.count - 60) }
            }
            let memRatio = snap.memory.totalBytes > 0
                ? Double(snap.memory.usedBytes) / Double(snap.memory.totalBytes)
                : 0
            let clamped = min(memRatio, 1)
            if abs((memoryHistory.last ?? -1) - clamped) > 0.001 {
                memoryHistory.append(clamped)
                if memoryHistory.count > 60 { memoryHistory.removeFirst(memoryHistory.count - 60) }
            }
            errorMessage = nil
            isLoading = false
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

@Observable
@MainActor
final class MemoryViewModel {
    private let metrics: SystemMetricsService
    private var loopTask: Task<Void, Never>?

    var memory: MemoryMetrics?
    var processes: [ProcessMemoryInfo] = []
    var errorMessage: String?
    var quitMessage: String?

    init(metrics: SystemMetricsService) {
        self.metrics = metrics
    }

    func start() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func refresh() async {
        do {
            let snap = try await metrics.quickSnapshot()
            if memory != snap.memory {
                memory = snap.memory
            }
            if processes != snap.topProcesses {
                processes = snap.topProcesses
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func canQuit(_ proc: ProcessMemoryInfo) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: proc.pid) else { return false }
        return app.activationPolicy == .regular && !app.isTerminated
    }

    @discardableResult
    func quit(_ proc: ProcessMemoryInfo) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: proc.pid),
              app.activationPolicy == .regular,
              !app.isTerminated
        else {
            quitMessage = LumaL10n.string("This process can’t be quit from Luma (system or helper).")
            return false
        }
        let ok = app.terminate()
        quitMessage = ok
            ? LumaL10n.format("Asked %@ to quit. Memory frees after it exits.", proc.name)
            : LumaL10n.format("Could not quit %@.", proc.name)
        Task { await refresh() }
        return ok
    }
}
