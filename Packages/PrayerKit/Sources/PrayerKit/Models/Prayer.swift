import Foundation

/// The six daily time markers shown in the app, in chronological order. `sunrise` is a
/// boundary marker (used to bound the Fajr window and for Hanafi Asr-adjacent context),
/// not a prayer the user performs — see `isPerformablePrayer`.
public enum Prayer: Int, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case fajr = 0       // İmsak
    case sunrise = 1    // Güneş
    case dhuhr = 2      // Öğle
    case asr = 3        // İkindi
    case maghrib = 4    // Akşam
    case isha = 5       // Yatsı

    public var id: Int { rawValue }

    /// Localization key resolved against `Localizable.xcstrings` by the UI layer.
    /// PrayerKit never contains display strings itself.
    public var localizationKey: String {
        switch self {
        case .fajr: return "prayer.fajr"
        case .sunrise: return "prayer.sunrise"
        case .dhuhr: return "prayer.dhuhr"
        case .asr: return "prayer.asr"
        case .maghrib: return "prayer.maghrib"
        case .isha: return "prayer.isha"
        }
    }

    /// SF Symbol name suggestion for the UI layer — sunrise/sunset motifs, never a crescent
    /// or mosque icon (keeps the app's iconography restrained, per the design direction).
    public var systemImageName: String {
        switch self {
        case .fajr: return "moon.stars"
        case .sunrise: return "sunrise"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.min"
        case .maghrib: return "sunset"
        case .isha: return "moon"
        }
    }

    /// `sunrise` is a boundary marker, not a prayer — notification scheduling and the
    /// "next prayer" countdown both skip it.
    public var isPerformablePrayer: Bool { self != .sunrise }
}
