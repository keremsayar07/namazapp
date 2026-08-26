import Foundation
import Observation
import PrayerKit

/// Bildirimlerin tek sorumlusu: izni ister, planı üretir, sisteme kurar.
///
/// Konumu kendisi tutmuyor, her yeniden planlamada dışarıdan alıyor. Sebep: konum
/// `HomeViewModel`'in sorumluluğu ve iki yerde birden tutulan bir gerçek, er ya da geç
/// iki farklı gerçeğe dönüşür — "widget başka şehri gösteriyor" sınıfı hatalar böyle çıkar.
@MainActor
@Observable
public final class NotificationCoordinator {

    public private(set) var settings: NotificationSettings
    public private(set) var authorization: NotificationAuthorization = .notDetermined
    /// Son kurulan plan. Ekran "önümüzdeki N gün" derken buradan okuyor.
    public private(set) var plan: NotificationPlan = .empty

    private let scheduler: NotificationScheduling
    private let planner: PrayerNotificationPlanner
    private let repository: PrayerTimesRepository
    private let preferences: Preferences
    private let content: @Sendable (PlannedNotification) -> NotificationContent
    private let clock: @Sendable () -> Date

    public init(
        scheduler: NotificationScheduling,
        content: @escaping @Sendable (PlannedNotification) -> NotificationContent,
        planner: PrayerNotificationPlanner = PrayerNotificationPlanner(),
        repository: PrayerTimesRepository = PrayerTimesRepository(),
        preferences: Preferences = Preferences(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.scheduler = scheduler
        self.content = content
        self.planner = planner
        self.repository = repository
        self.preferences = preferences
        self.clock = clock
        self.settings = preferences.notificationSettings()
    }

    /// İzin durumunu sistemden okur. Ekran açılırken çağrılıyor: kullanıcı Ayarlar'dan
    /// izni kapatmış olabilir ve bunu bize kimse haber vermiyor.
    public func refreshAuthorization() async {
        authorization = await scheduler.authorization
    }

    /// Kullanıcı bildirimleri ilk kez açtığında. Zaten karar verilmişse sistem tekrar sormaz.
    @discardableResult
    public func requestAuthorization() async -> NotificationAuthorization {
        authorization = await scheduler.requestAuthorization()
        return authorization
    }

    /// Planı baştan kurar.
    ///
    /// Şu durumlarda çağrılıyor: uygulama öne geldiğinde (kayan pencere tazelensin),
    /// şehir değiştiğinde, hesaplama ayarları değiştiğinde, bildirim ayarları değiştiğinde.
    /// Hepsi planı geçersiz kılan olaylar.
    public func reschedule(
        location: SavedLocation?,
        calculationSettings: CalculationSettings
    ) async {
        authorization = await scheduler.authorization

        // Konum yoksa hangi vakitler için bildirim kuracağımızı bilmiyoruz. İzin yoksa
        // zaten kuramayız. İkisinde de bekleyenleri temizliyoruz: eski bir şehrin
        // vakitleri için çalan bir ezan, hiç bildirim gelmemesinden kötü.
        guard let location, authorization.canSchedule, !settings.isSilent else {
            await scheduler.cancelAll()
            plan = .empty
            return
        }

        let now = clock()
        let newPlan = planner.plan(
            from: now,
            settings: settings,
            timeZone: location.coordinate.timeZone
        ) { [repository] day in
            repository.dailyTimes(on: day, location: location, settings: calculationSettings)
        }

        await scheduler.replaceAll(
            with: newPlan, content: content, playsSound: settings.playsSound
        )
        plan = newPlan
    }

    /// Bildirim ayarı değişti: kaydet ve planı yenile.
    public func update(
        _ newSettings: NotificationSettings,
        location: SavedLocation?,
        calculationSettings: CalculationSettings
    ) async {
        settings = newSettings
        preferences.setNotificationSettings(newSettings)
        await reschedule(location: location, calculationSettings: calculationSettings)
    }
}
