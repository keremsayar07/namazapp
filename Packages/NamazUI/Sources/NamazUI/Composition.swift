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
    public let notifications: NotificationCoordinator

    public init(
        homeModel: HomeViewModel,
        citySearch: CitySearching,
        notifications: NotificationCoordinator
    ) {
        self.homeModel = homeModel
        self.citySearch = citySearch
        self.notifications = notifications
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
            citySearch: GeocoderCitySearch(),
            notifications: NotificationCoordinator(
                scheduler: UserNotificationScheduler(),
                content: NotificationText.provider
            )
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
            citySearch: StubCitySearch(),
            notifications: NotificationCoordinator(
                scheduler: StubNotificationScheduler(),
                content: NotificationText.provider,
                preferences: Preferences(store: InMemoryPreferenceStore())
            )
        )
    }
}

/// Bildirim metinleri. `NamazCore` yerelleştirilmiş metin tutmuyor — planlayıcı sadece
/// hangi vakit ve kaç dakika olduğunu biliyor, sözcükler burada, UI paketinin kaynak
/// paketinden geliyor.
enum NotificationText {
    static let provider: @Sendable (PlannedNotification) -> NotificationContent = { planned in
        let name = Formatting.prayerName(planned.prayer)
        switch planned.kind {
        case .atTime:
            return NotificationContent(
                title: name,
                body: L.t("notification.body.at_time %@", name)
            )
        case .reminder:
            return NotificationContent(
                title: name,
                body: L.t(
                    "notification.body.reminder %@ %@",
                    name,
                    String(planned.minutesBefore ?? 0)
                )
            )
        }
    }
}
