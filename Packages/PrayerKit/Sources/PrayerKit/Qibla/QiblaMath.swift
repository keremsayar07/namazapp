import Foundation

/// Pure great-circle bearing math — no CoreLocation dependency, so it's usable from the widget
/// or a future watch target too, and trivially unit-testable with literal coordinates.
public enum QiblaMath {

    /// Kaaba coordinates (Masjid al-Haram, Mecca).
    public static let kaaba = Coordinate(latitude: 21.4225, longitude: 39.8262, timeZoneIdentifier: "Asia/Riyadh")

    /// Initial great-circle bearing from `coordinate` to the Kaaba, in degrees clockwise from
    /// true north, in `0..<360`.
    public static func qiblaBearing(from coordinate: Coordinate) -> Double {
        bearing(from: coordinate, to: kaaba)
    }

    /// Initial great-circle bearing from `origin` to `destination`, in degrees clockwise from
    /// true north, in `0..<360`. Standalone (not Kaaba-specific) so it can be unit-tested
    /// against unambiguous geometric facts (e.g. due-east/due-north cases) without relying on
    /// an external "known Qibla angle" reference figure.
    public static func bearing(from origin: Coordinate, to destination: Coordinate) -> Double {
        let lat1 = origin.latitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let deltaLon = (destination.longitude - origin.longitude) * .pi / 180

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let bearingDegrees = atan2(y, x) * 180 / .pi
        return (bearingDegrees + 360).truncatingRemainder(dividingBy: 360)
    }
}
