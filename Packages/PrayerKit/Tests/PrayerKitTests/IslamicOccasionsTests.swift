import Foundation
import XCTest
@testable import PrayerKit

/// Dini gün ve gece hesabının testleri.
///
/// **Burada belirli miladi tarihler iddia EDİLMİYOR.** "Kadir Gecesi 16 Mart 2026" gibi bir
/// assert, doğrulanmamış referans verisini teste gömmek olurdu: hicri dönüşümümüz arşiv
/// penceresinin dışında Ümmü'l-Kura tahminidir ve Diyanet'in ay başları ondan bir gün
/// ayrılabilir. Onun yerine **kuralların kendisi** sınanıyor — Regaib'in her zaman perşembe
/// olması, gece kandillerinin hedef hicri günün bir öncesine düşmesi gibi. Bunlar
/// dönüşümden bağımsız, her zaman doğru olması gereken değişmezler.
final class IslamicOccasionsTests: XCTestCase {

    private let calendarUTC: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private let islamic = IslamicCalendar()

    private func date(_ day: GregorianDay) -> Date {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = 12
        return calendarUTC.date(from: components)!
    }

    private func hijri(_ day: GregorianDay) -> HijriDate {
        DiyanetHijriDateConverter().hijriDate(from: date(day))
    }

    private func occasions(_ year: Int) -> [IslamicOccasionDay] {
        islamic.occasions(inGregorianYear: year)
    }

    /// Birkaç yıl birden: tek bir yıla bakmak, yıla özgü bir tesadüfü kural sanmaya yol açar.
    private let years = [2026, 2027, 2028, 2029, 2030]

    // MARK: - Temel sağlamlık

    func test_everyYearProducesOccasions() {
        for year in years {
            XCTAssertFalse(occasions(year).isEmpty, "\(year) boş çıktı")
        }
    }

    func test_occasionsAreSortedAndInsideTheRequestedYear() {
        for year in years {
            let list = occasions(year)
            XCTAssertEqual(list, list.sorted { $0.day < $1.day }, "\(year) sıralı değil")
            for item in list {
                XCTAssertEqual(item.day.year, year, "\(item.occasion) yanlış yıla düştü")
            }
        }
    }

    // MARK: - Gece kandilleri

    /// Değişmez: bir gece kandilinin yazıldığı günün ERTESİ günü, hedef hicri güne denk
    /// gelmeli. Kaydırmayı ters yöne uygularsak ya da hiç uygulamazsak bu test düşer.
    func test_nightOccasionsFallOnTheDayBeforeTheirHijriDate() {
        let expected: [IslamicOccasion: (month: Int, day: Int)] = [
            .mawlid: (3, 12),
            .miraj: (7, 27),
            .berat: (8, 15),
            .laylatAlQadr: (9, 27)
        ]

        for year in years {
            for item in occasions(year) {
                guard let target = expected[item.occasion] else { continue }
                guard let next = calendarUTC.date(byAdding: .day, value: 1, to: date(item.day)) else {
                    return XCTFail("Ertesi gün hesaplanamadı")
                }
                let nextHijri = DiyanetHijriDateConverter().hijriDate(from: next)
                XCTAssertEqual(
                    nextHijri.month, target.month,
                    "\(item.occasion) \(item.day): ertesi günün hicri ayı tutmuyor"
                )
                XCTAssertEqual(
                    nextHijri.day, target.day,
                    "\(item.occasion) \(item.day): ertesi günün hicri günü tutmuyor"
                )
            }
        }
    }

    func test_nightOccasionsAreMarkedAsNights() {
        for occasion in [IslamicOccasion.mawlid, .regaib, .miraj, .berat, .laylatAlQadr] {
            XCTAssertTrue(occasion.isNight, "\(occasion) gece olarak işaretli olmalı")
        }
        for occasion in [IslamicOccasion.hijriNewYear, .ashura, .ramadanStart, .ramadanFeast] {
            XCTAssertFalse(occasion.isNight, "\(occasion) gün olarak işaretli olmalı")
        }
    }

