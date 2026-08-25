import Foundation
@testable import PrayerKit

enum TestCities {
    static let istanbul = Coordinate(latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul")
    static let ankara = Coordinate(latitude: 39.9334, longitude: 32.8597, timeZoneIdentifier: "Europe/Istanbul")
    static let gaziantep = Coordinate(latitude: 37.0662, longitude: 37.3833, timeZoneIdentifier: "Europe/Istanbul")
    /// Tromsø, Norway — well above the Arctic Circle, deliberately used to exercise the
    /// high-latitude fallback path (the sun doesn't set at all around the summer solstice).
    static let tromso = Coordinate(latitude: 69.6492, longitude: 18.9553, timeZoneIdentifier: "Europe/Oslo")
}

/// Builds a `Date` at 12:00 UTC for the given Gregorian day. Noon UTC is used specifically so
/// that extracting (year, month, day) via a UTC calendar — which is what
/// `PrayerCalculationService` and the Hijri converters do internally — can never disagree with
/// the (year, month, day) passed in here, regardless of the target location's own time zone.
func utcNoon(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = 12
    return calendar.date(from: comps)!
}
