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

    // MARK: - Uzaklık

    // Same discipline as the bearing tests: asserted against exact spherical-geometry
    // identities, never against a looked-up "distance from city X to Mecca" figure.

    func test_quarterWayAroundTheEquator_isAQuarterCircumference() {
        let origin = Coordinate(latitude: 0, longitude: 0, timeZoneIdentifier: "UTC")
        let destination = Coordinate(latitude: 0, longitude: 90, timeZoneIdentifier: "UTC")
        XCTAssertEqual(
            QiblaMath.distance(from: origin, to: destination),
            QiblaMath.earthRadius * .pi / 2,
            accuracy: 1
        )
    }

    func test_antipodalPoints_areHalfACircumferenceApart() {
        let origin = Coordinate(latitude: 0, longitude: 0, timeZoneIdentifier: "UTC")
        let destination = Coordinate(latitude: 0, longitude: 180, timeZoneIdentifier: "UTC")
        XCTAssertEqual(
            QiblaMath.distance(from: origin, to: destination),
            QiblaMath.earthRadius * .pi,
            accuracy: 1
        )
    }

    func test_poleToPole_isHalfACircumference() {
        let north = Coordinate(latitude: 90, longitude: 0, timeZoneIdentifier: "UTC")
        let south = Coordinate(latitude: -90, longitude: 0, timeZoneIdentifier: "UTC")
        XCTAssertEqual(
            QiblaMath.distance(from: north, to: south),
            QiblaMath.earthRadius * .pi,
            accuracy: 1
        )
    }

    func test_distanceToSelf_isZero() {
        // Haversine yerine kosinüs teoremi kullanılsaydı burada `acos(1)` etrafındaki
        // hassasiyet kaybı yüzünden sıfır yerine gürültü çıkardı.
        XCTAssertEqual(QiblaMath.distance(from: TestCities.ankara, to: TestCities.ankara), 0, accuracy: 0.001)
    }

    func test_distanceIsSymmetric() {
        let there = QiblaMath.distance(from: TestCities.istanbul, to: TestCities.gaziantep)
        let back = QiblaMath.distance(from: TestCities.gaziantep, to: TestCities.istanbul)
        XCTAssertEqual(there, back, accuracy: 0.001)
    }

    // MARK: - Bağıl açı

    func test_relativeAngle_isZeroWhenAlreadyFacingTheTarget() {
        XCTAssertEqual(QiblaMath.relativeAngle(from: 137, to: 137), 0, accuracy: 0.001)
    }

    func test_relativeAngle_isPositiveWhenTheTargetIsToTheRight() {
        XCTAssertEqual(QiblaMath.relativeAngle(from: 100, to: 130), 30, accuracy: 0.001)
    }

    func test_relativeAngle_isNegativeWhenTheTargetIsToTheLeft() {
        XCTAssertEqual(QiblaMath.relativeAngle(from: 130, to: 100), -30, accuracy: 0.001)
    }

    func test_relativeAngle_takesTheShortWayAroundNorth() {
        // Çıplak çıkarma −340 derdi; doğru cevap sağa 20 derece.
        XCTAssertEqual(QiblaMath.relativeAngle(from: 350, to: 10), 20, accuracy: 0.001)
        XCTAssertEqual(QiblaMath.relativeAngle(from: 10, to: 350), -20, accuracy: 0.001)
    }

    func test_relativeAngle_staysWithinPlusMinus180() {
        for heading in stride(from: 0.0, to: 360.0, by: 7) {
            for bearing in stride(from: 0.0, to: 360.0, by: 11) {
                let angle = QiblaMath.relativeAngle(from: heading, to: bearing)
                XCTAssertTrue(angle >= -180 && angle <= 180, "\(heading)° → \(bearing)° = \(angle)°")
            }
        }
    }
}
