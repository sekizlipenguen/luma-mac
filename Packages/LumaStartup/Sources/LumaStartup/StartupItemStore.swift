import Darwin
import Foundation
import LumaCore
import LumaSupport

public enum StartupDomain: String, Sendable, Codable {
    case user
    case system
}

public struct StartupItem: Sendable, Equatable, Identifiable {
    public var id: String { path }
    public var label: String
    public var path: String
    public var domain: StartupDomain
    public var kind: String
    public var isEnabled: Bool
    public var isMutable: Bool
    public var unavailableReason: String?

    public init(
        label: String,
        path: String,
        domain: StartupDomain,
        kind: String,
        isEnabled: Bool,
        isMutable: Bool,
        unavailableReason: String? = nil
    ) {
        self.label = label
        self.path = path
        self.domain = domain
        self.kind = kind
        self.isEnabled = isEnabled
        self.isMutable = isMutable
        self.unavailableReason = unavailableReason
    }
}

public actor StartupItemStore {
    public init() {}

    public func listItems() async throws -> [StartupItem] {
        try await Task.detached(priority: .utility) {
            Self.scan()
        }.value
    }

    public func setEnabled(_ item: StartupItem, enabled: Bool) async throws {
        guard item.isMutable else {
            throw LumaError.permissionDenied(item.unavailableReason ?? "This startup item cannot be modified by Luma.")
        }
        try await Task.detached(priority: .userInitiated) {
            try Self.apply(item: item, enabled: enabled)
        }.value
    }

    private static func scan() -> [StartupItem] {
        var items: [StartupItem] = []
        let home = NSHomeDirectory()
        let pairs: [(String, StartupDomain, Bool)] = [
            ("\(home)/Library/LaunchAgents", .user, true),
            ("/Library/LaunchAgents", .system, false),
            ("/Library/LaunchDaemons", .system, false)
        ]

        for (dir, domain, mutable) in pairs {
            let url = URL(fileURLWithPath: dir)
            guard FileIO.directoryExists(url),
                  let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            else { continue }

            for file in files where file.pathExtension == "plist" {
                let dict = NSDictionary(contentsOf: file) as? [String: Any]
                let label = dict?["Label"] as? String ?? file.deletingPathExtension().lastPathComponent
                let disabled = dict?["Disabled"] as? Bool ?? false
                items.append(
                    StartupItem(
                        label: label,
                        path: file.path,
                        domain: domain,
                        kind: dir.contains("Daemon") ? "LaunchDaemon" : "LaunchAgent",
                        isEnabled: !disabled,
                        isMutable: mutable && domain == .user,
                        unavailableReason: mutable ? nil : "System domain / SIP-protected — use Reveal in Finder. Luma will not modify system daemons."
                    )
                )
            }
        }

        // Login Items (SMAppService) — list registered services for this app; other apps' login items
        // are not fully enumerable via public API on all OS versions.
        items.append(
            StartupItem(
                label: "Login Items (System Settings)",
                path: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
                domain: .user,
                kind: "LoginItem",
                isEnabled: true,
                isMutable: false,
                unavailableReason: "Manage other apps' Login Items in System Settings. Luma lists LaunchAgents/Daemons from disk."
            )
        )

        return items.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private static func apply(item: StartupItem, enabled: Bool) throws {
        let url = URL(fileURLWithPath: item.path)
        guard item.path.hasSuffix(".plist"),
              var dict = NSDictionary(contentsOf: url) as? [String: Any]
        else {
            throw LumaError.pathUnavailable(item.path)
        }
        dict["Disabled"] = !enabled
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)

        let uid = getuid()
        let domainTarget = "gui/\(uid)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        if enabled {
            process.arguments = ["bootstrap", domainTarget, item.path]
        } else {
            let label = dict["Label"] as? String ?? item.label
            process.arguments = ["bootout", "\(domainTarget)/\(label)"]
        }
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        // Non-zero may occur if already loaded/unloaded — not fatal if plist updated.
    }
}
