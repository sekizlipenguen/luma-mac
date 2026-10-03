import Darwin
import Foundation
import LumaCore

/// Volume capacity via FileManager / URL resource values.
/// Avoids `statfs` on every mounted volume (network mounts can hang indefinitely).
public struct DiskMetricsSampler: DiskMetricsProviding {
    public init() {}

    public func sampleVolumes() async throws -> [DiskVolumeMetrics] {
        try await Task.detached(priority: .utility) {
            Self.sampleVolumesSync()
        }.value
    }

    /// Fast path used by the dashboard — root volume only, never walks network mounts.
    public func sampleRootVolume() async -> DiskVolumeMetrics? {
        await Task.detached(priority: .utility) {
            Self.rootVolumeSync()
        }.value
    }

    private static func sampleVolumesSync() -> [DiskVolumeMetrics] {
        // Prefer root first so dashboard always has something useful.
        var result: [DiskVolumeMetrics] = []
        if let root = rootVolumeSync() {
            result.append(root)
        }

        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeIsRootFileSystemKey,
            .volumeIsLocalKey,
            .volumeIsBrowsableKey
        ]
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []

        for url in urls {
            // Skip network / non-local volumes — resourceValues/statfs can block for a long time.
            let values = try? url.resourceValues(forKeys: keys)
            if values?.volumeIsLocal == false { continue }
            if values?.volumeIsRootFileSystem == true { continue } // already added
            let total = UInt64(values?.volumeTotalCapacity ?? 0)
            let freeImportant = values?.volumeAvailableCapacityForImportantUsage.map { UInt64($0) }
            let free = freeImportant ?? UInt64(values?.volumeAvailableCapacity ?? 0)
            guard total > 0 else { continue }
            result.append(
                DiskVolumeMetrics(
                    path: url.path,
                    name: values?.volumeName ?? url.lastPathComponent,
                    totalBytes: total,
                    freeBytes: free,
                    fileSystem: "local"
                )
            )
        }
        return result.sorted { $0.path < $1.path }
    }

    private static func rootVolumeSync() -> DiskVolumeMetrics? {
        let url = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        let total = UInt64(values.volumeTotalCapacity ?? 0)
        let freeImportant = values.volumeAvailableCapacityForImportantUsage.map { UInt64($0) }
        let free = freeImportant ?? UInt64(values.volumeAvailableCapacity ?? 0)
        guard total > 0 else { return nil }
        return DiskVolumeMetrics(
            path: "/",
            name: values.volumeName ?? "Macintosh HD",
            totalBytes: total,
            freeBytes: free,
            fileSystem: "APFS"
        )
    }
}
