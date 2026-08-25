import Foundation

/// Computes a day's prayer times entirely from astronomical formulas — no network access, no
/// persisted state, no CoreLocation dependency. A pure function of its three inputs, which
/// makes it trivial to unit test (see `PrayerKitTests`) and safe to call from any context,
/// including a widget extension's timeline provider.
///
/// See `NOTICE.md` for the algorithm's provenance and `VERIFICATION_NEEDED.md` for the current
/// state of accuracy verification against Diyanet reference data.
public struct PrayerCalculationService: Sendable {

    public init() {}

    public func dailyTimes(
        for date: Date,
        coordinate: Coordinate,
        settings: CalculationSettings,
        hijriConverter: HijriDateConverting = UmmAlQuraHijriDateConverter()
    ) -> DailyPrayerTimes {
        let times = rawTimes(for: date, coordinate: coordinate, settings: settings)
        let hijri = hijriConverter.hijriDate(from: date)
        return DailyPrayerTimes(gregorianDate: date, coordinate: coordinate, times: times, hijriDate: hijri)
    }

    // MARK: - Core computation

    private func rawTimes(for date: Date, coordinate: Coordinate, settings: CalculationSettings) -> [PrayerTime] {
        let timeZone = coordinate.timeZone
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let comps = utcCalendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return []
        }

        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        let utcOffsetHours = Double(timeZone.secondsFromGMT(for: date)) / 3600.0
        let params = settings.method.parameters

        // Julian day for this calendar date, shifted so the "day fraction" arguments below
        // (5/24, 6/24, ...) line up with local solar time at this longitude rather than at
        // the Greenwich meridian.
        let baseJulianDay = SolarTime.julianDay(year: year, month: month, day: Double(day)) - longitude / (15 * 24)

        func solarNoonHour(dayFraction: Double) -> Double {
            let position = SolarTime.sunPosition(julianDay: baseJulianDay + dayFraction)
            return SolarTime.fixHour(12 - position.equationOfTimeHours)
        }

        /// Hour-of-day (unwrapped — may fall outside 0...24, which correctly signals a
        /// day-boundary crossing once the timezone correction is applied) at which the sun
        /// reaches `angle` degrees below the horizon, before (`afterNoon == false`) or after
        /// (`afterNoon == true`) solar noon. `nil` when the sun never reaches that angle on
        /// this day at this latitude (the high-latitude case).
        func hourAngleTime(angle: Double, dayFraction: Double, afterNoon: Bool) -> Double? {
            let position = SolarTime.sunPosition(julianDay: baseJulianDay + dayFraction)
            let noon = solarNoonHour(dayFraction: dayFraction)
            let cosArg = (-SolarTime.dsin(angle) - SolarTime.dsin(position.declination) * SolarTime.dsin(latitude))
                / (SolarTime.dcos(position.declination) * SolarTime.dcos(latitude))
            guard cosArg >= -1, cosArg <= 1 else { return nil }
            let t = SolarTime.dacos(cosArg) / 15
            return noon + (afterNoon ? t : -t)
        }

        func asrHourAngleTime(shadowFactor: Double, dayFraction: Double) -> Double {
            let position = SolarTime.sunPosition(julianDay: baseJulianDay + dayFraction)
            let noon = solarNoonHour(dayFraction: dayFraction)
            let angle = -SolarTime.dacot(shadowFactor + SolarTime.dtan(abs(latitude - position.declination)))
            let cosArg = (-SolarTime.dsin(angle) - SolarTime.dsin(position.declination) * SolarTime.dsin(latitude))
                / (SolarTime.dcos(position.declination) * SolarTime.dcos(latitude))
            let clamped = min(max(cosArg, -1), 1)
            let t = SolarTime.dacos(clamped) / 15
            return noon + t
        }

