import Foundation

/// A Hijri (Islamic lunar) calendar date. Deliberately a plain value type — not tied to
/// `Foundation.Calendar` or `DateComponents` — so it's cheap to construct in tests and to
/// embed in a reference-data table (see `VERIFICATION_NEEDED.md`).
public struct HijriDate: Codable, Sendable, Hashable {
    public var year: Int
    /// 1...12
    public var month: Int
    /// 1...30
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Localization key for the month name, resolved by the UI layer. Falls back to a
    /// generic "unknown month" key rather than crashing if `month` is somehow out of range.
    public var monthLocalizationKey: String {
        guard HijriDate.monthLocalizationKeys.indices.contains(month - 1) else {
            return "hijri.month.unknown"
        }
        return HijriDate.monthLocalizationKeys[month - 1]
    }

    static let monthLocalizationKeys = [
        "hijri.month.muharrem", "hijri.month.safer", "hijri.month.rebiulevvel",
        "hijri.month.rebiulahir", "hijri.month.cemaziyelevvel", "hijri.month.cemaziyelahir",
        "hijri.month.recep", "hijri.month.saban", "hijri.month.ramazan",
        "hijri.month.sevval", "hijri.month.zilkade", "hijri.month.zilhicce"
    ]
}
