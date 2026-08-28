import Foundation
import Observation
import PrayerKit

/// İmsakiyedeki tek bir satır.
///
/// İmsak ve iftar ayrı vakitler değil, mevcut vakitlerin başka adı: imsak = **fecr-i sadık**
/// (yani sabah/imsak vakti), iftar = **akşam** vakti. Yeni bir hesap eklemiyoruz; aynı
/// `PrayerKit` çıktısını başka bir başlıkla gösteriyoruz. Ayrı hesaplasaydık iki tablo
/// birbirinden ayrı düşerdi ve hangisinin doğru olduğu belirsizleşirdi.
public struct RamadanDay: Identifiable, Sendable, Hashable {
    /// Kaçıncı ramazan günü (1'den başlar).
    public let number: Int
    /// Konumun saat diliminde gün başlangıcı.
    public let date: Date
    public let imsak: Date
    public let iftar: Date
    public let isToday: Bool

    public var id: Int { number }

    public init(number: Int, date: Date, imsak: Date, iftar: Date, isToday: Bool) {
        self.number = number
        self.date = date
        self.imsak = imsak
        self.iftar = iftar
        self.isToday = isToday
    }
}

/// İmsakiye ekranının durumu.
///
/// Ay bilgisi ve otuz günün vakitleri bir kez hesaplanıp saklanıyor: ramazan aralığını
/// bulmak yaklaşık 440 günü tarayıp her biri için hicri dönüşüm yapmak demek — cihazda
/// milisaniyeler, ama ekran her yenilendiğinde tekrarlanacak bir iş değil.
@MainActor
@Observable
public final class RamadanViewModel {

    public private(set) var period: RamadanPeriod?
    public private(set) var days: [RamadanDay] = []

    private var location: SavedLocation?
    private var settings: CalculationSettings
    private let repository: PrayerTimesRepository
    private let clock: @Sendable () -> Date

    @ObservationIgnored
    private let islamicCalendar: IslamicCalendar

    public init(
        location: SavedLocation?,
        settings: CalculationSettings = .defaultForTurkey(),
        repository: PrayerTimesRepository = PrayerTimesRepository(),
        islamicCalendar: IslamicCalendar = IslamicCalendar(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.location = location
        self.settings = settings
        self.repository = repository
        self.islamicCalendar = islamicCalendar
        self.clock = clock
        rebuild()
    }

    /// Şehir veya hesaplama ayarı değiştiğinde.
    public func update(location: SavedLocation?, settings: CalculationSettings) {
        self.location = location
        self.settings = settings
        rebuild()
    }

    // MARK: - Türetilmiş değerler

    /// Bugün ramazanın içinde mi. Ramazan dışında ekran "yaklaşan ramazan" diye yazıyor.
    public var isActiveToday: Bool { today != nil }

    public var today: RamadanDay? {
        days.first(where: \.isToday)
    }

    /// Ramazana kaç gün kaldı. Ramazandaysak ya da ay bulunamadıysa `nil`.
    public func daysUntilStart(from now: Date) -> Int? {
        guard let first = days.first, !isActiveToday else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: first.date)
        let current = calendar.startOfDay(for: now)
        guard start > current else { return nil }
        return calendar.dateComponents([.day], from: current, to: start).day
    }

    /// Tablo Diyanet arşiviyle doğrulanmış mı. Değilse ekran bunu yazmak zorunda:
    /// ramazanın başlangıcı bir gün kayarsa tablonun **her satırı** yanlış olur.
    public var isVerified: Bool { period?.isVerified ?? false }

    public var timeZone: TimeZone { location?.coordinate.timeZone ?? .current }

    // MARK: - Kurulum

    private func rebuild() {
        guard let location else {
            period = nil
            days = []
            return
        }

        let now = clock()
        guard let found = islamicCalendar.ramadan(onOrAfter: now) else {
            period = nil
            days = []
            return
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.coordinate.timeZone
        let todayStart = calendar.startOfDay(for: now)

        var rows: [RamadanDay] = []
        for (index, day) in found.days.enumerated() {
            var components = DateComponents()
            components.year = day.year
            components.month = day.month
            components.day = day.day
            guard let date = calendar.date(from: components) else { continue }

            let times = repository.dailyTimes(on: date, location: location, settings: settings)
            // İmsak ya da akşam yoksa (kutup bölgesi gibi uç enlemlerde olabiliyor) satır
            // atlanıyor. Boş bir hücre göstermek, olmayan bir vakti varmış gibi sunmaktan
            // iyi; ama uydurma bir saat yazmak ikisinden de kötü olurdu.
            guard let imsak = times.time(for: .fajr), let iftar = times.time(for: .maghrib) else {
                continue
            }

            rows.append(RamadanDay(
                number: index + 1,
                date: date,
                imsak: imsak,
                iftar: iftar,
                isToday: calendar.isDate(date, inSameDayAs: todayStart)
            ))
        }

        period = found
        days = rows
    }
}
