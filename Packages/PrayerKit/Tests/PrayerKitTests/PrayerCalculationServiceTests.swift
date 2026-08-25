import Foundation
import XCTest
@testable import PrayerKit

/// These tests check internal consistency and general plausibility — they do NOT verify
/// minute-level accuracy against Diyanet's official times, because that reference data isn't
/// available yet. See `VERIFICATION_NEEDED.md`. Do not read a green run here as "the times are
/// correct" — only as "the math didn't obviously break".
final class PrayerCalculationServiceTests: XCTestCase {

    let service = PrayerCalculationService()

    func test_chronologicalOrder_forOrdinaryMidLatitudeCity() {
        let settings = CalculationSettings.defaultForTurkey(latitude: TestCities.istanbul.latitude)
        let daily = service.dailyTimes(for: utcNoon(2026, 6, 21), coordinate: TestCities.istanbul, settings: settings)

        let ordered = Prayer.allCases.compactMap { daily.time(for: $0) }
        XCTAssertEqual(ordered.count, 6, "Her 6 vakit de hesaplanmalı")
        for (earlier, later) in zip(ordered, ordered.dropFirst()) {
            XCTAssertLessThan(earlier, later, "Vakitler kronolojik sırada olmalı")
        }
    }

    func test_dhuhrNearSolarNoon_forIstanbulAnkaraGaziantep() {
        for coordinate in [TestCities.istanbul, TestCities.ankara, TestCities.gaziantep] {
            let settings = CalculationSettings.defaultForTurkey(latitude: coordinate.latitude)
            let daily = service.dailyTimes(for: utcNoon(2026, 6, 21), coordinate: coordinate, settings: settings)

            guard let dhuhr = daily.time(for: .dhuhr) else {
                XCTFail("Öğle vakti hesaplanamadı")
                continue
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = coordinate.timeZone
            let hour = Double(calendar.component(.hour, from: dhuhr)) + Double(calendar.component(.minute, from: dhuhr)) / 60
            // Türkiye tek dilimde UTC+3 kullanıyor; boylam farkları nedeniyle öğle vakti 12:00
            // sivil saatinin biraz öncesi/sonrasına düşebilir — geniş ama anlamlı bir aralık.
            XCTAssertTrue(hour > 11.5 && hour < 13.5, "Öğle vakti 11:30-13:30 aralığında olmalı, hesaplanan: \(hour)")
        }
    }

    func test_deterministic_sameInputsSameOutputs() {
        let settings = CalculationSettings.defaultForTurkey()
        let first = service.dailyTimes(for: utcNoon(2026, 3, 20), coordinate: TestCities.istanbul, settings: settings)
        let second = service.dailyTimes(for: utcNoon(2026, 3, 20), coordinate: TestCities.istanbul, settings: settings)
        XCTAssertEqual(first, second)
    }

    func test_hanafiAsr_isNoEarlierThanShafiAsr() {
        let base = CalculationSettings.defaultForTurkey(latitude: TestCities.ankara.latitude)
        var shafiSettings = base
        shafiSettings.madhab = .shafi
        var hanafiSettings = base
        hanafiSettings.madhab = .hanafi

        let date = utcNoon(2026, 9, 23)
        let shafi = service.dailyTimes(for: date, coordinate: TestCities.ankara, settings: shafiSettings).time(for: .asr)
        let hanafi = service.dailyTimes(for: date, coordinate: TestCities.ankara, settings: hanafiSettings).time(for: .asr)

        guard let shafi, let hanafi else {
            XCTFail("İkindi vakti hesaplanamadı")
            return
        }
        XCTAssertGreaterThanOrEqual(hanafi, shafi, "Hanefi ikindi, Şafi ikindiden erken olamaz")
    }

    func test_highLatitudeSummer_doesNotCrashAndStaysOrdered() {
        var settings = CalculationSettings.defaultForTurkey(latitude: TestCities.tromso.latitude)
        settings.highLatitudeRule = .seventhOfTheNight
        // Yaz gündönümüne yakın; kutup dairesine yakın enlemlerde güneş ufkun 18° altına hiç
        // inmeyebilir — bu durumda hourAngleTime nil döner ve HighLatitudeAdjuster devreye girer.
        let daily = service.dailyTimes(for: utcNoon(2026, 6, 21), coordinate: TestCities.tromso, settings: settings)

        let ordered = Prayer.allCases.compactMap { daily.time(for: $0) }
        XCTAssertEqual(ordered.count, 6)
        for time in ordered {
            XCTAssertFalse(time.timeIntervalSinceReferenceDate.isNaN)
        }
        for (earlier, later) in zip(ordered, ordered.dropFirst()) {
            XCTAssertLessThanOrEqual(earlier, later, "Yüksek enlemde bile vakitler kronolojik sırayı korumalı")
        }
    }

    func test_differentCalculationMethods_produceDifferentIshaTimes() {
        var mwl = CalculationSettings.defaultForTurkey(latitude: TestCities.istanbul.latitude)
        mwl.method = .muslimWorldLeague
        var makkah = mwl
        makkah.method = .ummAlQura

        let date = utcNoon(2026, 1, 15)
        let mwlIsha = service.dailyTimes(for: date, coordinate: TestCities.istanbul, settings: mwl).time(for: .isha)
        let makkahIsha = service.dailyTimes(for: date, coordinate: TestCities.istanbul, settings: makkah).time(for: .isha)

        XCTAssertNotNil(mwlIsha)
        XCTAssertNotNil(makkahIsha)
        XCTAssertNotEqual(mwlIsha, makkahIsha, "MWL açı-bazlı, Umm al-Qura 90 dakika sabit aralık kullanıyor — sonuçlar aynı olmamalı")
    }
}
