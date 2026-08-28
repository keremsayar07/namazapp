import Foundation
import OSLog

/// Uygulamanın tek günlük (log) yüzeyi.
///
/// **Tasarımın tek fikri: hassas veriyi loglamak mümkün olmasın.**
///
/// Alışıldık yol `logger.debug("konum: \(location)")` yazmaktır ve `%{private}` gibi
/// işaretlerle korunmaya çalışılır. O yaklaşımın sorunu, doğruluğun her çağrı yerinde
/// yeniden sağlanmak zorunda olması: yüz çağrının doksan dokuzu doğru olsa bile biri
/// kullanıcının notunu ya da koordinatını sistem günlüğüne düşürür ve kimse fark etmez.
///
/// Burada API **serbest metin almıyor**. Kaydedilebilecek her şey `Event` içinde sayılı bir
/// durum ve yanında yalnızca hassas olmayan değerler taşıyor: sayılar, bayraklar, enum
/// durumları. Not gövdesi, arama metni, koordinat, konum adı, parola, jeton — bunları
/// geçirebileceğin bir parametre yok. Yanlış kullanım derlenmiyor.
///
/// Yasak listesi (kullanıcının koyduğu kural): parolalar, API anahtarları, jetonlar, kesin
/// konum, özel notlar ve kişisel içerik loglanmaz. Yukarıdaki tasarım bu listeyi bir
/// hatırlatma olmaktan çıkarıp tip sisteminin sorunu haline getiriyor.
public enum Diagnostics {

    /// Alt sistem adı bundle kimliğiyle aynı: Console.app'te uygulamanın kendi satırlarını
    /// süzmek için.
    private static let subsystem = "com.keremsayar.namaz"

    public enum Category: String, Sendable {
        case location
        case notifications
        case storage
        case security
        case widget
    }

    /// Kaydedilebilecek olayların tamamı.
    ///
    /// Yeni bir olay eklerken kural basit: ilişkili değer olarak yalnızca **kullanıcıya ait
    /// olmayan** bir şey taşıyabilir. "Kaç tane" sorulur, "hangisi" sorulmaz.
    public enum Event: Sendable {

        // Konum
        /// Konum izni sonucu. Koordinat YOK — sadece izin durumu.
        case locationAuthorization(LocationAuthorization)
        /// Konum çözüldü. Enlem/boylam bilerek taşınmıyor.
        case locationResolved(source: LocationSource)
        case locationFailed(LocationFailure)

        // Bildirimler
        case notificationsScheduled(count: Int, coveredDays: Int, truncated: Bool)
        case notificationsCleared
        case notificationAuthorization(granted: Bool)

        // Depolama
        /// Dosya adı DEĞİL, deponun mantıksal adı; dosya adları koddan geliyor ve kullanıcı
        /// içeriği taşımıyor.
        case storeLoadFailed(store: String)
        case storeWriteFailed(store: String)
        case storeUnavailable

        // Güvenlik
        case biometricUnavailable
        case biometricResult(granted: Bool)
        case userDataDeleted(fileCount: Int)

        // Widget
        case widgetTimelineBuilt(entryCount: Int)
        case widgetHasNoLocation

        var category: Category {
            switch self {
            case .locationAuthorization, .locationResolved, .locationFailed:
                return .location
            case .notificationsScheduled, .notificationsCleared, .notificationAuthorization:
                return .notifications
            case .storeLoadFailed, .storeWriteFailed, .storeUnavailable:
                return .storage
            case .biometricUnavailable, .biometricResult, .userDataDeleted:
                return .security
            case .widgetTimelineBuilt, .widgetHasNoLocation:
                return .widget
            }
        }

        var level: OSLogType {
            switch self {
            case .locationFailed, .storeLoadFailed, .storeWriteFailed, .storeUnavailable:
                return .error
            default:
                return .info
            }
        }

        /// Günlüğe düşen metin. Testler bunu okuyup içinde kullanıcı verisi olmadığını
        /// doğruluyor.
        public var message: String {
            switch self {
            case .locationAuthorization(let status):
                return "konum izni: \(status)"
            case .locationResolved(let source):
                return "konum çözüldü: \(source)"
            case .locationFailed(let reason):
                return "konum alınamadı: \(reason)"
            case .notificationsScheduled(let count, let days, let truncated):
                return "bildirim kuruldu: \(count) adet, \(days) gün, kesildi=\(truncated)"
            case .notificationsCleared:
                return "bekleyen bildirimler temizlendi"
            case .notificationAuthorization(let granted):
                return "bildirim izni: \(granted)"
            case .storeLoadFailed(let store):
                return "depo okunamadı: \(store)"
            case .storeWriteFailed(let store):
                return "depo yazılamadı: \(store)"
            case .storeUnavailable:
                return "paylaşılan kap kullanılamıyor"
            case .biometricUnavailable:
                return "cihazda biyometri ya da parola tanımlı değil"
            case .biometricResult(let granted):
                return "kilit açma: \(granted)"
            case .userDataDeleted(let fileCount):
                return "kullanıcı verisi silindi: \(fileCount) dosya"
            case .widgetTimelineBuilt(let entryCount):
                return "widget zaman çizelgesi: \(entryCount) kayıt"
            case .widgetHasNoLocation:
                return "widget için konum yok"
            }
        }
    }

    /// Konumun nereden geldiği — koordinatın kendisi değil.
    public enum LocationSource: String, Sendable {
        case device
        case manual
        case lastKnown
    }

    public enum LocationFailure: String, Sendable {
        case unauthorized
        case servicesDisabled
        case timedOut
        case unknown
    }

    // MARK: - Yazma

    private static let loggers: [Category: Logger] = {
        var result: [Category: Logger] = [:]
        for category in [Category.location, .notifications, .storage, .security, .widget] {
            result[category] = Logger(subsystem: subsystem, category: category.rawValue)
        }
        return result
    }()

    public static func log(_ event: Event) {
        guard let logger = loggers[event.category] else { return }
        // `%{public}` bilinçli: `message` yalnızca sayılardan ve sabit metinlerden oluşuyor,
        // içine kullanıcı verisi girmesinin yolu yok. Herkese açık olması, cihazdan alınan
        // bir günlükte satırların `<private>` diye maskelenmemesini sağlıyor — aksi halde
        // hiçbir işe yaramazdı.
        logger.log(level: event.level, "\(event.message, privacy: .public)")
    }
}
