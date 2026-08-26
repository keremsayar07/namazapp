import Foundation
import XCTest
@testable import PrayerKit

/// `currentPrayer(at:)` — "içinde bulunulan vakit" kuralı.
///
/// Kural hem ana ekranın hem takvimin vurgusunu belirliyor. Ekranda gözle doğrulanamayacak
/// kadar sessiz bir kural (yanlış satır vurgulanır ve kimse fark etmez), o yüzden testi
/// burada, hesap katmanında duruyor.
final class DailyPrayerTimesTests: XCTestCase {

    private let times = PrayerCalculationService().dailyTimes(
        for: utcNoon(2026, 8, 25),
        coordinate: TestCities.istanbul,
        settings: .defaultForTurkey()
    )

    private func at(_ prayer: Prayer, plus minutes: Int) -> Date {
        times.time(for: prayer)!.addingTimeInterval(Double(minutes) * 60)
    }

    func test_beforeFajrThereIsNoCurrentPrayer() {
        // Gün başındayız ama günün ilk vakti henüz girmemiş: teknik olarak dünün
        // yatsısındayız ve bu tip kendi gününün dışına bakmıyor.
        XCTAssertNil(times.currentPrayer(at: at(.fajr, plus: -1)))
    }

    func test_currentPrayerIsTheLastOneEntered() {
        XCTAssertEqual(times.currentPrayer(at: at(.fajr, plus: 1)), .fajr)
        XCTAssertEqual(times.currentPrayer(at: at(.asr, plus: 30)), .asr)
        XCTAssertEqual(times.currentPrayer(at: at(.isha, plus: 90)), .isha)
    }

    func test_sunriseCountsAsAPeriod() {
        // Güneş ile öğle arası gerçekten "güneş doğduktan sonra"dır; o aralıkta hâlâ
        // imsağı vurgulamak yanlış olurdu.
        XCTAssertEqual(times.currentPrayer(at: at(.sunrise, plus: 5)), .sunrise)
    }

    func test_exactlyAtAPrayerTimeThatPrayerIsCurrent() {
        // Sınır dahil: 13:15'te öğle vakti girmiştir, bir saniye sonrasını beklemez.
        XCTAssertEqual(times.currentPrayer(at: at(.dhuhr, plus: 0)), .dhuhr)
    }

    func test_pastPrayersAndCurrentPrayerAgree() {
        let moment = at(.maghrib, plus: 10)
        let past = times.pastPrayers(relativeTo: moment)
        XCTAssertEqual(times.currentPrayer(at: moment), .maghrib)
        XCTAssertTrue(past.contains(.maghrib))
        XCTAssertFalse(past.contains(.isha))
    }
}
