import Foundation
import PrayerKit

/// Tek bir vakit için hatırlatma süresi.
///
/// Sözlük (`[Prayer: Int]`) değil dizi: `Prayer` `Int` ham değerli bir enum ve sözlük
/// anahtarı olarak JSON'a düz bir nesne değil, sıralı `[anahtar, değer, anahtar, değer]`
/// dizisi olarak yazılıyor. Kaydı gözle okumak gerektiğinde bu biçim insanı yanıltıyor;
/// açık bir yapı hem okunur hem de ileride "ses dosyası" gibi bir alan eklenirse yeri hazır.
public struct PrayerReminder: Codable, Sendable, Hashable, Identifiable {
    public var prayer: Prayer
    /// Vakitten kaç dakika önce. Her zaman pozitif — sıfır "hatırlatma yok" demek ve o
    /// durumda kayıt hiç tutulmuyor.
    public var minutes: Int

    public var id: Prayer { prayer }

    public init(prayer: Prayer, minutes: Int) {
        self.prayer = prayer
        self.minutes = minutes
    }
}

/// Kullanıcının bildirim tercihleri.
public struct NotificationSettings: Codable, Sendable, Hashable {

    /// Hangi vakitler için bildirim gelsin.
    ///
    /// `Set<Prayer>` yerine dizi: `Set` de `Codable` ama JSON'da sırasız çıkıyor ve
    /// kayıtları gözle karşılaştırmayı zorlaştırıyor. Sıra burada anlamlı değil ama
    /// okunabilirlik değerli.
    public var enabledPrayers: [Prayer]

    /// Vakit girdiğinde bildirim gelsin mi.
    public var notifyAtPrayerTime: Bool

    /// Vakit başına hatırlatma süreleri. Listede olmayan vakit için hatırlatma yok.
    ///
    /// **Tek bir genel süre yerine vakit başına olmasının sebebi** sabahla akşamın aynı
    /// şey olmaması: imsağa 45 dakika önceden uyandırılmak isteyen biri, akşam ezanından
    /// 45 dakika önce bildirim istemez. Tek sayı bu iki ihtiyacı aynı anda karşılayamıyordu.
    ///
    /// **Bedeli var ve kullanıcıya söyleniyor:** her hatırlatma günlük bildirim sayısını
    /// bir artırıyor ve iOS'un 64 bekleyen bildirim sınırında kapsanan gün sayısını
    /// düşürüyor. `notificationsPerDay` bu sayıyı ekrana veriyor.
    public var reminders: [PrayerReminder]

    /// Bildirim sesi çalsın mı. Kapalıysa sadece banner görünür.
    public var playsSound: Bool

    public init(
        enabledPrayers: [Prayer] = Prayer.allCases.filter(\.isPerformablePrayer),
        notifyAtPrayerTime: Bool = true,
        reminders: [PrayerReminder] = [],
        playsSound: Bool = true
    ) {
        self.enabledPrayers = enabledPrayers
        self.notifyAtPrayerTime = notifyAtPrayerTime
        self.reminders = reminders
        self.playsSound = playsSound
    }

    // MARK: - Sorgular

    public func isEnabled(_ prayer: Prayer) -> Bool {
        enabledPrayers.contains(prayer)
    }

    /// Bu vakit için hatırlatma süresi, yoksa `nil`.
    public func reminderMinutes(for prayer: Prayer) -> Int? {
        reminders.first { $0.prayer == prayer }?.minutes
    }

    /// Hatırlatmayı ayarlar; `nil` veya sıfırdan küçük bir değer hatırlatmayı kaldırır.
    public mutating func setReminder(_ minutes: Int?, for prayer: Prayer) {
        reminders.removeAll { $0.prayer == prayer }
        if let minutes, minutes > 0 {
            reminders.append(PrayerReminder(prayer: prayer, minutes: minutes))
            reminders.sort { $0.prayer.rawValue < $1.prayer.rawValue }
        }
    }

    /// Aynı süreyi kılınan bütün vakitlere uygular; `nil` hepsini kaldırır.
    ///
    /// Beş vakti tek tek ayarlamak isteyen azınlık; çoğunluk "hepsi 15 dakika" diyor.
    /// Ekrandaki "hepsine uygula" satırı bunu çağırıyor.
    public mutating func setReminderForAll(_ minutes: Int?) {
        for prayer in Prayer.allCases where prayer.isPerformablePrayer {
            setReminder(minutes, for: prayer)
        }
    }

    /// Günde kaç bildirim kurulacağı. Kapalı vakitlerin hatırlatması sayılmıyor: ayar
    /// saklanıyor (kullanıcı vakti tekrar açtığında süresi geri gelsin diye) ama bildirim
    /// kurulmuyor, dolayısıyla bütçeden de yemiyor.
    public var notificationsPerDay: Int {
        var count = 0
        for prayer in enabledPrayers where prayer.isPerformablePrayer {
            if notifyAtPrayerTime { count += 1 }
            if reminderMinutes(for: prayer) != nil { count += 1 }
        }
        return count
    }

    /// Hiç bildirim istenmiyor. Planlayıcı bu durumda boş plan üretiyor ve bekleyen
    /// bildirimler temizleniyor.
    public var isSilent: Bool { notificationsPerDay == 0 }

    /// Varsayılan: beş vakit, vakit girdiğinde, sesli. Güneş yok — o bir sınır işareti,
    /// kılınan bir namaz değil. Hatırlatma yok: kullanıcının istemediği ikinci bir bildirim
    /// akışını varsayılan yapmak, bütçeyi de yarıya indirirdi.
    public static let `default` = NotificationSettings()

