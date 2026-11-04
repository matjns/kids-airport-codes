import Foundation

public enum AirportCodesRelease {
    public static let appName = "Airport Codes"
    public static let bundleID = "com.kidscomputer.airportcodes"
    public static let supportFolder = "AirportCodes"
}

private struct Envelope: Codable {
    var version: Int
    var progress: AirportProgress
}

public struct ProgressStore {
    public var directory: URL
    public init(directory: URL) { self.directory = directory }
    public var fileURL: URL { directory.appendingPathComponent("progress.json") }

    public func load() -> AirportProgress {
        guard let data = try? Data(contentsOf: fileURL),
              let env = try? JSONDecoder().decode(Envelope.self, from: data) else { return .fresh }
        return env.progress
    }

    public func save(_ progress: AirportProgress) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Envelope(version: 1, progress: progress)).write(to: fileURL, options: .atomic)
    }
}
