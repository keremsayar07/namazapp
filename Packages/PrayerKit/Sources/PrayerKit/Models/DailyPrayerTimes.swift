import Foundation

/// One calendar day's full schedule — the core unit the Home screen, Calendar screen, and
/// widgets all render.
public struct DailyPrayerTimes: Codable, Sendable, Hashable {
    /// The calendar day this schedule belongs to, in `coordinate.timeZone` (not necessarily
    /// midnight UTC — do not use this for arithmetic, only for identifying "which day").
    public var gregorianDate: Date
    public var coordinate: Coordinate
    /// Always 6 entries, one per `Prayer.allCases`, in that order.
    public var times: [PrayerTime]
    /// `nil` only if Hijri conversion failed outright (never expected in practice — both
    /// converters in `Hijri/` are total functions with a safe fallback).
    public var hijriDate: HijriDate?

    public init(gregorianDate: Date, coordinate: Coordinate, times: [PrayerTime], hijriDate: HijriDate?) {
        self.gregorianDate = gregorianDate
        self.coordinate = coordinate
        self.times = times
        self.hijriDate = hijriDate
    }

    public func time(for prayer: Prayer) -> Date? {
        times.first { $0.prayer == prayer }?.date
    }

    /// The next upcoming performable prayer relative to `now`, or `nil` if every prayer in
    /// this schedule has already passed (the repository is responsible for rolling over to
    /// the next day's `DailyPrayerTimes` in that case — this type never looks past itself).
    public func nextPrayer(after now: Date) -> PrayerTime? {
        times
            .filter { $0.prayer.isPerformablePrayer && $0.date > now }
            .min { $0.date < $1.date }
    }

    /// Prayers whose time has already passed relative to `now` — used by the Home screen to
    /// render completed rows as visually faded.
    public func pastPrayers(relativeTo now: Date) -> Set<Prayer> {
        Set(times.filter { $0.date <= now }.map(\.prayer))
    }
}
