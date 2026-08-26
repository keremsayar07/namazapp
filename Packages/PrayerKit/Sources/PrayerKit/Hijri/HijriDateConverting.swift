import Foundation

/// A single Gregorian calendar day, used as a lookup key for Diyanet override data. Deliberately
/// not `Date` — a `Date` carries a time-of-day and is awkward to use as a stable dictionary key
/// across time zones; a Gregorian (year, month, day) triple is unambiguous.
public struct GregorianDay: Hashable, Sendable, Comparable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Chronological order, so a covered date window can be expressed as a plain range.
    /// Compared field by field rather than via a numeric key, which keeps it correct for
    /// negative (BCE) years too — costs nothing and removes a whole class of surprise.
    public static func < (lhs: GregorianDay, rhs: GregorianDay) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    /// `"2026-09-12"` — used in generated source and reports, so both read as dates rather
    /// than as three loose integers.
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
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
/// `overrides` defaults to `DiyanetHijriOverrides.table`, which is **generated** from the
/// Diyanet mirror archive by `prayerkit-hijri-table` — never hand-written, never estimated.
/// It contains only the days where Diyanet actually diverges from Umm al-Qura; everywhere
/// else the base converter is already right. With an empty table this behaves identically to
/// `base`, so it is safe at every stage of that data accumulating.
///
/// **Coverage is finite.** The archive spans a limited window, and outside it this converter
/// is an unverified estimate. `isVerified(_:)` reports which side of that line a date falls
/// on, so the UI can be honest about it rather than presenting a guess as an authority.
public struct DiyanetHijriDateConverter: HijriDateConverting {
    private let base: HijriDateConverting
    private let overrides: [GregorianDay: HijriDate]
    private let coverage: ClosedRange<GregorianDay>?
    private let calendar: Calendar

    public init(
        base: HijriDateConverting = UmmAlQuraHijriDateConverter(),
        overrides: [GregorianDay: HijriDate] = DiyanetHijriOverrides.table,
        coverage: ClosedRange<GregorianDay>? = DiyanetHijriOverrides.coverage
    ) {
        self.base = base
        self.overrides = overrides
        self.coverage = coverage
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        self.calendar = cal
    }

    public func hijriDate(from gregorian: Date) -> HijriDate {
        guard let key = gregorianDay(from: gregorian) else {
            return base.hijriDate(from: gregorian)
        }
        return overrides[key] ?? base.hijriDate(from: gregorian)
    }

    /// Whether this date falls inside the window the Diyanet archive actually covers.
    ///
    /// Outside it the returned Hijri date is still the best available answer, but it is Umm
    /// al-Qura's answer, not Diyanet's — and around a month boundary those can differ by a
    /// day. Anything that presents a Hijri date as authoritative (a Ramazan or bayram
    /// countdown, say) should check this first rather than imply a certainty we do not have.
    public func isVerified(_ gregorian: Date) -> Bool {
        guard let coverage, let day = gregorianDay(from: gregorian) else { return false }
        return coverage.contains(day)
    }

    private func gregorianDay(from date: Date) -> GregorianDay? {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return nil
        }
        return GregorianDay(year: year, month: month, day: day)
    }
}
