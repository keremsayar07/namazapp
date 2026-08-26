import SwiftUI
// UIKit açıkça import ediliyor: `UIColor` ve `UITraitCollection` SwiftUI'ın kendi yüzeyi
// değil. SwiftUI çoğu durumda UIKit'i dolaylı olarak getiriyor ama bu garanti değil.
import UIKit

/// "Dizgi" yönünün paleti.
///
/// Renkler `Color(light:dark:)` ile tanımlandı, `@Environment(\.colorScheme)` ile değil:
/// böylece tema değişimini sistem çözüyor, her görünümde dallanma olmuyor ve widget
/// süreci gibi ortamlarda da doğru çalışıyor.
///
/// Nötrler bilinçli seçildi. Saf gri yerine hafif sıcak kırık beyaz ve mora kaçan koyu
/// zemin var; ikisi de kiremit vurgusuyla aynı sıcaklık ekseninde duruyor.
public enum Palette {
    /// Kâğıt. Saf beyaz değil — ekrana uzun bakılan bir uygulamada saf beyaz sert kalıyor.
    public static let ground = Color(light: 0xF3F1EC, dark: 0x16151A)
    /// Ana metin rengi.
    public static let ink = Color(light: 0x1B1A18, dark: 0xEDEAE4)
    /// İkincil metin: hicri tarih, geçmiş vakitler, mikro etiketler.
    public static let inkSoft = Color(light: 0x7A766D, dark: 0x7A7681)
    /// Saç teli çizgiler.
    public static let rule = Color(light: 0xDAD6CC, dark: 0x262430)
    /// Tek vurgu rengi — kiremit. Yalnızca içinde bulunulan vakti ve birincil eylemi işaretler.
    public static let mark = Color(light: 0x7C3A2E, dark: 0xC4705C)

    /// Geçmiş vakitlerin soluklaştırma oranı. Gizlemiyoruz, geri çekiyoruz.
    public static let pastOpacity: Double = 0.42
}

extension Color {
    /// Hex sabitlerinden açık/koyu çifti kurar. Asset kataloğu gerektirmiyor, bu yüzden
    /// palet tek bir Swift dosyasında okunabilir hâlde duruyor.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Tipografi

/// Yön C'nin tipografisi sistem yazı tiplerine dayanıyor: serif için New York, rakamlar için
/// SF'in tabular varyantı. Yazı tipi paketlemiyoruz — Dinamik Yazı Tipi, optik boyutlar ve
/// tüm dil desteği hazır geliyor, uygulama boyutu da büyümüyor.
public enum Typography {
    /// Şehir adı. Serif, geniş, sayfa başlığı gibi.
    public static let place = Font.system(.largeTitle, design: .serif).weight(.regular)
    /// Hicri tarih. İtalik serif — başlığın altında ikinci bir ses.
    public static let dateline = Font.system(.subheadline, design: .serif).italic()
    /// Defterdeki vakit adları.
    public static let prayerName = Font.system(.body, design: .serif)
    /// Vakit saatleri. Tabular: rakamlar alt alta hizalanmalı.
    public static let prayerTime = Font.system(.callout, design: .monospaced).monospacedDigit()
    /// Geri sayımın kendisi.
    public static let countdown = Font.system(.title, design: .serif).monospacedDigit()
    /// Büyük harfli mikro etiketler.
    public static let microLabel = Font.system(.caption2, design: .monospaced)
}

extension View {
    /// Mikro etiket biçimi: büyük harf, harf aralığı açılmış, ikincil renk.
    func microLabelStyle(color: Color = Palette.inkSoft) -> some View {
        self
            .font(Typography.microLabel)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}
