import Foundation
import LumaCore

/// Best-effort disk health using `diskutil info` parse + volume filesystem metadata.
/// SMART / wear / temperature are reported only when present in tool output — never invented.
public struct DiskHealthSampler: DiskHealthProviding {
    public init() {}

    public func sample(volumePath: String) async throws -> DiskHealthMetrics {
        try await Task.detached(priority: .utility) {
            try Self.sampleSync(volumePath: volumePath)
        }.value
    }

    private static func sampleSync(volumePath: String) throws -> DiskHealthMetrics {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", volumePath]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return DiskHealthMetrics(
                volumePath: volumePath,
                fileSystem: "Unknown",
                available: false,
                unavailableReason: "Unable to run diskutil: \(error.localizedDescription)",
                sourceDescription: "diskutil unavailable"
            )
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let map = parseDiskutil(output)

        let fs = map["Type (Bundle)"] ?? map["File System Personality"] ?? "Unknown"
        let smart = map["SMART Status"]
        let medium = map["Solid State"] == "Yes" ? "SSD" : (map["Solid State"] == "No" ? "HDD" : map["Protocol"])

        let hasAny = smart != nil || medium != nil || fs != "Unknown"
        return DiskHealthMetrics(
            volumePath: volumePath,
            fileSystem: fs,
            smartStatus: smart,
            mediumType: medium,
            temperatureCelsius: nil, // Not exposed reliably via diskutil on Apple Silicon
            wearLevelPercent: nil,
            available: hasAny,
            unavailableReason: hasAny
                ? nil
                : "Limited SMART/temperature data on this Mac. Values shown only when reported by diskutil.",
            sourceDescription: "Parsed from `/usr/sbin/diskutil info` (no invented sensors)."
        )
    }

    private static func parseDiskutil(_ output: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else { continue }
            result[parts[0]] = parts[1]
        }
        return result
    }
}
