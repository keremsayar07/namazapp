import Foundation
import XCTest
import PrayerKit
@testable import NamazCore

/// Bildirim planlayıcısının testleri.
///
/// Bunlar gerçek cihazda denenmesi en zor davranışlar: 64 bildirim sınırına dayanmak,
/// gece yarısını geçmek, geçmiş vakitleri atlamak. Planlayıcı saf bir hesap olduğu için
/// hepsi burada, saniyeler içinde sınanabiliyor.
final class NotificationPlannerTests: XCTestCase {

    private let istanbul = SavedLocation(
        name: "İstanbul",
        coordinate: Coordinate(latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"),
        source: .manual
    )
    private let repository = PrayerTimesRepository()
    private var timeZone: TimeZone { istanbul.coordinate.timeZone }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso) ?? Date()
    }

    /// Beş vaktin hepsine aynı hatırlatma süresi. Bütçeye en hızlı yüklenen ayar,
    /// dolayısıyla sınır testlerinin çoğu bunu kullanıyor.
    private func reminding(_ minutes: Int) -> NotificationSettings {
        var settings = NotificationSettings()
        settings.setReminderForAll(minutes)
        return settings
    }

    private func makePlan(
        now: Date,
        settings: NotificationSettings,
        capacity: Int = PrayerNotificationPlanner.capacity,
        maxDaysAhead: Int = PrayerNotificationPlanner.maxDaysAhead
    ) -> NotificationPlan {
        PrayerNotificationPlanner(capacity: capacity, maxDaysAhead: maxDaysAhead)
            .plan(from: now, settings: settings, timeZone: timeZone) { day in
                repository.dailyTimes(
                    on: day, location: istanbul, settings: .defaultForTurkey()
                )
            }
    }

    // MARK: - Sistem sınırı

    func test_neverExceedsCapacity() {
        // Hatırlatma da açık: vakit başına iki bildirim, yani sınıra en hızlı giden ayar.
        let settings = reminding(15)
        let plan = makePlan(now: date("2026-08-25T00:01:00+03:00"), settings: settings)

        XCTAssertLessThanOrEqual(plan.notifications.count, PrayerNotificationPlanner.capacity)
        // iOS 65'inciyi sessizce atıyor — hata da uyarı da vermiyor. Bu yüzden sınırın
        // altında kalmak bizim sorumluluğumuz.
        XCTAssertLessThan(plan.notifications.count, PrayerNotificationPlanner.systemLimit)
        XCTAssertTrue(plan.wasTruncated, "Kapasite dolmalıydı")
    }

    func test_reminderHalvesTheCoveredDays() {
        let now = date("2026-08-25T00:01:00+03:00")
        let withoutReminder = makePlan(now: now, settings: NotificationSettings())
        let withReminder = makePlan(now: now, settings: reminding(20))

        // Kullanıcıya söylenecek şey bu: hatırlatma açıkken kapsanan gün sayısı düşüyor.
        XCTAssertGreaterThan(withoutReminder.coveredDays, withReminder.coveredDays)
        XCTAssertGreaterThan(withoutReminder.coveredDays, 8, "5 vakitle en az bir hafta kapsanmalı")
    }

    // MARK: - Zaman sınırları

    func test_pastPrayersAreNotScheduled() {
        // Günün ortası: imsak, güneş ve öğle geçti.
        let now = date("2026-08-25T15:20:00+03:00")
        let plan = makePlan(now: now, settings: NotificationSettings())

        XCTAssertFalse(
            plan.notifications.contains { $0.fireDate <= now },
            "Geçmiş bir vakit için bildirim planlanmamalı"
        )
    }

    func test_lateAtNight_firstNotificationIsTomorrowsFajr() {
        // Yatsıdan sonra: bugünün vakitleri tükendi, sıradaki yarının imsağı.
        let now = date("2026-08-25T23:50:00+03:00")
        let plan = makePlan(now: now, settings: NotificationSettings())

        let first = plan.notifications.first
        XCTAssertEqual(first?.prayer, .fajr)
        XCTAssertGreaterThan(first?.fireDate ?? .distantPast, now)
    }

    func test_notificationsAreSortedByFireDate() {
        let plan = makePlan(now: date("2026-08-25T05:00:00+03:00"), settings: NotificationSettings())
        let dates = plan.notifications.map(\.fireDate)
        XCTAssertEqual(dates, dates.sorted(), "Plan tetiklenme sırasında olmalı")
    }

    // MARK: - Vakit seçimi

    func test_sunriseIsNeverScheduled() {
        // Güneş kılınan bir vakit değil, imsak penceresinin sonunu işaretliyor.
        // Kullanıcı ayarlarda açsa bile bildirimi olmamalı.
        var settings = NotificationSettings()
        settings.enabledPrayers = Prayer.allCases
        let plan = makePlan(now: date("2026-08-25T00:01:00+03:00"), settings: settings)

        XCTAssertFalse(plan.notifications.contains { $0.prayer == .sunrise })
    }

    func test_disabledPrayersAreSkipped() {
        var settings = NotificationSettings()
        settings.enabledPrayers = [.fajr, .maghrib]
        let plan = makePlan(now: date("2026-08-25T00:01:00+03:00"), settings: settings)

        let prayers = Set(plan.notifications.map(\.prayer))
        XCTAssertEqual(prayers, [.fajr, .maghrib])
    }

    func test_silentSettingsProduceEmptyPlan() {
        var noPrayers = NotificationSettings()
        noPrayers.enabledPrayers = []
        XCTAssertTrue(makePlan(now: date("2026-08-25T00:01:00+03:00"), settings: noPrayers).notifications.isEmpty)

        var noTrigger = NotificationSettings()
        noTrigger.notifyAtPrayerTime = false
        noTrigger.setReminderForAll(nil)
        XCTAssertTrue(makePlan(now: date("2026-08-25T00:01:00+03:00"), settings: noTrigger).notifications.isEmpty)
    }

    // MARK: - Hatırlatma

    func test_reminderFiresBeforeItsPrayer() {
        let settings = reminding(30)
        let plan = makePlan(now: date("2026-08-25T00:01:00+03:00"), settings: settings, capacity: 20)

        guard let reminder = plan.notifications.first(where: { $0.kind == .reminder }) else {
            return XCTFail("Hatırlatma bekleniyordu")
        }
        XCTAssertEqual(reminder.prayerDate.timeIntervalSince(reminder.fireDate), 30 * 60, accuracy: 1)
        XCTAssertEqual(reminder.minutesBefore, 30)
    }

    func test_eachPrayerUsesItsOwnOffset() {
        // Özelliğin bütün amacı bu: sabaha 45 dakika, akşama 5 dakika. Tek bir genel
        // süreyle bu ikisi aynı anda karşılanamıyordu.
        var settings = NotificationSettings()
        settings.notifyAtPrayerTime = false
        settings.setReminder(45, for: .fajr)
        settings.setReminder(5, for: .maghrib)

        let plan = makePlan(now: date("2026-08-25T00:01:00+03:00"), settings: settings, capacity: 20)

        XCTAssertEqual(Set(plan.notifications.map(\.prayer)), [.fajr, .maghrib])
        for notification in plan.notifications {
            let offset = notification.prayerDate.timeIntervalSince(notification.fireDate)
            XCTAssertEqual(offset, Double(notification.prayer == .fajr ? 45 : 5) * 60, accuracy: 1)
        }
    }

    func test_aPrayerWithoutAnOffsetGetsNoReminder() {
        var settings = NotificationSettings()
        settings.setReminder(15, for: .isha)

        let plan = makePlan(now: date("2026-08-25T00:01:00+03:00"), settings: settings, capacity: 30)
        let reminders = plan.notifications.filter { $0.kind == .reminder }

        XCTAssertFalse(reminders.isEmpty)
        XCTAssertTrue(reminders.allSatisfy { $0.prayer == .isha })
    }

    func test_aDisabledPrayersReminderIsNotScheduled() {
        // Ayar saklanıyor ama bildirim kurulmamalı: kapattığı vakit için hatırlatma alan
        // kullanıcı, kapatmanın işe yaramadığını düşünürdü.
        var settings = NotificationSettings()
        settings.setReminderForAll(15)
        settings.enabledPrayers = [.fajr]

        let plan = makePlan(now: date("2026-08-25T00:01:00+03:00"), settings: settings, capacity: 30)
        XCTAssertTrue(plan.notifications.allSatisfy { $0.prayer == .fajr })
    }

    func test_theBudgetLineMatchesWhatIsActuallyScheduled() {
        // Ekranda yazan "günde N bildirim" ile planlayıcının kurduğu sayı ayrı düşerse,
        // kullanıcıya söylenen şey yanlış olur. Aynı ayardan iki farklı sayı çıkmamalı.
        var settings = NotificationSettings()
        settings.setReminder(20, for: .fajr)
        settings.setReminder(10, for: .maghrib)

        // Gece yarısından hemen sonra: günün hiçbir vakti geçmemiş durumda.
        let plan = makePlan(now: date("2026-08-26T00:01:00+03:00"), settings: settings, maxDaysAhead: 1)
        XCTAssertEqual(plan.notifications.count, settings.notificationsPerDay)
    }

    // MARK: - İdempotanlık

    func test_identifiersAreStableAcrossRuns() {
        let now = date("2026-08-25T10:00:00+03:00")
        let first = makePlan(now: now, settings: NotificationSettings())
        let second = makePlan(now: now, settings: NotificationSettings())

        // Aynı girdi aynı kimlikleri üretmeli: yeniden planlama iOS'ta üzerine yazma olur,
        // kullanıcı aynı ezanı iki kez almaz. Rastgele kimlikle bu garanti kaybolurdu.
        XCTAssertEqual(first.notifications.map(\.id), second.notifications.map(\.id))
    }

    func test_identifiersAreUnique() {
        let plan = makePlan(now: date("2026-08-25T00:01:00+03:00"), settings: reminding(10))
        let ids = plan.notifications.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Kimlikler çakışırsa bildirimler birbirini siler")
    }
}

