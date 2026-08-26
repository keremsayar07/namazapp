import SwiftUI
import NamazCore

/// Uygulamanın gezinme iskeleti: dört sekme.
///
/// `NavigationSplitView` değil `TabView` — v1 iPhone. iPad'e geçildiğinde bu tip
/// değişecek ama sekmelerin içeriği aynı kalacak; bu yüzden her sekmenin kökü bağımsız
/// bir görünüm, sekme çubuğuna bağlı hiçbir şey bilmiyor.
public struct RootTabView: View {

    private let dependencies: Dependencies
    @Environment(\.scenePhase) private var scenePhase

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        TabView {
            HomeScreen(model: dependencies.homeModel, citySearch: dependencies.citySearch)
                .tabItem { Label(L.t("tab.times"), systemImage: "clock") }

            // Takvim kendi konumunu tutmuyor: Vakit sekmesindeki tek gerçeği okuyor.
            // Kullanıcı orada şehri değiştirdiğinde takvim de aynı anda değişiyor.
            CalendarScreen(
                location: dependencies.homeModel.state.schedule?.location,
                calculationSettings: dependencies.homeModel.settings
            )
            .tabItem { Label(L.t("tab.calendar"), systemImage: "calendar") }

            PlaceholderScreen(name: L.t("tab.qibla"))
                .tabItem { Label(L.t("tab.qibla"), systemImage: "location.north.line") }

            NotificationSettingsScreen(
                coordinator: dependencies.notifications,
                location: dependencies.homeModel.state.schedule?.location,
                calculationSettings: dependencies.homeModel.settings
            )
            .tabItem { Label(L.t("tab.settings"), systemImage: "gearshape") }
        }
        .tint(Palette.mark)
        .task { await rescheduleNotifications() }
        // Bildirim penceresi kayan bir pencere: iOS'un 64 bildirim sınırı yüzünden ancak
        // ~10 gün ileriyi kapsıyor. Uygulama her öne geldiğinde tazeliyoruz — kullanıcı
        // uygulamayı düzenli açtığı sürece bildirimler hiç tükenmiyor.
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            Task { await rescheduleNotifications() }
        }
        // Şehir değiştiğinde bildirimler de değişmeli: eski şehrin vaktinde çalan bir ezan,
        // hiç bildirim gelmemesinden kötü.
        .onChange(of: dependencies.homeModel.state.schedule?.location) {
            Task { await rescheduleNotifications() }
        }
    }

    private func rescheduleNotifications() async {
        await dependencies.notifications.reschedule(
            location: dependencies.homeModel.state.schedule?.location,
            calculationSettings: dependencies.homeModel.settings
        )
    }
}

/// Sonraki fazlarda dolacak sekmeler. Boş bir ekran göstermek yerine ne olduğunu söylüyor —
/// geliştirme sırasında bile "bozuk mu, boş mu" sorusunu ortadan kaldırıyor.
struct PlaceholderScreen: View {
    let name: String

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Rectangle()
                    .fill(Palette.ink)
                    .frame(height: 2)
                    .padding(.bottom, 12)
                    .accessibilityHidden(true)

                Text(L.t("placeholder.title %@", name))
                    .font(Font.system(.title2, design: .serif))
                    .foregroundStyle(Palette.ink)

                Text(L.t("placeholder.body"))
                    .font(Typography.prayerName)
                    .foregroundStyle(Palette.inkSoft)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 18)
        }
    }
}

#Preview {
    RootTabView(dependencies: .preview())
}
