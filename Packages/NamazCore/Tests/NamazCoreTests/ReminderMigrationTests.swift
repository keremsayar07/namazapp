import Foundation
import XCTest
import PrayerKit
@testable import NamazCore

/// Vakit başına hatırlatmanın testleri.
///
/// **En kritik olanı geçiş testi.** Güncellemeden önce "20 dakika önce hatırlat" demiş bir
/// kullanıcının kaydında yeni alan yok. Çözümleme bunu kaçırırsa hatırlatma sessizce
/// kaybolur: çökme yok, hata yok, sadece bir sabah gelmeyen bildirim. Bu sınıftaki testler
/// tam olarak o sessiz kaybı yakalamak için var.
final class ReminderMigrationTests: XCTestCase {

    private func decode(_ json: String) throws -> NotificationSettings {
        try JSONDecoder().decode(NotificationSettings.self, from: Data(json.utf8))
    }

    // MARK: - Eski kayıttan geçiş

    func test_legacyGlobalReminderBecomesAReminderForEveryEnabledPrayer() throws {
        let legacy = """
        {
          "enabledPrayers": [0, 2, 3, 4, 5],
          "notifyAtPrayerTime": true,
          "remindBeforeMinutes": 20,
          "playsSound": true
        }
        """
        let settings = try decode(legacy)

        XCTAssertEqual(settings.reminders.count, 5, "Beş vaktin hepsine taşınmalı")
        for prayer in Prayer.allCases where prayer.isPerformablePrayer {
            XCTAssertEqual(
                settings.reminderMinutes(for: prayer), 20,
                "\(prayer) hatırlatması kaybolmuş"
            )
        }
    }

    func test_legacyReminderOnlyCoversPrayersThatWereEnabled() throws {
        // Kullanıcı sadece sabahı açık bırakmışsa, geçişte diğer vakitler için hatırlatma
        // uydurmak onun hiç istemediği dört bildirim eklemek olurdu.
        let legacy = """
        {"enabledPrayers": [0], "notifyAtPrayerTime": true, "remindBeforeMinutes": 15, "playsSound": true}
        """
        let settings = try decode(legacy)

        XCTAssertEqual(settings.reminders.map(\.prayer), [.fajr])
        XCTAssertEqual(settings.reminderMinutes(for: .fajr), 15)
        XCTAssertNil(settings.reminderMinutes(for: .isha))
    }

    func test_legacyNullReminderStaysOff() throws {
        let legacy = """
        {"enabledPrayers": [0, 2, 3, 4, 5], "notifyAtPrayerTime": true, "remindBeforeMinutes": null, "playsSound": true}
        """
        XCTAssertTrue(try decode(legacy).reminders.isEmpty)
    }

    func test_legacyRecordWithoutTheKeyAtAllStaysOff() throws {
        let legacy = """
        {"enabledPrayers": [0, 4], "notifyAtPrayerTime": true, "playsSound": false}
        """
        let settings = try decode(legacy)
        XCTAssertTrue(settings.reminders.isEmpty)
        XCTAssertEqual(settings.enabledPrayers, [.fajr, .maghrib])
        XCTAssertFalse(settings.playsSound)
    }

    func test_newRecordWinsOverTheLegacyKey() throws {
        // İkisi birden bulunursa yeni alan doğru olan. Eski alan bir kez yazıldıktan sonra
        // güncellenmiyor; ona bakmak bayat veriyi geri getirirdi.
        let mixed = """
        {
          "enabledPrayers": [0, 2, 3, 4, 5],
          "notifyAtPrayerTime": true,
          "remindBeforeMinutes": 45,
          "reminders": [{"prayer": 0, "minutes": 10}],
          "playsSound": true
        }
        """
        let settings = try decode(mixed)
        XCTAssertEqual(settings.reminders.count, 1)
        XCTAssertEqual(settings.reminderMinutes(for: .fajr), 10)
    }

