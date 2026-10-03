import Darwin
import Foundation
import LumaCore
import LumaSupport

/// Read-only macOS security *hygiene* probes.
/// Not antivirus: no signature database, no “your Mac is safe” score, no invented XProtect verdicts.
public struct SecurityStatusSampler: Sendable {
    public init() {}

    public func sample(
        fullDiskAccessGranted: Bool,
        fullDiskAccessDetail: String
    ) async -> SecuritySnapshot {
        await Task.detached(priority: .utility) {
            Self.sampleSync(
                fullDiskAccessGranted: fullDiskAccessGranted,
                fullDiskAccessDetail: fullDiskAccessDetail
            )
        }.value
    }

    nonisolated private static func sampleSync(
        fullDiskAccessGranted: Bool,
        fullDiskAccessDetail: String
    ) -> SecuritySnapshot {
        var checks: [SecurityCheckItem] = []
        checks.append(fileVaultCheck())
        checks.append(firewallCheck())
        checks.append(firewallStealthCheck())
        checks.append(gatekeeperCheck())
        checks.append(sipCheck())
        checks.append(fullDiskAccessCheck(granted: fullDiskAccessGranted, detail: fullDiskAccessDetail))
        checks.append(quarantinedAppsCheck())

        return SecuritySnapshot(
            checks: checks,
            honestyNote: LumaL10n.string(
                "Luma reports built-in macOS protections and permissions. It is not antivirus and does not scan for malware signatures."
            )
        )
    }

    // MARK: - Individual checks

    nonisolated private static func fileVaultCheck() -> SecurityCheckItem {
        let settings = "x-apple.systempreferences:com.apple.preference.security?FileVault"
        let (code, out, err) = run("/usr/bin/fdesetup", ["status"])
        let text = (out + "\n" + err).lowercased()
        if code == 0 || !out.isEmpty {
            if text.contains("filevault is on") {
                return item(
                    id: "filevault",
                    title: LumaL10n.string("FileVault"),
                    summary: LumaL10n.string("On"),
                    detail: LumaL10n.string("Disk encryption is enabled for this Mac."),
                    state: .ok,
                    source: "fdesetup status",
                    settings: settings
                )
            }
            if text.contains("filevault is off") {
                return item(
                    id: "filevault",
                    title: LumaL10n.string("FileVault"),
                    summary: LumaL10n.string("Off"),
                    detail: LumaL10n.string("Disk encryption is off. Enable FileVault in System Settings if you want full-disk encryption."),
                    state: .attention,
                    source: "fdesetup status",
                    settings: settings
                )
            }
        }
        return item(
            id: "filevault",
            title: LumaL10n.string("FileVault"),
            summary: LumaL10n.string("Unknown"),
            detail: LumaL10n.string("Could not read FileVault status honestly from fdesetup."),
            state: .unknown,
            source: "fdesetup status",
            settings: settings
        )
    }

    nonisolated private static func firewallCheck() -> SecurityCheckItem {
        let path = "/usr/libexec/ApplicationFirewall/socketfilterfw"
        let settings = "x-apple.systempreferences:com.apple.preference.security?Firewall"
        let (code, out, err) = run(path, ["--getglobalstate"])
        let text = (out + "\n" + err)
        let lower = text.lowercased()
        if code == 0 || !out.isEmpty {
            if lower.contains("enabled") || lower.contains("state = 1") {
                return item(
                    id: "firewall",
                    title: LumaL10n.string("Application Firewall"),
                    summary: LumaL10n.string("On"),
                    detail: LumaL10n.string("The application firewall appears enabled."),
                    state: .ok,
                    source: "socketfilterfw --getglobalstate",
                    settings: settings
                )
            }
            if lower.contains("disabled") || lower.contains("state = 0") {
                return item(
                    id: "firewall",
                    title: LumaL10n.string("Application Firewall"),
                    summary: LumaL10n.string("Off"),
                    detail: LumaL10n.string("The application firewall appears disabled. You can turn it on in System Settings."),
                    state: .attention,
                    source: "socketfilterfw --getglobalstate",
                    settings: settings
                )
            }
        }
        return item(
            id: "firewall",
            title: LumaL10n.string("Application Firewall"),
            summary: LumaL10n.string("Unknown"),
            detail: LumaL10n.string("Could not read firewall state from socketfilterfw."),
            state: .unknown,
            source: "socketfilterfw --getglobalstate",
            settings: settings
        )
    }

