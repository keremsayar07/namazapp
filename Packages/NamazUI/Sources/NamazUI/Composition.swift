import Foundation
import NamazCore

/// Uygulama hedefinin tek giriş noktası.
///
/// Xcode'daki App target'ının yapması gereken her şey burada toplandı: bir satır çağırıp
/// `RootTabView`'a vermek yeterli. Bağımlılıkların nasıl kurulduğu (hangi konum servisi,
/// hangi yedek ad) UI paketinin içinde kalıyor; App target'ı bunları bilmek zorunda değil.
///
/// Yedek konum adının burada üretilmesinin sebebi: `NamazCore` yerelleştirilmiş metin
/// tutmuyor, tutmamalı da — o katman servis katmanı. Gösterim metni UI paketinin kaynak
/// paketinden geliyor.
public enum Composition {

    /// Üretim yapılandırması: gerçek CoreLocation.
    @MainActor
    public static func makeHomeModel() -> HomeViewModel {
        HomeViewModel(
            locationService: CoreLocationService(),
            unknownPlaceName: L.t("home.location.fallback")
        )
    }

    /// Önizleme ve UI testleri için: konum servisi sahte, GPS beklenmiyor.
    @MainActor
    public static func makePreviewHomeModel(
        authorization: LocationAuthorization = .whenInUse
    ) -> HomeViewModel {
        HomeViewModel(
            locationService: StubLocationService(authorization: authorization),
            unknownPlaceName: L.t("home.location.fallback")
        )
    }
}
