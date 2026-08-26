import Foundation
import XCTest
import PrayerKit
@testable import NamazCore

@MainActor
final class QiblaViewModelTests: XCTestCase {

    private let istanbul = SavedLocation(
        name: "İstanbul",
        coordinate: Coordinate(latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"),
        source: .manual
    )

    private func makeModel(
        location: SavedLocation? = nil,
        compass: Bool = true
    ) -> QiblaViewModel {
        QiblaViewModel(
            location: location ?? istanbul,
            headingService: StubHeadingService(isAvailable: compass)
        )
    }

    private func reading(_ degrees: Double, accuracy: Double = 5) -> HeadingSnapshot {
        HeadingSnapshot(trueHeading: degrees, accuracy: accuracy)
    }

    /// Yumuşatma yüzünden tek okuma hedefe tam oturmuyor. Aynı okumayı yeterince
    /// tekrarlamak ibreyi oraya yakınsatıyor — gerçek kullanımda da olan bu.
    private func settle(_ model: QiblaViewModel, at degrees: Double, samples: Int = 60) {
        for _ in 0..<samples { model.ingest(reading(degrees)) }
    }

    // MARK: - Uygunluk durumları

    func test_withoutLocationNothingCanBeComputed() {
        let model = QiblaViewModel(location: nil, headingService: StubHeadingService())
        XCTAssertEqual(model.availability, .noLocation)
        XCTAssertNil(model.bearing)
        XCTAssertNil(model.distanceMeters)
        XCTAssertNil(model.relativeAngle)
        XCTAssertFalse(model.isAligned)
    }

    func test_withoutCompassTheBearingIsStillKnown() {
        // Pusulasız cihazda bile kıble açısı hesaplanabilir; ekran onu göstermeye devam
        // etmeli, çünkü kullanıcı başka bir pusulayla yönü bulabilir.
        let model = makeModel(compass: false)
        XCTAssertEqual(model.availability, .noCompass)
        XCTAssertNotNil(model.bearing)
        XCTAssertNotNil(model.distanceMeters)
        XCTAssertNil(model.relativeAngle)
    }

    func test_compassPresentButNoReadingYet() {
        let model = makeModel()
        XCTAssertEqual(model.availability, .waiting)
        XCTAssertNil(model.heading)
    }

    func test_afterAReadingItGoesLive() {
        let model = makeModel()
        model.ingest(reading(90))
        XCTAssertEqual(model.availability, .live)
        XCTAssertNotNil(model.heading)
    }

    // MARK: - Okuma geçerliliği

    func test_invalidReadingIsIgnored() {
        let model = makeModel()
        settle(model, at: 90)
        let before = model.heading

        // trueHeading −1, accuracy −1: CoreLocation'ın "geçerli okumam yok" işareti.
        model.ingest(HeadingSnapshot(trueHeading: -1, accuracy: -1))

        // Son iyi değer korunuyor: ibrenin yok olup geri gelmesi kaymasından beter.
        XCTAssertEqual(model.heading, before)
    }

    func test_poorAccuracyIsSurfaced() {
        let model = makeModel()
        model.ingest(reading(90, accuracy: 40))
        XCTAssertTrue(model.needsCalibration, "40° sapma kullanıcıya söylenmeli")

        model.ingest(reading(90, accuracy: 4))
        XCTAssertFalse(model.needsCalibration)
    }

    // MARK: - Yumuşatma

    func test_smoothingConvergesToTheReading() {
        let model = makeModel()
        settle(model, at: 217)
        XCTAssertEqual(model.heading ?? 0, 217, accuracy: 0.5)
    }

    func test_firstReadingIsTakenAsIs() {
        // Sıfırdan yumuşatmaya başlansaydı ibre önce kuzeyi gösterip oradan yola çıkardı.
        let model = makeModel()
        model.ingest(reading(217))
        XCTAssertEqual(model.heading ?? 0, 217, accuracy: 0.001)
    }

    func test_smoothingCrossesNorthWithoutSpinningAround() {
        // Asıl mesele bu: 359° ile 1° arası 2 derecelik bir yol. Dereceleri doğrudan
        // ortalayan bir yumuşatma ibreyi 180°'ye, yani tam ters yöne savururdu.
        let model = makeModel()
        settle(model, at: 359)
        model.ingest(reading(1))

        guard let heading = model.heading else { return XCTFail("Okuma yok") }
        let distanceFromNorth = min(heading, 360 - heading)
        XCTAssertLessThan(distanceFromNorth, 2, "İbre kuzeyin yakınında kalmalı, bulunan: \(heading)°")
    }

    // MARK: - Hizalama

    func test_alignedWhenPointingAtTheQibla() {
        let model = makeModel()
        guard let bearing = model.bearing else { return XCTFail("Açı yok") }

        settle(model, at: bearing)
        XCTAssertTrue(model.isAligned)
        XCTAssertEqual(model.relativeAngle ?? 99, 0, accuracy: QiblaViewModel.alignmentTolerance)
    }

    func test_notAlignedWhenFacingAway() {
        let model = makeModel()
        guard let bearing = model.bearing else { return XCTFail("Açı yok") }

        settle(model, at: (bearing + 180).truncatingRemainder(dividingBy: 360))
        XCTAssertFalse(model.isAligned)
        XCTAssertEqual(abs(model.relativeAngle ?? 0), 180, accuracy: 1)
    }

    func test_relativeAngleTellsWhichWayToTurn() {
        let model = makeModel()
        guard let bearing = model.bearing else { return XCTFail("Açı yok") }

        // Kıbleden 30° solda duruyoruz: sağa dönmemiz söylenmeli (pozitif).
        settle(model, at: (bearing - 30 + 360).truncatingRemainder(dividingBy: 360))
        XCTAssertEqual(model.relativeAngle ?? 0, 30, accuracy: 1)

        let other = makeModel()
        settle(other, at: (bearing + 30).truncatingRemainder(dividingBy: 360))
        XCTAssertEqual(other.relativeAngle ?? 0, -30, accuracy: 1)
    }

    // MARK: - Konum değişimi

    func test_changingCityChangesTheBearing() {
        let model = makeModel()
        let istanbulBearing = model.bearing

        let tromso = SavedLocation(
            name: "Tromsø",
            coordinate: Coordinate(latitude: 69.6492, longitude: 18.9553, timeZoneIdentifier: "Europe/Oslo"),
            source: .manual
        )
        model.update(location: tromso)

        XCTAssertNotEqual(model.bearing, istanbulBearing)
        XCTAssertNotNil(model.bearing)
    }

    func test_startWithoutCompassEndsImmediately() async {
        // Pusulası olmayan cihazda `start()` asılı kalmamalı; ekran sonsuza kadar
        // "bekleniyor" göstermesin.
        let model = makeModel(compass: false)
        await model.start()
        XCTAssertEqual(model.availability, .noCompass)
    }

    func test_startConsumesTheStream() async {
        let model = QiblaViewModel(
            location: istanbul,
            headingService: StubHeadingService(
                snapshots: (0..<40).map { _ in HeadingSnapshot(trueHeading: 120, accuracy: 6) }
            )
        )
        await model.start()
        XCTAssertEqual(model.heading ?? 0, 120, accuracy: 1)
    }
}