    // MARK: - Kodlama ve eski kayıttan geçiş

    private enum CodingKeys: String, CodingKey {
        case enabledPrayers, notifyAtPrayerTime, reminders, playsSound
    }

    /// Eski sürümde tek bir genel süre vardı: `remindBeforeMinutes`.
    private enum LegacyKeys: String, CodingKey {
        case remindBeforeMinutes
    }

    /// **Geçiş burada oluyor ve sessizce çalışması önemli.**
    ///
    /// Güncellemeden önce "20 dakika önce hatırlat" demiş bir kullanıcının kaydında
    /// `reminders` yok, `remindBeforeMinutes` var. Çözümleme başarısız sayılsaydı ayar
    /// varsayılana döner, kullanıcı bir sabah hatırlatmasının kaybolduğunu fark ederdi.
    /// Bunun yerine eski değer açık olan her vakte uygulanıyor: davranış güncellemeden
    /// önceki gün neyse aynısı kalıyor.
    ///
    /// Alanlar tek tek ve toleranslı okunuyor; eksik bir alan varsayılanına düşüyor,
    /// tamamı çözümlenemezse `Preferences` zaten varsayılana dönüyor.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = NotificationSettings.default

        let enabled = (try? container.decode([Prayer].self, forKey: .enabledPrayers))
            ?? fallback.enabledPrayers

        self.enabledPrayers = enabled
        self.notifyAtPrayerTime = (try? container.decode(Bool.self, forKey: .notifyAtPrayerTime))
            ?? fallback.notifyAtPrayerTime
        self.playsSound = (try? container.decode(Bool.self, forKey: .playsSound))
            ?? fallback.playsSound

        if let stored = try? container.decode([PrayerReminder].self, forKey: .reminders) {
            // Yeni alan varsa doğru olan o. Eski alan bir kez yazıldıktan sonra
            // güncellenmiyor; ona bakmak bayat veriyi geri getirirdi.
            self.reminders = stored
                .filter { $0.minutes > 0 }
                .sorted { $0.prayer.rawValue < $1.prayer.rawValue }
        } else if
            let legacy = try? decoder.container(keyedBy: LegacyKeys.self),
            // `decodeIfPresent` DEĞİL: onun `Int?` dönüşü `try?` ile iç içe iki katmanlı
            // bir isteğe bağlı üretiyor ve okunmaz hale geliyor. `decode` alan yoksa da
            // `null` ise de fırlatıyor — burada istediğimiz tam olarak bu.
            let minutes = try? legacy.decode(Int.self, forKey: .remindBeforeMinutes),
            minutes > 0
        {
            self.reminders = enabled
                .filter(\.isPerformablePrayer)
                .sorted { $0.rawValue < $1.rawValue }
                .map { PrayerReminder(prayer: $0, minutes: minutes) }
        } else {
            self.reminders = []
        }
    }
}

/// Planlanmış tek bir bildirim.
public struct PlannedNotification: Sendable, Hashable, Identifiable {

    public enum Kind: String, Sendable, Hashable {
        /// Vaktin kendisi.
        case atTime
        /// Vakitten önce hatırlatma.
        case reminder
    }

    /// Kimlik tarihten ve vakitten türetiliyor, rastgele değil.
    ///
    /// Böylece yeniden planlama **idempotent** oluyor: aynı gün ve vakit için iki kez
    /// planlanırsa iOS ikincisini birincinin üzerine yazıyor, kullanıcı aynı ezanı iki kez
    /// almıyor. Rastgele kimlikle bu garanti kaybolurdu.
    public var id: String
    public var prayer: Prayer
    public var kind: Kind
    /// Bildirimin tetikleneceği an.
    public var fireDate: Date
    /// Vaktin kendisi — hatırlatmada gövde metni "20 dakika sonra" derken buna ihtiyaç var.
    public var prayerDate: Date
    /// `reminder` için kaç dakika önce olduğu; `atTime` için `nil`.
    public var minutesBefore: Int?

    public init(
        id: String, prayer: Prayer, kind: Kind,
        fireDate: Date, prayerDate: Date, minutesBefore: Int?
    ) {
        self.id = id
        self.prayer = prayer
        self.kind = kind
        self.fireDate = fireDate
        self.prayerDate = prayerDate
        self.minutesBefore = minutesBefore
    }

    static func identifier(prayer: Prayer, kind: Kind, dayKey: String) -> String {
        "namaz.\(dayKey).\(prayer.rawValue).\(kind.rawValue)"
    }
}

/// Planlayıcının çıktısı.
public struct NotificationPlan: Sendable, Hashable {
    public var notifications: [PlannedNotification]
    /// Kaç günlük ileriye dönük kapsama sağlandı. Ekranda kullanıcıya söylemek için —
    /// "bildirimler önümüzdeki N gün için ayarlandı" demek, sessizce yetersiz kalmaktan iyi.
    public var coveredDays: Int
    /// Kapasite dolduğu için plan kesildi mi.
    public var wasTruncated: Bool

    public init(notifications: [PlannedNotification], coveredDays: Int, wasTruncated: Bool) {
        self.notifications = notifications
        self.coveredDays = coveredDays
        self.wasTruncated = wasTruncated
    }

    public static let empty = NotificationPlan(notifications: [], coveredDays: 0, wasTruncated: false)
}
