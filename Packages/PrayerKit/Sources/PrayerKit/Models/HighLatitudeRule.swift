import Foundation

/// How Fajr/Isha are estimated at latitudes where the sun never reaches the required angle
/// below the horizon for part of the year (the astronomical hour-angle formula has no
/// solution there — see `PrayerCalculationService`).
public enum HighLatitudeRule: String, CaseIterable, Codable, Sendable, Hashable {
    /// Fajr/Isha fall no earlier/later than the midpoint of the night. The safe general default.
    case middleOfTheNight
    /// Fajr/Isha fall no earlier/later than one-seventh of the night — recommended above ~48°.
    case seventhOfTheNight
    /// Splits the night proportionally to the method's own Fajr/Isha angles.
    case twilightAngle

    public var localizationKey: String {
        switch self {
        case .middleOfTheNight: return "highLatitude.middleOfNight"
        case .seventhOfTheNight: return "highLatitude.seventhOfNight"
        case .twilightAngle: return "highLatitude.twilightAngle"
        }
    }

    /// A reasonable automatic starting point based on latitude magnitude — Settings always
    /// lets the user override this explicitly.
    public static func recommended(forLatitude latitude: Double) -> HighLatitudeRule {
        abs(latitude) >= 48 ? .seventhOfTheNight : .middleOfTheNight
    }
}
