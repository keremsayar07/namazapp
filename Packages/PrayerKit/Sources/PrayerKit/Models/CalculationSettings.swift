import Foundation

/// The user's complete, adjustable calculation configuration. `PrayerCalculationService` takes
/// this alongside a `Coordinate` and `Date` — nothing about the calculation reads global state.
public struct CalculationSettings: Codable, Sendable, Hashable {
    public var method: CalculationMethod
    public var madhab: Madhab
    public var highLatitudeRule: HighLatitudeRule
    /// Per-prayer fine-tuning in minutes, applied after the base astronomical calculation
    /// (e.g. "yerel ezan benim bölgemde birkaç dakika farklı okunuyor").
    public var manualOffsets: [PrayerOffset]

    public init(
        method: CalculationMethod = .turkey,
        madhab: Madhab = .shafi,
        highLatitudeRule: HighLatitudeRule = .middleOfTheNight,
        manualOffsets: [PrayerOffset] = []
    ) {
        self.method = method
        self.madhab = madhab
        self.highLatitudeRule = highLatitudeRule
        self.manualOffsets = manualOffsets
    }

    public func manualOffsetMinutes(for prayer: Prayer) -> Int {
        manualOffsets.first { $0.prayer == prayer }?.minutes ?? 0
    }

    /// Diyanet'in yayımladığı takvimi yeniden üreten varsayılanlar.
    ///
    /// **İkindi neden Şafii:** Diyanet'in yayımladığı İkindi vakti asr-ı evvel, yani gölge
    /// çarpanı 1'dir. Ölçüldü: 12 ilde 384 gün üzerinde Şafii ile fark ortalama +4.4 dakika
    /// (std 0.32), Hanefi ile **−52.3 dakika** (std 2.88). Yani Hanefi varsayılanla uygulama
    /// Diyanet'ten yaklaşık bir saat sapardı. Hanefi ikindi ayarlarda seçenek olarak duruyor;
    /// varsayılan olmaması, Türkiye'deki kullanıcının Diyanet'i beklemesinden.
    ///
    /// `latitude` yalnızca makul bir yüksek-enlem kuralı seçmek için — Türkiye'nin neredeyse
    /// tamamı için ilgisiz, ama yurt dışındaki kullanıcı için varsayılanı sağlıklı tutuyor.
    public static func defaultForTurkey(latitude: Double = 39.0) -> CalculationSettings {
        CalculationSettings(
            method: .turkey,
            madhab: .shafi,
            highLatitudeRule: .recommended(forLatitude: latitude)
        )
    }
}
