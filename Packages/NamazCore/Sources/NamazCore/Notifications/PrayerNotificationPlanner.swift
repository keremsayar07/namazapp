import Foundation
import PrayerKit

/// Hangi bildirimin ne zaman kurulacağına karar veren saf hesap.
///
/// **Bu tasarımın etrafında döndüğü kısıt:** iOS bir uygulamaya aynı anda en fazla **64
/// bekleyen yerel bildirim** hakkı veriyor. 65'inciyi eklerseniz sistem sessizce en uzaktakini
/// atıyor — hata yok, uyarı yok. Biz ise günde 5 vakit × sonsuz gün istiyoruz.
///
/// Çözüm kayan pencere: bugünden başlayıp kapasite dolana kadar ileri gidiyoruz, sonra
/// uygulama her öne geldiğinde ve arka plan yenilemesinde pencereyi tazeliyoruz. Kullanıcı
/// uygulamayı haftalarca açmazsa bildirimler eninde sonunda tükenir — bunu gizlemek yerine
/// `coveredDays` ile açıkça raporluyoruz.
///
/// Hesabın kendisi saf: girdi olarak vakitleri üreten bir kapanış alıyor, sistem servisine
/// dokunmuyor. Bu yüzden 64 sınırı, gece yarısı sınırları ve geçmiş vakitler gerçek bir
/// cihaz olmadan test edilebiliyor.
public struct PrayerNotificationPlanner: Sendable {

    /// iOS'un sert sınırı 64. Biraz pay bırakıyoruz: ileride başka bir özellik (ör. bayram
    /// hatırlatması) bildirim kurarsa, vakit bildirimleri onu kenara itmesin.
    public static let systemLimit = 64
    public static let capacity = 58

    /// Ne kadar ileri gidileceğinin üst sınırı. Kapasite izin verse bile bir yıl ileri
    /// planlamanın anlamı yok: kullanıcı şehir değiştirebilir, ayarları değiştirebilir,
    /// yaz saati uygulaması değişebilir. Kısa pencere = daha az bayat bildirim.
    public static let maxDaysAhead = 30

    private let capacity: Int
    private let maxDaysAhead: Int

    public init(
        capacity: Int = PrayerNotificationPlanner.capacity,
        maxDaysAhead: Int = PrayerNotificationPlanner.maxDaysAhead
    ) {
        self.capacity = capacity
        self.maxDaysAhead = maxDaysAhead
    }

    /// `dailyTimes`: verilen takvim günü için vakitleri üreten kapanış.
    /// `now`: bu andan önceki hiçbir vakit planlanmıyor.
    public func plan(
        from now: Date,
        settings: NotificationSettings,
        timeZone: TimeZone,
        dailyTimes: (Date) -> DailyPrayerTimes
    ) -> NotificationPlan {
        guard !settings.isSilent else { return .empty }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var planned: [PlannedNotification] = []
        var coveredDays = 0
        var truncated = false

        let dayKeyFormatter = DateFormatter()
        dayKeyFormatter.calendar = calendar
        dayKeyFormatter.timeZone = timeZone
        dayKeyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayKeyFormatter.dateFormat = "yyyy-MM-dd"

        dayLoop: for dayOffset in 0..<maxDaysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { break }
            let times = dailyTimes(day)
            let dayKey = dayKeyFormatter.string(from: day)
            var addedThisDay = false

            for time in times.times {
                // Güneş kılınan bir vakit değil, sınır işareti — bildirimi olmaz.
                guard time.prayer.isPerformablePrayer else { continue }
                guard settings.isEnabled(time.prayer) else { continue }

                // Hatırlatma önce geliyor, sıralamayı bozmayalım.
                if let minutesBefore = settings.reminderMinutes(for: time.prayer), minutesBefore > 0 {
                    let fire = time.date.addingTimeInterval(-Double(minutesBefore) * 60)
                    if fire > now {
                        guard planned.count < capacity else { truncated = true; break dayLoop }
                        planned.append(PlannedNotification(
                            id: PlannedNotification.identifier(
                                prayer: time.prayer, kind: .reminder, dayKey: dayKey
                            ),
                            prayer: time.prayer,
                            kind: .reminder,
                            fireDate: fire,
                            prayerDate: time.date,
                            minutesBefore: minutesBefore
                        ))
                        addedThisDay = true
                    }
                }

                if settings.notifyAtPrayerTime, time.date > now {
                    guard planned.count < capacity else { truncated = true; break dayLoop }
                    planned.append(PlannedNotification(
                        id: PlannedNotification.identifier(
                            prayer: time.prayer, kind: .atTime, dayKey: dayKey
                        ),
                        prayer: time.prayer,
                        kind: .atTime,
                        fireDate: time.date,
                        prayerDate: time.date,
                        minutesBefore: nil
                    ))
                    addedThisDay = true
                }
            }

            if addedThisDay { coveredDays += 1 }
        }

        // Tetiklenme sırasına göre: iOS sıraya bakmıyor ama hata ayıklarken ve testte
        // okunabilir olması değerli.
        planned.sort { $0.fireDate < $1.fireDate }

        return NotificationPlan(
            notifications: planned,
            coveredDays: coveredDays,
            wasTruncated: truncated
        )
    }
}
