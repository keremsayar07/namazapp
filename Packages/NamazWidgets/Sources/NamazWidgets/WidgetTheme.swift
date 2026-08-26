import SwiftUI
import UIKit
import PrayerKit

/// Widget'ın paleti ve tipografisi.
///
/// `NamazUI`'nin `Palette`'i kopyalanmadı, yeniden tanımlandı — çünkü widget farklı bir
/// bağlamda yaşıyor: ana ekranda kullanıcının duvar kâğıdının üstünde, kilit ekranında ise
/// sistemin dayattığı tek renkli (vibrant) katmanda. Aynı değerler ama farklı kurallar.
enum WidgetTheme {
    static let ground = Color(light: 0xF3F1EC, dark: 0x16151A)
    static let ink = Color(light: 0x1B1A18, dark: 0xEDEAE4)
    static let inkSoft = Color(light: 0x7A766D, dark: 0x7A7681)
    static let rule = Color(light: 0xDAD6CC, dark: 0x262430)
    static let mark = Color(light: 0x7C3A2E, dark: 0xC4705C)

    static let pastOpacity: Double = 0.4

    static let place = Font.system(.caption2, design: .monospaced)
    static let prayerName = Font.system(.footnote, design: .serif)
    static let prayerTime = Font.system(.footnote, design: .monospaced).monospacedDigit()
    static let headline = Font.system(.title3, design: .serif)
    static let countdown = Font.system(.title2, design: .serif).monospacedDigit()
}

extension Color {
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

/// Widget metinleri. `Bundle.module` bu paketin kendi kaynak paketi.
enum W {
    static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }

    static func t(_ key: String, _ first: String) -> String {
        String(format: t(key), first)
    }

    static func prayerName(_ prayer: Prayer) -> String {
        t(prayer.localizationKey)
    }

    /// Vakit saati, konumun saat diliminde — cihazınkinde değil.
    static func clock(_ date: Date, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return date.formatted(style)
    }
}
