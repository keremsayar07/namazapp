import Foundation
import PrayerKit

/// Home ekranının tek seferde ihtiyaç duyduğu her şey.
///
/// Bugün *ve* yarın birlikte tutuluyor: gece yatsıdan sonra "sıradaki vakit" yarının
/// imsağıdır. Bunu ekranda hesaplamak yerine burada çözmek, gece yarısı sınırındaki
/// hataların tek bir yerde ve test edilebilir olmasını sağlıyor.
public struct PrayerSchedule: Sendable, Hashable {
    public var location: SavedLocation
    public var today: DailyPrayerTimes
    public var tomorrow: DailyPrayerTimes

    public init(location: SavedLocation, today: DailyPrayerTimes, tomorrow: DailyPrayerTimes) {
        self.location = location
        self.today = today
        self.tomorrow = tomorrow
    }

    /// `now` anından sonraki ilk kılınacak vakit. Bugünün vakitleri tükendiyse yarına geçer,
    /// dolayısıyla asla `nil` dönmez — ekranda "sıradaki vakit yok" diye bir durum olamaz.
    public func nextPrayer(after now: Date) -> PrayerTime? {
        today.nextPrayer(after: now) ?? tomorrow.nextPrayer(after: now)
    }

    /// Sıradaki vakte kalan süre. Negatife düşmez: saat ileri alınırsa veya hesap bir saniye
    /// geriden gelirse geri sayım eksiye dönmesin.
    public func timeRemaining(at now: Date) -> TimeInterval {
        guard let next = nextPrayer(after: now) else { return 0 }
        return max(0, next.date.timeIntervalSince(now))
    }

    /// O an içinde bulunulan vakit — yani `now`'dan önceki son vakit. Home ekranı bunu
    /// vurgulamak için kullanıyor. Günün ilk vaktinden önceyse dünün yatsısındayız demektir,
    /// bu durumda `nil` döner ve ekran vurgusuz kalır.
    public func currentPrayer(at now: Date) -> Prayer? {
        today.times
            .filter { $0.date <= now }
            .max { $0.date < $1.date }?
            .prayer
    }
}

/// Vakitleri üreten katman. Hesaplamanın kendisi `PrayerKit`'te; burada yapılan iş, doğru
/// günleri seçip sonucu Home ekranının anlayacağı biçime getirmek.
///
/// Kasıtlı olarak durumsuz (stateless) ve `Sendable`: aynı örnek widget zaman çizelgesinden
/// de, ana uygulamadan da çağrılabilir.
public struct PrayerTimesRepository: Sendable {

    private let service: PrayerCalculationService
    private let hijriConverter: HijriDateConverting

    public init(
        service: PrayerCalculationService = PrayerCalculationService(),
        hijriConverter: HijriDateConverting = DiyanetHijriDateConverter()
    ) {
        self.service = service
        self.hijriConverter = hijriConverter
    }

    /// `date`'in içinde bulunduğu takvim günü ve ertesi gün için vakitleri üretir.
    ///
    /// Gün sınırı, konumun kendi saat diliminde belirleniyor — cihazınkinde değil. Kullanıcı
    /// yurt dışındayken memleketinin vaktine bakıyorsa "bugün" onun için orada geçerli olan
    /// gündür.
    public func schedule(
        for date: Date,
        location: SavedLocation,
        settings: CalculationSettings
    ) -> PrayerSchedule {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.coordinate.timeZone

        let startOfToday = calendar.startOfDay(for: date)
        // Gün ekleme, DST geçişlerinde 86400 saniye eklemekten farklı davranır; takvimin
        // kendisine sorduğumuz için o geçişler doğru ele alınıyor.
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? startOfToday.addingTimeInterval(86_400)

        // Hesaplama, günü UTC üzerinden okuduğu için gün ortasını veriyoruz: yerel gece
        // yarısı UTC'de bir önceki güne düşebilir.
        let noonToday = startOfToday.addingTimeInterval(12 * 3600)
        let noonTomorrow = startOfTomorrow.addingTimeInterval(12 * 3600)

        return PrayerSchedule(
            location: location,
            today: daily(at: noonToday, location: location, settings: settings),
            tomorrow: daily(at: noonTomorrow, location: location, settings: settings)
        )
    }

    private func daily(
        at date: Date,
        location: SavedLocation,
        settings: CalculationSettings
    ) -> DailyPrayerTimes {
        service.dailyTimes(
            for: date,
            coordinate: location.coordinate,
            settings: settings,
            hijriConverter: hijriConverter
        )
    }
}
