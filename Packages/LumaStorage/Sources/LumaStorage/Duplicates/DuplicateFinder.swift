import Foundation
import LumaCore
import LumaSupport

public struct DuplicateGroup: Sendable, Equatable, Identifiable {
    public var id: String { hashHex }
    public var hashHex: String
    public var byteCount: UInt64
    public var paths: [String]

    public init(hashHex: String, byteCount: UInt64, paths: [String]) {
        self.hashHex = hashHex
        self.byteCount = byteCount
        self.paths = paths
    }

    public var wastedBytes: UInt64 {
        guard paths.count > 1 else { return 0 }
        return byteCount * UInt64(paths.count - 1)
    }
}

public struct DuplicateScanResult: Sendable, Equatable {
    public var groups: [DuplicateGroup]
    public var filesExamined: Int
    public var filesAboveThreshold: Int
    public var sizeCollisionBuckets: Int
    public var roots: [String]

    public init(
        groups: [DuplicateGroup],
        filesExamined: Int,
        filesAboveThreshold: Int,
        sizeCollisionBuckets: Int,
        roots: [String]
    ) {
        self.groups = groups
        self.filesExamined = filesExamined
        self.filesAboveThreshold = filesAboveThreshold
        self.sizeCollisionBuckets = sizeCollisionBuckets
        self.roots = roots
    }
}

public struct DuplicateScanProgress: Sendable, Equatable {
    public var label: String
    public var filesExamined: Int
    public var previewGroups: [DuplicateGroup]
    /// 0...1 overall scan progress across index → partial → full hash.
    public var fractionComplete: Double

    public init(
        label: String,
        filesExamined: Int,
        previewGroups: [DuplicateGroup],
        fractionComplete: Double
    ) {
        self.label = label
        self.filesExamined = filesExamined
        self.previewGroups = previewGroups
        self.fractionComplete = min(max(fractionComplete, 0), 1)
    }
}

public enum DuplicateMinSize: UInt64, Sendable, CaseIterable, Identifiable {
    case kb100 = 102_400
    case mb1 = 1_048_576
    case mb10 = 10_485_760

    public var id: UInt64 { rawValue }

    public var title: String {
        switch self {
        case .kb100: LumaL10n.string("≥ 100 KB")
        case .mb1: LumaL10n.string("≥ 1 MB")
        case .mb10: LumaL10n.string("≥ 10 MB")
        }
    }

    public var mebibytes: Double {
        Double(rawValue) / (1024.0 * 1024.0)
    }
}

public enum DuplicateGroupSort: String, Sendable, CaseIterable, Identifiable {
    case reclaimable
    case fileCount
    case fileSize

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .reclaimable: LumaL10n.string("Reclaimable")
        case .fileCount: LumaL10n.string("File count")
        case .fileSize: LumaL10n.string("File size")
        }
    }

    public func sorted(_ groups: [DuplicateGroup]) -> [DuplicateGroup] {
        switch self {
        case .reclaimable:
            groups.sorted {
                if $0.wastedBytes != $1.wastedBytes { return $0.wastedBytes > $1.wastedBytes }
                return $0.paths.count > $1.paths.count
            }
        case .fileCount:
            groups.sorted {
                if $0.paths.count != $1.paths.count { return $0.paths.count > $1.paths.count }
                return $0.wastedBytes > $1.wastedBytes
            }
        case .fileSize:
            groups.sorted {
                if $0.byteCount != $1.byteCount { return $0.byteCount > $1.byteCount }
                return $0.wastedBytes > $1.wastedBytes
            }
        }
    }
}

