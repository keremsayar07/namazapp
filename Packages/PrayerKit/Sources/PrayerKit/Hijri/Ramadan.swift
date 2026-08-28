import Foundation

/// Bir ramazan ayının miladi karşılığı.
///
/// Gün listesi olarak tutuluyor, "başlangıç + 30" olarak değil: ramazan **29 da 30 da**
/// çekebiliyor ve hangisi olduğu ay sonundaki hilâle bağlı. Sabit bir uzunluk varsaymak,
/// imsakiyeye var olmayan bir 30. günü eklemek olurdu.
public struct RamadanPeriod: Sendable, Hashable {

    public let hijriYear: Int
    /// Ayın günleri, sırayla. Her zaman en az bir eleman; 29 ya da 30 olması beklenir.
    public let days: [GregorianDay]

    /// Bu ayın tamamı Diyanet arşiviyle doğrulanmış pencerenin içinde mi?
    ///
    /// Değilse tarihler Ümmü'l-Kura hesabına dayanıyor ve ramazanın başlangıcı Diyanet'in
    /// ilan ettiğinden bir gün sapabilir. Arayüz bunu söylemek zorunda: imsakiye, bir gün
    /// kayması halinde her satırı yanlış olan bir tablodur.
    public let isVerified: Bool

    public init(hijriYear: Int, days: [GregorianDay], isVerified: Bool) {
        self.hijriYear = hijriYear
        self.days = days
        self.isVerified = isVerified
    }

    public var firstDay: GregorianDay? { days.first }
    public var lastDay: GregorianDay? { days.last }
    public var dayCount: Int { days.count }

    /// Kaçıncı ramazan günü (1'den başlar), ay dışındaysa `nil`.
    public func dayNumber(of day: GregorianDay) -> Int? {
        days.firstIndex(of: day).map { $0 + 1 }
    }

    public func contains(_ day: GregorianDay) -> Bool {
        dayNumber(of: day) != nil
    }
}

extension IslamicCalendar {

    /// `date` ramazandaysa içinde bulunulan ramazan; değilse `date`'ten sonraki ilk ramazan.
    ///
    /// **Eksik bulunan ay döndürülmüyor.** Tarama penceresinin kenarına denk gelen ve bu
    /// yüzden baştan ya da sondan kırpılmış bir ay, imsakiyede sessizce eksik günler
    /// demek olurdu. Ayın 1 Ramazan ile başladığı ve ertesi günün 1 Şevval olduğu
    /// doğrulanamıyorsa sonuç `nil` — eksik bir tabloyu göstermektense hiç göstermemek.
    public func ramadan(onOrAfter date: Date) -> RamadanPeriod? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        // Geriye 40 gün: `date` ramazanın son gününde bile olsa ayın başı pencereye girer
        // (ramazan en fazla 30 gün). İleriye 400 gün: hicri yıl ~354 gün, yani bir sonraki
        // ramazanın tamamı da pencereye sığar.
        guard
            let start = calendar.date(byAdding: .day, value: -40, to: date),
            let end = calendar.date(byAdding: .day, value: 400, to: date),
            let startDay = gregorianDay(start, calendar),
            let endDay = gregorianDay(end, calendar),
            let today = gregorianDay(date, calendar)
        else { return nil }

        let scanned = scan(from: startDay, to: endDay)

        for run in ramadanRuns(in: scanned) {
            guard let last = run.days.last else { continue }
            // Bugünü içeren ay, yoksa bugünden sonra biten ilk ay.
            guard run.contains(today) || today < last else { continue }
            return run
        }
        return nil
    }

    /// Taranan günlerdeki kesintisiz ramazan dizileri, tarih sırasıyla.
    ///
    /// Bir dizi ancak 1 Ramazan ile başlıyor ve hemen ardından 1 Şevval geliyorsa tam
    /// sayılıyor; aksi halde pencerenin kenarında kırpılmış demektir ve atılıyor.
    private func ramadanRuns(in scanned: [(GregorianDay, HijriDate, Date)]) -> [RamadanPeriod] {
        var runs: [RamadanPeriod] = []
        var current: [(GregorianDay, HijriDate, Date)] = []

        func flush(followedByShawwal: Bool) {
            defer { current = [] }
            guard let first = current.first, first.1.day == 1, followedByShawwal else { return }
            runs.append(RamadanPeriod(
                hijriYear: first.1.year,
                days: current.map(\.0),
                // Tek bir günü bile pencerenin dışındaysa ay doğrulanmış sayılmıyor:
                // imsakiyede "şu satırlar kesin, şunlar tahmin" ayrımı kullanıcıya
                // anlatılabilir bir şey değil, ay ya güvenilir ya değil.
                isVerified: current.allSatisfy { isVerified($0.2) }
            ))
        }

        for entry in scanned {
            if entry.1.month == 9 {
                current.append(entry)
            } else if !current.isEmpty {
                flush(followedByShawwal: entry.1.month == 10 && entry.1.day == 1)
            }
        }
        // Pencerenin sonunda kalan dizi hiçbir zaman tam değil: ardından gelen günü
        // görmedik, dolayısıyla ayın bittiğini de bilmiyoruz.
        flush(followedByShawwal: false)

        return runs
    }

    private func gregorianDay(_ date: Date, _ calendar: Calendar) -> GregorianDay? {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil }
        return GregorianDay(year: y, month: m, day: d)
    }
}
