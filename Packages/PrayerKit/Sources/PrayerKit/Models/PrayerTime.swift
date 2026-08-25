import Foundation

/// A single computed time for one `Prayer`.
public struct PrayerTime: Codable, Sendable, Hashable, Identifiable {
    public var prayer: Prayer
    /// Absolute instant (always safe to compare/sort across time zones). The UI layer formats
    /// this for display using the location's `timeZone` and the user's 12/24-hour preference.
    public var date: Date

    public var id: Int { prayer.id }

    public init(prayer: Prayer, date: Date) {
        self.prayer = prayer
        self.date = date
    }
}