/// Multi-stage duplicate finder: size → partial hash → full SHA-256.
public actor DuplicateFinder {
    public init() {}

    public func findDuplicates(
        in roots: [URL],
        minBytes: UInt64 = DuplicateMinSize.kb100.rawValue,
        progress: (@Sendable (DuplicateScanProgress) -> Void)? = nil
    ) async throws -> DuplicateScanResult {
        // Child `Task` inherits cancellation (unlike `Task.detached`).
        try await Task(priority: .utility) {
            try Self.findSync(roots: roots, minBytes: minBytes, progress: progress)
        }.value
    }

    nonisolated private static func findSync(
        roots: [URL],
        minBytes: UInt64,
        progress: (@Sendable (DuplicateScanProgress) -> Void)?
    ) throws -> DuplicateScanResult {
        let fm = FileManager.default
        var bySize: [UInt64: [URL]] = [:]
        var filesExamined = 0
        var filesAboveThreshold = 0
        var groups: [DuplicateGroup] = []
        var lastPublish = Date.distantPast
        var fraction = 0.0
        let rootCount = max(roots.count, 1)

        func publish(_ label: String, force: Bool = false) {
            guard let progress else { return }
            let now = Date()
            guard force || now.timeIntervalSince(lastPublish) >= 0.12 else { return }
            lastPublish = now
            let preview = Array(groups.sorted { $0.wastedBytes > $1.wastedBytes }.prefix(40))
            progress(
                DuplicateScanProgress(
                    label: label,
                    filesExamined: filesExamined,
                    previewGroups: preview,
                    fractionComplete: fraction
                )
            )
        }

        for (rootIndex, root) in roots.enumerated() {
            try Task.checkCancellation()
            let base = 0.45 * Double(rootIndex) / Double(rootCount)
            let span = 0.45 / Double(rootCount)
            fraction = base
            publish(LumaL10n.format("Indexing %@", root.lastPathComponent), force: true)
            guard fm.fileExists(atPath: root.path) else {
                fraction = base + span
                continue
            }
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .fileSizeKey,
                    .isSymbolicLinkKey,
                    .isDirectoryKey
                ],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                fraction = base + span
                continue
            }

            var rootFiles = 0
            while let fileURL = enumerator.nextObject() as? URL {
                try Task.checkCancellation()
                if PathSafety.isDenied(fileURL.path) {
                    enumerator.skipDescendants()
                    continue
                }

                let name = fileURL.lastPathComponent.lowercased()
                if name == "node_modules" || name == ".git" || name == "pods"
                    || name == "deriveddata" || name == ".trash" {
                    enumerator.skipDescendants()
                    continue
                }

                do {
                    let values = try fileURL.resourceValues(forKeys: [
                        .isRegularFileKey,
                        .fileSizeKey,
                        .isSymbolicLinkKey,
                        .isDirectoryKey
                    ])
                    if values.isSymbolicLink == true {
                        if values.isDirectory == true {
                            enumerator.skipDescendants()
                        }
                        continue
                    }
                    guard values.isRegularFile == true else { continue }
                    filesExamined += 1
                    rootFiles += 1
                    fraction = base + span * min(0.92, Double(rootFiles) / 80_000)
                    if filesExamined % 250 == 0 {
                        publish(LumaL10n.format("Indexed %lld files…", Int64(filesExamined)))
                    }
                    let size = UInt64(values.fileSize ?? 0)
                    guard size >= minBytes else { continue }
                    filesAboveThreshold += 1
                    bySize[size, default: []].append(fileURL)
                } catch {
                    continue
                }
            }
            fraction = base + span
        }

        let sizeCandidates = bySize.filter { $0.value.count > 1 }
        fraction = 0.45
        publish(LumaL10n.format("Checking %lld size groups…", Int64(sizeCandidates.count)), force: true)
        var byPartial: [String: [URL]] = [:]

        let partialTotal = max(sizeCandidates.values.reduce(0) { $0 + $1.count }, 1)
        var partialDone = 0
        for (size, urls) in sizeCandidates {
            try Task.checkCancellation()
            for url in urls {
                do {
                    let partial = try FileHasher.sha256(of: url, sampleFirstBytes: 4096)
                    let key = "\(size)-\(partial.map { String(format: "%02x", $0) }.joined())"
                    byPartial[key, default: []].append(url)
                    partialDone += 1
                    fraction = 0.45 + 0.30 * Double(partialDone) / Double(partialTotal)
                    if partialDone % 40 == 0 {
                        publish(LumaL10n.format("Partial hash %lld…", Int64(partialDone)))
                    }
                } catch {
                    continue
                }
            }
        }

        let partialCandidates = byPartial.filter { $0.value.count > 1 }
        let fullBuckets = max(partialCandidates.count, 1)
        fraction = 0.75
        publish(
            LumaL10n.format(
                "Full hash %lld candidates…",
                Int64(partialCandidates.values.reduce(0) { $0 + $1.count })
            ),
            force: true
        )
        var fullDone = 0
        for (_, urls) in partialCandidates {
            try Task.checkCancellation()
            var byFull: [String: [URL]] = [:]
            var size: UInt64 = 0
            for url in urls {
                do {
                    let hex = try FileHasher.sha256Hex(of: url)
                    byFull[hex, default: []].append(url)
                    if size == 0 {
                        size = UInt64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                    }
                } catch {
                    continue
                }
            }
            for (hex, matched) in byFull where matched.count > 1 {
                groups.append(
                    DuplicateGroup(
                        hashHex: hex,
                        byteCount: size,
                        paths: matched.map(\.path).sorted()
                    )
                )
            }
            fullDone += 1
            fraction = 0.75 + 0.25 * Double(fullDone) / Double(fullBuckets)
            publish(
                LumaL10n.format(
                    "%lld groups · %lld files",
                    Int64(groups.count),
                    Int64(filesExamined)
                ),
                force: true
            )
        }

        let sorted = groups.sorted { $0.wastedBytes > $1.wastedBytes }
        fraction = 1
        publish(LumaL10n.string("Finishing…"), force: true)
        return DuplicateScanResult(
            groups: sorted,
            filesExamined: filesExamined,
            filesAboveThreshold: filesAboveThreshold,
            sizeCollisionBuckets: sizeCandidates.count,
            roots: roots.map(\.path)
        )
    }
}
