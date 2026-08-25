import Foundation

/// A small, self-contained snapshot of "what to show right now" — written by the main app
/// whenever it recomputes prayer times, and read by the widget extension (small, medium, and
/// Lock Screen widgets), which never touch SwiftData or CoreLocation directly.
public struct PrayerTimesSnapshot: Codable, Sendable {
    public var generatedAt: Date
    public var locationDisplayName: String
    public var today: DailyPrayerTimes
    public var tomorrow: DailyPrayerTimes

    public init(generatedAt: Date, locationDisplayName: String, today: DailyPrayerTimes, tomorrow: DailyPrayerTimes) {
        self.generatedAt = generatedAt
        self.locationDisplayName = locationDisplayName
        self.today = today
        self.tomorrow = tomorrow
    }
}

/// App Group identifiers shared between the app target, the widget extension, and the
/// notification-scheduling code. Centralized here so a bundle ID change only happens in one place.
public enum AppGroup {
    /// Must match the "App Groups" capability enabled on both the app and widget extension
    /// targets in Xcode, and registered on the App ID in the Apple Developer portal.
    public static let identifier = "group.com.keremsayar.namaz"

    public static let snapshotFileName = "prayer_times_snapshot.json"

    /// `nil` if the App Group entitlement isn't configured yet (e.g. before that Xcode
    /// capability is turned on) — callers must handle this, never force-unwrap it.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

public enum SnapshotStoreError: Error {
    case containerUnavailable
}

public enum PrayerTimesSnapshotStore {
    public static func write(_ snapshot: PrayerTimesSnapshot) throws {
        guard let container = AppGroup.containerURL else {
            throw SnapshotStoreError.containerUnavailable
        }
        let url = container.appendingPathComponent(AppGroup.snapshotFileName)
        let data = try JSONEncoder.prayerKit.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public static func read() throws -> PrayerTimesSnapshot {
        guard let container = AppGroup.containerURL else {
            throw SnapshotStoreError.containerUnavailable
        }
        let url = container.appendingPathComponent(AppGroup.snapshotFileName)
        let data = try Data(contentsOf: url)
        return try JSONDecoder.prayerKit.decode(PrayerTimesSnapshot.self, from: data)
    }
}

extension JSONEncoder {
    static var prayerKit: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var prayerKit: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