    nonisolated private static func firewallStealthCheck() -> SecurityCheckItem {
        let path = "/usr/libexec/ApplicationFirewall/socketfilterfw"
        let settings = "x-apple.systempreferences:com.apple.preference.security?Firewall"
        let (code, out, err) = run(path, ["--getstealthmode"])
        let text = (out + "\n" + err).lowercased()
        if code == 0 || !out.isEmpty {
            if text.contains("enabled") {
                return item(
                    id: "stealth",
                    title: LumaL10n.string("Firewall stealth mode"),
                    summary: LumaL10n.string("On"),
                    detail: LumaL10n.string("Stealth mode is on — the Mac may not respond to some unsolicited network probes."),
                    state: .info,
                    source: "socketfilterfw --getstealthmode",
                    settings: settings
                )
            }
            if text.contains("disabled") {
                return item(
                    id: "stealth",
                    title: LumaL10n.string("Firewall stealth mode"),
                    summary: LumaL10n.string("Off"),
                    detail: LumaL10n.string("Stealth mode is off. Optional hardening, not a malware finding."),
                    state: .info,
                    source: "socketfilterfw --getstealthmode",
                    settings: settings
                )
            }
        }
        return item(
            id: "stealth",
            title: LumaL10n.string("Firewall stealth mode"),
            summary: LumaL10n.string("Unknown"),
            detail: LumaL10n.string("Could not read stealth mode."),
            state: .unknown,
            source: "socketfilterfw --getstealthmode",
            settings: settings
        )
    }

    nonisolated private static func gatekeeperCheck() -> SecurityCheckItem {
        let settings = "x-apple.systempreferences:com.apple.preference.security?General"
        let (code, out, err) = run("/usr/sbin/spctl", ["--status"])
        let text = (out + "\n" + err).lowercased()
        if code == 0 || !out.isEmpty {
            if text.contains("assessments enabled") || text.contains("enabled") {
                return item(
                    id: "gatekeeper",
                    title: LumaL10n.string("Gatekeeper"),
                    summary: LumaL10n.string("Assessments on"),
                    detail: LumaL10n.string("Gatekeeper is assessing apps before they run (spctl)."),
                    state: .ok,
                    source: "spctl --status",
                    settings: settings
                )
            }
            if text.contains("disabled") {
                return item(
                    id: "gatekeeper",
                    title: LumaL10n.string("Gatekeeper"),
                    summary: LumaL10n.string("Assessments off"),
                    detail: LumaL10n.string("Gatekeeper assessments appear disabled. Re-enable in System Settings unless you disabled them on purpose."),
                    state: .attention,
                    source: "spctl --status",
                    settings: settings
                )
            }
        }
        return item(
            id: "gatekeeper",
            title: LumaL10n.string("Gatekeeper"),
            summary: LumaL10n.string("Unknown"),
            detail: LumaL10n.string("Could not read Gatekeeper status from spctl."),
            state: .unknown,
            source: "spctl --status",
            settings: settings
        )
    }

