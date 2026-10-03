import Darwin
import Foundation
import Network
import SystemConfiguration
import LumaCore
import LumaSupport

/// Network interface counters / addresses via `getifaddrs` + 64-bit `NET_RT_IFLIST2`,
/// path via `NWPathMonitor`, DNS via `SCDynamicStore`.
///
/// Headline download/upload sums **external** interfaces (`en*`, cellular) so VPN tunnels
/// (`utun*`) and peer radios (`awdl*`) do not inflate or dilute Wi‑Fi / Ethernet rates.
public final class NetworkMetricsSampler: NetworkMetricsProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var previousTotals: (in: UInt64, out: UInt64, at: Date)?
    private var previousPerInterface: [String: (in: UInt64, out: UInt64, at: Date)] = [:]
    private var didWarmup = false

    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "dev.luma.network-path")
    private var latestPath: NWPath?

    public init() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self.latestPath = path
            self.lock.unlock()
        }
        pathMonitor.start(queue: pathQueue)
    }

    deinit {
        pathMonitor.cancel()
    }

    public func sample() async throws -> NetworkMetrics {
        try await sampleDetail(includeConnections: false).aggregate
    }

    public func sampleDetail() async throws -> NetworkDetailSnapshot {
        try await sampleDetail(includeConnections: true)
    }

    public func sampleDetail(includeConnections: Bool) async throws -> NetworkDetailSnapshot {
        try await Task.detached(priority: .utility) { [self] in
            try self.sampleDetailSync(includeConnections: includeConnections)
        }.value
    }

    private func sampleDetailSync(includeConnections: Bool) throws -> NetworkDetailSnapshot {
        lock.lock()
        let needsWarmup = !didWarmup
        if needsWarmup { didWarmup = true }
        lock.unlock()

        if needsWarmup {
            _ = try readSnapshot(includeConnections: false)
            Thread.sleep(forTimeInterval: 0.35)
        }
        return try readSnapshot(includeConnections: includeConnections)
    }

    private func readSnapshot(includeConnections: Bool) throws -> NetworkDetailSnapshot {
        let path: NWPath?
        let interfaces: [NetworkInterfaceInfo]
        let aggregate: NetworkMetrics
        let primaryIPv4: String?

        lock.lock()
        do {
            let byName = try Self.collectInterfaces()
            let linkBytes = Self.linkByteCounters()
            let now = Date()
            path = latestPath

            var totalIn: UInt64 = 0
            var totalOut: UInt64 = 0
            var built: [NetworkInterfaceInfo] = []

            for (name, acc) in byName {
                if name == "lo0" || name.hasPrefix("lo") { continue }

                let bytesIn = linkBytes[name]?.in ?? acc.bytesIn
                let bytesOut = linkBytes[name]?.out ?? acc.bytesOut
                let hasStats = linkBytes[name] != nil || acc.hasLinkStats

                let isUp = (Int32(acc.flags) & IFF_UP) != 0
                let isRunning = (Int32(acc.flags) & IFF_RUNNING) != 0
                let hasAddress = !acc.ipv4.isEmpty || !acc.ipv6.isEmpty
                guard hasStats || hasAddress else { continue }

                if Self.countsTowardAggregate(name) {
                    totalIn += bytesIn
                    totalOut += bytesOut
                }

                var inRate: Double = 0
                var outRate: Double = 0
                if let prev = previousPerInterface[name] {
                    let dt = now.timeIntervalSince(prev.at)
                    if dt > 0.05 {
                        let din = NumericSafety.saturatingDelta(bytesIn, prev.in)
                        let dout = NumericSafety.saturatingDelta(bytesOut, prev.out)
                        inRate = Double(din) / dt
                        outRate = Double(dout) / dt
                    }
                }
                previousPerInterface[name] = (bytesIn, bytesOut, now)

                built.append(
                    NetworkInterfaceInfo(
                        name: name,
                        kindLabel: Self.kindLabel(for: name),
                        ipv4Addresses: acc.ipv4,
                        ipv6Addresses: acc.ipv6,
                        macAddress: acc.mac,
                        isUp: isUp,
                        isRunning: isRunning,
                        bytesIn: bytesIn,
                        bytesOut: bytesOut,
                        bytesInPerSecond: inRate,
                        bytesOutPerSecond: outRate
                    )
                )
            }

            built.sort {
                let score: (NetworkInterfaceInfo) -> Int = { iface in
                    var s = 0
                    if Self.countsTowardAggregate(iface.name) { s += 8 }
                    if iface.isRunning { s += 4 }
                    if iface.isUp { s += 2 }
                    if !iface.ipv4Addresses.isEmpty { s += 1 }
                    return s
                }
                let ls = score($0)
                let rs = score($1)
                if ls != rs { return ls > rs }
                return $0.name < $1.name
            }

            var inRate: Double = 0
            var outRate: Double = 0
            if let prevTotals = previousTotals {
                let dt = now.timeIntervalSince(prevTotals.at)
                if dt > 0.05 {
                    let din = NumericSafety.saturatingDelta(totalIn, prevTotals.in)
                    let dout = NumericSafety.saturatingDelta(totalOut, prevTotals.out)
                    inRate = Double(din) / dt
                    outRate = Double(dout) / dt
                }
            }
            previousTotals = (totalIn, totalOut, now)

            aggregate = NetworkMetrics(
                bytesInPerSecond: inRate,
                bytesOutPerSecond: outRate,
                totalBytesIn: totalIn,
                totalBytesOut: totalOut,
                sampledAt: now
            )

            primaryIPv4 = built.first(where: {
                Self.countsTowardAggregate($0.name) && $0.isRunning && !$0.ipv4Addresses.isEmpty
            })?.ipv4Addresses.first
                ?? built.first(where: { !$0.ipv4Addresses.isEmpty })?.ipv4Addresses.first

            interfaces = built
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }

        let pathStatus: NetworkPathStatus
        var usesWiFi = false
        var usesEthernet = false
        var usesCellular = false
        var isExpensive = false
        var isConstrained = false
        if let path {
            switch path.status {
            case .satisfied: pathStatus = .satisfied
            case .unsatisfied: pathStatus = .unsatisfied
            case .requiresConnection: pathStatus = .requiresConnection
            @unknown default: pathStatus = .unknown
            }
            usesWiFi = path.usesInterfaceType(.wifi)
            usesEthernet = path.usesInterfaceType(.wiredEthernet)
            usesCellular = path.usesInterfaceType(.cellular)
            isExpensive = path.isExpensive
            isConstrained = path.isConstrained
        } else {
            pathStatus = .unknown
        }

        let connections: [LumaCore.NetworkConnection]
        let appSummaries: [NetworkAppSummary]
        if includeConnections {
            connections = NetworkConnectionSampler.listConnections(limit: 150)
            appSummaries = NetworkConnectionSampler.summarizeByApp(connections, limit: 24)
        } else {
            connections = []
            appSummaries = []
        }

        return NetworkDetailSnapshot(
            aggregate: aggregate,
            interfaces: interfaces,
            dnsServers: Self.dnsServers(),
            pathStatus: pathStatus,
            isExpensive: isExpensive,
            isConstrained: isConstrained,
            usesWiFi: usesWiFi,
            usesEthernet: usesEthernet,
            usesCellular: usesCellular,
            primaryIPv4: primaryIPv4,
            connections: connections,
            appSummaries: appSummaries,
            note: "Rates use Wi‑Fi / Ethernet counters (64-bit). VPN and AirDrop radios are listed separately so they do not double-count. Per-app byte rates need private APIs — Luma does not invent them."
        )
    }

    // MARK: - Interface collection

    private struct Acc {
        var ipv4: [String] = []
        var ipv6: [String] = []
        var mac: String?
        var flags: UInt32 = 0
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var hasLinkStats = false
    }

    /// Headline throughput: physical / cellular NICs only (matches Activity Monitor feel).
    private static func countsTowardAggregate(_ name: String) -> Bool {
        if name.hasPrefix("en") { return true }
        if name.hasPrefix("pdp_ip") { return true } // cellular
        return false
    }

    private static func collectInterfaces() throws -> [String: Acc] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            throw LumaError.ioFailure("getifaddrs failed")
        }
        defer { freeifaddrs(ifaddr) }

        var byName: [String: Acc] = [:]
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let name = String(cString: current.pointee.ifa_name)
            var acc = byName[name] ?? Acc()
            acc.flags = current.pointee.ifa_flags

            if let addr = current.pointee.ifa_addr {
                switch Int32(addr.pointee.sa_family) {
                case AF_LINK:
                    if let data = current.pointee.ifa_data {
                        // Fallback only — prefer 64-bit `linkByteCounters()`.
                        let networkData = data.assumingMemoryBound(to: if_data.self)
                        acc.bytesIn = UInt64(networkData.pointee.ifi_ibytes)
                        acc.bytesOut = UInt64(networkData.pointee.ifi_obytes)
                        acc.hasLinkStats = true
                    }
                    if let mac = Self.macAddress(from: addr) {
                        acc.mac = mac
                    }
                case AF_INET:
                    if let ip = Self.numericHost(from: addr), !acc.ipv4.contains(ip) {
                        acc.ipv4.append(ip)
                    }
                case AF_INET6:
                    if var ip = Self.numericHost(from: addr) {
                        if let percent = ip.firstIndex(of: "%") {
                            ip = String(ip[..<percent])
                        }
                        if !ip.hasPrefix("fe80:"), !acc.ipv6.contains(ip) {
                            acc.ipv6.append(ip)
                        }
                    }
                default:
                    break
                }
            }

            byName[name] = acc
            ptr = current.pointee.ifa_next
        }
        return byName
    }

    /// 64-bit interface byte counters from `sysctl(NET_RT_IFLIST2)`.
    private static func linkByteCounters() -> [String: (in: UInt64, out: UInt64)] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, u_int(mib.count), nil, &length, nil, 0) == 0, length > 0 else {
            return [:]
        }
        var buffer = [UInt8](repeating: 0, count: length)
        let result = buffer.withUnsafeMutableBytes { raw -> Int32 in
            sysctl(&mib, u_int(mib.count), raw.baseAddress, &length, nil, 0)
        }
        guard result == 0 else { return [:] }

        var out: [String: (in: UInt64, out: UInt64)] = [:]
        var offset = 0
        while offset + MemoryLayout<if_msghdr>.size <= length {
            let msgLen: Int = buffer.withUnsafeBytes { raw in
                Int(raw.load(fromByteOffset: offset, as: if_msghdr.self).ifm_msglen)
            }
            guard msgLen > 0, offset + msgLen <= length else { break }

            let msgType: UInt8 = buffer.withUnsafeBytes { raw in
                raw.load(fromByteOffset: offset, as: if_msghdr.self).ifm_type
            }

            if msgType == UInt8(RTM_IFINFO2), msgLen >= MemoryLayout<if_msghdr2>.size {
                buffer.withUnsafeBytes { raw in
                    guard let base = raw.baseAddress?.advanced(by: offset) else { return }
                    let ifm = base.assumingMemoryBound(to: if_msghdr2.self).pointee
                    let sdl = base.advanced(by: MemoryLayout<if_msghdr2>.size)
                        .assumingMemoryBound(to: sockaddr_dl.self)
                    let nameLen = Int(sdl.pointee.sdl_nlen)
                    guard nameLen > 0, nameLen <= 32 else { return }
                    let name: String = withUnsafeBytes(of: sdl.pointee.sdl_data) { dataRaw in
                        let bytes = dataRaw.prefix(nameLen)
                        return String(bytes: bytes, encoding: .utf8) ?? ""
                    }
                    guard !name.isEmpty else { return }
                    out[name] = (ifm.ifm_data.ifi_ibytes, ifm.ifm_data.ifi_obytes)
                }
            }
            offset += msgLen
        }
        return out
    }

    private static func numericHost(from addr: UnsafePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            addr,
            socklen_t(addr.pointee.sa_len),
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return nil }
        return String(cString: host)
    }

    private static func macAddress(from addr: UnsafePointer<sockaddr>) -> String? {
        addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { sdlPtr in
            let sdl = sdlPtr.pointee
            let addressLength = Int(sdl.sdl_alen)
            guard addressLength == 6 else { return nil }
            return withUnsafeBytes(of: sdl.sdl_data) { raw -> String? in
                let nameLength = Int(sdl.sdl_nlen)
                guard raw.count >= nameLength + addressLength else { return nil }
                let mac = raw.dropFirst(nameLength).prefix(addressLength)
                return mac.map { String(format: "%02x", $0) }.joined(separator: ":")
            }
        }
    }

    private static func kindLabel(for name: String) -> String {
        if name.hasPrefix("en") { return "Ethernet / Wi‑Fi" }
        if name.hasPrefix("bridge") { return "Bridge" }
        if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") { return "VPN / Tunnel" }
        if name.hasPrefix("awdl") { return "AirDrop / AWDL" }
        if name.hasPrefix("llw") { return "Low-latency WLAN" }
        if name.hasPrefix("ap") { return "Access Point" }
        if name.hasPrefix("gif") || name.hasPrefix("stf") { return "Tunnel" }
        if name.hasPrefix("anpi") { return "Thunderbolt bridge" }
        if name.hasPrefix("pdp_ip") { return "Cellular" }
        return "Interface"
    }

    private static func dnsServers() -> [String] {
        guard let store = SCDynamicStoreCreate(nil, "LumaNetwork" as CFString, nil, nil) else {
            return []
        }
        let key = "State:/Network/Global/DNS" as CFString
        guard let value = SCDynamicStoreCopyValue(store, key) as? [String: Any],
              let servers = value["ServerAddresses"] as? [String]
        else {
            return []
        }
        return servers
    }
}
