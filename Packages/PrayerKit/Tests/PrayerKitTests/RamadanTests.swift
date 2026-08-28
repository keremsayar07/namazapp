import Foundation
import XCTest
@testable import PrayerKit

/// Ramazan aralığının testleri.
///
/// **Sabit tarih iddiası yok.** "1 Ramazan 1448 = 18 Şubat 2027" diye bir test yazmak,
/// Diyanet'in henüz ilan etmediği bir tarihi doğru kabul etmek olurdu — ve elimizdeki
/// düzeltme tablosu o günleri kapsamıyor. Test edilen şey **değişmezler**: ay 1 Ramazan'da
/// başlıyor, 29 ya da 30 gün sürüyor, hemen ardından 1 Şevval geliyor. Bunlar takvim
/// sisteminin kendi kuralları; hangi hesap kullanılırsa kullanılsın tutmak zorundalar.
final class RamadanTests: XCTestCase {

    private let calendar = IslamicCalendar()
    private let converter = DiyanetHijriDateConverter()

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso) ?? Date()
    }

    /// Miladi gün → o günün öğle vakti (UTC). Dönüştürücü gün ortasından okunuyor ki
    /// saat dilimi ne olursa olsun gün kaymasın.
    private func noon(_ day: GregorianDay) -> Date {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal.date(from: components) ?? Date()
    }

    private func hijri(_ day: GregorianDay) -> HijriDate {
        converter.hijriDate(from: noon(day))
    }

    /// Beş ayrı yıldan bakıldığında bulunan ramazanlar. Tek bir yıla bakmak, o yıla özgü
    /// bir tesadüfü kural sanmaya yol açardı.
    private var samples: [Date] {
        [
            date("2026-08-25T12:00:00Z"),
            date("2027-01-10T12:00:00Z"),
            date("2028-03-01T12:00:00Z"),
            date("2029-06-15T12:00:00Z"),
            date("2030-11-20T12:00:00Z")
        ]
    }

    // MARK: - Değişmezler

    func test_aPeriodIsAlwaysFound() {
        for sample in samples {
            XCTAssertNotNil(
                calendar.ramadan(onOrAfter: sample),
                "\(sample) için ramazan bulunamadı"
            )
        }
    }

    func test_periodStartsOnTheFirstOfRamadan() {
        for sample in samples {
            guard let period = calendar.ramadan(onOrAfter: sample),
                  let first = period.firstDay else {
                return XCTFail("Ramazan bulunamadı: \(sample)")
            }
            let h = hijri(first)
            XCTAssertEqual(h.month, 9, "İlk gün ramazanda olmalı: \(first)")
            XCTAssertEqual(h.day, 1, "İlk gün 1 Ramazan olmalı: \(first)")
        }
    }

    func test_periodIsTwentyNineOrThirtyDays() {
        // Ay 29 da 30 da çekebiliyor; sabit 30 varsaymak imsakiyeye olmayan bir gün eklerdi.
        for sample in samples {
            guard let period = calendar.ramadan(onOrAfter: sample) else {
                return XCTFail("Ramazan bulunamadı: \(sample)")
            }
            XCTAssertTrue(
                period.dayCount == 29 || period.dayCount == 30,
                "\(period.hijriYear) için beklenmeyen uzunluk: \(period.dayCount)"
            )
        }
    }

    func test_everyDayInThePeriodIsInRamadan() {
        for sample in samples {
            guard let period = calendar.ramadan(onOrAfter: sample) else {
                return XCTFail("Ramazan bulunamadı: \(sample)")
            }
            for day in period.days {
                XCTAssertEqual(hijri(day).month, 9, "\(day) ramazan dışında")
            }
        }
    }

    func test_theDayAfterThePeriodIsTheFirstOfShawwal() {
        // Bayramın ilk günü. Bu tutmuyorsa ya ay kırpılmış ya da dönüştürücü tutarsız.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC") ?? .current

        for sample in samples {
            guard let period = calendar.ramadan(onOrAfter: sample),
                  let last = period.lastDay,
                  let next = gregorian.date(byAdding: .day, value: 1, to: noon(last)) else {
                return XCTFail("Ramazan bulunamadı: \(sample)")
            }
            let h = converter.hijriDate(from: next)
            XCTAssertEqual(h.month, 10, "Ramazandan sonra Şevval gelmeli")
            XCTAssertEqual(h.day, 1, "Bayramın ilk günü olmalı")
        }
    }

    func test_dayNumbersRunFromOneToTheLength() {
        guard let period = calendar.ramadan(onOrAfter: samples[0]) else {
            return XCTFail("Ramazan bulunamadı")
        }
        XCTAssertEqual(period.dayNumber(of: period.days[0]), 1)
        XCTAssertEqual(period.dayNumber(of: period.days[period.dayCount - 1]), period.dayCount)
        XCTAssertNil(period.dayNumber(of: GregorianDay(year: 1900, month: 1, day: 1)))
    }

    // MARK: - Seçim kuralı

    func test_aDateInsideRamadanReturnsThatSameRamadan() {
        guard let period = calendar.ramadan(onOrAfter: samples[0]),
              let first = period.firstDay else {
            return XCTFail("Ramazan bulunamadı")
        }
        // Ayın ortasından tekrar sorunca bir sonraki yılın ramazanına atlamamalı:
        // oruç tutan biri için "yaklaşan ramazan" o an içinde bulunduğu aydır.
        let middle = noon(period.days[period.dayCount / 2])
        XCTAssertEqual(calendar.ramadan(onOrAfter: middle)?.firstDay, first)
    }

    func test_theLastDayStillReturnsTheCurrentRamadan() {
        guard let period = calendar.ramadan(onOrAfter: samples[0]),
              let last = period.lastDay else {
            return XCTFail("Ramazan bulunamadı")
        }
        XCTAssertEqual(calendar.ramadan(onOrAfter: noon(last))?.lastDay, last)
    }

    func test_theDayAfterRamadanReturnsTheNextYear() {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC") ?? .current

        guard let period = calendar.ramadan(onOrAfter: samples[0]),
              let last = period.lastDay,
              let afterFeast = gregorian.date(byAdding: .day, value: 1, to: noon(last)),
              let next = calendar.ramadan(onOrAfter: afterFeast) else {
            return XCTFail("Sonraki ramazan bulunamadı")
        }
        XCTAssertEqual(next.hijriYear, period.hijriYear + 1)
    }

    func test_resultIsDeterministic() {
        // Aynı girdi aynı çıktı: imsakiyenin iki açılışta farklı görünmesi kabul edilemez.
        let first = calendar.ramadan(onOrAfter: samples[2])
        let second = calendar.ramadan(onOrAfter: samples[2])
        XCTAssertEqual(first, second)
    }

    // MARK: - Dürüstlük

    func test_aPeriodOutsideTheArchiveIsNotMarkedVerified() {
        // Kapsamı olmayan bir dönüştürücüyle bulunan ay, doğrulanmış sayılmamalı.
        // Doğrulanmış görünseydi arayüz uyarıyı gizler ve tahmini bir tarihi Diyanet'in
        // ilanı gibi sunardı — kaçındığımız şey tam olarak bu.
        //
        // Test arşivin bugünkü içeriğine bağlanmıyor: kapsam ileride genişleyip bir
        // ramazanı içine aldığında bu test yine geçerli kalmalı.
        let uncovered = IslamicCalendar(
            converter: DiyanetHijriDateConverter(overrides: [:], coverage: nil)
        )
        XCTAssertEqual(uncovered.ramadan(onOrAfter: samples[0])?.isVerified, false)
    }

    func test_aFullyCoveredPeriodIsMarkedVerified() {
        // Kapsamın diğer ucu: ay tamamen arşivin içindeyse uyarı gösterilmemeli.
        // Sürekli uyaran bir arayüz, uyarısı okunmayan bir arayüze dönüşür.
        let covered = IslamicCalendar(
            converter: DiyanetHijriDateConverter(
                overrides: [:],
                coverage: GregorianDay(year: 1900, month: 1, day: 1)
                    ...GregorianDay(year: 2100, month: 1, day: 1)
            )
        )
        XCTAssertEqual(covered.ramadan(onOrAfter: samples[0])?.isVerified, true)
    }
}
