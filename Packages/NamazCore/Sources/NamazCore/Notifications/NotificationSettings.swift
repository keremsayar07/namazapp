import Foundation
import PrayerKit

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

    /// Vakitten kaç dakika önce ayrıca hatırlatılsın. `nil` = hatırlatma yok.
    ///
    /// **Bunun bir bedeli var ve kullanıcıya söylenmeli:** açıkken her vakit için iki
    /// bildirim planlanıyor, dolayısıyla iOS'un 64 bildirim sınırında kapsanan gün sayısı
    /// yarıya iniyor. `NotificationPlan.coveredDays` bu sayıyı geri veriyor ki ekran
    /// "önümüzdeki 6 gün" diye dürüstçe yazabilsin.
    public var remindBeforeMinutes: Int?

    /// Bildirim sesi çalsın mı. Kapalıysa sadece banner görünür.
    public var playsSound: Bool

    public init(
        enabledPrayers: [Prayer] = Prayer.allCases.filter(\.isPerformablePrayer),
        notifyAtPrayerTime: Bool = true,
        remindBeforeMinutes: Int? = nil,
        playsSound: Bool = true
    ) {
        self.enabledPrayers = enabledPrayers
        self.notifyAtPrayerTime = notifyAtPrayerTime
        self.remindBeforeMinutes = remindBeforeMinutes
        self.playsSound = playsSound
    }

    /// Hiç bildirim istenmiyor. Planlayıcı bu durumda boş plan üretiyor ve bekleyen
    /// bildirimler temizleniyor.
    public var isSilent: Bool {
        enabledPrayers.isEmpty || (!notifyAtPrayerTime && remindBeforeMinutes == nil)
    }

    public func isEnabled(_ prayer: Prayer) -> Bool {
        enabledPrayers.contains(prayer)
    }

    /// Varsayılan: beş vakit, vakit girdiğinde, sesli. Güneş yok — o bir sınır işareti,
    /// kılınan bir namaz değil.
    public static let `default` = NotificationSettings()
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
