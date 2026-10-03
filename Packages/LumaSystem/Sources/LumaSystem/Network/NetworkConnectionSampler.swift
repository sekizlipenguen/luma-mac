import Darwin
import Foundation
import LumaCore

/// Lists live TCP/UDP sockets per process via `proc_pidfdinfo` (public Darwin API).
/// Shows who ↔ where. Per-app byte counters are not available without private APIs.
public enum NetworkConnectionSampler {
    public static func listConnections(limit: Int = 150) -> [NetworkConnection] {
        let numberOfBytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard numberOfBytes > 0 else { return [] }
        let count = min(Int(numberOfBytes) / MemoryLayout<pid_t>.size, 4_096)
        var pids = [pid_t](repeating: 0, count: count)
        let filled = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(count * MemoryLayout<pid_t>.size))
        guard filled > 0 else { return [] }
        let actualPIDCount = Int(filled) / MemoryLayout<pid_t>.size

        var results: [NetworkConnection] = []
        results.reserveCapacity(min(limit, 256))
        var seen = Set<String>()

        for i in 0..<actualPIDCount {
            let pid = pids[i]
            guard pid > 0 else { continue }
            let name = processName(pid)
            appendSockets(pid: pid, name: name, into: &results, seen: &seen, limit: limit)
            if results.count >= limit { break }
        }

        results.sort { lhs, rhs in
            let ls = rank(lhs)
            let rs = rank(rhs)
            if ls != rs { return ls > rs }
            if lhs.processName != rhs.processName {
                return lhs.processName.localizedCaseInsensitiveCompare(rhs.processName) == .orderedAscending
            }
            return lhs.remoteEndpoint < rhs.remoteEndpoint
        }
        return results
    }

    public static func summarizeByApp(_ connections: [NetworkConnection], limit: Int = 20) -> [NetworkAppSummary] {
        var map: [Int32: (name: String, remotes: Set<String>, count: Int)] = [:]
        for connection in connections {
            var entry = map[connection.pid] ?? (connection.processName, [], 0)
            entry.name = connection.processName
            entry.remotes.insert(connection.remoteEndpoint)
            entry.count += 1
            map[connection.pid] = entry
        }
        return map.map { pid, value in
            NetworkAppSummary(
                pid: pid,
                processName: value.name,
                connectionCount: value.count,
                remoteEndpoints: Array(value.remotes).sorted()
            )
        }
        .sorted { $0.connectionCount > $1.connectionCount }
        .prefix(limit)
        .map { $0 }
    }

    private static func rank(_ connection: NetworkConnection) -> Int {
        switch connection.tcpState {
        case "established": return 5
        case "syn_sent", "syn_received": return 4
        case nil where connection.protocolKind == .udp: return 3
        default: return 1
        }
    }

    private static func appendSockets(
        pid: pid_t,
        name: String,
        into results: inout [NetworkConnection],
        seen: inout Set<String>,
        limit: Int
    ) {
        let bufSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bufSize > 0 else { return }
        let fdCount = Int(bufSize) / MemoryLayout<proc_fdinfo>.size
        guard fdCount > 0, fdCount < 20_000 else { return }
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: fdCount)
        let filled = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, bufSize)
        guard filled > 0 else { return }
        let actual = Int(filled) / MemoryLayout<proc_fdinfo>.size

        for index in 0..<actual {
            guard results.count < limit else { return }
            guard fds[index].proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) else { continue }

            var info = socket_fdinfo()
            let size = Int32(MemoryLayout<socket_fdinfo>.size)
            guard proc_pidfdinfo(pid, fds[index].proc_fd, PROC_PIDFDSOCKETINFO, &info, size) == size else {
                continue
            }

            let family = Int32(info.psi.soi_family)
            guard family == AF_INET || family == AF_INET6 else { continue }
            let kind = Int32(info.psi.soi_kind)
            guard kind == SOCKINFO_TCP || kind == SOCKINFO_IN else { continue }

            let isTCP = kind == SOCKINFO_TCP
            let ini = isTCP ? info.psi.soi_proto.pri_tcp.tcpsi_ini : info.psi.soi_proto.pri_in
            guard let remote = endpoint(ini, local: false, family: family), remote.port != 0 else { continue }
            guard remote.address != "0.0.0.0", remote.address != "::" else { continue }
            let local = endpoint(ini, local: true, family: family) ?? (address: "*", port: 0)

            let state: String?
            if isTCP {
                state = tcpStateName(info.psi.soi_proto.pri_tcp.tcpsi_state)
                // Skip pure listeners with no remote peer.
                if state == "listen" { continue }
            } else {
                state = nil
            }

            let connection = NetworkConnection(
                pid: pid,
                processName: name.isEmpty ? "pid \(pid)" : name,
                protocolKind: isTCP ? .tcp : .udp,
                localAddress: local.address,
                localPort: local.port,
                remoteAddress: remote.address,
                remotePort: remote.port,
                tcpState: state
            )
            guard seen.insert(connection.id).inserted else { continue }
            results.append(connection)
        }
    }

    private static func endpoint(_ ini: in_sockinfo, local: Bool, family: Int32) -> (address: String, port: Int)? {
        let port = Int(UInt16(bigEndian: UInt16(truncatingIfNeeded: local ? ini.insi_lport : ini.insi_fport)))
        if family == AF_INET || (ini.insi_vflag & UInt8(INI_IPV4)) != 0 {
            var address = local ? ini.insi_laddr.ina_46.i46a_addr4 : ini.insi_faddr.ina_46.i46a_addr4
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { return nil }
            return (String(cString: buffer), port)
        }
        if family == AF_INET6 || (ini.insi_vflag & UInt8(INI_IPV6)) != 0 {
            var address = local ? ini.insi_laddr.ina_6 : ini.insi_faddr.ina_6
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard inet_ntop(AF_INET6, &address, &buffer, socklen_t(INET6_ADDRSTRLEN)) != nil else { return nil }
            var ip = String(cString: buffer)
            if let percent = ip.firstIndex(of: "%") {
                ip = String(ip[..<percent])
            }
            return (ip, port)
        }
        return nil
    }

    private static func tcpStateName(_ state: Int32) -> String {
        switch state {
        case TSI_S_CLOSED: return "closed"
        case TSI_S_LISTEN: return "listen"
        case TSI_S_SYN_SENT: return "syn_sent"
        case TSI_S_SYN_RECEIVED: return "syn_received"
        case TSI_S_ESTABLISHED: return "established"
        case TSI_S__CLOSE_WAIT: return "close_wait"
        case TSI_S_FIN_WAIT_1: return "fin_wait_1"
        case TSI_S_CLOSING: return "closing"
        case TSI_S_LAST_ACK: return "last_ack"
        case TSI_S_FIN_WAIT_2: return "fin_wait_2"
        case TSI_S_TIME_WAIT: return "time_wait"
        default: return "state_\(state)"
        }
    }

    private static func processName(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) * 2)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? String(cString: buffer) : ""
    }
}
