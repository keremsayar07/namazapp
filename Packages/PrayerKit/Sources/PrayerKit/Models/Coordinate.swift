import Foundation

/// A location expressed purely as numbers — deliberately independent of CoreLocation so the
/// calculation engine has zero dependency on system location services and is trivially
/// testable with literal values (see PrayerKitTests).
public struct Coordinate: Codable, Sendable, Hashable {
    public var latitude: Double
    public var longitude: Double
    /// IANA time zone identifier (e.g. "Europe/Istanbul"). Stored explicitly rather than
    /// derived, because deriving a time zone from lat/lon alone requires either a network
    /// lookup or a bundled geo-timezone database — neither of which this package depends on.
    public var timeZoneIdentifier: String

    public init(latitude: Double, longitude: Double, timeZoneIdentifier: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// Falls back to the device's current time zone if `timeZoneIdentifier` is somehow
    /// invalid — never crashes, per the app's error-handling policy.
    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
}
