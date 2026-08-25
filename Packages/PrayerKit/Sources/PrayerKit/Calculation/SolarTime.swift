import Foundation

/// Apparent solar declination and the equation of time for a given instant — the two
/// quantities every prayer-time hour-angle formula is built from.
struct SolarPosition {
    /// Apparent solar declination, in degrees.
    let declination: Double
    /// Equation of time, in hours (how far apparent solar noon is from mean/clock noon).
    let equationOfTimeHours: Double
}

/// Low-precision solar position formulas, accurate to roughly a minute — the standard
/// approach used by prayer-time calculators. See `NOTICE.md` for algorithm provenance.
enum SolarTime {

    /// Julian Day Number at 0h UTC for a Gregorian calendar date. `day` may carry a fractional
    /// part (used elsewhere to shift by a longitude-based offset).
    static func julianDay(year: Int, month: Int, day: Double) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = floor(Double(y) / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * Double(y + 4716))
            + floor(30.6001 * Double(m + 1))
            + day + b - 1524.5
    }

    static func sunPosition(julianDay jd: Double) -> SolarPosition {
        let d = jd - 2451545.0
        let g = fixAngle(357.529 + 0.98560028 * d)
        let q = fixAngle(280.459 + 0.98564736 * d)
        let l = fixAngle(q + 1.915 * dsin(g) + 0.020 * dsin(2 * g))

        let e = 23.439 - 0.00000036 * d

        let declination = dasin(dsin(e) * dsin(l))
        let rightAscension = fixHour(datan2(dcos(e) * dsin(l), dcos(l)) / 15)

        let equationOfTime = q / 15 - rightAscension
        return SolarPosition(declination: declination, equationOfTimeHours: equationOfTime)
    }

    // MARK: - Degree-based trig helpers

    static func dsin(_ degrees: Double) -> Double { sin(degrees * .pi / 180) }
    static func dcos(_ degrees: Double) -> Double { cos(degrees * .pi / 180) }
    static func dtan(_ degrees: Double) -> Double { tan(degrees * .pi / 180) }
    static func dasin(_ x: Double) -> Double { asin(x) * 180 / .pi }
    static func dacos(_ x: Double) -> Double { acos(x) * 180 / .pi }
    static func datan2(_ y: Double, _ x: Double) -> Double { atan2(y, x) * 180 / .pi }
    /// Arccotangent, in degrees.
    static func dacot(_ x: Double) -> Double { atan(1 / x) * 180 / .pi }

    static func fixAngle(_ angle: Double) -> Double { fix(angle, 360) }
    static func fixHour(_ hour: Double) -> Double { fix(hour, 24) }

    private static func fix(_ value: Double, _ bound: Double) -> Double {
        var v = value.truncatingRemainder(dividingBy: bound)
        if v < 0 { v += bound }
        return v
    }
}
