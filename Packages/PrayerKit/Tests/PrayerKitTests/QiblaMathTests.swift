import Foundation
import XCTest
@testable import PrayerKit

/// Verified against unambiguous spherical-geometry facts (due-east / due-north bearings)
/// rather than an external "known Qibla angle for city X" figure — those weren't independently
/// verified against an official source, so asserting a precise expected value here would be
/// exactly the kind of unverified reference data `VERIFICATION_NEEDED.md` warns against.
/// The Istanbul case below only asserts a broad, unmistakably-correct compass quadrant.
final class QiblaMathTests: XCTestCase {

    func test_dueEastOnEquator_is90DegreeBearing() {
        let origin = Coordinate(latitude: 0, longitude: 0, timeZoneIdentifier: "UTC")
        let destination = Coordinate(latitude: 0, longitude: 90, timeZoneIdentifier: "UTC")
        let bearing = QiblaMath.bearing(from: origin, to: destination)
        XCTAssertEqual(bearing, 90, accuracy: 0.001)
    }

    func test_dueNorthTowardPole_is0DegreeBearing() {
        let origin = Coordinate(latitude: 10, longitude: 30, timeZoneIdentifier: "UTC")
        let destination = Coordinate(latitude: 89, longitude: 30, timeZoneIdentifier: "UTC")
        let bearing = QiblaMath.bearing(from: origin, to: destination)
        XCTAssertEqual(bearing, 0, accuracy: 0.001)
    }

    func test_dueSouth_is180DegreeBearing() {
        let origin = Coordinate(latitude: 10, longitude: 30, timeZoneIdentifier: "UTC")
        let destination = Coordinate(latitude: -10, longitude: 30, timeZoneIdentifier: "UTC")
        let bearing = QiblaMath.bearing(from: origin, to: destination)
        XCTAssertEqual(bearing, 180, accuracy: 0.001)
    }

    func test_bearing_isAlwaysNormalizedTo0Through360() {
        for coordinate in [TestCities.istanbul, TestCities.ankara, TestCities.gaziantep, TestCities.tromso] {
            let bearing = QiblaMath.qiblaBearing(from: coordinate)
            XCTAssertTrue(bearing >= 0 && bearing < 360)
        }
    }

    func test_istanbulQibla_isPlausiblySouthEast() {
        // Sanity check only (Kaaba lies SE of Turkey), not a precise reference figure.
        let bearing = QiblaMath.qiblaBearing(from: TestCities.istanbul)
        XCTAssertTrue(bearing > 90 && bearing < 180, "Beklenen kabaca güneydoğu yönü, hesaplanan: \(bearing)°")
    }
}
