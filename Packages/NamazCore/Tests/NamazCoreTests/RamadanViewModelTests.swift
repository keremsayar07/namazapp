import Foundation
import XCTest
import PrayerKit
@testable import NamazCore

/// İmsakiye tablosunun testleri.
///
/// Burada da sabit saat iddiası yok — "18 Şubat'ta iftar 18:12" demek, Diyanet'in henüz
/// ilan etmediği bir ramazan başlangıcını ve o güne ait bir saati doğru kabul etmek olurdu.
/// Sınanan şey tablonun **iç tutarlılığı**: gün sayısı ayın uzunluğuyla aynı, her satırda
/// imsak iftardan önce, numaralar 1'den başlayıp kesintisiz gidiyor.
@MainActor
final class RamadanViewModelTests: XCTestCase {

    private let istanbul = SavedLocation(
        name: "İstanbul",
        coordinate: Coordinate(
            latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"
        ),
        source: .manual
    )

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso) ?? Date()
    }

    private func makeModel(
        location: SavedLocation?,
        now: String = "2026-08-25T10:00:00+03:00"
    ) -> RamadanViewModel {
        let fixed = date(now)
        return RamadanViewModel(location: location, clock: { fixed })
    }

    // MARK: - Tablo

    func test_withoutACityThereIsNoTable() {
        // Konum olmadan vakit hesaplanamaz. Boş bir tablo çizmektense hiç çizmemek.
        let model = makeModel(location: nil)
        XCTAssertTrue(model.days.isEmpty)
        XCTAssertNil(model.period)
    }

    func test_theTableHasOneRowPerDayOfTheMonth() {
        let model = makeModel(location: istanbul)
        guard let period = model.period else { return XCTFail("Ramazan bulunamadı") }

        XCTAssertEqual(model.days.count, period.dayCount)
        XCTAssertTrue(
            model.days.count == 29 || model.days.count == 30,
            "Ramazan 29 ya da 30 gün: \(model.days.count)"
        )
    }

    func test_dayNumbersAreContiguousFromOne() {
        let model = makeModel(location: istanbul)
        // Boş tabloda `1...0` çöker; testin kendisi çökerek "başarısız" olmamalı.
        guard !model.days.isEmpty else { return XCTFail("Tablo boş") }
        XCTAssertEqual(model.days.map(\.number), Array(1...model.days.count))
    }

    func test_suhoorEndsBeforeIftarOnEveryRow() {
        // İmsak = sabah vakti, iftar = akşam vakti. Sıraları bozulursa satır anlamsızdır.
        let model = makeModel(location: istanbul)
        for day in model.days {
            XCTAssertLessThan(day.imsak, day.iftar, "\(day.number). gün ters")
        }
    }

    func test_rowsAreInChronologicalOrder() {
        let model = makeModel(location: istanbul)
        for (previous, next) in zip(model.days, model.days.dropFirst()) {
            XCTAssertLessThan(previous.date, next.date)
        }
    }

    func test_theTimesMatchThePrayerScheduleForTheSameDay() {
        // İmsakiye ayrı bir hesap değil, aynı hesabın başka bir başlığı. İki tablo ayrı
        // düşerse kullanıcı hangisine güveneceğini bilemez.
        let model = makeModel(location: istanbul)
        guard let first = model.days.first else { return XCTFail("Tablo boş") }

        let times = PrayerTimesRepository().dailyTimes(
            on: first.date, location: istanbul, settings: .defaultForTurkey()
        )
        XCTAssertEqual(first.imsak, times.time(for: .fajr))
        XCTAssertEqual(first.iftar, times.time(for: .maghrib))
    }

    // MARK: - Bugün

    func test_outsideRamadanNoRowIsMarkedAsToday() {
        // 25 Ağustos 2026 ramazan değil; tablo yaklaşan ramazanı gösteriyor.
        let model = makeModel(location: istanbul, now: "2026-08-25T10:00:00+03:00")
        XCTAssertFalse(model.isActiveToday)
        XCTAssertNil(model.today)
        XCTAssertTrue(model.days.allSatisfy { !$0.isToday })
    }

    func test_theCountdownToRamadanIsPositiveAndDisappearsInsideIt() {
        let model = makeModel(location: istanbul, now: "2026-08-25T10:00:00+03:00")
        guard let remaining = model.daysUntilStart(from: date("2026-08-25T10:00:00+03:00")) else {
            return XCTFail("Ramazana kalan gün hesaplanamadı")
        }
        XCTAssertGreaterThan(remaining, 0)

        // Ayın ortasından bakıldığında geri sayım değil, "kaçıncı gün" anlamlı olan.
        guard let middle = model.days.first(where: { $0.number == 10 })?.date else {
            return XCTFail("Onuncu gün bulunamadı")
        }
        let inside = RamadanViewModel(
            location: istanbul,
            clock: { middle.addingTimeInterval(10 * 3600) }
        )
        XCTAssertTrue(inside.isActiveToday)
        XCTAssertEqual(inside.today?.number, 10)
        XCTAssertNil(inside.daysUntilStart(from: middle))
    }

    // MARK: - Dürüstlük

    func test_anUnverifiedMonthIsReportedAsUnverified() {
        // Diyanet düzeltme tablosu şimdilik 2026 sonbaharının birkaç haftasını kapsıyor;
        // hiçbir ramazan o pencerede değil. Ekran uyarıyı bu bayrağa göre gösteriyor ve
        // bayrak sessizce `true` olursa tahmini bir tarih resmî ilan gibi görünür.
        let model = makeModel(location: istanbul)
        XCTAssertEqual(model.isVerified, model.period?.isVerified ?? false)
    }

    func test_changingTheCityRebuildsTheTable() {
        let model = makeModel(location: istanbul)
        let istanbulIftar = model.days.first?.iftar

        let izmir = SavedLocation(
            name: "İzmir",
            coordinate: Coordinate(
                latitude: 38.4237, longitude: 27.1428, timeZoneIdentifier: "Europe/Istanbul"
            ),
            source: .manual
        )
        model.update(location: izmir, settings: .defaultForTurkey())

        XCTAssertEqual(model.days.count, model.period?.dayCount)
        XCTAssertNotEqual(model.days.first?.iftar, istanbulIftar, "İzmir'de akşam daha geç olur")
    }
}
