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
    /// Pusula. Kıble ekranı dışında kimse kullanmıyor ama burada duruyor: manyetometreyi
    /// açan tek nesnenin nereden geldiği tek bakışta görünsün.
    public let heading: HeadingProviding
    /// Araçlar sekmesinin üç aracı. Hepsi aynı dosya deposunu paylaşıyor ama ayrı
    /// dosyalara yazıyor — birinin bozulması diğerlerini etkilemesin.
    public let tasbih: TasbihViewModel
    public let prayerLog: PrayerLogViewModel
    public let qadha: QadhaViewModel
    public let notes: NotesViewModel
    public let timer: TimerViewModel

    public init(
        homeModel: HomeViewModel,
        citySearch: CitySearching,
        notifications: NotificationCoordinator,
        heading: HeadingProviding,
        tasbih: TasbihViewModel,
        prayerLog: PrayerLogViewModel,
        qadha: QadhaViewModel,
        notes: NotesViewModel,
        timer: TimerViewModel
    ) {
        self.homeModel = homeModel
        self.citySearch = citySearch
        self.notifications = notifications
        self.heading = heading
        self.tasbih = tasbih
        self.prayerLog = prayerLog
        self.qadha = qadha
        self.notes = notes
        self.timer = timer
    }

    /// Üretim yapılandırması: gerçek CoreLocation ve gerçek coğrafi kodlama.
    ///
    /// Yedek konum adının burada üretilmesinin sebebi: `NamazCore` yerelleştirilmiş metin
    /// tutmuyor, tutmamalı da — o katman servis katmanı. Gösterim metni UI paketinin
    /// kaynak paketinden geliyor.
    @MainActor
    public static func live() -> Dependencies {
        // Tek depo örneği: üç araç aynı klasörü paylaşıyor, her biri kendi dosyasına
        // yazıyor. Ayrı örnekler kurmak aynı klasörü üç kez oluşturmaya çalışırdı.
        let store = JSONFileStore()
        let scheduler = UserNotificationScheduler()
        return Dependencies(
            homeModel: HomeViewModel(
                locationService: CoreLocationService(),
                unknownPlaceName: L.t("home.location.fallback")
            ),
            citySearch: GeocoderCitySearch(),
            notifications: NotificationCoordinator(
                scheduler: scheduler,
                content: NotificationText.provider
            ),
            heading: CoreLocationHeadingService(),
            tasbih: TasbihViewModel(store: store),
            prayerLog: PrayerLogViewModel(store: store),
            qadha: QadhaViewModel(store: store),
            notes: NotesViewModel(store: store),
            // Zamanlayıcı, vakit bildirimleriyle AYNI planlayıcıyı kullanıyor ama farklı
            // bir kimlik ad alanında; `cancelAll()` ona dokunmuyor.
            timer: TimerViewModel(store: store, scheduler: scheduler)
        )
    }

    /// Önizleme ve UI testleri için: ne GPS ne ağ bekleniyor.
    @MainActor
    public static func preview(
        authorization: LocationAuthorization = .whenInUse
    ) -> Dependencies {
        let previewStore = InMemoryFileStore()
        let previewScheduler = StubNotificationScheduler()
        return Dependencies(
            homeModel: HomeViewModel(
                locationService: StubLocationService(authorization: authorization),
                preferences: Preferences(store: InMemoryPreferenceStore()),
                unknownPlaceName: L.t("home.location.fallback")
            ),
            citySearch: StubCitySearch(),
            notifications: NotificationCoordinator(
                scheduler: previewScheduler,
                content: NotificationText.provider,
                preferences: Preferences(store: InMemoryPreferenceStore())
            ),
            // Önizlemede manyetometre yok; sabit bir okuma kadranın çizimini gösteriyor.
            heading: StubHeadingService(
                snapshots: [HeadingSnapshot(trueHeading: 120, accuracy: 8)]
            ),
            tasbih: TasbihViewModel(store: previewStore),
            prayerLog: PrayerLogViewModel(store: previewStore),
            qadha: QadhaViewModel(store: previewStore),
            notes: NotesViewModel(
                store: previewStore,
                preferences: Preferences(store: InMemoryPreferenceStore()),
                lock: StubBiometricLock()
            ),
            timer: TimerViewModel(store: previewStore, scheduler: previewScheduler)
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
