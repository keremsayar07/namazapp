import Foundation
import NamazCore

/// Uygulama hedefinin tek giriş noktası.
///
/// Xcode'daki App target'ının yapması gereken her şey burada toplandı:
/// `RootTabView(dependencies: .live())` demek yeterli. Bağımlılıkların nasıl kurulduğu
/// (hangi konum servisi, hangi arama, hangi yedek ad) UI paketinin içinde kalıyor.
public struct Dependencies {
    public let homeModel: HomeViewModel
    public let citySearch: CitySearching

    public init(homeModel: HomeViewModel, citySearch: CitySearching) {
        self.homeModel = homeModel
        self.citySearch = citySearch
    }

    /// Üretim yapılandırması: gerçek CoreLocation ve gerçek coğrafi kodlama.
    ///
    /// Yedek konum adının burada üretilmesinin sebebi: `NamazCore` yerelleştirilmiş metin
    /// tutmuyor, tutmamalı da — o katman servis katmanı. Gösterim metni UI paketinin
    /// kaynak paketinden geliyor.
    @MainActor
    public static func live() -> Dependencies {
        Dependencies(
            homeModel: HomeViewModel(
                locationService: CoreLocationService(),
                unknownPlaceName: L.t("home.location.fallback")
            ),
            citySearch: GeocoderCitySearch()
        )
    }

    /// Önizleme ve UI testleri için: ne GPS ne ağ bekleniyor.
    @MainActor
    public static func preview(
        authorization: LocationAuthorization = .whenInUse
    ) -> Dependencies {
        Dependencies(
            homeModel: HomeViewModel(
                locationService: StubLocationService(authorization: authorization),
                preferences: Preferences(store: InMemoryPreferenceStore()),
                unknownPlaceName: L.t("home.location.fallback")
            ),
            citySearch: StubCitySearch()
        )
    }
}
