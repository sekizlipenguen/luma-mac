import CryptoKit
import Foundation
import LumaCore

/// Streaming SHA-256 for duplicate detection.
public enum FileHasher {
    public static func sha256(of url: URL, sampleFirstBytes: Int? = nil) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        if let sampleFirstBytes {
            let data = try handle.read(upToCount: sampleFirstBytes) ?? Data()
            hasher.update(data: data)
            return Data(hasher.finalize())
        }

        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return Data(hasher.finalize())
    }

    public static func sha256Hex(of url: URL) throws -> String {
        try sha256(of: url).map { String(format: "%02x", $0) }.joined()
    }
}