        // First pass: fixed starting guesses (hour of day), matching the standard reference
        // algorithm's defaults (Fajr ~05:00, sunrise ~06:00, sunset ~18:00, Isha ~19:00).
        var fajrHour = hourAngleTime(angle: params.fajrAngle, dayFraction: 5.0 / 24, afterNoon: false) ?? 5.0
        var sunriseHour = hourAngleTime(angle: 0.833, dayFraction: 6.0 / 24, afterNoon: false) ?? 6.0
        var sunsetHour = hourAngleTime(angle: 0.833, dayFraction: 18.0 / 24, afterNoon: true) ?? 18.0
        var ishaHour = isha(params: params, sunsetHour: sunsetHour, dayFraction: 19.0 / 24, hourAngleTime: hourAngleTime)
        var dhuhrHour = solarNoonHour(dayFraction: 12.0 / 24)
        var asrHour = asrHourAngleTime(shadowFactor: settings.madhab.asrShadowFactor, dayFraction: 13.0 / 24)

        // Second pass: refine every value using the first pass's own result as the day
        // fraction. This meaningfully improves accuracy over a single fixed guess, since the
        // sun's declination shifts slightly over the course of the day.
        fajrHour = hourAngleTime(angle: params.fajrAngle, dayFraction: fajrHour / 24, afterNoon: false) ?? fajrHour
        sunriseHour = hourAngleTime(angle: 0.833, dayFraction: sunriseHour / 24, afterNoon: false) ?? sunriseHour
        sunsetHour = hourAngleTime(angle: 0.833, dayFraction: sunsetHour / 24, afterNoon: true) ?? sunsetHour
        ishaHour = isha(params: params, sunsetHour: sunsetHour, dayFraction: ishaHour / 24, hourAngleTime: hourAngleTime)
        dhuhrHour = solarNoonHour(dayFraction: dhuhrHour / 24)
        asrHour = asrHourAngleTime(shadowFactor: settings.madhab.asrShadowFactor, dayFraction: asrHour / 24)

        // Convert from "local solar meridian" hour fractions to this location's civil clock time.
        let correction = utcOffsetHours - longitude / 15
        var hours: [Prayer: Double] = [
            .fajr: fajrHour + correction,
            .sunrise: sunriseHour + correction,
            .dhuhr: dhuhrHour + correction,
            .asr: asrHour + correction,
            .maghrib: sunsetHour + correction + params.maghribOffsetMinutes / 60,
            .isha: ishaHour + correction
        ]

        hours = HighLatitudeAdjuster.adjust(
            hours: hours,
            rule: settings.highLatitudeRule,
            fajrAngle: params.fajrAngle,
            ishaAngle: params.ishaAngle ?? params.fajrAngle
        )

        return Prayer.allCases.compactMap { prayer -> PrayerTime? in
            guard let baseHour = hours[prayer] else { return nil }
            let hour = baseHour + Double(settings.manualOffsetMinutes(for: prayer)) / 60
            guard let date = Self.date(year: year, month: month, day: day, hourFraction: hour, timeZone: timeZone) else {
                return nil
            }
            return PrayerTime(prayer: prayer, date: date)
        }
    }

    /// Isha is either angle-based (most methods) or a fixed interval after Maghrib/sunset
    /// (Umm al-Qura, Qatar) — factored out since both calculation passes need this branch.
    private func isha(
        params: CalculationParameters,
        sunsetHour: Double,
        dayFraction: Double,
        hourAngleTime: (Double, Double, Bool) -> Double?
    ) -> Double {
        if let ishaAngle = params.ishaAngle {
            return hourAngleTime(ishaAngle, dayFraction, true) ?? (sunsetHour + 90.0 / 60)
        }
        return sunsetHour + (params.ishaIntervalMinutes ?? 90) / 60
    }

    /// Builds an absolute `Date` by adding `hourFraction` hours to local midnight for the
    /// given calendar day and time zone. `hourFraction` may be negative or exceed 24 — that
    /// correctly rolls over into the previous/next calendar day.
    private static func date(year: Int, month: Int, day: Int, hourFraction: Double, timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        guard let startOfDay = calendar.date(from: comps) else { return nil }
        return startOfDay.addingTimeInterval(hourFraction * 3600)
    }
}
