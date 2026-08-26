import Foundation
import Observation
import PrayerKit

/// Takvimdeki tek bir gün.
public struct CalendarDay: Identifiable, Sendable, Hashable {
    public var id: Date { date }
    /// Konumun saat diliminde gün başlangıcı.
    public var date: Date
    public var dayNumber: Int
    public var times: DailyPrayerTimes
    public var isToday: Bool

    public var hijri: HijriDate? { times.hijriDate }

    public init(date: Date, dayNumber: Int, times: DailyPrayerTimes, isToday: Bool) {
        self.date = date
        self.dayNumber = dayNumber
        self.times = times
        self.isToday = isToday
    }
}

/// Bir ayın tamamı.
public struct CalendarMonth: Sendable, Hashable {
    /// Ayın ilk gününü temsil eden tarih.
    public var anchor: Date
    public var days: [CalendarDay]
    /// Izgarada ilk günün önüne konacak boş hücre sayısı.
    ///
    /// Haftanın ilk günü sabit kodlanmıyor — `Calendar`'ın yereline bırakılıyor. Türkiye'de
    /// pazartesi, ABD'de pazar; kullanıcı hangi bölgedeyse ızgara ona göre hizalanmalı.
    public var leadingBlanks: Int

    public init(anchor: Date, days: [CalendarDay], leadingBlanks: Int) {
        self.anchor = anchor
        self.days = days
        self.leadingBlanks = leadingBlanks
    }

    /// Ay içinde geçilen hicri aylar, sırayla. Genelde iki tane olur: miladi ay ile hicri ay
    /// hiçbir zaman hizalanmaz. Başlıkta "Rebiülevvel – Rebiülahir 1448" yazabilmek için.
    public var hijriSpan: [HijriDate] {
        var seen: [HijriDate] = []
        for day in days {
            guard let hijri = day.hijri else { continue }
            if seen.last?.month != hijri.month || seen.last?.year != hijri.year {
                seen.append(hijri)
            }
        }
        return seen
    }
}

/// Takvim ekranının durumu.
///
/// Ayın 30-31 gününün vakitlerini hesaplamak `PrayerKit` için mikrosaniyeler sürüyor;
/// bu yüzden önbellek yok. Önbellek olsaydı şehir veya mezhep değiştiğinde geçersiz kılma
/// derdi doğardı — kazanacağından fazlasını hata olarak geri verirdi.
@MainActor
@Observable
public final class CalendarViewModel {

    public private(set) var month: CalendarMonth?
    /// Kullanıcının dokunduğu gün. Ekran açıldığında bugün seçili geliyor.
    public private(set) var selectedDay: CalendarDay?

    private var anchor: Date
    private let repository: PrayerTimesRepository
    private let clock: @Sendable () -> Date

    private var location: SavedLocation?
    private var settings: CalculationSettings

    public init(
        location: SavedLocation?,
        settings: CalculationSettings = .defaultForTurkey(),
        repository: PrayerTimesRepository = PrayerTimesRepository(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.location = location
        self.settings = settings
        self.repository = repository
        self.clock = clock
        self.anchor = clock()
        rebuild(selectToday: true)
    }

    // MARK: - Gezinme

    public func goToPreviousMonth() { shiftMonth(by: -1) }
    public func goToNextMonth() { shiftMonth(by: 1) }

    /// Bugüne dön ve bugünü seç.
    public func goToToday() {
        anchor = clock()
        rebuild(selectToday: true)
    }

    public func select(_ day: CalendarDay) {
        selectedDay = day
    }

    /// Şehir veya hesaplama ayarı değiştiğinde. Görüntülenen ay korunuyor — kullanıcı
    /// Ekim'e bakıyorsa ayarı değiştirince Ağustos'a fırlamamalı.
    public func update(location: SavedLocation?, settings: CalculationSettings) {
        self.location = location
        self.settings = settings
        rebuild(selectToday: false)
    }

    // MARK: - Kurulum

    private func shiftMonth(by delta: Int) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        guard let shifted = calendar.date(byAdding: .month, value: delta, to: startOfMonth(for: anchor)) else {
            return
        }
        anchor = shifted
        rebuild(selectToday: false)
    }

    private var timeZone: TimeZone {
        location?.coordinate.timeZone ?? .current
    }

    private func startOfMonth(for date: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func rebuild(selectToday: Bool) {
        guard let location else {
            month = nil
            selectedDay = nil
            return
        }

        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let first = startOfMonth(for: anchor)
        guard let range = calendar.range(of: .day, in: .month, for: first) else {
            month = nil
            return
        }

        let today = calendar.startOfDay(for: clock())
        var days: [CalendarDay] = []

        for offset in 0..<range.count {
            guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
            let times = repository.dailyTimes(on: date, location: location, settings: settings)
            days.append(CalendarDay(
                date: date,
                dayNumber: calendar.component(.day, from: date),
                times: times,
                isToday: calendar.isDate(date, inSameDayAs: today)
            ))
        }

        // Izgara hizalaması: haftanın ilk gününe göre kaç boş hücre gerekiyor.
        let weekday = calendar.component(.weekday, from: first)
        let blanks = (weekday - calendar.firstWeekday + 7) % 7

        month = CalendarMonth(anchor: first, days: days, leadingBlanks: blanks)

        if selectToday, let todayDay = days.first(where: \.isToday) {
            selectedDay = todayDay
        } else if let current = selectedDay {
            // Ay değiştiyse seçim düşer; aynı aydaysak seçili günü koru.
            selectedDay = days.first { calendar.isDate($0.date, inSameDayAs: current.date) }
        }
    }
}
