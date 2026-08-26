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
    /// Extra minutes added after the astronomically computed sunset for Maghrib, for methods
    /// that define Maghrib as a fixed interval rather than sunset itself. Not the same thing
    /// as `temkinMinutes` below — this one changes what Maghrib *means*.
    public var maghribOffsetMinutes: Double
    /// Per-prayer safety margin ("temkin") in minutes, added after the astronomical
    /// calculation. This is not a fudge factor: authorities publish times that deliberately
    /// differ from the pure astronomical instant, and reproducing an authority's calendar
    /// means reproducing its margins. Positive = later, negative = earlier.
    ///
    /// Only `.turkey` sets these today, and its values were **measured**, not guessed — see
    /// `Reference/diyanet/calibration-report.md`.
    public var temkinMinutes: [Prayer: Double]

    public init(
        fajrAngle: Double,
        ishaAngle: Double?,
        ishaIntervalMinutes: Double? = nil,
        maghribOffsetMinutes: Double = 0,
        temkinMinutes: [Prayer: Double] = [:]
    ) {
        self.fajrAngle = fajrAngle
        self.ishaAngle = ishaAngle
        self.ishaIntervalMinutes = ishaIntervalMinutes
        self.maghribOffsetMinutes = maghribOffsetMinutes
        self.temkinMinutes = temkinMinutes
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
            // Diyanet İşleri Başkanlığı. Açılar (İmsak 18°, Yatsı 17°) yayımlanmış değerler;
            // temkin payları ise TAHMİN DEĞİL, ÖLÇÜM: 12 ilde 384 günlük resmi Diyanet
            // verisiyle karşılaştırılarak bulundu (Reference/diyanet/calibration-report.md).
            //
            // Her vakit için farkın standart sapması 0.3 dakika civarında çıktı — yani bunlar
            // rastgele sapmalar değil, sabit ve sistematik paylar; sabit offset olarak
            // kodlanmaları doğru. Ölçüm bir aylık veriye (19.08–19.09.2026) dayanıyor;
            // aylık toplama sürdükçe mevsimsel doğrulama da birikiyor.
            return CalculationParameters(
                fajrAngle: 18,
                ishaAngle: 17,
                temkinMinutes: [
                    .fajr: -0.4,     // ölçülen ortalama fark
                    .sunrise: -7.3,  // Diyanet güneşi ~7 dk erken yayımlıyor
                    .dhuhr: 5.0,
                    .asr: 4.4,
                    .maghrib: 8.0,
                    .isha: 1.3
                ]
            )
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
