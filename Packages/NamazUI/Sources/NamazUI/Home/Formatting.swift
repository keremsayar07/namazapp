import Foundation
import PrayerKit

/// Ekranda görünen her sayının tek üretim yeri. Biçimlendirme mantığını görünümlerin içine
/// dağıtmamak, "bir ekranda 04:44, diğerinde 4:44" gibi tutarsızlıkları baştan engelliyor.
enum Formatting {

    /// Vakit saati, **konumun** saat diliminde.
    ///
    /// Cihazınkinde değil: kullanıcı yurt dışındayken memleketinin vaktine bakıyorsa,
    /// saatin orada kaça denk geldiğini görmesi gerekir.
    ///
    /// `.shortened` kullanılıyor, sabit "HH:mm" değil — cihazın 12/24 saat tercihi
    /// kullanıcının kararı, uygulamanın dayatacağı bir şey değil.
    static func clock(_ date: Date, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// Geri sayım: "1:36" biçiminde saat ve dakika.
    ///
    /// Saniye gösterilmiyor. Bir namaz vaktine kalan sürede saniye ne bilgi katıyor ne de
    /// sakin duruyor; ayrıca saniyelik yenileme pil yakar. Aşağı yuvarlanıyor, çünkü
    /// "1:36" yazarken gerçekte 1 saat 36 dakikadan az kalmış olması yanıltıcı olurdu.
    static func countdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return "\(hours):\(String(format: "%02d", minutes))"
    }

    /// Ekran okuyucu için geri sayım — "1:36" diye okunmaz, "1 saat 36 dakika" diye okunur.
    static func spokenCountdown(_ interval: TimeInterval) -> String {
        let style = Duration.UnitsFormatStyle(
            allowedUnits: [.hours, .minutes],
            width: .wide
        )
        return Duration.seconds(max(0, Int(interval))).formatted(style)
    }

    static func prayerName(_ prayer: Prayer) -> String {
        L.t(prayer.localizationKey)
    }

    /// "12 Rebiülevvel 1448". Ay adı yerelleştirmeden, sıra ise `hijri.dateline` anahtarından
    /// geliyor — bazı dillerde gün/ay/yıl sırası farklı.
    static func hijriLine(_ hijri: HijriDate) -> String {
        L.t(
            "hijri.dateline %@ %@ %@",
            String(hijri.day),
            L.t(hijri.monthLocalizationKey),
            String(hijri.year)
        )
    }

    /// Miladi tarih, konumun saat diliminde: "25 Ağustos 2026".
    static func gregorianLine(_ date: Date, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle(date: .long, time: .omitted)
        style.timeZone = timeZone
        return date.formatted(style)
    }
}
