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

            QiblaScreen(
                location: dependencies.homeModel.state.schedule?.location,
                headingService: dependencies.heading
            )
            .tabItem { Label(L.t("tab.qibla"), systemImage: "location.north.line") }

            SettingsScreen(dependencies: dependencies)
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
        // Aynısı hesaplama ayarı için de geçerli: mezhep ya da yöntem değişince kurulu
        // bildirimler eski vakitlere kalmış olur. Ayarlar ekranı bunu kendisi yapamaz —
        // bildirim planlayıcısını orada da çağırmak, iki ayrı yerde iki ayrı zamanlama
        // mantığı demek olurdu.
        .onChange(of: dependencies.homeModel.settings) {
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

#Preview {
    RootTabView(dependencies: .preview())
}
