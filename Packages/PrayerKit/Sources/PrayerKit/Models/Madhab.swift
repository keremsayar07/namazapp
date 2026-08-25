import Foundation

/// Determines how Asr is calculated: Shafi uses the standard shadow-length definition,
/// Hanafi uses a doubled shadow length (so Hanafi Asr falls later in the afternoon).
public enum Madhab: String, CaseIterable, Codable, Sendable, Hashable {
    case shafi
    case hanafi

    /// Shadow-length multiplier used in the Asr hour-angle formula.
    public var asrShadowFactor: Double {
        switch self {
        case .shafi: return 1.0
        case .hanafi: return 2.0
        }
    }

    public var localizationKey: String {
        switch self {
        case .shafi: return "madhab.shafi"
        case .hanafi: return "madhab.hanafi"
        }
    }
}
