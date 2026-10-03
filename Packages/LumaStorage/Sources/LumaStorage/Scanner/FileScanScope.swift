import Foundation
import LumaCore
import LumaSupport

/// Where Large Files / Duplicates walk. Never crawls `/System` — PathSafety denylist still applies.
/// Full Disk Access unlocks protected Library paths (e.g. Safari); without it those folders are skipped honestly.
public enum FileScanScope: String, Sendable, CaseIterable, Identifiable {
    /// Fast: common personal folders only.
    case commonFolders
    /// Wide: entire home directory + Applications (default product intent).
    case homeAndApps

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .commonFolders: LumaL10n.string("Common folders")
        case .homeAndApps: LumaL10n.string("This Mac (user areas)")
        }
    }

    public var subtitle: String {
        switch self {
        case .commonFolders:
            LumaL10n.string("Downloads, Documents, Desktop, and Movies — faster.")
        case .homeAndApps:
            LumaL10n.string("Your whole home folder plus Applications. Full Disk Access covers protected Library paths. System stays off-limits.")
        }
    }

    public func roots() -> [URL] {
        let fm = FileManager.default
        let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL
        func exists(_ url: URL) -> Bool {
            fm.fileExists(atPath: url.path)
        }

        switch self {
        case .commonFolders:
            return [
                home.appendingPathComponent("Downloads"),
                home.appendingPathComponent("Documents"),
                home.appendingPathComponent("Desktop"),
                home.appendingPathComponent("Movies")
            ]
            .map(\.standardizedFileURL)
            .filter(exists)

        case .homeAndApps:
            var urls: [URL] = []
            if exists(home) { urls.append(home) }
            let apps = URL(fileURLWithPath: "/Applications").standardizedFileURL
            if exists(apps) { urls.append(apps) }
            let userApps = home.appendingPathComponent("Applications").standardizedFileURL
            if exists(userApps), userApps.path != apps.path {
                urls.append(userApps)
            }
            return urls
        }
    }
}
