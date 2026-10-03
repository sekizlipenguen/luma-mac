import Foundation
import LumaCore
import LumaSupport

public actor CleanupEngine: CleanupEngineProviding {
    public let rules: [any CleanupRule]
    private let history: OperationHistoryStore

    public init(rules: [any CleanupRule] = CleanupRuleCatalog.allRules(), history: OperationHistoryStore) {
        self.rules = rules
        self.history = history
    }

    public func estimate(ruleIDs: Set<String>) async throws -> [String: CleanupEstimate] {
        var result: [String: CleanupEstimate] = [:]
        for rule in rules where ruleIDs.contains(rule.id) {
            try Task.checkCancellation()
            result[rule.id] = try await rule.estimate()
        }
        return result
    }

    public func execute(ruleIDs: Set<String>, mode: CleanupExecutionMode) async throws -> [CleanupResult] {
        var results: [CleanupResult] = []
        for rule in rules where ruleIDs.contains(rule.id) {
            try Task.checkCancellation()
            let outcome = try await rule.execute(mode: mode)
            results.append(outcome)
            let entry = OperationLogEntry(
                ruleID: rule.id,
                ruleTitle: rule.title,
                mode: mode,
                estimatedBytes: outcome.estimatedBytes,
                recoveredBytes: outcome.recoveredBytes,
                paths: outcome.movedToTrash + outcome.deletedPaths,
                notes: outcome.failedPaths.isEmpty ? "" : "Failed: \(outcome.failedPaths.joined(separator: ", "))"
            )
            try await history.append(entry)
        }
        return results
    }
}

public actor OperationHistoryStore: OperationHistoryProviding {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func append(_ entry: OperationLogEntry) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        var line = data
        line.append(contentsOf: "\n".utf8)
        let file = directory.appendingPathComponent("operations.jsonl")
        if FileManager.default.fileExists(atPath: file.path) {
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } else {
            try line.write(to: file, options: .atomic)
        }
    }

    public func recent(limit: Int) async throws -> [OperationLogEntry] {
        let file = directory.appendingPathComponent("operations.jsonl")
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let text = try String(contentsOf: file, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var entries: [OperationLogEntry] = []
        for line in text.split(separator: "\n") where !line.isEmpty {
            if let data = line.data(using: .utf8),
               let entry = try? decoder.decode(OperationLogEntry.self, from: data) {
                entries.append(entry)
            }
        }
        return Array(entries.suffix(limit).reversed())
    }
}
