import Foundation

/// Falls back Fajr/Isha to a fraction of the night when the astronomical hour-angle formula
/// has no solution — which happens for part of the year at latitudes far enough from the
/// equator that the sun never reaches the method's required angle below the horizon.
///
/// `hours` and the return value are hour-of-day `Double`s that may already be timezone-corrected
/// (this type only reasons about relative differences, so it doesn't matter which frame they're
/// in as long as `.sunrise` and `.maghrib` are in the same frame as `.fajr`/`.isha`).
enum HighLatitudeAdjuster {

    static func adjust(
        hours: [Prayer: Double],
        rule: HighLatitudeRule,
        fajrAngle: Double,
        ishaAngle: Double
    ) -> [Prayer: Double] {
        guard let sunrise = hours[.sunrise], let sunset = hours[.maghrib] else {
            return hours
        }
        var result = hours
        let night = nightLength(sunrise: sunrise, sunset: sunset)

        if let fajr = hours[.fajr] {
            let portion = nightPortion(angle: fajrAngle, night: night, rule: rule)
            if fajr.isNaN || (sunrise - fajr) > portion {
                result[.fajr] = sunrise - portion
            }
        }
        if let isha = hours[.isha] {
            let portion = nightPortion(angle: ishaAngle, night: night, rule: rule)
            if isha.isNaN || (isha - sunset) > portion {
                result[.isha] = sunset + portion
            }
        }
        return result
    }

    /// Length of the night in hours, handling the case where `sunset`'s hour-of-day is
    /// numerically smaller than `sunrise`'s (i.e. sunset rolled into the "next day" frame).
    private static func nightLength(sunrise: Double, sunset: Double) -> Double {
        var diff = sunrise - sunset
        if diff < 0 { diff += 24 }
        return diff
    }

    private static func nightPortion(angle: Double, night: Double, rule: HighLatitudeRule) -> Double {
        let fraction: Double
        switch rule {
        case .middleOfTheNight: fraction = 1.0 / 2.0
        case .seventhOfTheNight: fraction = 1.0 / 7.0
        case .twilightAngle: fraction = angle / 60.0
        }
        return fraction * night
    }
}
