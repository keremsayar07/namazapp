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
    /// Mean Earth radius in metres (IUGG mean radius R₁, the arithmetic mean of the WGS-84
    /// ellipsoid's three semi-axes). Using a sphere costs up to ~0.5% versus a full geodesic
    /// solution — irrelevant for a figure shown to the nearest kilometre.
    public static let earthRadius: Double = 6_371_008.8

    /// Great-circle distance to the Kaaba, in metres.
    public static func distanceToKaaba(from coordinate: Coordinate) -> Double {
        distance(from: coordinate, to: kaaba)
    }

    /// Great-circle distance between two coordinates, in metres.
    ///
    /// Haversine rather than the plain spherical law of cosines: the latter loses precision
    /// for small distances because `acos` is ill-conditioned near 1, and this same function
    /// would then be wrong for any future short-distance use.
    public static func distance(from origin: Coordinate, to destination: Coordinate) -> Double {
        let lat1 = origin.latitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let deltaLat = lat2 - lat1
        let deltaLon = (destination.longitude - origin.longitude) * .pi / 180

        let a = pow(sin(deltaLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(deltaLon / 2), 2)
        return 2 * earthRadius * asin(min(1, sqrt(a)))
    }

    /// The signed turn from `heading` to `bearing`, in `-180...180`: positive means turn
    /// clockwise (to the right), negative counter-clockwise.
    ///
    /// The wrap-around is the whole point. Naive subtraction says a device pointing at 350°
    /// must turn −340° to reach 10°, when the answer is +20°; a compass built on that
    /// arithmetic spins the long way round past north.
    public static func relativeAngle(from heading: Double, to bearing: Double) -> Double {
        let raw = (bearing - heading).truncatingRemainder(dividingBy: 360)
        if raw > 180 { return raw - 360 }
        if raw < -180 { return raw + 360 }
        return raw
    }

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
