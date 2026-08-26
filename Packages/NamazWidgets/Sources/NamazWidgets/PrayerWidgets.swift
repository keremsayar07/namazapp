import SwiftUI
import WidgetKit

/// Ana ekran widget'ı: küçük ve orta boy.
///
/// `containerBackground` iOS 17'de zorunlu — onsuz widget App Store incelemesinden
/// dönüyor ve StandBy / kilit ekranı bağlamlarında yanlış çiziliyor.
public struct PrayerTimesWidget: Widget {
    public static let kind = "com.keremsayar.namaz.PrayerTimesWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            PrayerTimesWidgetEntryView(entry: entry)
                .containerBackground(WidgetTheme.ground, for: .widget)
        }
        .configurationDisplayName(W.t("widget.home.title"))
        .description(W.t("widget.home.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PrayerTimesWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumPrayerView(entry: entry)
        default:
            SmallPrayerView(entry: entry)
        }
    }
}

/// Kilit ekranı ve StandBy aksesuarları.
///
/// Ana ekran widget'ından ayrı bir `Widget` olarak tanımlı: kullanıcı ikisini bağımsız
/// ekleyip kaldırabilsin ve widget galerisinde ayrı görünsünler.
public struct PrayerLockScreenWidget: Widget {
    public static let kind = "com.keremsayar.namaz.PrayerLockScreenWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            PrayerLockScreenEntryView(entry: entry)
                // Aksesuarlarda zemin sistemin: kendi rengimizi koymak kilit ekranında
                // duvar kâğıdıyla çakışıyor.
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(W.t("widget.lock.title"))
        .description(W.t("widget.lock.description"))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct PrayerLockScreenEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularPrayerView(entry: entry)
        case .accessoryInline:
            InlinePrayerView(entry: entry)
        default:
            RectangularPrayerView(entry: entry)
        }
    }
}
