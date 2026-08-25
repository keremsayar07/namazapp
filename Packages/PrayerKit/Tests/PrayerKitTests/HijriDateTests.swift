import Foundation
import XCTest
@testable import PrayerKit

final class HijriDateTests: XCTestCase {

    func test_ummAlQuraConverter_returnsPlausibleMonthDayRange() {
        let converter = UmmAlQuraHijriDateConverter()
        let hijri = converter.hijriDate(from: utcNoon(2026, 6, 21))
        XCTAssertTrue((1...12).contains(hijri.month))
        XCTAssertTrue((1...30).contains(hijri.day))
        XCTAssertTrue(hijri.year > 1400 && hijri.year < 1500)
    }

    func test_diyanetConverter_withNoOverrides_matchesBaseConverterExactly() {
        let base = UmmAlQuraHijriDateConverter()
        let diyanet = DiyanetHijriDateConverter(base: base, overrides: [:])
        let date = utcNoon(2026, 3, 20)
        XCTAssertEqual(diyanet.hijriDate(from: date), base.hijriDate(from: date))
    }

    func test_override_forSpecificDay_takesPrecedenceOverBaseConverter() {
        let base = UmmAlQuraHijriDateConverter()
        let overrideDay = GregorianDay(year: 2026, month: 3, day: 20)
        let overrideValue = HijriDate(year: 1447, month: 9, day: 1) // hipotetik örnek değer, gerçek veri değil
        let diyanet = DiyanetHijriDateConverter(base: base, overrides: [overrideDay: overrideValue])

        let overridden = diyanet.hijriDate(from: utcNoon(2026, 3, 20))
        XCTAssertEqual(overridden, overrideValue)

        // Komşu bir gün override tablosunda yok — base converter'a düşmeli.
        let neighboring = diyanet.hijriDate(from: utcNoon(2026, 3, 21))
        XCTAssertEqual(neighboring, base.hijriDate(from: utcNoon(2026, 3, 21)))
    }

    func test_monthLocalizationKey_fallsBackGracefullyForOutOfRangeMonth() {
        let invalid = HijriDate(year: 1447, month: 99, day: 1)
        XCTAssertEqual(invalid.monthLocalizationKey, "hijri.month.unknown")

        let ramazan = HijriDate(year: 1447, month: 9, day: 1)
        XCTAssertEqual(ramazan.monthLocalizationKey, "hijri.month.ramazan")
    }
}
