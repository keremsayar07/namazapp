import SwiftUI
import NamazCore

/// Uygulamanın gezinme iskeleti: dört sekme.
///
/// `NavigationSplitView` değil `TabView` — v1 iPhone. iPad'e geçildiğinde bu tip
/// değişecek ama sekmelerin içeriği aynı kalacak; bu yüzden her sekmenin kökü bağımsız
/// bir görünüm, sekme çubuğuna bağlı hiçbir şey bilmiyor.
public struct RootTabView: View {

    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        TabView {
            HomeScreen(model: dependencies.homeModel, citySearch: dependencies.citySearch)
                .tabItem { Label(L.t("tab.times"), systemImage: "clock") }

            PlaceholderScreen(name: L.t("tab.calendar"))
                .tabItem { Label(L.t("tab.calendar"), systemImage: "calendar") }

            PlaceholderScreen(name: L.t("tab.qibla"))
                .tabItem { Label(L.t("tab.qibla"), systemImage: "location.north.line") }

            PlaceholderScreen(name: L.t("tab.settings"))
                .tabItem { Label(L.t("tab.settings"), systemImage: "gearshape") }
        }
        .tint(Palette.mark)
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
