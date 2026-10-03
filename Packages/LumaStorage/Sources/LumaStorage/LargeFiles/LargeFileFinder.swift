import Foundation
import LumaCore
import LumaSupport

public struct LargeFileHit: Sendable, Equatable, Identifiable {
    public var id: String { path }
    public var path: String
    public var name: String
    public var byteCount: UInt64

    public init(path: String, name: String, byteCount: UInt64) {
        self.path = path
        self.name = name
        self.byteCount = byteCount
    }
}

public enum LargeFileThreshold: UInt64, Sendable, CaseIterable, Identifiable {
    case mb100 = 104_857_600
    case mb500 = 524_288_000
    case gb1 = 1_073_741_824
    case gb5 = 5_368_709_120

    public var id: UInt64 { rawValue }

    public var title: String {
        switch self {
        case .mb100: LumaL10n.string("> 100 MB")
        case .mb500: LumaL10n.string("> 500 MB")
        case .gb1: LumaL10n.string("> 1 GB")
        case .gb5: LumaL10n.string("> 5 GB")
        }
    }

    /// Whole mebibytes for preset values (for syncing the custom field).
    public var mebibytes: Int {
        Int(rawValue / (1024 * 1024))
    }
}

public struct LargeFileScanProgress: Sendable, Equatable {
    public var label: String
    public var filesExamined: Int
    public var previewHits: [LargeFileHit]
    /// 0...1 overall scan progress (by roots; soft estimate within a root).
    public var fractionComplete: Double

    public init(
        label: String,
        filesExamined: Int,
        previewHits: [LargeFileHit],
        fractionComplete: Double
    ) {
        self.label = label
        self.filesExamined = filesExamined
        self.previewHits = previewHits
        self.fractionComplete = min(max(fractionComplete, 0), 1)
    }
}

public struct LargeFileScanResult: Sendable, Equatable {
    public var hits: [LargeFileHit]
    public var filesExamined: Int
    public var roots: [String]

    public init(hits: [LargeFileHit], filesExamined: Int, roots: [String]) {
        self.hits = hits
        self.filesExamined = filesExamined
        self.roots = roots
    }
}

public actor LargeFileFinder {
    public init() {}

    public func find(
        in roots: [URL],
        minBytes: UInt64,
        limit: Int = 200,
        progress: (@Sendable (LargeFileScanProgress) -> Void)? = nil
    ) async throws -> LargeFileScanResult {
        try await Task(priority: .utility) {
            try Self.findSync(roots: roots, minBytes: minBytes, limit: limit, progress: progress)
        }.value
    }

    /// Preset convenience.
    public func find(
        in roots: [URL],
        threshold: LargeFileThreshold,
        limit: Int = 200,
        progress: (@Sendable (LargeFileScanProgress) -> Void)? = nil
    ) async throws -> LargeFileScanResult {
        try await find(in: roots, minBytes: threshold.rawValue, limit: limit, progress: progress)
    }

    nonisolated private static func findSync(
        roots: [URL],
        minBytes: UInt64,
        limit: Int,
        progress: (@Sendable (LargeFileScanProgress) -> Void)?
    ) throws -> LargeFileScanResult {
        var hits: [LargeFileHit] = []
        var filesExamined = 0
        let fm = FileManager.default
        let thresholdBytes = max(minBytes, 1)
        var lastPublish = Date.distantPast
        let rootCount = max(roots.count, 1)
        var fraction = 0.0

        func publish(_ label: String, force: Bool = false) {
            guard let progress else { return }
            let now = Date()
            guard force || now.timeIntervalSince(lastPublish) >= 0.12 else { return }
            lastPublish = now
            let preview = Array(hits.sorted { $0.byteCount > $1.byteCount }.prefix(min(limit, 40)))
            progress(
                LargeFileScanProgress(
                    label: label,
                    filesExamined: filesExamined,
                    previewHits: preview,
                    fractionComplete: fraction
                )
            )
        }

        for (rootIndex, root) in roots.enumerated() {
            try Task.checkCancellation()
            let base = Double(rootIndex) / Double(rootCount)
            let span = 1.0 / Double(rootCount)
            fraction = base
            publish(LumaL10n.format("Scanning %@", root.lastPathComponent), force: true)
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
            while let next = enumerator.nextObject() as? URL {
                try Task.checkCancellation()

                if PathSafety.isDenied(next.path) {
                    enumerator.skipDescendants()
                    continue
                }

                let name = next.lastPathComponent.lowercased()
                if name == "node_modules" || name == ".git" || name == "pods"
                    || name == "deriveddata" || name == ".trash" {
                    enumerator.skipDescendants()
                    continue
                }

                do {
                    let values = try next.resourceValues(forKeys: [
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
                    // Soft within-root progress; unknown total file count.
                    let within = min(0.92, Double(rootFiles) / 80_000)
                    fraction = base + span * within

                    let size = UInt64(values.fileSize ?? 0)
                    if size >= thresholdBytes {
                        hits.append(
                            LargeFileHit(
                                path: next.path,
                                name: next.lastPathComponent,
                                byteCount: size
                            )
                        )
                        publish(
                            LumaL10n.format(
                                "%@ · %lld files · %lld matches",
                                root.lastPathComponent,
                                Int64(filesExamined),
                                Int64(hits.count)
                            ),
                            force: true
                        )
                        if hits.count >= limit * 3 { break }
                    } else if filesExamined % 150 == 0 {
                        publish(
                            LumaL10n.format(
                                "%@ · %lld files",
                                root.lastPathComponent,
                                Int64(filesExamined)
                            )
                        )
                    }
                } catch {
                    continue
                }
            }
            fraction = base + span
            publish(LumaL10n.format("Measured %@", root.lastPathComponent), force: true)
        }

        let finalHits = Array(hits.sorted { $0.byteCount > $1.byteCount }.prefix(limit))
        fraction = 1
        publish(LumaL10n.string("Finishing…"), force: true)
        return LargeFileScanResult(
            hits: finalHits,
            filesExamined: filesExamined,
            roots: roots.map(\.path)
        )
    }
}