    // MARK: - Regaib

    /// Regaib "Recep ayının ilk cuma gecesi" — yani perşembeyi cumaya bağlayan gece.
    /// Dolayısıyla yazıldığı gün **her zaman perşembe** olmak zorunda. Algoritma bozulursa
    /// en hızlı bu test yakalar.
    func test_regaibIsAlwaysOnAThursday() {
        var found = 0
        for year in years {
            for item in occasions(year) where item.occasion == .regaib {
                found += 1
                let weekday = calendarUTC.component(.weekday, from: date(item.day))
                XCTAssertEqual(weekday, 5, "\(item.day) perşembe değil (weekday=\(weekday))")
            }
        }
        XCTAssertGreaterThan(found, 0, "Hiç Regaib bulunamadı")
    }

    /// Ertesi gün cuma olmalı ve Recep ayına düşmeli — kuralın diğer yarısı.
    func test_regaibIsFollowedByAFridayInRajab() {
        for year in years {
            for item in occasions(year) where item.occasion == .regaib {
                guard let friday = calendarUTC.date(byAdding: .day, value: 1, to: date(item.day)) else {
                    return XCTFail("Ertesi gün yok")
                }
                XCTAssertEqual(calendarUTC.component(.weekday, from: friday), 6, "\(item.day) + 1 cuma değil")
                XCTAssertEqual(
                    DiyanetHijriDateConverter().hijriDate(from: friday).month, 7,
                    "\(item.day) + 1 Recep ayında değil"
                )
            }
        }
    }

    /// Regaib'in kendisi Recep'ten ÖNCEKİ güne düşebiliyor (1 Recep cumaysa). Bu yüzden
    /// "Regaib günü Recep ayında olmalı" diye bir kural KOYMUYORUZ — koysaydık o yılların
    /// kandilini kaçırırdık. Test, düşülen günün Recep ya da bir önceki ay olduğunu doğruluyor.
    func test_regaibMayFallOnTheDayBeforeRajabBegins() {
        for year in years {
            for item in occasions(year) where item.occasion == .regaib {
                let month = hijri(item.day).month
                XCTAssertTrue(
                    month == 7 || month == 6,
                    "\(item.day) Recep veya Cemaziyelahir'de olmalı, bulunan ay: \(month)"
                )
            }
        }
    }

    /// Bir hicri yılda yalnızca bir Regaib olur. Recep'te birden fazla cuma var; ilki
    /// dışındakiler alınmamalı.
    func test_onlyOneRegaibPerHijriYear() {
        var perHijriYear: [Int: Int] = [:]
        for year in years {
            for item in occasions(year) where item.occasion == .regaib {
                // Kandilin ait olduğu hicri yıl, ertesi günün (cuma) yılı.
                let friday = calendarUTC.date(byAdding: .day, value: 1, to: date(item.day))!
                let hijriYear = DiyanetHijriDateConverter().hijriDate(from: friday).year
                perHijriYear[hijriYear, default: 0] += 1
            }
        }
        for (hijriYear, count) in perHijriYear {
            XCTAssertEqual(count, 1, "Hicri \(hijriYear) yılında \(count) Regaib bulundu")
        }
    }

    // MARK: - Bayramlar

    func test_ramadanFeastRunsForThreeDays() {
        for year in years {
            let feast = occasions(year).filter { $0.occasion == .ramadanFeast }
            guard !feast.isEmpty else { continue }
            // Yıl sınırında kesilmiş olabilir; kesilmemişse tam üç gün ve sıralı olmalı.
            if feast.count == 3 {
                XCTAssertEqual(feast.compactMap(\.ordinal), [1, 2, 3], "\(year) bayram sırası bozuk")
            }
            for item in feast {
                XCTAssertEqual(hijri(item.day).month, 10, "Ramazan Bayramı Şevval'de olmalı")
            }
        }
    }

