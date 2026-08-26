import SwiftUI
// `UIApplication.openSettingsURLString` için — SwiftUI'ın kendi yüzeyinde değil.
import UIKit
import NamazCore
import PrayerKit

/// Ana ekran — "Dizgi" yönü.
///
/// Düzen: üstte kalın bir kural çizgisi, altında serif şehir adı ve italik tarih satırı,
/// sonra saç teli çizgilerle ayrılmış altı satırlık defter, en altta çerçeveli geri sayım
/// kutusu. İkon yok, gradyan yok, kart yok — hiyerarşiyi tipografi ve boşluk kuruyor.
public struct HomeScreen: View {

    @State private var model: HomeViewModel
    @Environment(\.openURL) private var openURL

    public init(model: HomeViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ZStack {
            // Zemin açıkça boyanıyor: varsayılan sistem zemini bu paletin kâğıdı değil.
            Palette.ground.ignoresSafeArea()

            switch model.state {
            case .idle, .loading:
                LoadingView()
            case .locationDenied:
                LocationNoticeView(
                    title: L.t("home.denied.title"),
                    message: L.t("home.denied.body"),
                    primary: .init(title: L.t("home.denied.pick"), action: {}),
                    // Reddedilmiş izinde "tekrar dene" yok: sistem bir daha sormaz,
                    // düğme hiçbir şey yapmazdı. Tek gerçek yol Ayarlar.
                    secondary: .init(title: L.t("home.denied.settings"), action: openSettings)
                )
            case .locationUnavailable:
                LocationNoticeView(
                    title: L.t("home.unavailable.title"),
                    message: L.t("home.unavailable.body"),
                    // Burada tekrar denemek gerçekten işe yarayabilir, o yüzden birincil eylem o.
                    primary: .init(title: L.t("home.unavailable.retry"), action: { Task { await model.refresh() } }),
                    secondary: .init(title: L.t("home.unavailable.pick"), action: {})
                )
            case .ready(let schedule):
                ScheduleView(schedule: schedule)
            }
        }
        .task { await model.refresh() }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Hazır durum

private struct ScheduleView: View {
    let schedule: PrayerSchedule

    private var timeZone: TimeZone { schedule.location.coordinate.timeZone }

    var body: some View {
        // Geri sayım ve "şu anki vakit" vurgusu zamanla değişir. Bunu view model'de bir
        // Timer ile sürmek yerine TimelineView'a bırakıyoruz: ekran görünmediğinde tik
        // atılmıyor, dakikaya hizalı yenileniyor ve model test edilebilir kalıyor.
        TimelineView(.everyMinute) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(Palette.ink)
                    .frame(height: 2)
                    .accessibilityHidden(true)

                header

                PrayerLedger(
                    times: schedule.today.times,
                    currentPrayer: schedule.currentPrayer(at: now),
                    now: now,
                    timeZone: timeZone
                )
                .padding(.top, 22)

                Spacer(minLength: 24)

                if let next = schedule.nextPrayer(after: now) {
                    CountdownPanel(
                        prayer: next.prayer,
                        remaining: schedule.timeRemaining(at: now)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(schedule.location.name)
                .font(Typography.place)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(dateline)
                .font(Typography.dateline)
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var dateline: String {
        let gregorian = Formatting.gregorianLine(schedule.today.gregorianDate, in: timeZone)
        guard let hijri = schedule.today.hijriDate else { return gregorian }
        return "\(Formatting.hijriLine(hijri)) · \(gregorian)"
    }
}

// MARK: - Defter

private struct PrayerLedger: View {
    let times: [PrayerTime]
    let currentPrayer: Prayer?
    let now: Date
    let timeZone: TimeZone

    var body: some View {
        VStack(spacing: 0) {
            ForEach(times) { time in
                LedgerRow(
                    time: time,
                    isCurrent: time.prayer == currentPrayer,
                    isPast: time.date <= now,
                    timeZone: timeZone
                )
            }
        }
    }
}

private struct LedgerRow: View {
    let time: PrayerTime
    let isCurrent: Bool
    let isPast: Bool
    let timeZone: TimeZone

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var name: String { Formatting.prayerName(time.prayer) }
    private var clock: String { Formatting.clock(time.date, in: timeZone) }

    private var foreground: Color { isCurrent ? Palette.mark : Palette.ink }
    /// Geçmiş vakitler gizlenmiyor, geri çekiliyor — içinde bulunulan vakit hariç, o her
    /// hâlükârda vurgulu kalmalı.
    private var opacity: Double { (isPast && !isCurrent) ? Palette.pastOpacity : 1 }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Erişilebilirlik boyutlarında ad ve saat yan yana sığmıyor; çakışmak
                // yerine alt alta geçiyorlar.
                VStack(alignment: .leading, spacing: 2) {
                    nameText
                    clockText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    nameText
                    Spacer(minLength: 12)
                    clockText
                }
            }
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
        .opacity(opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenRow)
    }

    private var nameText: some View {
        Text(name)
            .font(Typography.prayerName)
            .fontWeight(isCurrent ? .medium : .regular)
            .foregroundStyle(foreground)
    }

    private var clockText: some View {
        Text(clock)
            .font(Typography.prayerTime)
            .fontWeight(isCurrent ? .medium : .regular)
            .foregroundStyle(foreground)
    }

    /// VoiceOver satırı tek parça okur ve durumu da söyler — görsel soluklaştırma ekran
    /// okuyucuya hiçbir şey anlatmaz, o bilgi metne girmek zorunda.
    private var spokenRow: String {
        if isCurrent {
            return L.t("home.accessibility.current %@ %@", name, clock)
        }
        return isPast
            ? L.t("home.accessibility.passed %@ %@", name, clock)
            : L.t("home.accessibility.upcoming %@ %@", name, clock)
    }
}

// MARK: - Geri sayım kutusu

private struct CountdownPanel: View {
    let prayer: Prayer
    let remaining: TimeInterval

    private var name: String { Formatting.prayerName(prayer) }

    var body: some View {
        HStack(alignment: .center) {
            Text(L.t("home.countdown.label %@", name))
                .microLabelStyle()
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            Text(Formatting.countdown(remaining))
                .font(Typography.countdown)
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay {
            Rectangle().stroke(Palette.rule, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L.t("home.accessibility.remaining %@ %@", name, Formatting.spokenCountdown(remaining))
        )
    }
}

// MARK: - Diğer durumlar

private struct LocationNoticeView: View {
    struct Action {
        let title: String
        let action: () -> Void
    }

    let title: String
    /// `body` DEĞİL: `View` protokolünün `body`'siyle çakışırdı ve derlenmezdi.
    let message: String
    let primary: Action
    let secondary: Action

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Palette.ink)
                .frame(height: 2)
                .padding(.bottom, 12)
                .accessibilityHidden(true)

            Text(title)
                .font(Font.system(.title2, design: .serif))
                .foregroundStyle(Palette.ink)

            Text(message)
                .font(Typography.prayerName)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(spacing: 10) {
                Button(primary.title, action: primary.action)
                    .buttonStyle(FilledButtonStyle())
                Button(secondary.title, action: secondary.action)
                    .buttonStyle(OutlineButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(Palette.rule).frame(height: 2)
            Rectangle().fill(Palette.rule).frame(width: 150, height: 30)
            Rectangle().fill(Palette.rule).frame(width: 210, height: 14)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("home.loading.accessibility"))
    }
}

// MARK: - Düğme biçimleri

private struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.prayerName)
            .foregroundStyle(Palette.ground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Palette.mark)
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.prayerName)
            .foregroundStyle(Palette.mark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .overlay { Rectangle().stroke(Palette.rule, lineWidth: 1) }
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Önizlemeler

#Preview("Hazır") {
    HomeScreen(model: HomeViewModel(
        locationService: StubLocationService(),
        manualLocation: SavedLocation(
            name: "İstanbul",
            coordinate: Coordinate(
                latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"
            ),
            source: .manual
        )
    ))
}

#Preview("İzin reddedildi") {
    HomeScreen(model: HomeViewModel(
        locationService: StubLocationService(authorization: .denied)
    ))
}

#Preview("Konum alınamadı") {
    HomeScreen(model: HomeViewModel(
        locationService: StubLocationService(authorization: .whenInUse, result: .failure(.unavailable))
    ))
}
