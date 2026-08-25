import Foundation

/// The resolved astronomical parameters `PrayerCalculationService` actually reads.
/// `CalculationMethod` is the user-facing preset; this is what it expands to.
public struct CalculationParameters: Sendable, Hashable {
    /// Degrees below the horizon that defines Fajr (astronomical/nautical twilight start).
    public var fajrAngle: Double
    /// Degrees below the horizon that defines Isha — `nil` when Isha is instead a fixed
    /// number of minutes after Maghrib (e.g. Umm al-Qura).
    public var ishaAngle: Double?
    /// Minutes after Maghrib, used only when `ishaAngle` is `nil`.
    public var ishaIntervalMinutes: Double?
    /// Extra minutes added after the astronomically computed sunset for Maghrib — a fixed
    /// safety margin some authorities (Diyanet included) apply. Defaults to 0 until the
    /// exact figure is confirmed against verified reference data — see `VERIFICATION_NEEDED.md`.
    public var maghribOffsetMinutes: Double

    public init(
        fajrAngle: Double,
        ishaAngle: Double?,
        ishaIntervalMinutes: Double? = nil,
        maghribOffsetMinutes: Double = 0
    ) {
        self.fajrAngle = fajrAngle
        self.ishaAngle = ishaAngle
        self.ishaIntervalMinutes = ishaIntervalMinutes
        self.maghribOffsetMinutes = maghribOffsetMinutes
    }
}

/// A named calculation method preset, or a fully custom pair of angles. Every case (except
/// `.custom`) mirrors the parameters documented in adhan-swift's METHODS.md, which in turn
/// mirrors the values long published by PrayTimes.org — see `NOTICE.md`.
public enum CalculationMethod: Codable, Sendable, Hashable {
    case turkey
    case muslimWorldLeague
    case egyptian
    case karachi
    case ummAlQura
    case dubai
    case qatar
    case kuwait
    case moonsightingCommittee
    case singapore
    case tehran
    case northAmerica
    case custom(fajrAngle: Double, ishaAngle: Double)

    /// All fixed presets, in the order shown in the Settings picker. `.custom` is
    /// intentionally excluded — it's parameterized, not a preset the user just picks.
    public static let allPresets: [CalculationMethod] = [
        .turkey, .muslimWorldLeague, .egyptian, .karachi, .ummAlQura,
        .dubai, .qatar, .kuwait, .moonsightingCommittee, .singapore,
        .tehran, .northAmerica
    ]

    public var parameters: CalculationParameters {
        switch self {
        case .turkey:
            // Approximates Diyanet İşleri Başkanlığı. Angle values match adhan-swift's
            // "turkey" preset; the Maghrib safety-margin (temkin) figure is intentionally
            // left at 0 until we have verified reference data — see VERIFICATION_NEEDED.md.
            return CalculationParameters(fajrAngle: 18, ishaAngle: 17, maghribOffsetMinutes: 0)
        case .muslimWorldLeague:
            return CalculationParameters(fajrAngle: 18, ishaAngle: 17)
        case .egyptian:
            return CalculationParameters(fajrAngle: 19.5, ishaAngle: 17.5)
        case .karachi:
            return CalculationParameters(fajrAngle: 18, ishaAngle: 18)
        case .ummAlQura:
            return CalculationParameters(fajrAngle: 18.5, ishaAngle: nil, ishaIntervalMinutes: 90)
        case .dubai:
            return CalculationParameters(fajrAngle: 18.2, ishaAngle: 18.2)
        case .qatar:
            return CalculationParameters(fajrAngle: 18, ishaAngle: nil, ishaIntervalMinutes: 90)
        case .kuwait:
            return CalculationParameters(fajrAngle: 18, ishaAngle: 17.5)
        case .moonsightingCommittee:
            return CalculationParameters(fajrAngle: 18, ishaAngle: 18)
        case .singapore:
            return CalculationParameters(fajrAngle: 20, ishaAngle: 18)
        case .tehran:
            return CalculationParameters(fajrAngle: 17.7, ishaAngle: 14)
        case .northAmerica:
            return CalculationParameters(fajrAngle: 15, ishaAngle: 15)
        case .custom(let fajrAngle, let ishaAngle):
            return CalculationParameters(fajrAngle: fajrAngle, ishaAngle: ishaAngle)
        }
    }

    public var localizationKey: String {
        switch self {
        case .turkey: return "method.turkey"
        case .muslimWorldLeague: return "method.muslimWorldLeague"
        case .egyptian: return "method.egyptian"
        case .karachi: return "method.karachi"
        case .ummAlQura: return "method.ummAlQura"
        case .dubai: return "method.dubai"
        case .qatar: return "method.qatar"
        case .kuwait: return "method.kuwait"
        case .moonsightingCommittee: return "method.moonsightingCommittee"
        case .singapore: return "method.singapore"
        case .tehran: return "method.tehran"
        case .northAmerica: return "method.northAmerica"
        case .custom: return "method.custom"
        }
    }
}
