import Foundation
import LumaSupport

struct InstalledProductVersion: Equatable, Sendable {
    var productKey: String
    var version: [Int]
}

/// Versioned support/cache/log folders left next to the copy an installed app still uses.
enum StaleAppVersionFinder {
    private struct ParsedName: Equatable {
        var productRaw: String
        var version: [Int]
    }

    static func productKey(from displayName: String) -> String {
        let base = parse(displayName)?.productRaw ?? displayName
        let filtered = base.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(filtered)).lowercased()
    }

    /// Sibling folder names that are safe to offer. The newest folder matching each installed version stays.
    /// When no installed app matches the product, every versioned folder is leftover.
    static func staleNames(folderNames: [String], installed: [InstalledProductVersion]) -> [String] {
        var groups: [String: [(name: String, version: [Int])]] = [:]
        for name in folderNames {
            guard let parsed = parse(name) else { continue }
            let key = productKey(from: parsed.productRaw)
            guard key.count >= 3 else { continue }
            groups[key, default: []].append((name, parsed.version))
        }

        var stale: [String] = []
        for (key, folders) in groups {
            let apps = installed.filter { $0.productKey == key && $0.version.isEmpty == false }
            if apps.isEmpty {
                stale.append(contentsOf: folders.map(\.name))
                continue
            }

            var keep = Set<String>()
            for app in apps {
                let compatible = folders.filter { versionsCompatible(folder: $0.version, installed: app.version) }
                if let best = compatible.max(by: { compareVersions($0.version, $1.version) == .orderedAscending }) {
                    keep.insert(best.name)
                }
            }
            if keep.isEmpty, let newest = folders.max(by: { compareVersions($0.version, $1.version) == .orderedAscending }) {
                keep.insert(newest.name)
            }
            stale.append(contentsOf: folders.filter { !keep.contains($0.name) }.map(\.name))
        }
        return stale.sorted()
    }

    static func staleFolderURLs(
        home: URL = URL(fileURLWithPath: NSHomeDirectory()),
        installed: [InstalledProductVersion]? = nil
    ) -> [URL] {
        let known = installed ?? installedProducts(home: home)
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let roots = ["Application Support", "Caches", "Logs"].map {
            library.appendingPathComponent($0, isDirectory: true)
        }
        let skip: Set<String> = [
            "chrome", "chromium", "google chrome", "firefox", "safari", "googleupdater",
            "steam", "discord", "slack", "spotify", "code", "cursor", "containers",
            "group containers", "mail", "messages", "cookies", "keychains", "toolbox",
            "node_modules", "pods", "carthage"
        ]
        let fm = FileManager.default
        var urls: [URL] = []
        for root in roots where FileIO.directoryExists(root) {
            var parents = [root]
            if let children = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for child in children where isDirectory(child) && !skip.contains(child.lastPathComponent.lowercased()) {
                    parents.append(child)
                }
            }
            for parent in parents {
                guard let children = try? fm.contentsOfDirectory(
                    at: parent,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }
                let dirs = children.filter(isDirectory)
                let stale = Set(staleNames(folderNames: dirs.map(\.lastPathComponent), installed: known))
                for dir in dirs where stale.contains(dir.lastPathComponent) && !PathSafety.isDenied(dir.path) {
                    urls.append(dir)
                }
            }
        }
        return urls.sorted { $0.path < $1.path }
    }

    static func installedProducts(home: URL = URL(fileURLWithPath: NSHomeDirectory())) -> [InstalledProductVersion] {
        let roots: [(URL, Int)] = [
            (URL(fileURLWithPath: "/Applications", isDirectory: true), 2),
            (URL(fileURLWithPath: "/System/Applications", isDirectory: true), 2),
            (home.appendingPathComponent("Applications", isDirectory: true), 2),
            (home.appendingPathComponent("Library/Application Support/JetBrains/Toolbox/apps", isDirectory: true), 6)
        ]
        var found: [InstalledProductVersion] = []
        for (root, depth) in roots {
            for app in applicationBundles(in: root, maxDepth: depth) {
                found.append(contentsOf: products(in: app))
            }
        }
        return found
    }

    static func products(in app: URL) -> [InstalledProductVersion] {
        let plistURL = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [] }
        guard let versionString = plistString(dict, "CFBundleShortVersionString") ?? plistString(dict, "CFBundleVersion"),
              let version = parseVersion(versionString)
        else { return [] }

        var names = [app.deletingPathExtension().lastPathComponent]
        if let name = plistString(dict, "CFBundleName") { names.append(name) }
        if let name = plistString(dict, "CFBundleDisplayName") { names.append(name) }

        var seen = Set<String>()
        var result: [InstalledProductVersion] = []
        for name in names {
            let key = productKey(from: name)
            guard key.count >= 3, seen.insert(key).inserted else { continue }
            result.append(InstalledProductVersion(productKey: key, version: version))
        }
        return result
    }

    private static func parse(_ name: String) -> ParsedName? {
        parseSeparated(name) ?? parseCompact(name)
    }

    private static func parseSeparated(_ name: String) -> ParsedName? {
        guard let idx = name.lastIndex(where: { $0 == " " || $0 == "_" || $0 == "-" }) else { return nil }
        let product = name[..<idx].trimmingCharacters(in: .whitespacesAndNewlines)
        let versionRaw = name[name.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard product.count >= 2, product.contains(where: \.isLetter), let version = parseVersion(String(versionRaw)) else {
            return nil
        }
        return ParsedName(productRaw: String(product), version: version)
    }

    private static func parseCompact(_ name: String) -> ParsedName? {
        guard let firstDigit = name.firstIndex(where: \.isNumber), firstDigit > name.startIndex else { return nil }
        let before = name[name.index(before: firstDigit)]
        if before == " " || before == "_" || before == "-" { return nil }
        let product = name[..<firstDigit]
        guard product.count >= 2, product.allSatisfy({ $0.isLetter || $0.isNumber }), product.contains(where: \.isLetter) else {
            return nil
        }
        guard let version = parseVersion(String(name[firstDigit...])) else { return nil }
        return ParsedName(productRaw: String(product), version: version)
    }

    private static func parseVersion(_ raw: String) -> [Int]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.allSatisfy({ part in !part.isEmpty && part.allSatisfy(\.isNumber) }) else { return nil }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count, !numbers.isEmpty else { return nil }
        if numbers.count >= 2 { return numbers }
        if (1990...2100).contains(numbers[0]) { return numbers }
        return nil
    }

    private static func versionsCompatible(folder: [Int], installed: [Int]) -> Bool {
        guard !folder.isEmpty, !installed.isEmpty else { return false }
        return zip(folder, installed).allSatisfy { $0 == $1 }
    }

    private static func compareVersions(_ lhs: [Int], _ rhs: [Int]) -> ComparisonResult {
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left < right ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func applicationBundles(in root: URL, maxDepth: Int) -> [URL] {
        guard FileIO.directoryExists(root) else { return [] }
        var found: [URL] = []
        func walk(_ url: URL, depth: Int) {
            guard depth <= maxDepth else { return }
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { return }
            for child in children {
                if child.pathExtension == "app" {
                    found.append(child)
                    continue
                }
                if isDirectory(child) {
                    walk(child, depth: depth + 1)
                }
            }
        }
        walk(root, depth: 0)
        return found
    }

    private static func plistString(_ dict: [String: Any], _ key: String) -> String? {
        switch dict[key] {
        case let value as String:
            return value
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }
}
