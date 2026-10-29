import Foundation
import LumaCore

/// Parses `sfltool dumpbtm` — the same catalog System Settings uses for Background App Activity.
enum BackgroundTaskDump {
    struct Item: Equatable, Sendable {
        var name: String
        var identifier: String
        var typeRaw: String
        var kind: BackgroundActivityKind
        var url: String?
        var executablePath: String?
        var bundleIdentifier: String?
        var parentIdentifier: String?
        var lastUse: Date?
        var embeddedIdentifiers: [String]
        var launchLabel: String?
    }

    static func parse(_ text: String, uid: UInt32, home: String) -> [Item] {
        let chunks = text.components(separatedBy: "\n #")
        var items: [Item] = []
        items.reserveCapacity(chunks.count)
        for chunk in chunks.dropFirst() {
            guard let item = parseItem(chunk, uid: uid, home: home) else { continue }
            items.append(item)
        }
        return items
    }

    static func displayRows(
        _ items: [Item],
        launchJobs: [String: Int32],
        executables: [String: Int32],
        runningBundles: Set<String>,
        now: Date,
        home: String,
        ownBundleIdentifier: String?,
        ownApplicationPath: String?
    ) -> [BackgroundApp] {
        let foldable = Set(items.filter { $0.kind == .app || $0.kind == .developer }.map(\.identifier))
        var rows: [Item] = []
        for item in items {
            if item.kind == .app || item.kind == .developer {
                rows.append(item)
            } else if let parent = item.parentIdentifier, foldable.contains(parent) {
                continue
            } else if item.kind == .agent || item.kind == .daemon {
                rows.append(item)
            }
        }

        return rows.compactMap { root in
            if isOwn(root, ownBundleIdentifier: ownBundleIdentifier, ownApplicationPath: ownApplicationPath) {
                return nil
            }
            let children = items.filter {
                $0.parentIdentifier == root.identifier || root.embeddedIdentifiers.contains($0.identifier)
            }
            let members = [root] + children
            var pid: Int32?
            var running = false
            for member in members {
                let live = liveness(
                    member,
                    launchJobs: launchJobs,
                    executables: executables,
                    runningBundles: runningBundles,
                    parentRunning: parentAppRunning(root, runningBundles: runningBundles, executables: executables),
                    now: now
                )
                if live.running {
                    running = true
                    if pid == nil { pid = live.pid }
                }
            }
            guard running else { return nil }
            let jobs = members.compactMap { stopJob(for: $0, home: home) }
            let icon = members.compactMap(\.url).first(where: { $0.hasSuffix(".app") })
                ?? root.url
                ?? root.executablePath
            let detail: String
            if let pid {
                detail = "PID \(pid)"
            } else {
                detail = kindLabel(root.kind)
            }
            return BackgroundApp(
                identifier: root.identifier,
                name: root.name,
                kind: root.kind == .developer ? .app : root.kind,
                bundleIdentifier: root.bundleIdentifier ?? members.compactMap(\.bundleIdentifier).first,
                iconPath: icon.flatMap { rewritePath($0, uid: nil, home: home) } ?? icon,
                detail: detail,
                pid: pid,
                isRunning: true,
                stopJobs: uniqueJobs(jobs)
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    struct LaunchPlist: Equatable, Sendable {
        var label: String
        var plistPath: String
        var executablePath: String?
        var isUser: Bool
    }

    static func launchPlist(from dict: [String: Any], path: String, isUser: Bool) -> LaunchPlist? {
        let label = (dict["Label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard !label.isEmpty, !label.hasPrefix("com.apple.") else { return nil }
        let program = dict["Program"] as? String
            ?? (dict["ProgramArguments"] as? [String])?.first
        if let program, isPlaceholderExecutable(program) { return nil }
        return LaunchPlist(label: label, plistPath: path, executablePath: program, isUser: isUser)
    }

    static func rows(
        from plists: [LaunchPlist],
        launchJobs: [String: Int32],
        executables: [String: Int32],
        home: String,
        ownBundleIdentifier: String?,
        ownApplicationPath: String?
    ) -> [BackgroundApp] {
        let agents = (home as NSString).appendingPathComponent("Library/LaunchAgents")
        return plists.compactMap { item -> BackgroundApp? in
            if isOwnPlist(item, ownBundleIdentifier: ownBundleIdentifier, ownApplicationPath: ownApplicationPath) {
                return nil
            }
            let pid = livePID(item, launchJobs: launchJobs, executables: executables)
            guard let pid else { return nil }
            let name: String = {
                if let exe = item.executablePath {
                    return URL(fileURLWithPath: exe).lastPathComponent
                }
                return item.label
            }()
            let canStop = item.isUser && item.plistPath.hasPrefix(agents)
            return BackgroundApp(
                identifier: item.label,
                name: name,
                kind: item.isUser ? .agent : .daemon,
                bundleIdentifier: nil,
                iconPath: item.executablePath ?? item.plistPath,
                detail: "PID \(pid)",
                pid: pid,
                isRunning: true,
                stopJobs: canStop ? [BackgroundStopJob(label: item.label, plistPath: item.plistPath)] : []
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func launchLabel(from identifier: String) -> String? {
        let parts = identifier.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let code = Int(parts[0]), code == 8 || code == 16 else { return nil }
        return String(parts[1])
    }

    // MARK: - Parse

    private static func parseItem(_ chunk: String, uid: UInt32, home: String) -> Item? {
        let fields = fieldMap(chunk)
        let name = cleaned(fields["Name"])
        let identifier = cleaned(fields["Identifier"])
        guard let name, let identifier, !name.isEmpty, !identifier.isEmpty else { return nil }
        let typeRaw = cleaned(fields["Type"]) ?? ""
        let kind = kind(from: typeRaw)
        if kind == .other && typeRaw.isEmpty { return nil }
        let url = rewritePath(cleaned(fields["URL"]), uid: uid, home: home)
        let executable = rewritePath(cleaned(fields["Executable Path"]), uid: uid, home: home)
        return Item(
            name: name,
            identifier: identifier,
            typeRaw: typeRaw,
            kind: kind,
            url: url,
            executablePath: executable,
            bundleIdentifier: cleaned(fields["Bundle Identifier"]),
            parentIdentifier: cleaned(fields["Parent Identifier"]),
            lastUse: parseDate(cleaned(fields["Last Use"])),
            embeddedIdentifiers: embeddedIdentifiers(chunk),
            launchLabel: launchLabel(from: identifier)
        )
    }

    private static func fieldMap(_ chunk: String) -> [String: String] {
        var fields: [String: String] = [:]
        for line in chunk.split(separator: "\n", omittingEmptySubsequences: false) {
            let raw = String(line)
            guard let colon = raw.firstIndex(of: ":") else { continue }
            let key = raw[..<colon].trimmingCharacters(in: .whitespaces)
            let value = raw[raw.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, key.count < 40, !key.hasPrefix("#") else { continue }
            if fields[key] == nil { fields[key] = value }
        }
        return fields
    }

    private static func embeddedIdentifiers(_ chunk: String) -> [String] {
        chunk.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#"), let colon = trimmed.firstIndex(of: ":") else { return nil }
            let value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
    }

    private static func kind(from raw: String) -> BackgroundActivityKind {
        let value = raw.lowercased()
        if value.contains("background task") { return .backgroundTasks }
        if value.contains("developer") { return .developer }
        if value.contains("daemon") { return .daemon }
        if value.contains("agent") { return .agent }
        if value.contains("app") { return .app }
        return .other
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "(null)" { return nil }
        return trimmed
    }

    private static func rewritePath(_ path: String?, uid: UInt32?, home: String) -> String? {
        guard var path else { return nil }
        if let uid {
            let prefix = "/Users/\(uid)"
            if path.hasPrefix(prefix) {
                path = home + path.dropFirst(prefix.count)
            }
        }
        return path
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let posix = DateFormatter()
        posix.locale = Locale(identifier: "en_US_POSIX")
        posix.dateFormat = "yyyy-MM-dd HH:mm:ssxxxx"
        if let date = posix.date(from: value) { return date }
        posix.dateFormat = "yyyy-MM-dd HH:mm:ssZZZZZ"
        if let date = posix.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value.replacingOccurrences(of: " ", with: "T"))
    }

    // MARK: - Running / stop

    private static func liveness(
        _ item: Item,
        launchJobs: [String: Int32],
        executables: [String: Int32],
        runningBundles: Set<String>,
        parentRunning: Bool,
        now: Date
    ) -> (running: Bool, pid: Int32?) {
        if let exe = item.executablePath, isPlaceholderExecutable(exe) {
            return (false, nil)
        }
        if let label = item.launchLabel, let pid = launchJobs[label], pid > 0 {
            return (true, pid)
        }
        if let exe = item.executablePath {
            let key = (exe as NSString).standardizingPath
            let base = (key as NSString).lastPathComponent
            if let pid = executables[key] ?? executables[exe] ?? executables[base] {
                return (true, pid)
            }
        }
        if item.kind == .backgroundTasks, let lastUse = item.lastUse {
            let age = now.timeIntervalSince(lastUse)
            if age >= 0 && age < 120 { return (true, nil) }
            if age >= 0 && age < 900 && parentRunning { return (true, nil) }
        }
        if item.kind == .app, let bundle = item.bundleIdentifier, runningBundles.contains(bundle) {
            return (false, nil)
        }
        _ = runningBundles
        return (false, nil)
    }

    private static func parentAppRunning(
        _ root: Item,
        runningBundles: Set<String>,
        executables: [String: Int32]
    ) -> Bool {
        if let bundle = root.bundleIdentifier, runningBundles.contains(bundle) { return true }
        if let url = root.url, url.hasSuffix(".app"), executables[(url as NSString).standardizingPath] != nil {
            return true
        }
        return false
    }

    private static func stopJob(for item: Item, home: String) -> BackgroundStopJob? {
        guard let label = item.launchLabel, let plist = item.url else { return nil }
        let agents = (home as NSString).appendingPathComponent("Library/LaunchAgents")
        guard plist.hasPrefix(agents), plist.hasSuffix(".plist") else { return nil }
        if isPlaceholderExecutable(item.executablePath ?? "") { return nil }
        return BackgroundStopJob(label: label, plistPath: plist)
    }

    private static func uniqueJobs(_ jobs: [BackgroundStopJob]) -> [BackgroundStopJob] {
        var seen = Set<String>()
        return jobs.filter { seen.insert($0.label).inserted }
    }

    private static func isOwn(_ item: Item, ownBundleIdentifier: String?, ownApplicationPath: String?) -> Bool {
        if let ownBundleIdentifier {
            if item.bundleIdentifier == ownBundleIdentifier { return true }
            if item.identifier.contains(ownBundleIdentifier) { return true }
        }
        if let ownApplicationPath {
            if item.url == ownApplicationPath || item.executablePath == ownApplicationPath { return true }
            if item.url?.hasPrefix(ownApplicationPath) == true { return true }
        }
        return false
    }

    private static func livePID(
        _ item: LaunchPlist,
        launchJobs: [String: Int32],
        executables: [String: Int32]
    ) -> Int32? {
        if let pid = launchJobs[item.label], pid > 0 { return pid }
        guard let exe = item.executablePath else { return nil }
        let key = (exe as NSString).standardizingPath
        let base = (key as NSString).lastPathComponent
        return executables[key] ?? executables[exe] ?? executables[base]
    }

    private static func isOwnPlist(
        _ item: LaunchPlist,
        ownBundleIdentifier: String?,
        ownApplicationPath: String?
    ) -> Bool {
        if let ownBundleIdentifier, item.label.contains(ownBundleIdentifier) { return true }
        if let ownApplicationPath, item.executablePath == ownApplicationPath { return true }
        if let ownApplicationPath, item.executablePath?.hasPrefix(ownApplicationPath) == true { return true }
        return false
    }

    private static func isPlaceholderExecutable(_ path: String) -> Bool {
        path == "/usr/bin/true" || path == "/bin/true" || path == "/usr/bin/false"
    }

    private static func kindLabel(_ kind: BackgroundActivityKind) -> String {
        switch kind {
        case .app, .developer: "App"
        case .agent: "Agent"
        case .daemon: "Daemon"
        case .backgroundTasks: "Background tasks"
        case .other: "Background"
        }
    }
}
