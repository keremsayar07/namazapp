import Foundation

/// Diyanet'in yayımladığı dini gün ve geceler.
///
/// **Gece ile gün ayrımı bu dosyanın en önemli fikri.** İslami gün akşam ezanıyla başlıyor,
/// dolayısıyla "27 Recep gecesi" 26 Recep gününün akşamında idrak ediliyor. Diyanet
/// takvimi kandili o akşamın miladi gününe yazıyor — yani hicri gün numarasından BİR GÜN
/// ÖNCESİNE. Bu kaydırmayı atlamak, kullanıcıya Kadir Gecesi'ni bir gün geç göstermek
/// demek olurdu.
///
/// Doğrulama: 1447 zinciri (1 Recep = 21.12.2025) üzerinden Miraç 15.01.2026, Berat
/// 02.02.2026, Kadir 16.03.2026 çıkıyor ve bunlar Diyanet takvimini aktaran kaynaklarla
/// birebir tutuyor. Aynı sınama 1448 ve 1440 yıllarında da tuttu.
public enum IslamicOccasion: String, Codable, Sendable, Hashable, CaseIterable {
    case hijriNewYear
    case ashura
    case mawlid
    case regaib
    case miraj
    case berat
    case ramadanStart
    case laylatAlQadr
    case ramadanEve
    case ramadanFeast
    case qurbanEve
    case qurbanFeast

    /// Gece olarak idrak edilenler. Arayüz bunları "… akşamı" diye yazmalı: kullanıcı
    /// "16 Mart Kadir Gecesi"ni 16 Mart gündüzü diye okuyabiliyor.
    public var isNight: Bool {
        switch self {
        case .mawlid, .regaib, .miraj, .berat, .laylatAlQadr: return true
        default: return false
        }
    }

    public var localizationKey: String { "occasion.\(rawValue)" }
}

/// Bir dini günün miladi karşılığı.
public struct IslamicOccasionDay: Sendable, Hashable, Identifiable {
    public var occasion: IslamicOccasion
    public var day: GregorianDay
    /// Bayramın kaçıncı günü (1'den başlar). Bayram dışında `nil`.
    public var ordinal: Int?
    /// Bu tarih, Diyanet arşiviyle doğrulanmış pencerenin içinde mi?
    ///
    /// Dışındaysa hicri dönüşüm Ümmü'l-Kura tahminidir ve ay başlarında bir gün
    /// sapabilir — yani bayram ya da kandil bir gün kayabilir. Arayüz bunu söylemek
    /// zorunda; sessizce kesin bir tarih göstermek, tam da kaçındığımız şey.
    public var isVerified: Bool

    public var id: String { "\(occasion.rawValue)-\(day)-\(ordinal ?? 0)" }

    public init(occasion: IslamicOccasion, day: GregorianDay, ordinal: Int? = nil, isVerified: Bool) {
        self.occasion = occasion
        self.day = day
        self.ordinal = ordinal
        self.isVerified = isVerified
    }
}

/// Dini gün ve geceleri hesaplayan katman.
///
/// **Neden tersten tarama.** Elimizdeki dönüştürücüler miladi → hicri yönünde çalışıyor.
/// "1 Ramazan hangi miladi güne denk geliyor" sorusu için ayrı bir ters algoritma yazmak
/// yerine, aralıktaki her miladi günün hicri karşılığını hesaplayıp eşleşeni buluyoruz.
/// Bir yıl 365 gün; maliyeti yok. Kazancı büyük: hesap **tam olarak uygulamanın kullandığı
/// dönüştürücüyü** kullanıyor, Diyanet düzeltme tablosu dahil. Ayrı bir ters algoritma
/// yazsaydık ikisi birbirinden ayrı düşebilirdi.
public struct IslamicCalendar: Sendable {

    private let converter: HijriDateConverting

    public init(converter: HijriDateConverting = DiyanetHijriDateConverter()) {
        self.converter = converter
    }

    /// Verilen miladi yıla düşen tüm dini gün ve geceler, tarih sırasıyla.
    ///
    /// Bir miladi yılda aynı kandil **iki kez** görünebilir (hicri yıl 11 gün kısa) ya da
    /// hiç görünmeyebilir. Bu yüzden sonuç bir sözlük değil, dizi.
    public func occasions(inGregorianYear year: Int) -> [IslamicOccasionDay] {
        // Kenar boşluğu: Regaib, Recep'ten önceki güne düşebiliyor (aşağıya bakınız) ve
        // yıl sınırındaki olaylar taşabiliyor. Bir aylık pay yeterli.
        let days = scan(from: GregorianDay(year: year - 1, month: 12, day: 1),
                        to: GregorianDay(year: year + 1, month: 1, day: 31))

        var result: [IslamicOccasionDay] = []
        result += dayOccasions(in: days)
        result += nightOccasions(in: days)
        result += regaib(in: days)

        return result
            .filter { $0.day.year == year }
            .sorted { $0.day < $1.day }
    }

    // MARK: - Kurallar

