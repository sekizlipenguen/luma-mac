import Foundation

/// One step in a soft network refresh (DNS / DHCP / optional Wi‑Fi bounce).
public struct NetworkRefreshStep: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let succeeded: Bool
    public let detail: String?

    public init(id: String, title: String, succeeded: Bool, detail: String? = nil) {
        self.id = id
        self.title = title
        self.succeeded = succeeded
        self.detail = detail
    }
}

/// Result of refreshing the local network stack without rebooting.
public struct NetworkRefreshReport: Sendable, Equatable {
    public let steps: [NetworkRefreshStep]
    public let completedAt: Date
    public let cancelled: Bool

    public var succeededCount: Int { steps.filter(\.succeeded).count }
    public var failedCount: Int { steps.filter { !$0.succeeded }.count }

    public init(steps: [NetworkRefreshStep], completedAt: Date = .now, cancelled: Bool = false) {
        self.steps = steps
        self.completedAt = completedAt
        self.cancelled = cancelled
    }
}

/// Soft “network restart”: flush DNS, renew DHCP on Wi‑Fi/Ethernet, optionally bounce Wi‑Fi.
///
/// VPN leftovers often show up as sticky DNS or stale DHCP state after disconnecting.
/// This does **not** uninstall VPN apps or tear down every `utun` (those belong to the VPN
/// process). It asks for an admin password once via `osascript` — same pattern as other
/// maintenance tools — and only runs a fixed allowlisted shell script (no user paths).
public enum NetworkStackRefresher {
    public enum RefreshError: Error, LocalizedError, Sendable {
        case cancelled
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case .cancelled: "Authentication cancelled"
            case .failed(let message): message
            }
        }
    }

    /// Detect Wi‑Fi / Ethernet-like hardware ports (service name + BSD device).
    public static func renewableServices(
        hardwarePortsText: String? = nil
    ) -> [(service: String, device: String)] {
        let text = hardwarePortsText ?? runCapture("/usr/sbin/networksetup", ["-listallhardwareports"]).1
        return parseHardwarePorts(text)
            .filter { isRenewableHardwarePort($0.port) }
            .map { (service: $0.port, device: $0.device) }
    }

    public static func refresh(bounceWiFi: Bool) async throws -> NetworkRefreshReport {
        try await Task.detached(priority: .userInitiated) {
            try refreshSync(bounceWiFi: bounceWiFi)
        }.value
    }

    // MARK: - Sync implementation

    nonisolated private static func refreshSync(bounceWiFi: Bool) throws -> NetworkRefreshReport {
        let services = renewableServices()
        let wifiDevices = services
            .filter { isWiFiHardwarePort($0.service) }
            .map(\.device)

        var scriptLines: [String] = [
            "#!/bin/bash",
            "echo LUMA_STEP:dns",
            "/usr/bin/dscacheutil -flushcache || true",
            "/usr/bin/killall -HUP mDNSResponder 2>/dev/null || true",
            "/usr/bin/killall -HUP mDNSResponderHelper 2>/dev/null || true",
            "echo LUMA_OK:dns"
        ]

        if services.isEmpty {
            scriptLines.append("echo LUMA_STEP:dhcp")
            scriptLines.append("echo LUMA_SKIP:dhcp:no-wifi-ethernet-services")
        } else {
            for (index, service) in services.enumerated() {
                let stepID = "dhcp-\(index)"
                let quoted = shellSingleQuoted(service.service)
                scriptLines.append("echo LUMA_STEP:\(stepID)")
                scriptLines.append("if /usr/sbin/networksetup -setdhcp \(quoted); then echo LUMA_OK:\(stepID); else echo LUMA_FAIL:\(stepID); fi")
            }
        }

        if bounceWiFi {
            if wifiDevices.isEmpty {
                scriptLines.append("echo LUMA_STEP:wifi")
                scriptLines.append("echo LUMA_SKIP:wifi:no-wifi-device")
            } else {
                for (index, device) in wifiDevices.enumerated() {
                    let stepID = "wifi-\(index)"
                    let quoted = shellSingleQuoted(device)
                    scriptLines.append("echo LUMA_STEP:\(stepID)")
                    scriptLines.append("if /usr/sbin/networksetup -setairportpower \(quoted) off && /bin/sleep 2 && /usr/sbin/networksetup -setairportpower \(quoted) on; then echo LUMA_OK:\(stepID); else echo LUMA_FAIL:\(stepID); fi")
                }
            }
        }

        scriptLines.append("echo LUMA_DONE")
        let shell = scriptLines.joined(separator: "\n")
        let (status, stdout, stderr) = try runPrivilegedScriptFile(shell)

        if status != 0 {
            let combined = (stderr + "\n" + stdout).trimmingCharacters(in: .whitespacesAndNewlines)
            if combined.localizedCaseInsensitiveContains("canceled")
                || combined.localizedCaseInsensitiveContains("cancelled")
                || combined.localizedCaseInsensitiveContains("(-128)")
            {
                throw RefreshError.cancelled
            }
            // Partial progress may still be in stdout — parse what we can, then surface failure.
            var steps = parseSteps(
                stdout: stdout,
                services: services,
                wifiDevices: wifiDevices,
                bounceWiFi: bounceWiFi
            )
            if steps.isEmpty {
                throw RefreshError.failed(combined.isEmpty ? "Network refresh failed" : combined)
            }
            steps.append(
                NetworkRefreshStep(
                    id: "error",
                    title: "Network refresh",
                    succeeded: false,
                    detail: combined.isEmpty ? "Finished with errors" : combined
                )
            )
            return NetworkRefreshReport(steps: steps)
        }

        let steps = parseSteps(
            stdout: stdout,
            services: services,
            wifiDevices: wifiDevices,
            bounceWiFi: bounceWiFi
        )
        return NetworkRefreshReport(steps: steps)
    }

    nonisolated static func parseHardwarePorts(_ text: String) -> [(port: String, device: String)] {
        var results: [(port: String, device: String)] = []
        var currentPort: String?
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Hardware Port:") {
                currentPort = String(line.dropFirst("Hardware Port:".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Device:"), let port = currentPort {
                let device = String(line.dropFirst("Device:".count)).trimmingCharacters(in: .whitespaces)
                if !device.isEmpty {
                    results.append((port: port, device: device))
                }
                currentPort = nil
            }
        }
        return results
    }

    nonisolated static func isRenewableHardwarePort(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.contains("bridge") || lower.contains("thunderbolt") || lower.contains("bluetooth") {
            return false
        }
        if lower.contains("iphone") || lower.contains("ipad") || lower.contains("vpn") {
            return false
        }
        return isWiFiHardwarePort(name)
            || lower.contains("ethernet")
            || lower.contains("usb") && (lower.contains("lan") || lower.contains("ethernet"))
    }

    nonisolated static func isWiFiHardwarePort(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("wi-fi") || lower.contains("wifi") || lower.contains("airport")
    }

    nonisolated private static func parseSteps(
        stdout: String,
        services: [(service: String, device: String)],
        wifiDevices: [String],
        bounceWiFi: Bool
    ) -> [NetworkRefreshStep] {
        let lines = stdout.split(whereSeparator: \.isNewline).map(String.init)
        var ok = Set<String>()
        var skipped: [String: String] = [:]
        for line in lines {
            if line.hasPrefix("LUMA_OK:") {
                ok.insert(String(line.dropFirst("LUMA_OK:".count)))
            } else if line.hasPrefix("LUMA_SKIP:") {
                let rest = String(line.dropFirst("LUMA_SKIP:".count))
                let parts = rest.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    skipped[parts[0]] = parts[1]
                } else if let id = parts.first {
                    skipped[id] = "skipped"
                }
            }
        }

        var steps: [NetworkRefreshStep] = []
        steps.append(
            NetworkRefreshStep(
                id: "dns",
                title: "Flush DNS cache",
                succeeded: ok.contains("dns"),
                detail: ok.contains("dns")
                    ? "dscacheutil + mDNSResponder"
                    : "DNS flush did not confirm"
            )
        )

        if services.isEmpty {
            steps.append(
                NetworkRefreshStep(
                    id: "dhcp",
                    title: "Renew DHCP",
                    succeeded: true,
                    detail: skipped["dhcp"] ?? "No Wi‑Fi / Ethernet service found"
                )
            )
        } else {
            for (index, service) in services.enumerated() {
                let id = "dhcp-\(index)"
                steps.append(
                    NetworkRefreshStep(
                        id: id,
                        title: "Renew DHCP — \(service.service)",
                        succeeded: ok.contains(id),
                        detail: "\(service.device)"
                    )
                )
            }
        }

        if bounceWiFi {
            if wifiDevices.isEmpty {
                steps.append(
                    NetworkRefreshStep(
                        id: "wifi",
                        title: "Bounce Wi‑Fi",
                        succeeded: true,
                        detail: skipped["wifi"] ?? "No Wi‑Fi device found"
                    )
                )
            } else {
                for (index, device) in wifiDevices.enumerated() {
                    let id = "wifi-\(index)"
                    steps.append(
                        NetworkRefreshStep(
                            id: id,
                            title: "Bounce Wi‑Fi — \(device)",
                            succeeded: ok.contains(id),
                            detail: "off → on"
                        )
                    )
                }
            }
        }

        return steps
    }

    /// Writes an allowlisted script to a temp file and runs it with administrator privileges.
    nonisolated private static func runPrivilegedScriptFile(_ shell: String) throws -> (Int32, String, String) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("luma-network-refresh-\(UUID().uuidString).sh")
        try shell.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let appleScript = "do shell script \"/bin/bash \(shellSingleQuoted(url.path))\" with administrator privileges"
        return runCapture("/usr/bin/osascript", ["-e", appleScript])
    }

    nonisolated private static func runCapture(_ executable: String, _ arguments: [String]) -> (Int32, String, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, "", error.localizedDescription)
        }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        return (
            process.terminationStatus,
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
        )
    }

    nonisolated private static func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
