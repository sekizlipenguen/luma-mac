import AppKit
import Foundation
import LumaCore

/// Full Disk Access and related TCC helpers. Never fakes access.
@MainActor
public final class PermissionGate {
    public static let shared = PermissionGate()

    public private(set) var lastProbeSucceeded: Bool = false
    public private(set) var lastProbeDetail: String = ""

    private init() {}

    /// Probe a known TCC-protected location. Success does not guarantee all paths are readable.
    public func refreshFullDiskAccessProbe() {
        let probe = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Safari")
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: probe.path)
            lastProbeSucceeded = true
            lastProbeDetail = "Able to list ~/Library/Safari (Full Disk Access likely granted)."
        } catch {
            lastProbeSucceeded = false
            lastProbeDetail = "Cannot list ~/Library/Safari — grant Full Disk Access for complete scans. (\(error.localizedDescription))"
        }
    }

    public func openFullDiskAccessSettings() {
        // System Settings → Privacy & Security → Full Disk Access
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
        ]
        for string in urls {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
