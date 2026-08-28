import Foundation
import XCTest
import PrayerKit
@testable import NamazCore

@MainActor
final class NotificationCoordinatorTests: XCTestCase {

    private let istanbul = SavedLocation(
        name: "İstanbul",
        coordinate: Coordinate(latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"),
        source: .manual
    )

    private let content: @Sendable (PlannedNotification) -> NotificationContent = { _ in
        NotificationContent(title: "başlık", body: "gövde")
    }

    private func makeCoordinator(
        scheduler: StubNotificationScheduler,
        store: PreferenceStoring = InMemoryPreferenceStore()
    ) -> NotificationCoordinator {
        NotificationCoordinator(
            scheduler: scheduler,
            content: content,
            planner: PrayerNotificationPlanner(capacity: 20, maxDaysAhead: 7),
            preferences: Preferences(store: store),
            clock: { Date(timeIntervalSince1970: 1_787_000_000) }
        )
    }

    func test_schedulesWhenAuthorizedAndLocationKnown() async {
        let scheduler = StubNotificationScheduler(authorization: .authorized)
        let coordinator = makeCoordinator(scheduler: scheduler)

        await coordinator.reschedule(location: istanbul, calculationSettings: .defaultForTurkey())

        let count = await scheduler.pendingCount()
        XCTAssertGreaterThan(count, 0)
        XCTAssertGreaterThan(coordinator.plan.coveredDays, 0)
    }

    func test_deniedAuthorization_clearsInsteadOfScheduling() async {
        let scheduler = StubNotificationScheduler(authorization: .denied)
        let coordinator = makeCoordinator(scheduler: scheduler)

        await coordinator.reschedule(location: istanbul, calculationSettings: .defaultForTurkey())

        let count = await scheduler.pendingCount()
        XCTAssertEqual(count, 0)
        XCTAssertEqual(coordinator.plan, .empty)
    }

    func test_noLocation_clearsPendingNotifications() async {
        let scheduler = StubNotificationScheduler(authorization: .authorized)
        let coordinator = makeCoordinator(scheduler: scheduler)

        await coordinator.reschedule(location: istanbul, calculationSettings: .defaultForTurkey())
        let beforeClearing = await scheduler.pendingCount()
        XCTAssertGreaterThan(beforeClearing, 0)

        // Konum kaybolduğunda eski şehrin vakitleri için çalan bir ezan, hiç bildirim
        // gelmemesinden kötü.
        await coordinator.reschedule(location: nil, calculationSettings: .defaultForTurkey())
        let afterClearing = await scheduler.pendingCount()
        XCTAssertEqual(afterClearing, 0)
    }

    func test_turningEverythingOff_clearsPendingNotifications() async {
        let scheduler = StubNotificationScheduler(authorization: .authorized)
        let coordinator = makeCoordinator(scheduler: scheduler)
        await coordinator.reschedule(location: istanbul, calculationSettings: .defaultForTurkey())
        let beforeSilencing = await scheduler.pendingCount()
        XCTAssertGreaterThan(beforeSilencing, 0)

        var silent = NotificationSettings()
        silent.enabledPrayers = []
        await coordinator.update(silent, location: istanbul, calculationSettings: .defaultForTurkey())

        let afterSilencing = await scheduler.pendingCount()
        XCTAssertEqual(afterSilencing, 0)
    }

    func test_settingsArePersistedAcrossLaunches() async {
        let store = InMemoryPreferenceStore()
        let first = makeCoordinator(scheduler: StubNotificationScheduler(), store: store)

        var custom = NotificationSettings()
        custom.enabledPrayers = [.fajr]
        custom.setReminderForAll(15)
        custom.playsSound = false
        await first.update(custom, location: istanbul, calculationSettings: .defaultForTurkey())

        let second = makeCoordinator(scheduler: StubNotificationScheduler(), store: store)
        XCTAssertEqual(second.settings, custom)
    }

    func test_reschedulingTwiceDoesNotDouble() async {
        let scheduler = StubNotificationScheduler(authorization: .authorized)
        let coordinator = makeCoordinator(scheduler: scheduler)

        await coordinator.reschedule(location: istanbul, calculationSettings: .defaultForTurkey())
        let first = await scheduler.pendingCount()
        await coordinator.reschedule(location: istanbul, calculationSettings: .defaultForTurkey())
        let second = await scheduler.pendingCount()

        // Uygulama her öne geldiğinde yeniden planlıyoruz; bu sayıyı büyütmemeli.
        XCTAssertEqual(first, second)
    }

    func test_changingMadhabChangesTheScheduledTimes() async {
        let scheduler = StubNotificationScheduler(authorization: .authorized)
        let coordinator = makeCoordinator(scheduler: scheduler)

        await coordinator.reschedule(location: istanbul, calculationSettings: .defaultForTurkey())
        let afterShafi = await scheduler.scheduled
        let shafiAsr = afterShafi.first { $0.prayer == .asr }?.fireDate

        var hanafi = CalculationSettings.defaultForTurkey()
        hanafi.madhab = .hanafi
        await coordinator.reschedule(location: istanbul, calculationSettings: hanafi)
        let afterHanafi = await scheduler.scheduled
        let hanafiAsr = afterHanafi.first { $0.prayer == .asr }?.fireDate

        XCTAssertNotNil(shafiAsr)
        XCTAssertNotNil(hanafiAsr)
        // Hesaplama ayarı değişince kurulu bildirimler de değişmeli — yoksa kullanıcı
        // ayarı değiştirir ama eski vakitte ezan duyar.
        XCTAssertNotEqual(shafiAsr, hanafiAsr)
    }
}