    /// Gün olarak idrak edilenler: miladi tarih, hicri günün kendi karşılığı.
    private func dayOccasions(in days: [(GregorianDay, HijriDate, Date)]) -> [IslamicOccasionDay] {
        var result: [IslamicOccasionDay] = []

        for (gregorian, hijri, date) in days {
            let verified = isVerified(date)
            func add(_ occasion: IslamicOccasion, ordinal: Int? = nil) {
                result.append(IslamicOccasionDay(
                    occasion: occasion, day: gregorian, ordinal: ordinal, isVerified: verified
                ))
            }

            switch (hijri.month, hijri.day) {
            case (1, 1):   add(.hijriNewYear)
            case (1, 10):  add(.ashura)
            case (9, 1):   add(.ramadanStart)
            // Ramazan Bayramı üç gün. Türkiye'de böyle.
            case (10, 1), (10, 2), (10, 3): add(.ramadanFeast, ordinal: hijri.day)
            case (12, 9):  add(.qurbanEve)
            // Kurban Bayramı Türkiye'de DÖRT gün. Genel İslami takvim kütüphaneleri
            // çoğu zaman tek gün işaretliyor; buradaki dört bilinçli.
            case (12, 10), (12, 11), (12, 12), (12, 13):
                add(.qurbanFeast, ordinal: hijri.day - 9)
            default: break
            }
        }

        // Ramazan arefesi "29 Ramazan" diye sabitlenemez: Ramazan 29 da 30 da çekebiliyor.
        // Tanım gereği bayramdan bir önceki gün, yani 1 Şevval'in bir öncesi.
        for (index, entry) in days.enumerated() where entry.1.month == 10 && entry.1.day == 1 {
            guard index > 0 else { continue }
            let eve = days[index - 1]
            result.append(IslamicOccasionDay(
                occasion: .ramadanEve, day: eve.0, isVerified: isVerified(eve.2)
            ))
        }

        return result
    }

    /// Gece olarak idrak edilenler: hicri günün bir ÖNCEKİ miladi gününe yazılır.
    private func nightOccasions(in days: [(GregorianDay, HijriDate, Date)]) -> [IslamicOccasionDay] {
        let nights: [(month: Int, day: Int, occasion: IslamicOccasion)] = [
            (3, 12, .mawlid),        // 11 Rebiülevvel'i 12'sine bağlayan gece
            (7, 27, .miraj),         // 26 Recep'i 27'sine bağlayan gece
            (8, 15, .berat),         // 14 Şaban'ı 15'ine bağlayan gece
            (9, 27, .laylatAlQadr)   // 26 Ramazan'ı 27'sine bağlayan gece
        ]

        var result: [IslamicOccasionDay] = []
        for (index, entry) in days.enumerated() {
            guard index > 0 else { continue }
            guard let match = nights.first(where: { $0.month == entry.1.month && $0.day == entry.1.day })
            else { continue }
            let eve = days[index - 1]
            result.append(IslamicOccasionDay(
                occasion: match.occasion, day: eve.0, isVerified: isVerified(eve.2)
            ))
        }
        return result
    }

    /// Regaib Kandili — tek haftanın gününe bağlı kural.
    ///
    /// Tanım: Recep ayının **ilk cuma gecesi**, yani ilk perşembeyi cumaya bağlayan gece.
    /// Sonuç bu yüzden **her zaman bir perşembeye** düşüyor ve sabit bir hicri günü yok;
    /// 1 ile 7 Recep arasında herhangi bir geceye denk gelebiliyor.
    ///
    /// **Kritik kenar durum:** 1 Recep'in kendisi cumaya denk gelirse Regaib, Recep'ten
    /// ÖNCEKİ güne (30 Cemaziyelahir'e) düşüyor. 2019'da tam bu oldu — Recep 8 Mart Cuma
    /// başladı, Regaib 7 Mart Perşembe ilan edildi. "Recep aralığına kırp" gibi bir kontrol
    /// koyarsak o yılların kandilini kaçırırız; o yüzden yok.
    private func regaib(in days: [(GregorianDay, HijriDate, Date)]) -> [IslamicOccasionDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        var result: [IslamicOccasionDay] = []
        var seenRajabYears: Set<Int> = []

        for (index, entry) in days.enumerated() {
            let (_, hijri, date) = entry
            guard hijri.month == 7 else { continue }
            guard !seenRajabYears.contains(hijri.year) else { continue }
            guard calendar.component(.weekday, from: date) == 6 else { continue }  // 6 = Cuma
            guard index > 0 else { continue }

            seenRajabYears.insert(hijri.year)
            let eve = days[index - 1]
            result.append(IslamicOccasionDay(
                occasion: .regaib, day: eve.0, isVerified: isVerified(eve.2)
            ))
        }
        return result
    }

    // MARK: - Tarama

    /// Aralıktaki her gün için (miladi gün, hicri karşılığı, çapa tarih).
    ///
    /// Çapa öğle vakti UTC: hangi saat diliminden bakılırsa bakılsın gün kaymasın.
    private func scan(
        from start: GregorianDay, to end: GregorianDay
    ) -> [(GregorianDay, HijriDate, Date)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        guard let startDate = noon(start, calendar), let endDate = noon(end, calendar) else {
            return []
        }

        var result: [(GregorianDay, HijriDate, Date)] = []
        var cursor = startDate
        while cursor <= endDate {
            let comps = calendar.dateComponents([.year, .month, .day], from: cursor)
            if let y = comps.year, let m = comps.month, let d = comps.day {
                result.append((
                    GregorianDay(year: y, month: m, day: d),
                    converter.hijriDate(from: cursor),
                    cursor
                ))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private func noon(_ day: GregorianDay, _ calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = 12
        return calendar.date(from: components)
    }

    private func isVerified(_ date: Date) -> Bool {
        (converter as? DiyanetHijriDateConverter)?.isVerified(date) ?? false
    }
}