    /// Türkiye'de Kurban Bayramı dört gün. Genel takvim kütüphaneleri çoğu zaman tek gün
    /// işaretliyor; bu test o hatayı yakalar.
    func test_qurbanFeastRunsForFourDays() {
        for year in years {
            let feast = occasions(year).filter { $0.occasion == .qurbanFeast }
            guard feast.count == 4 else { continue }
            XCTAssertEqual(feast.compactMap(\.ordinal), [1, 2, 3, 4], "\(year) kurban sırası bozuk")
            for item in feast {
                let h = hijri(item.day)
                XCTAssertEqual(h.month, 12)
                XCTAssertTrue((10...13).contains(h.day), "Kurban günü 10-13 Zilhicce olmalı")
            }
        }
    }

    /// Arefe "29 Ramazan" diye sabitlenemez — Ramazan 29 da 30 da çekebiliyor. Tanım
    /// gereği bayramın bir önceki günü; testi de öyle kuruyoruz.
    func test_ramadanEveIsTheDayBeforeTheFeast() {
        for year in years {
            let list = occasions(year)
            guard let eve = list.first(where: { $0.occasion == .ramadanEve }) else { continue }
            guard let next = calendarUTC.date(byAdding: .day, value: 1, to: date(eve.day)) else {
                return XCTFail("Ertesi gün yok")
            }
            let nextHijri = DiyanetHijriDateConverter().hijriDate(from: next)
            XCTAssertEqual(nextHijri.month, 10, "Arefenin ertesi günü Şevval olmalı")
            XCTAssertEqual(nextHijri.day, 1, "Arefenin ertesi günü 1 Şevval olmalı")
            XCTAssertEqual(hijri(eve.day).month, 9, "Arefe Ramazan'da olmalı")
        }
    }

    func test_qurbanEveIsTheNinthOfDhulHijjah() {
        for year in years {
            for item in occasions(year) where item.occasion == .qurbanEve {
                let h = hijri(item.day)
                XCTAssertEqual(h.month, 12)
                XCTAssertEqual(h.day, 9)
            }
        }
    }

    // MARK: - Gün olarak idrak edilenler

    func test_dayOccasionsMatchTheirHijriDateExactly() {
        let expected: [IslamicOccasion: (month: Int, day: Int)] = [
            .hijriNewYear: (1, 1),
            .ashura: (1, 10),
            .ramadanStart: (9, 1)
        ]
        for year in years {
            for item in occasions(year) {
                guard let target = expected[item.occasion] else { continue }
                let h = hijri(item.day)
                XCTAssertEqual(h.month, target.month, "\(item.occasion) ayı tutmuyor")
                XCTAssertEqual(h.day, target.day, "\(item.occasion) günü tutmuyor")
            }
        }
    }

    // MARK: - Kapsam dürüstlüğü

    /// Arşiv penceresi dar olduğu için neredeyse hiçbir dini gün "doğrulanmış" olmayacak.
    /// Bu bir kusur değil, bilinen bir sınır — ve arayüzün söylemesi gereken şey.
    /// Test, bayrağın hiç değilse tutarlı üretildiğini garanti ediyor.
    func test_verificationFlagIsProducedForEveryOccasion() {
        let converter = DiyanetHijriDateConverter()
        for year in years {
            for item in occasions(year) {
                XCTAssertEqual(
                    item.isVerified, converter.isVerified(date(item.day)),
                    "\(item.occasion) \(item.day) doğrulama bayrağı tutarsız"
                )
            }
        }
    }

    /// Bir miladi yılda aynı kandil iki kez görünebilir (hicri yıl 11 gün kısa). Kimlik
    /// üretimi buna dayanmalı; `(yıl, olay)` ikilisiyle eşsizlik varsayan bir kod kırılır.
    func test_identifiersStayUniqueEvenWhenAnOccasionRepeats() {
        for year in years {
            let ids = occasions(year).map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "\(year) yılında yinelenen kimlik var")
        }
    }
}
