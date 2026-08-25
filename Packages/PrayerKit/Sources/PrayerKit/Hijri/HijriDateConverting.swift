import Foundation

/// A single Gregorian calendar day, used as a lookup key for Diyanet override data. Deliberately
/// not `Date` — a `Date` carries a time-of-day and is awkward to use as a stable dictionary key
/// across time zones; a Gregorian (year, month, day) triple is unambiguous.
public struct GregorianDay: Hashable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

/// Converts a Gregorian date to a Hijri date. Implementations must be pure functions of their
/// input — no I/O, no shared mutable state — so results are deterministic and unit-testable,
/// per the product requirement that the Hijri calendar be "mümkün olduğunca deterministik ve
/// test edilebilir".
public protocol HijriDateConverting: Sendable {
    func hijriDate(from gregorian: Date) -> HijriDate
}

/// Foundation's built-in tabular Umm al-Qura calendar. Fully offline, deterministic, and
/// backed by Apple's own ICU data — no network access, no bundled tables to maintain.
///
/// This is accurate for the large majority of days, but Diyanet İşleri Başkanlığı's own
/// religious calendar can fall a day earlier or later than Umm al-Qura specifically around a
/// month boundary (the two authorities apply slightly different new-moon visibility
/// criteria). Use `DiyanetHijriDateConverter` when that distinction matters.
public struct UmmAlQuraHijriDateConverter: HijriDateConverting {
    public init() {}

    public func hijriDate(from gregorian: Date) -> HijriDate {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = calendar.dateComponents([.year, .month, .day], from: gregorian)
        return HijriDate(
            year: components.year ?? 0,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }
}

/// Wraps a base converter (Umm al-Qura by default) and overrides specific Gregorian days where
/// Diyanet's official calendar is known to diverge from it — in practice, this concentrates
/// around the first day of Ramazan, Şevval (Ramazan Bayramı), Zilhicce (Kurban Bayramı) and
/// Muharrem (Hicri Yılbaşı).
///
/// `overrides` ships empty until populated with verified dates from Diyanet's official
/// calendar — see `VERIFICATION_NEEDED.md`. With an empty table this behaves identically to
/// `base`, so it is always safe to use even before that data exists.
public struct DiyanetHijriDateConverter: HijriDateConverting {
    private let base: HijriDateConverting
    private let overrides: [GregorianDay: HijriDate]
    private let calendar: Calendar

    public init(base: HijriDateConverting = UmmAlQuraHijriDateConverter(), overrides: [GregorianDay: HijriDate] = [:]) {
        self.base = base
        self.overrides = overrides
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        self.calendar = cal
    }

    public func hijriDate(from gregorian: Date) -> HijriDate {
        let comps = calendar.dateComponents([.year, .month, .day], from: gregorian)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return base.hijriDate(from: gregorian)
        }
        let key = GregorianDay(year: year, month: month, day: day)
        return overrides[key] ?? base.hijriDate(from: gregorian)
    }
}
