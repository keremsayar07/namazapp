import Foundation

/// A user's manual fine-tuning for one prayer, in minutes (positive = later, negative = earlier).
/// Modeled as a small struct rather than `[Prayer: Int]` so the type stays trivially `Codable`
/// (dictionaries with a non-`String`/`Int` `Key` don't get the compact JSON-object encoding).
public struct PrayerOffset: Codable, Sendable, Hashable {
    public var prayer: Prayer
    public var minutes: Int

    public init(prayer: Prayer, minutes: Int) {
        self.prayer = prayer
        self.minutes = minutes
    }
}
