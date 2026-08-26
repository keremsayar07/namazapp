import Foundation
import XCTest
import PrayerKit
@testable import NamazCore

@MainActor
final class CalendarViewModelTests: XCTestCase {

    private let istanbul = SavedLocation(
        name: "İstanbul",
        coordinate: Coordinate(latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"),
        source: .manual
    )

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso) ?? Date()
    }

    private func makeModel(now: String = "2026-08-25T12:00:00+03:00") -> CalendarViewModel {
        let fixedNow = date(now)
        return CalendarViewModel(
            location: istanbul,
            repository: PrayerTimesRepository(),
            clock: { fixedNow }
        )
    }

    // MARK: - Ay kurulumu

    func test_monthHasCorrectNumberOfDays() {
        let model = makeModel()
        XCTAssertEqual(model.month?.days.count, 31, "Ağustos 31 gün")
    }

    func test_februaryInLeapYear() {
        // 2028 artık yıl. Gün sayısını elle hesaplamak yerine takvime soruyoruz;
        // artık yıl kuralını kendimiz yazsaydık er ya da geç yanlış yazardık.
        let fixedNow = date("2028-02-10T12:00:00+03:00")
        let model = CalendarViewModel(location: istanbul, clock: { fixedNow })
        XCTAssertEqual(model.month?.days.count, 29)
    }

    func test_everyDayHasSixPrayerTimes() {
        let model = makeModel()
        for day in model.month?.days ?? [] {
            XCTAssertEqual(day.times.times.count, 6, "\(day.dayNumber) Ağustos'ta altı vakit olmalı")
        }
    }

    func test_todayIsMarkedExactlyOnce() {
        let model = makeModel()
        let todays = model.month?.days.filter(\.isToday) ?? []
        XCTAssertEqual(todays.count, 1)
        XCTAssertEqual(todays.first?.dayNumber, 25)
    }

    func test_todayIsSelectedOnLaunch() {
        let model = makeModel()
        XCTAssertEqual(model.selectedDay?.dayNumber, 25)
    }

    // MARK: - Izgara hizalaması

    func test_leadingBlanksAlignFirstDayToItsWeekday() {
        let model = makeModel()
        guard let month = model.month else { return XCTFail("Ay yok") }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let weekday = calendar.component(.weekday, from: month.anchor)
        let expected = (weekday - calendar.firstWeekday + 7) % 7

        // Haftanın ilk gününü sabit kodlamıyoruz: Türkiye'de pazartesi, ABD'de pazar.
        XCTAssertEqual(month.leadingBlanks, expected)
        XCTAssertLessThan(month.leadingBlanks, 7)
    }

    // MARK: - Gezinme

    func test_navigatingBackwardAndForwardReturnsToTheSameMonth() {
        let model = makeModel()
        let original = model.month?.anchor

        model.goToPreviousMonth()
        XCTAssertNotEqual(model.month?.anchor, original)

        model.goToNextMonth()
        XCTAssertEqual(model.month?.anchor, original)
    }

    func test_navigatingAcrossYearBoundary() {
        let model = makeModel(now: "2026-01-15T12:00:00+03:00")
        model.goToPreviousMonth()

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        guard let anchor = model.month?.anchor else { return XCTFail("Ay yok") }

        XCTAssertEqual(calendar.component(.year, from: anchor), 2025)
        XCTAssertEqual(calendar.component(.month, from: anchor), 12)
        XCTAssertEqual(model.month?.days.count, 31, "Aralık 31 gün")
    }

    func test_goToTodayReturnsAndSelects() {
        let model = makeModel()
        model.goToPreviousMonth()
        model.goToPreviousMonth()
        XCTAssertNil(model.selectedDay, "Başka aya gidince seçim düşmeli")

        model.goToToday()
        XCTAssertEqual(model.selectedDay?.dayNumber, 25)
    }

    // MARK: - Hicri

    func test_monthSpansTwoHijriMonths() {
        let model = makeModel()
        let span = model.month?.hijriSpan ?? []

        // Miladi ay ile hicri ay hiçbir zaman hizalanmaz; bir miladi ay neredeyse her zaman
        // iki hicri aya değer. Başlıkta ikisini de yazabilmek için bu gerekli.
        XCTAssertEqual(span.count, 2, "Ağustos 2026 iki hicri aya yayılmalı")
    }

    // MARK: - Ayar değişikliği

    func test_changingSettingsKeepsTheDisplayedMonth() {
        let model = makeModel()
        model.goToNextMonth()
        let displayed = model.month?.anchor

        var hanafi = CalculationSettings.defaultForTurkey()
        hanafi.madhab = .hanafi
        model.update(location: istanbul, settings: hanafi)

        // Kullanıcı Eylül'e bakıyorsa ayarı değiştirince Ağustos'a fırlamamalı.
        XCTAssertEqual(model.month?.anchor, displayed)
    }

    func test_changingMadhabChangesAsrThroughoutTheMonth() {
        let model = makeModel()
        let shafiAsr = model.month?.days.first?.times.time(for: .asr)

        var hanafi = CalculationSettings.defaultForTurkey()
        hanafi.madhab = .hanafi
        model.update(location: istanbul, settings: hanafi)
        let hanafiAsr = model.month?.days.first?.times.time(for: .asr)

        XCTAssertNotNil(shafiAsr)
        XCTAssertGreaterThan(hanafiAsr ?? .distantPast, shafiAsr ?? .distantFuture)
    }

    // MARK: - Konum yok

    func test_withoutLocationThereIsNoMonth() {
        let fixedNow = date("2026-08-25T12:00:00+03:00")
        let model = CalendarViewModel(location: nil, clock: { fixedNow })
        XCTAssertNil(model.month)
        XCTAssertNil(model.selectedDay)
    }
}