    nonisolated private static func sipCheck() -> SecurityCheckItem {
        let (code, out, err) = run("/usr/bin/csrutil", ["status"])
        let text = (out + "\n" + err).lowercased()
        if code == 0 || !out.isEmpty {
            if text.contains("enabled") {
                return item(
                    id: "sip",
                    title: LumaL10n.string("System Integrity Protection"),
                    summary: LumaL10n.string("Enabled"),
                    detail: LumaL10n.string("SIP is enabled. This is normal for most Macs."),
                    state: .ok,
                    source: "csrutil status",
                    settings: nil
                )
            }
            if text.contains("disabled") {
                return item(
                    id: "sip",
                    title: LumaL10n.string("System Integrity Protection"),
                    summary: LumaL10n.string("Disabled"),
                    detail: LumaL10n.string("SIP appears disabled. That weakens macOS system protections — only keep it off if you intentionally need it."),
                    state: .attention,
                    source: "csrutil status",
                    settings: nil
                )
            }
        }
        return item(
            id: "sip",
            title: LumaL10n.string("System Integrity Protection"),
            summary: LumaL10n.string("Unknown"),
            detail: LumaL10n.string("Could not read SIP status from csrutil."),
            state: .unknown,
            source: "csrutil status",
            settings: nil
        )
    }

    nonisolated private static func fullDiskAccessCheck(granted: Bool, detail: String) -> SecurityCheckItem {
        let settings = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
        if granted {
            return item(
                id: "fda",
                title: LumaL10n.string("Full Disk Access (Luma)"),
                summary: LumaL10n.string("Likely granted"),
                detail: detail,
                state: .ok,
                source: "list ~/Library/Safari",
                settings: settings
            )
        }
        return item(
            id: "fda",
            title: LumaL10n.string("Full Disk Access (Luma)"),
            summary: LumaL10n.string("Not granted"),
            detail: detail.isEmpty
                ? LumaL10n.string("Without Full Disk Access, protected Library folders are skipped.")
                : detail,
            state: .attention,
            source: "list ~/Library/Safari",
            settings: settings
        )
    }

    /// Count of .app bundles under Applications that still carry a quarantine flag.
    nonisolated private static func quarantinedAppsCheck() -> SecurityCheckItem {
        let apps = URL(fileURLWithPath: "/Applications")
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        var total = 0
        var quarantined = 0
        for root in [apps, userApps] {
            guard FileManager.default.fileExists(atPath: root.path) else { continue }
            let children = (try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey, .isPackageKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for url in children where url.pathExtension.lowercased() == "app" {
                total += 1
                if hasQuarantine(url) { quarantined += 1 }
            }
        }

        let summary = LumaL10n.format("%lld of %lld apps", Int64(quarantined), Int64(total))
        let detail: String
        let state: SecurityCheckState
        if total == 0 {
            detail = LumaL10n.string("No applications found to inspect.")
            state = .unknown
        } else if quarantined == 0 {
            detail = LumaL10n.string("No Application bundles still carry a download quarantine attribute. That is informational — not a malware scan.")
            state = .info
        } else {
            detail = LumaL10n.string("These apps still have a quarantine flag from download/open. First launch goes through Gatekeeper — not a virus verdict.")
            state = .info
        }

        return item(
            id: "quarantine",
            title: LumaL10n.string("Quarantined apps"),
            summary: summary,
            detail: detail,
            state: state,
            source: "com.apple.quarantine xattr on *.app",
            settings: nil
        )
    }

    // MARK: - Helpers

    nonisolated private static func hasQuarantine(_ url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            var buffer = [CChar](repeating: 0, count: 4)
            let result = getxattr(path, "com.apple.quarantine", &buffer, buffer.count, 0, 0)
            return result >= 0
        }
    }

    nonisolated private static func item(
        id: String,
        title: String,
        summary: String,
        detail: String,
        state: SecurityCheckState,
        source: String,
        settings: String?
    ) -> SecurityCheckItem {
        SecurityCheckItem(
            id: id,
            title: title,
            summary: summary,
            detail: detail,
            state: state,
            source: source,
            settingsURLString: settings
        )
    }

    nonisolated private static func run(_ executable: String, _ arguments: [String]) -> (Int32, String, String) {
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
}
