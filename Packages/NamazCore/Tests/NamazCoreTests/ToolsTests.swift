import Foundation
import XCTest
import PrayerKit
@testable import NamazCore

@MainActor
final class ToolsTests: XCTestCase {

    private let istanbul = TimeZone(identifier: "Europe/Istanbul")!

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso) ?? Date()
    }

    // MARK: - Gün anahtarı

    func test_dayKeyUsesTheGivenTimeZoneNotTheDevices() {
        // 23:30 İstanbul = 20:30 UTC. Cihaz UTC'de olsa bile gün İstanbul'a göre yazılmalı,
        // yoksa gece kılınan yatsı bir önceki güne düşer.
        let moment = date("2026-08-27T23:30:00+03:00")
        XCTAssertEqual(DayKey.string(for: moment, in: istanbul), "2026-08-27")
        XCTAssertEqual(DayKey.string(for: moment, in: TimeZone(identifier: "UTC")!), "2026-08-27")

        // 00:30 İstanbul = önceki gün 21:30 UTC. Burada ayrışıyorlar.
        let afterMidnight = date("2026-08-28T00:30:00+03:00")
        XCTAssertEqual(DayKey.string(for: afterMidnight, in: istanbul), "2026-08-28")
        XCTAssertEqual(
            DayKey.string(for: afterMidnight, in: TimeZone(identifier: "UTC")!), "2026-08-27"
        )
    }

    func test_dayKeyRoundTrips() {
        let key = "2026-09-12"
        guard let back = DayKey.date(from: key, in: istanbul) else { return XCTFail("Çevrilemedi") }
        XCTAssertEqual(DayKey.string(for: back, in: istanbul), key)
    }

    // MARK: - Depo

    func test_storeRoundTripsAValue() async {
        let store = InMemoryFileStore()
        await store.save(QadhaCounts(entries: [QadhaEntry(prayer: .fajr, count: 12)]), to: "x")
        let loaded = await store.load(QadhaCounts.self, from: "x")
        XCTAssertEqual(loaded?.count(for: .fajr), 12)
    }

    func test_missingFileReturnsNilNotACrash() async {
        let store = InMemoryFileStore()
        let loaded = await store.load(QadhaCounts.self, from: "yok")
        XCTAssertNil(loaded)
    }

    func test_pathTraversalNamesAreRejected() async {
        // Dosya adları koddan geliyor ama yol ayracı içeren bir ad konteynerin dışına
        // yazabilirdi. Gerçek depoda bu reddediliyor; konteyner yoksa da çökmüyor.
        let store = JSONFileStore(containerURL: nil)
        await store.save(QadhaCounts(), to: "../kacis")
        let loaded = await store.load(QadhaCounts.self, from: "../kacis")
        XCTAssertNil(loaded)
    }

    // MARK: - Zikirmatik

    private func makeTasbih(now: String = "2026-08-27T10:00:00+03:00") -> TasbihViewModel {
        let fixed = date(now)
        return TasbihViewModel(store: InMemoryFileStore(), timeZone: istanbul, clock: { fixed })
    }

    func test_tasbihStartsWithDefaultPresets() async {
        let model = makeTasbih()
        await model.load()
        XCTAssertFalse(model.state.presets.isEmpty)
        XCTAssertNotNil(model.state.activePreset)
    }

    func test_incrementRaisesCountAndDailyTotal() async {
        let model = makeTasbih()
        await model.load()
        model.increment()
        model.increment()
        XCTAssertEqual(model.state.count, 2)
        XCTAssertEqual(model.todayTotal, 2)
    }

    func test_reachingTargetIsReportedExactlyOnce() async {
        let model = makeTasbih()
        await model.load()
        guard let target = model.state.activePreset?.target else { return XCTFail("Hedef yok") }

        for _ in 0..<(target - 1) { model.increment() }
        XCTAssertFalse(model.didReachTarget, "Hedeften önce bildirilmemeli")

        model.increment()
        XCTAssertTrue(model.didReachTarget, "Tam hedefte bildirilmeli")

        model.increment()
        XCTAssertFalse(model.didReachTarget, "Hedefi geçtikten sonra tekrar bildirilmemeli")
    }

    func test_resetClearsCounterButKeepsTheDailyTotal() async {
        // O gün gerçekten çekilmiş zikri sayaç sıfırlandı diye yok saymak yanlış olurdu.
        let model = makeTasbih()
        await model.load()
        model.increment(); model.increment(); model.increment()
        model.reset()
        XCTAssertEqual(model.state.count, 0)
        XCTAssertEqual(model.todayTotal, 3)
    }

    func test_switchingPresetResetsTheCounter() async {
        let model = makeTasbih()
        await model.load()
        model.increment()
        guard let other = model.state.presets.last else { return XCTFail("Zikir yok") }
        model.select(other)
        XCTAssertEqual(model.state.count, 0)
        XCTAssertEqual(model.state.activePreset?.id, other.id)
    }

    func test_lastPresetCannotBeDeleted() async {
        // Boş bir zikirmatik ekranı hiçbir şey yapamaz.
        let model = makeTasbih()
        await model.load()
        while model.state.presets.count > 1 {
            model.deletePreset(model.state.presets[0])
        }
        model.deletePreset(model.state.presets[0])
        XCTAssertEqual(model.state.presets.count, 1)
    }

    func test_emptyPresetNameIsRejected() async {
        let model = makeTasbih()
        await model.load()
        let before = model.state.presets.count
        model.addPreset(name: "   ", target: 33)
        XCTAssertEqual(model.state.presets.count, before)
    }

    func test_tasbihSurvivesAReload() async {
        let store = InMemoryFileStore()
        let fixed = date("2026-08-27T10:00:00+03:00")
        let first = TasbihViewModel(store: store, timeZone: istanbul, clock: { fixed })
        await first.load()
        first.increment(); first.increment()
        await first.save()

        let second = TasbihViewModel(store: store, timeZone: istanbul, clock: { fixed })
        await second.load()
        XCTAssertEqual(second.state.count, 2)
        XCTAssertEqual(second.todayTotal, 2)
    }

    // MARK: - Namaz takibi

    private func makeLog(now: String = "2026-08-27T10:00:00+03:00") -> PrayerLogViewModel {
        let fixed = date(now)
        return PrayerLogViewModel(store: InMemoryFileStore(), timeZone: istanbul, clock: { fixed })
    }

    func test_togglingMarksAndUnmarks() async {
        let model = makeLog()
        await model.load()
        XCTAssertFalse(model.isMarked(.fajr))
        await model.toggle(.fajr)
        XCTAssertTrue(model.isMarked(.fajr))
        await model.toggle(.fajr)
        XCTAssertFalse(model.isMarked(.fajr))
    }

    func test_emptyDaysAreNotStored() async {
        // Kayıt yalnızca gerçekten işaretlenmiş günleri taşısın; boş günler dosyayı
        // gereksiz şişirirdi.
        let model = makeLog()
        await model.load()
        await model.toggle(.asr)
        await model.toggle(.asr)
        XCTAssertTrue(model.log.days.isEmpty)
    }

    func test_canGoBackButNotIntoTheFuture() async {
        let model = makeLog()
        await model.load()
        XCTAssertTrue(model.isShowingToday)

        model.showNextDay()
        XCTAssertTrue(model.isShowingToday, "Bugünün ötesine geçilmemeli")

        model.showPreviousDay()
        XCTAssertFalse(model.isShowingToday)
        XCTAssertEqual(model.displayedDayKey, "2026-08-26")

        model.showNextDay()
        XCTAssertTrue(model.isShowingToday)
    }

    func test_marksBelongToTheDisplayedDayNotToday() async {
        let model = makeLog()
        await model.load()
        model.showPreviousDay()
        await model.toggle(.maghrib)

        XCTAssertTrue(model.log.isMarked(.maghrib, on: "2026-08-26"))
        XCTAssertFalse(model.log.isMarked(.maghrib, on: "2026-08-27"))
    }

    func test_recentDaysEndsWithTodayAndHasTheRightLength() async {
        let model = makeLog()
        await model.load()
        await model.toggle(.fajr)

        let recent = model.recentDays()
        XCTAssertEqual(recent.count, 7)
        XCTAssertEqual(recent.last?.dayKey, "2026-08-27")
        XCTAssertEqual(recent.last?.marked, 1)
        XCTAssertEqual(recent.first?.dayKey, "2026-08-21")
    }

    // MARK: - Kaza

    func test_qadhaCountsGoUpAndDown() async {
        let model = QadhaViewModel(store: InMemoryFileStore())
        await model.load()
        await model.adjust(.isha, by: 5)
        XCTAssertEqual(model.count(for: .isha), 5)
        await model.adjust(.isha, by: -2)
        XCTAssertEqual(model.count(for: .isha), 3)
    }

    func test_qadhaNeverGoesNegative() async {
        // Eksi bir kaza sayısının anlamı yok; fazladan basılan düğme sayacı bozmamalı.
        let model = QadhaViewModel(store: InMemoryFileStore())
        await model.load()
        await model.adjust(.dhuhr, by: 1)
        await model.adjust(.dhuhr, by: -5)
        XCTAssertEqual(model.count(for: .dhuhr), 0)
    }

    func test_addingAFullDayRaisesFivePrayersNotSix() async {
        // Güneş kılınacak bir vakit değil.
        let model = QadhaViewModel(store: InMemoryFileStore())
        await model.load()
        await model.addFullDay()
        XCTAssertEqual(model.total, 5)
        XCTAssertEqual(model.count(for: .sunrise), 0)
        XCTAssertEqual(model.count(for: .fajr), 1)
    }

    func test_qadhaSurvivesAReload() async {
        let store = InMemoryFileStore()
        let first = QadhaViewModel(store: store)
        await first.load()
        await first.adjust(.asr, by: 7)

        let second = QadhaViewModel(store: store)
        await second.load()
        XCTAssertEqual(second.count(for: .asr), 7)
    }
}
