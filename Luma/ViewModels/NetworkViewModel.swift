import Foundation
import Observation
import LumaCore
import LumaSystem

@Observable
@MainActor
final class NetworkViewModel {
    private let sampler: NetworkMetricsSampler
    private var loopTask: Task<Void, Never>?
    private var ticks = 0

    var snapshot: NetworkDetailSnapshot?
    var inHistory: [Double] = []
    var outHistory: [Double] = []
    var errorMessage: String?
    var isLoading = false
    var intervalSeconds: Double = 1

    var isRefreshingNetwork = false
    var bounceWiFiOnRefresh = false
    var refreshReport: NetworkRefreshReport?
    var refreshErrorMessage: String?

    /// Active VPN / tunnel interfaces currently listed (utun / ipsec / ppp).
    var tunnelInterfaceNames: [String] {
        guard let snapshot else { return [] }
        return snapshot.interfaces
            .filter { iface in
                let name = iface.name.lowercased()
                return name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")
            }
            .map(\.name)
            .sorted()
    }

    init(sampler: NetworkMetricsSampler) {
        self.sampler = sampler
    }

    func start() {
        loopTask?.cancel()
        isLoading = snapshot == nil
        ticks = 0
        loopTask = Task { [weak self] in
            await self?.refresh(includeConnections: true)
            while let self, !Task.isCancelled {
                let ns = UInt64(max(self.intervalSeconds, 0.5) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                guard !Task.isCancelled else { break }
                self.ticks += 1
                // Full socket listing is heavy — pull rates every tick, apps/sockets ~every 3s.
                await self.refresh(includeConnections: self.ticks % 3 == 0)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func refresh() async {
        await refresh(includeConnections: true)
    }

    /// Soft network restart (DNS + DHCP, optional Wi‑Fi bounce). Shows macOS admin password prompt.
    func refreshNetworkStack() async {
        guard !isRefreshingNetwork else { return }
        isRefreshingNetwork = true
        refreshErrorMessage = nil
        defer { isRefreshingNetwork = false }
        do {
            let report = try await NetworkStackRefresher.refresh(bounceWiFi: bounceWiFiOnRefresh)
            refreshReport = report
            // Give DHCP / Wi‑Fi a moment, then re-sample.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await refresh(includeConnections: true)
        } catch let error as NetworkStackRefresher.RefreshError {
            switch error {
            case .cancelled:
                refreshErrorMessage = nil
                refreshReport = NetworkRefreshReport(steps: [], cancelled: true)
            case .failed(let message):
                refreshErrorMessage = message
            }
        } catch {
            refreshErrorMessage = error.localizedDescription
        }
    }

    private func refresh(includeConnections: Bool) async {
        isLoading = snapshot == nil
        do {
            let snap = try await sampler.sampleDetail(includeConnections: includeConnections)
            if includeConnections || snapshot == nil {
                snapshot = snap
            } else if var current = snapshot {
                // Keep last connection list; refresh live rates + interfaces.
                current.aggregate = snap.aggregate
                current.interfaces = snap.interfaces
                current.dnsServers = snap.dnsServers
                current.pathStatus = snap.pathStatus
                current.isExpensive = snap.isExpensive
                current.isConstrained = snap.isConstrained
                current.usesWiFi = snap.usesWiFi
                current.usesEthernet = snap.usesEthernet
                current.usesCellular = snap.usesCellular
                current.primaryIPv4 = snap.primaryIPv4
                current.sampledAt = snap.sampledAt
                current.note = snap.note
                snapshot = current
            }
            appendRate(&inHistory, snap.aggregate.bytesInPerSecond)
            appendRate(&outHistory, snap.aggregate.bytesOutPerSecond)
            errorMessage = nil
            isLoading = false
        } catch is CancellationError {
            // ignore
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func appendRate(_ history: inout [Double], _ bytesPerSecond: Double) {
        guard bytesPerSecond.isFinite else { return }
        history.append(max(bytesPerSecond, 0))
        if history.count > 60 { history.removeFirst(history.count - 60) }
    }
}