final class NotificationSchedulerContractTests: XCTestCase {

    func test_stubReplacesRatherThanAppends() async {
        let scheduler = StubNotificationScheduler()
        let planner = PrayerNotificationPlanner(capacity: 5, maxDaysAhead: 3)
        let location = SavedLocation(
            name: "Ankara",
            coordinate: Coordinate(latitude: 39.93, longitude: 32.86, timeZoneIdentifier: "Europe/Istanbul"),
            source: .manual
        )
        let repository = PrayerTimesRepository()
        let now = Date(timeIntervalSince1970: 1_787_000_000)

        let plan = planner.plan(
            from: now, settings: .default, timeZone: location.coordinate.timeZone
        ) { repository.dailyTimes(on: $0, location: location, settings: .defaultForTurkey()) }

        let content: @Sendable (PlannedNotification) -> NotificationContent = { _ in
            NotificationContent(title: "t", body: "b")
        }

        await scheduler.replaceAll(with: plan, content: content, playsSound: true)
        let firstCount = await scheduler.pendingCount()
        await scheduler.replaceAll(with: plan, content: content, playsSound: true)
        let secondCount = await scheduler.pendingCount()

        // İki kez kurmak sayıyı ikiye katlamamalı.
        XCTAssertEqual(firstCount, secondCount)
        XCTAssertEqual(firstCount, plan.notifications.count)
    }

    func test_cancelAllEmptiesTheQueue() async {
        let scheduler = StubNotificationScheduler()
        await scheduler.cancelAll()
        let count = await scheduler.pendingCount()
        XCTAssertEqual(count, 0)
    }
}