    func test_aCorruptRecordFallsBackToDefaultsFieldByField() throws {
        // Tek bir alanın bozuk olması ayarın tamamını çöpe atmamalı: kullanıcının seçtiği
        // vakitler duruyorken sesi varsayılana döndürmek, hepsini sıfırlamaktan iyi.
        let broken = """
        {"enabledPrayers": [0, 4], "notifyAtPrayerTime": "evet", "playsSound": true}
        """
        let settings = try decode(broken)
        XCTAssertEqual(settings.enabledPrayers, [.fajr, .maghrib])
        XCTAssertEqual(settings.notifyAtPrayerTime, NotificationSettings.default.notifyAtPrayerTime)
    }

    func test_roundTripKeepsPerPrayerReminders() throws {
        var settings = NotificationSettings()
        settings.setReminder(45, for: .fajr)
        settings.setReminder(5, for: .maghrib)

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(NotificationSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(decoded.reminderMinutes(for: .fajr), 45)
        XCTAssertEqual(decoded.reminderMinutes(for: .maghrib), 5)
    }

    func test_theLegacyKeyIsNoLongerWritten() throws {
        // Eski alan yazılmaya devam etseydi iki gerçek ortaya çıkardı ve bir gün
        // birbirinden ayrı düşerlerdi.
        var settings = NotificationSettings()
        settings.setReminderForAll(15)
        let json = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)
        XCTAssertFalse(json.contains("remindBeforeMinutes"))
    }

    // MARK: - Ayarlama

    func test_settingZeroOrNilRemovesTheReminder() {
        var settings = NotificationSettings()
        settings.setReminder(15, for: .asr)
        XCTAssertEqual(settings.reminderMinutes(for: .asr), 15)

        settings.setReminder(nil, for: .asr)
        XCTAssertNil(settings.reminderMinutes(for: .asr))

        settings.setReminder(0, for: .asr)
        XCTAssertNil(settings.reminderMinutes(for: .asr), "Sıfır dakika hatırlatma değildir")
    }

    func test_settingTheSamePrayerTwiceDoesNotDuplicate() {
        var settings = NotificationSettings()
        settings.setReminder(10, for: .isha)
        settings.setReminder(30, for: .isha)
        XCTAssertEqual(settings.reminders.count, 1)
        XCTAssertEqual(settings.reminderMinutes(for: .isha), 30)
    }

    func test_applyingToAllSkipsSunrise() {
        // Güneş kılınan bir vakit değil, sınır işareti. Ona hatırlatma kurmak bütçeden
        // boşuna yer yerdi.
        var settings = NotificationSettings()
        settings.setReminderForAll(10)
        XCTAssertEqual(settings.reminders.count, 5)
        XCTAssertNil(settings.reminderMinutes(for: .sunrise))
    }

    // MARK: - Bütçe

    func test_dailyCountAddsOnePerReminder() {
        var settings = NotificationSettings()
        XCTAssertEqual(settings.notificationsPerDay, 5, "Beş vakit, vakit girdiğinde")

        settings.setReminder(10, for: .fajr)
        XCTAssertEqual(settings.notificationsPerDay, 6)

        settings.setReminderForAll(10)
        XCTAssertEqual(settings.notificationsPerDay, 10, "Hatırlatma açıkken sayı ikiye katlanıyor")
    }

    func test_aDisabledPrayersReminderIsKeptButNotCounted() {
        // Vakti kapatınca süresinin silinmesi, tekrar açan kullanıcıyı yeniden ayar
        // yapmaya zorlardı. Saklanıyor ama bildirim kurulmadığı için bütçeden de yemiyor.
        var settings = NotificationSettings()
        settings.setReminderForAll(15)
        settings.enabledPrayers = [.fajr]

        XCTAssertEqual(settings.reminders.count, 5, "Ayar saklanmalı")
        XCTAssertEqual(settings.notificationsPerDay, 2, "Sadece sabah sayılmalı")
    }

    func test_silentWhenNothingWouldFire() {
        var settings = NotificationSettings()
        settings.notifyAtPrayerTime = false
        XCTAssertTrue(settings.isSilent, "Ne vakit bildirimi ne hatırlatma varsa sessiz")

        settings.setReminder(10, for: .dhuhr)
        XCTAssertFalse(settings.isSilent, "Tek bir hatırlatma bile sessizliği bozar")

        settings.enabledPrayers = []
        XCTAssertTrue(settings.isSilent, "Hiç vakit açık değilse hatırlatma da kurulmaz")
    }
}
