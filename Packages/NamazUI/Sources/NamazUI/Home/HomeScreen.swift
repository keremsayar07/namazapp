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
    @State private var isPickingCity = false
    @Environment(\.openURL) private var openURL

    private let citySearch: CitySearching

    public init(model: HomeViewModel, citySearch: CitySearching) {
        _model = State(initialValue: model)
        self.citySearch = citySearch
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
                    primary: .init(title: L.t("home.denied.pick"), action: pickCity),
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
                    secondary: .init(title: L.t("home.unavailable.pick"), action: pickCity)
                )
            case .ready(let schedule):
                ScheduleView(schedule: schedule, changeCity: pickCity)
            }
        }
        .task { await model.refresh() }
        .sheet(isPresented: $isPickingCity) {
            CityPickerScreen(
                model: CityPickerViewModel(search: citySearch),
                onSelect: { model.selectManualLocation($0) }
            )
        }
    }

    private func pickCity() {
        isPickingCity = true
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Hazır durum

private struct ScheduleView: View {
    let schedule: PrayerSchedule
    let changeCity: () -> Void

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

                // Yalnızca ramazanda görünüyor; kendi içinde karar veriyor. Yılın on bir
                // ayında boş bir kutu bırakmamak için `if` burada değil, şeridin içinde.
                RamadanStrip(schedule: schedule, now: now)

                PrayerLedger(
                    times: schedule.today.times,
                    currentPrayer: schedule.currentPrayer(at: now),
                    // Ana ekranda "geçti" vurgusu var: gün içindeyiz, hangi vakitlerin
                    // arkada kaldığı doğrudan işe yarayan bir bilgi.
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
        HStack(alignment: .firstTextBaseline, spacing: 12) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            // Görünür bir "Değiştir" bağlantısı. Şehir adına gizlice dokunmak da işe
            // yarardı ama kimse denemez; keşfedilemeyen arayüz, olmayan arayüzdür.
            Button(L.t("home.change_location"), action: changeCity)
                .microLabelStyle(color: Palette.mark)
                .accessibilityLabel(L.t("home.change_location.accessibility"))
        }
        .padding(.top, 14)
    }

    private var dateline: String {
        let gregorian = Formatting.gregorianLine(schedule.today.gregorianDate, in: timeZone)
        guard let hijri = schedule.today.hijriDate else { return gregorian }
        return "\(Formatting.hijriLine(hijri)) · \(gregorian)"
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
    HomeScreen(
        model: HomeViewModel(
            locationService: StubLocationService(),
            manualLocation: SavedLocation(
                name: "İstanbul",
                coordinate: Coordinate(
                    latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"
                ),
                source: .manual
            )
        ),
        citySearch: StubCitySearch()
    )
}

#Preview("İzin reddedildi") {
    HomeScreen(
        model: HomeViewModel(locationService: StubLocationService(authorization: .denied)),
        citySearch: StubCitySearch()
    )
}

#Preview("Konum alınamadı") {
    HomeScreen(
        model: HomeViewModel(
            locationService: StubLocationService(authorization: .whenInUse, result: .failure(.unavailable))
        ),
        citySearch: StubCitySearch()
    )
}
