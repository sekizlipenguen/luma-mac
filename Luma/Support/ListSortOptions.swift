import Foundation
import LumaCore
import LumaStorage

/// Size / name — Storage folders & Large Files.
enum SizeNameSort: String, CaseIterable, Identifiable {
    case size
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .size: LumaL10n.string("Size")
        case .name: LumaL10n.string("Name")
        }
    }

    func sortedHits(_ hits: [LargeFileHit]) -> [LargeFileHit] {
        switch self {
        case .size:
            hits.sorted {
                if $0.byteCount != $1.byteCount { return $0.byteCount > $1.byteCount }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .name:
            hits.sorted {
                let cmp = $0.name.localizedCaseInsensitiveCompare($1.name)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return $0.byteCount > $1.byteCount
            }
        }
    }

    func sortedFolders(_ folders: [StorageNode]) -> [StorageNode] {
        switch self {
        case .size:
            folders.sorted {
                if $0.byteCount != $1.byteCount { return $0.byteCount > $1.byteCount }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .name:
            folders.sorted {
                let cmp = $0.name.localizedCaseInsensitiveCompare($1.name)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return $0.byteCount > $1.byteCount
            }
        }
    }

    /// Finder-like: folders first, then files; each group uses size/name sort.
    func sortedBrowserItems(_ items: [StorageNode]) -> [StorageNode] {
        let folders = sortedFolders(items.filter(\.isDirectory))
        let files = sortedFolders(items.filter { !$0.isDirectory })
        return folders + files
    }
}

enum NetworkAppSort: String, CaseIterable, Identifiable {
    case connections
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connections: LumaL10n.string("Connections")
        case .name: LumaL10n.string("Name")
        }
    }

    func sorted(_ apps: [NetworkAppSummary]) -> [NetworkAppSummary] {
        switch self {
        case .connections:
            apps.sorted {
                if $0.connectionCount != $1.connectionCount {
                    return $0.connectionCount > $1.connectionCount
                }
                return $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending
            }
        case .name:
            apps.sorted {
                let cmp = $0.processName.localizedCaseInsensitiveCompare($1.processName)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return $0.connectionCount > $1.connectionCount
            }
        }
    }
}

enum NetworkConnectionSort: String, CaseIterable, Identifiable {
    case process
    case remote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .process: LumaL10n.string("Process")
        case .remote: LumaL10n.string("Remote")
        }
    }

    func sorted(_ connections: [NetworkConnection]) -> [NetworkConnection] {
        switch self {
        case .process:
            connections.sorted {
                let cmp = $0.processName.localizedCaseInsensitiveCompare($1.processName)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return $0.remoteEndpoint.localizedCaseInsensitiveCompare($1.remoteEndpoint) == .orderedAscending
            }
        case .remote:
            connections.sorted {
                let cmp = $0.remoteEndpoint.localizedCaseInsensitiveCompare($1.remoteEndpoint)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending
            }
        }
    }
}
