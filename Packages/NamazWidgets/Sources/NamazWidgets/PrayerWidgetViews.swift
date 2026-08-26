import SwiftUI
import WidgetKit
import NamazCore
import PrayerKit

// MARK: - Ana ekran: küçük

/// Sıradaki vakit ve geri sayım.
///
/// Geri sayım için zaman çizelgesine giriş eklemiyoruz — `Text(date, style: .relative)`
/// kendi kendini tazeliyor. Dakikada bir giriş üretmek widget'ın uyanma bütçesini boşa
/// harcar ve iOS bir süre sonra çizelgeyi yenilemeyi seyrekleştirir.
struct SmallPrayerView: View {
    let entry: PrayerEntry

    var body: some View {
        if let schedule = entry.schedule, let next = entry.nextPrayer {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(WidgetTheme.ink).frame(height: 1.5)

                Text(schedule.location.name)
                    .font(WidgetTheme.place)
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(WidgetTheme.inkSoft)
                    .lineLimit(1)
                    .padding(.top, 7)

                Spacer(minLength: 4)

                Text(W.prayerName(next.prayer))
                    .font(WidgetTheme.headline)
                    .foregroundStyle(WidgetTheme.mark)

                Text(W.clock(next.date, in: schedule.location.coordinate.timeZone))
                    .font(WidgetTheme.prayerTime)
                    .foregroundStyle(WidgetTheme.ink)

                Spacer(minLength: 4)

                Text(next.date, style: .relative)
                    .font(WidgetTheme.prayerTime)
                    .foregroundStyle(WidgetTheme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            EmptyStateView()
        }
    }
}

// MARK: - Ana ekran: orta

/// Günün tamamı — uygulamadaki defterin küçültülmüş hâli.
struct MediumPrayerView: View {
    let entry: PrayerEntry

    var body: some View {
        if let schedule = entry.schedule {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(WidgetTheme.ink).frame(height: 1.5)

                HStack(alignment: .firstTextBaseline) {
                    Text(schedule.location.name)
                        .font(WidgetTheme.place)
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundStyle(WidgetTheme.inkSoft)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let next = entry.nextPrayer {
                        Text(next.date, style: .relative)
                            .font(WidgetTheme.place)
                            .foregroundStyle(WidgetTheme.mark)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 6)

                // Altı vakit iki sütunda: tek sütunda satırlar çok sıkışıyor, üç sütunda
                // ad ve saat aynı hizada durmuyor.
                let times = schedule.today.times
                HStack(alignment: .top, spacing: 14) {
                    column(Array(times.prefix(3)), schedule: schedule)
                    column(Array(times.suffix(3)), schedule: schedule)
                }
            }
        } else {
            EmptyStateView()
        }
    }

    private func column(_ times: [PrayerTime], schedule: PrayerSchedule) -> some View {
        VStack(spacing: 0) {
            ForEach(times) { time in
                let isCurrent = time.prayer == entry.currentPrayer
                let isPast = time.date <= entry.date

                HStack(alignment: .firstTextBaseline) {
                    Text(W.prayerName(time.prayer))
                        .font(WidgetTheme.prayerName)
                    Spacer(minLength: 6)
                    Text(W.clock(time.date, in: schedule.location.coordinate.timeZone))
                        .font(WidgetTheme.prayerTime)
                }
                .foregroundStyle(isCurrent ? WidgetTheme.mark : WidgetTheme.ink)
                .opacity((isPast && !isCurrent) ? WidgetTheme.pastOpacity : 1)
                .padding(.vertical, 2.5)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(WidgetTheme.rule).frame(height: 0.5)
                }
            }
        }
    }
}

// MARK: - Kilit ekranı

/// Yuvarlak aksesuar: vakit kısaltması ve saati.
///
/// Kilit ekranı aksesuarları sistem tarafından tek renge indirgeniyor (vibrant render).
/// Bu yüzden burada renk kullanmıyoruz — kullansak da görünmezdi. Hiyerarşi yalnızca
/// boyut ve ağırlıkla kuruluyor.
struct CircularPrayerView: View {
    let entry: PrayerEntry

    var body: some View {
        if let schedule = entry.schedule, let next = entry.nextPrayer {
            VStack(spacing: 0) {
                Text(W.prayerName(next.prayer))
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(W.clock(next.date, in: schedule.location.coordinate.timeZone))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .widgetAccessoryPadding()
        } else {
            Image(systemName: "location.slash")
        }
    }
}

/// Dikdörtgen aksesuar: vakit, saat ve geri sayım birlikte.
struct RectangularPrayerView: View {
    let entry: PrayerEntry

    var body: some View {
        if let schedule = entry.schedule, let next = entry.nextPrayer {
            VStack(alignment: .leading, spacing: 1) {
                Text(schedule.location.name)
                    .font(.system(size: 11, design: .monospaced))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .widgetAccessoryTint()

                Text(W.prayerName(next.prayer) + " · " + W.clock(next.date, in: schedule.location.coordinate.timeZone))
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .lineLimit(1)

                Text(next.date, style: .relative)
                    .font(.system(size: 12, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .widgetAccessoryTint()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(W.t("widget.empty.short"))
                .font(.system(size: 13, design: .serif))
        }
    }
}

/// Satır aksesuarı: kilit ekranında saatin hemen üstündeki tek satır.
struct InlinePrayerView: View {
    let entry: PrayerEntry

    var body: some View {
        if let schedule = entry.schedule, let next = entry.nextPrayer {
            Text("\(W.prayerName(next.prayer)) \(W.clock(next.date, in: schedule.location.coordinate.timeZone))")
        } else {
            Text(W.t("widget.empty.short"))
        }
    }
}

// MARK: - Şehir yok

/// Widget CoreLocation'ı kullanamıyor. Kullanıcı uygulamayı hiç açmadıysa ya da konum
/// izni yoksa gösterecek vakit yok — bunu boş bir kutu yerine söylüyoruz.
private struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(WidgetTheme.ink).frame(height: 1.5)
            Spacer(minLength: 0)
            Text(W.t("widget.empty.title"))
                .font(WidgetTheme.prayerName)
                .foregroundStyle(WidgetTheme.ink)
            Text(W.t("widget.empty.body"))
                .font(WidgetTheme.place)
                .foregroundStyle(WidgetTheme.inkSoft)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Küçük yardımcılar

extension View {
    /// Kilit ekranı aksesuarlarında sistemin ikincil vurgusu.
    func widgetAccessoryTint() -> some View {
        self.foregroundStyle(.secondary)
    }

    /// Yuvarlak aksesuarda içerik kenarlara değmesin.
    func widgetAccessoryPadding() -> some View {
        self.padding(2)
    }
}
