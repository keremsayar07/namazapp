import Foundation
import Observation
import PrayerKit

/// Home ekranının tüm durumu tek bir enum'da. Ekranın çizeceği her şey buradan türüyor;
/// "yükleniyor mu ama aynı zamanda hata var mı" gibi imkânsız kombinasyonlar tip düzeyinde
/// engelleniyor.
public enum HomeState: Sendable, Hashable {
    /// Henüz hiçbir şey denenmedi.
    case idle
    /// Konum bekleniyor veya izin soruluyor.
    case loading
    /// Kullanıcı izin vermedi. Ekran, elle şehir seçimine ve Ayarlar'a yönlendirir.
    case locationDenied
    /// Konum alınamadı ama kullanıcı reddetmiş değil (kapalı alan, servis kapalı, zaman aşımı).
    case locationUnavailable
    case ready(PrayerSchedule)

    public var schedule: PrayerSchedule? {
        if case .ready(let schedule) = self { return schedule }
        return nil
    }
}

/// Home ekranının beyni.
///
/// **Geri sayım burada tutulmuyor.** View, `TimelineView` ile saniyede bir kendini yeniler
/// ve o anın `Date`'ini bu modele sorar. Böylece view model'in içinde `Timer` yok: test
/// ederken zamanı beklemek gerekmiyor, ekran görünmezken boşuna tik atılmıyor ve widget
/// aynı hesabı kendi zaman çizelgesiyle kullanabiliyor.
@MainActor
@Observable
public final class HomeViewModel {

    public private(set) var state: HomeState = .idle
    /// Kullanıcı elle bir şehir seçtiyse konum servisi hiç çağrılmaz.
    ///
    /// Kasıtlı olarak `didSet` ile otomatik yenileme YOK: gözlenen bir özelliğin yan etkisi
    /// olarak arka planda iş başlatmak, çağrı sırasını okunmaz hâle getiriyor ve testte
    /// yarış oluşturuyor. Yenileme her zaman açıkça çağrılıyor.
    public private(set) var manualLocation: SavedLocation?
    public private(set) var settings: CalculationSettings

    private let locationService: LocationProviding
    private let repository: PrayerTimesRepository
    private let clock: @Sendable () -> Date
    /// Konum adı çözülemezse Home'da gösterilecek ad.
    private let unknownPlaceName: String

    public init(
        locationService: LocationProviding,
        repository: PrayerTimesRepository = PrayerTimesRepository(),
        settings: CalculationSettings = .defaultForTurkey(),
        manualLocation: SavedLocation? = nil,
        unknownPlaceName: String = "Konumunuz",
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.locationService = locationService
        self.repository = repository
        self.settings = settings
        self.manualLocation = manualLocation
        self.unknownPlaceName = unknownPlaceName
        self.clock = clock
    }

    // MARK: - Akış

    /// Ekran her göründüğünde çağrılır. Elle seçilmiş şehir varsa konum servisine hiç
    /// dokunmaz — kullanıcı zaten kararını vermiş, ona tekrar izin sormak gereksiz.
    public func refresh() async {
        if let manualLocation {
            state = .ready(makeSchedule(for: manualLocation))
            return
        }

        state = .loading

        var authorization = await locationService.authorization
        if authorization == .notDetermined {
            authorization = await locationService.requestAuthorization()
        }

        guard authorization.canUseLocation else {
            state = .locationDenied
            return
        }

        do {
            let snapshot = try await locationService.currentLocation()
            let location = SavedLocation.fromDevice(snapshot, fallbackName: unknownPlaceName)
            state = .ready(makeSchedule(for: location))
        } catch LocationError.unauthorized {
            state = .locationDenied
        } catch {
            state = .locationUnavailable
        }
    }

    /// Kullanıcı elle şehir seçtiğinde. Konum izni reddedilmişse tek çıkış yolu bu.
    /// Konum servisine hiç dokunmadığı için `async` bile değil — sonuç anında hazır.
    public func selectManualLocation(_ location: SavedLocation) {
        manualLocation = location
        state = .ready(makeSchedule(for: location))
    }

    /// Elle seçimden cihaz konumuna dönmek.
    public func useDeviceLocation() async {
        manualLocation = nil
        await refresh()
    }

    /// Vakit ayarları değiştiğinde (mezhep, yöntem, ince ayar) yeniden hesaplar. Konum
    /// tekrar sorulmaz; elde olan konumla yeni ayarlar uygulanır.
    public func apply(settings newSettings: CalculationSettings) {
        settings = newSettings
        if let location = state.schedule?.location {
            state = .ready(makeSchedule(for: location))
        }
    }

    // MARK: - Görünüm için türetilmiş değerler

    /// Sıradaki vakte kalan süre. View bunu `TimelineView` içinden, o anın tarihiyle çağırır.
    public func timeRemaining(at now: Date) -> TimeInterval {
        state.schedule?.timeRemaining(at: now) ?? 0
    }

    public func nextPrayer(at now: Date) -> PrayerTime? {
        state.schedule?.nextPrayer(after: now)
    }

    public func currentPrayer(at now: Date) -> Prayer? {
        state.schedule?.currentPrayer(at: now)
    }

    private func makeSchedule(for location: SavedLocation) -> PrayerSchedule {
        repository.schedule(for: clock(), location: location, settings: settings)
    }
}
