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
        madhab: Madhab = .hanafi,
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

    /// Turkey-appropriate defaults (Diyanet-approximating method, Hanafi Asr). `latitude` is
    /// used only to pick a sensible starting high-latitude rule — irrelevant for almost all
    /// of Turkey, but keeps the default sane for a diaspora user opening the app abroad.
    public static func defaultForTurkey(latitude: Double = 39.0) -> CalculationSettings {
        CalculationSettings(
            method: .turkey,
            madhab: .hanafi,
            highLatitudeRule: .recommended(forLatitude: latitude)
        )
    }
}
