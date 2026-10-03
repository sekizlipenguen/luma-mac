import Foundation
import LumaCore

/// Critical paths that must never be deleted by allowlisted cleaners.
public enum PathSafety {
    public static let denylistPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private/var/db",
        "/private/var/folders",
        "/Library/Apple",
        "/Library/Filesystems",
        "/Library/Frameworks",
        "/Library/Keychains"
    ]

    public static let denylistExactHomeSuffixes: [String] = [
        ".ssh",
        ".gnupg",
        "Library/Keychains",
        "Library/Mail",
        "Library/Messages",
        "Library/Cookies"
    ]

    /// System areas we never walk. Home Mail/Messages are still measurable — just not deletable.
    public static func blocksScan(_ path: String) -> Bool {
        let standardized = (path as NSString).standardizingPath
        for prefix in denylistPrefixes where standardized == prefix || standardized.hasPrefix(prefix + "/") {
            return true
        }
        return false
    }

    public static func isDenied(_ path: String, home: String = NSHomeDirectory()) -> Bool {
        let standardized = (path as NSString).standardizingPath
        if blocksScan(standardized) { return true }
        for suffix in denylistExactHomeSuffixes {
            let full = (home as NSString).appendingPathComponent(suffix)
            if standardized == full || standardized.hasPrefix(full + "/") {
                // Allow browser *Caches* under Library but not keychains/mail roots above.
                return true
            }
        }
        return false
    }

    public static func assertSafeForDeletion(_ path: String) throws {
        if isDenied(path) {
            throw LumaError.permissionDenied("Refusing to touch protected path: \(path)")
        }
    }
}

/// Directory size / listing helpers used by scanners and cleaners.
public enum FileIO {
    public static func directoryExists(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    public static func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public static func measureSize(at url: URL) throws -> UInt64 {
        var total: UInt64 = 0
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
            return UInt64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: []
        ) else {
            return 0
        }

        while let fileURL = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            do {
                let values = try fileURL.resourceValues(forKeys: [
                    .isRegularFileKey,
                    .totalFileAllocatedSizeKey,
                    .fileSizeKey
                ])
                if values.isRegularFile == true {
                    total += UInt64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                }
            } catch {
                // Skip unreadable entries (TCC / busy files) instead of failing the whole scan.
                continue
            }
        }
        return total
    }

    public static func listImmediateChildren(at url: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
    }

    /// Moves to Trash when possible; returns the resulting Trash URL if known.
    @MainActor
    public static func moveToTrash(_ url: URL) throws {
        try PathSafety.assertSafeForDeletion(url.path)
        var resulting: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
    }

    public static func removePermanently(_ url: URL) throws {
        try PathSafety.assertSafeForDeletion(url.path)
        try FileManager.default.removeItem(at: url)
    }
}
