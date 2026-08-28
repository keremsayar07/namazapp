import Foundation
import WidgetKit
import NamazCore
import PrayerKit

/// Widget'ın tek bir anda göstereceği her şey.
public struct PrayerEntry: TimelineEntry, Sendable {
    public var date: Date
    /// `nil` ise kullanıcı henüz şehir seçmemiş / konum yok — widget bunu söylemeli.
    public var schedule: PrayerSchedule?
    /// Yer tutucu (placeholder) çizimi mi — gerçek veri yerine iskelet gösterilir.
    public var isPlaceholder: Bool

    public init(date: Date, schedule: PrayerSchedule?, isPlaceholder: Bool = false) {
        self.date = date
        self.schedule = schedule
        self.isPlaceholder = isPlaceholder
    }

    var nextPrayer: PrayerTime? { schedule?.nextPrayer(after: date) }
    var currentPrayer: Prayer? { schedule?.currentPrayer(at: date) }
}

/// Widget'ın zaman çizelgesini üretir.
///
/// **Widget ayrı bir süreçte çalışıyor** — uygulamanın belleğine, view model'lerine,
/// hiçbir şeyine erişemiyor. Elindeki tek köprü App Group. Faz 2'de tercihleri baştan
/// App Group'a yazmamızın sebebi buydu.
///
/// **Anlık görüntü (snapshot) dosyası tutmuyoruz.** İlk planda uygulama vakitleri hesaplayıp
/// paylaşılan bir dosyaya yazacaktı; widget onu okuyacaktı. Ama `PrayerKit` saf hesaplama —
/// sıfır bağımlılık, mikrosaniyeler içinde çalışıyor. Widget aynı hesabı kendisi yapabildiği
/// sürece dosya sadece bayatlama riski ekliyordu: kullanıcı uygulamayı bir hafta açmasa
/// widget boş kalırdı. Şimdi konum ve ayar App Group'ta durduğu sürece widget her zaman
/// doğru vakti gösteriyor.
public struct PrayerTimelineProvider: TimelineProvider {

    private let preferences: Preferences
    private let repository: PrayerTimesRepository
    private let clock: @Sendable () -> Date

    public init(
        preferences: Preferences = Preferences(),
        repository: PrayerTimesRepository = PrayerTimesRepository(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.preferences = preferences
        self.repository = repository
        self.clock = clock
    }

    public func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: clock(), schedule: makeSchedule(at: clock()), isPlaceholder: true)
    }

    public func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        let now = clock()
        completion(PrayerEntry(date: now, schedule: makeSchedule(at: now)))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now = clock()
        guard let schedule = makeSchedule(at: now) else {
            // Şehir yok: tek bir giriş, bir saat sonra tekrar bak. Kullanıcı uygulamada
            // şehir seçtiğinde `WidgetCenter.reloadAllTimelines()` zaten tetikleyecek;
            // bu sadece emniyet ağı.
            let entry = PrayerEntry(date: now, schedule: nil)
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(3600))))
            return
        }

        // Her vakit sınırında bir giriş: "şu anki vakit" vurgusu ve "sıradaki vakit"
        // doğru anda değişsin. Geri sayımın kendisi için girişe gerek yok — görünüm
        // `Text(date, style:)` kullanıyor ve kendi kendini tazeliyor.
        var entries: [PrayerEntry] = [PrayerEntry(date: now, schedule: schedule)]
        let boundaries = (schedule.today.times + schedule.tomorrow.times)
            .map(\.date)
            .filter { $0 > now }
            .sorted()

        for boundary in boundaries {
            // Sınırın bir saniye sonrası: tam sınırda hangi tarafta olduğumuz belirsiz kalmasın.
            let at = boundary.addingTimeInterval(1)
            entries.append(PrayerEntry(date: at, schedule: makeSchedule(at: at) ?? schedule))
        }

        // Son girişten sonra sistem yeni çizelge istesin. Yarının vakitleri de elimizde
        // olduğu için bu genelde 24 saatten uzak — widget'ın uyanma bütçesini boşa harcamıyoruz.
        let refreshAt = boundaries.last ?? now.addingTimeInterval(3600)
        Diagnostics.log(.widgetTimelineBuilt(entryCount: entries.count))
        completion(Timeline(entries: entries, policy: .after(refreshAt)))
    }

    /// Verilen an için çizelge. Şehir seçilmemişse `nil`.
    private func makeSchedule(at date: Date) -> PrayerSchedule? {
        guard let location = preferences.selectedLocation() ?? preferences.lastKnownLocation() else {
            Diagnostics.log(.widgetHasNoLocation)
            return nil
        }
        return repository.schedule(
            for: date, location: location, settings: preferences.calculationSettings()
        )
    }
}
