import Foundation
import XCTest
import PrayerKit
@testable import NamazCore

/// Bu testler izin akışının her dalını ve gece yarısı/gün sonu sınırlarını kontrol ediyor —
/// yani gerçek cihazda test etmesi en zahmetli, hata yapılması en kolay yerleri.
@MainActor
final class HomeViewModelTests: XCTestCase {

    private let istanbul = SavedLocation(
        id: "test-istanbul",
        name: "İstanbul",
        coordinate: Coordinate(latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"),
        source: .manual
    )

    /// Testler gerçek kullanıcı ayarlarına dokunmamalı: bir test koştuğunda
    /// geliştiricinin seçtiği şehir silinmemeli.
    private func memoryPreferences() -> Preferences {
        Preferences(store: InMemoryPreferenceStore())
    }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso) ?? Date()
    }

    // MARK: - İzin akışı

    func test_whenAuthorizationNotDetermined_itAsksAndProceedsOnGrant() async {
        let service = StubLocationService(
            authorization: .notDetermined,
            authorizationAfterRequest: .whenInUse
        )
        let model = HomeViewModel(locationService: service, preferences: memoryPreferences())

        await model.refresh()

        guard case .ready = model.state else {
            return XCTFail("İzin verilince hazır duruma geçmeliydi, durum: \(model.state)")
        }
    }

    func test_whenUserDeniesAtPrompt_itLandsInDeniedState() async {
        let service = StubLocationService(
            authorization: .notDetermined,
            authorizationAfterRequest: .denied
        )
        let model = HomeViewModel(locationService: service, preferences: memoryPreferences())

        await model.refresh()

        XCTAssertEqual(model.state, .locationDenied)
    }

    func test_whenLocationFailsButPermissionGranted_itDistinguishesUnavailableFromDenied() async {
        let service = StubLocationService(
            authorization: .whenInUse,
            result: .failure(.unavailable)
        )
        let model = HomeViewModel(locationService: service, preferences: memoryPreferences())

        await model.refresh()

        // Bu ayrım önemli: reddedilmişse kullanıcıyı Ayarlar'a, alınamıyorsa tekrar denemeye
        // veya elle şehir seçimine yönlendiriyoruz. İkisini karıştırmak kötü bir akış olurdu.
        XCTAssertEqual(model.state, .locationUnavailable)
    }

    func test_manualLocation_bypassesLocationServiceEntirely() async {
        // Konum servisi reddedilmiş olsa bile elle seçilen şehirle çalışmalı.
        let service = StubLocationService(authorization: .denied)
        let model = HomeViewModel(
            locationService: service, preferences: memoryPreferences(), manualLocation: istanbul
        )

        await model.refresh()

        XCTAssertEqual(model.state.schedule?.location.name, "İstanbul")
    }

    func test_deviceLocationWithoutPlaceName_fallsBackToProvidedLabel() async {
        let service = StubLocationService(
            authorization: .whenInUse,
            result: .success(LocationSnapshot(latitude: 39.93, longitude: 32.86, placeName: nil))
        )
        let model = HomeViewModel(
            locationService: service, preferences: memoryPreferences(), unknownPlaceName: "Konumunuz"
        )

        await model.refresh()

        XCTAssertEqual(model.state.schedule?.location.name, "Konumunuz")
    }

    // MARK: - Sıradaki vakit ve geri sayım

    func test_nextPrayer_isAlwaysPresent_evenLateAtNightAfterIsha() async {
        let model = HomeViewModel(
            locationService: StubLocationService(),
            preferences: memoryPreferences(),
            manualLocation: istanbul
        )
        await model.refresh()

        // Yatsıdan sonra, gece yarısına yakın bir an. Bugünün vakitleri tükendi.
        let lateNight = date("2026-08-25T23:45:00+03:00")
        let next = model.nextPrayer(at: lateNight)

        XCTAssertNotNil(next, "Yatsıdan sonra sıradaki vakit yarının imsağı olmalı, nil değil")
        XCTAssertEqual(next?.prayer, .fajr)
        XCTAssertGreaterThan(next?.date ?? .distantPast, lateNight)
    }

    func test_timeRemaining_isNeverNegative() async {
        let model = HomeViewModel(
            locationService: StubLocationService(),
            preferences: memoryPreferences(),
            manualLocation: istanbul
        )
        await model.refresh()

        for hour in 0...23 {
            let moment = date(String(format: "2026-08-25T%02d:30:00+03:00", hour))
            XCTAssertGreaterThanOrEqual(
                model.timeRemaining(at: moment), 0,
                "Saat \(hour):30 için geri sayım negatife düştü"
            )
        }
    }

    func test_currentPrayer_isNilBeforeTheDaysFirstPrayer() async {
        let model = HomeViewModel(
            locationService: StubLocationService(),
            preferences: memoryPreferences(),
            manualLocation: istanbul
        )
        await model.refresh()

        // Gece yarısından hemen sonra: henüz imsak girmedi, o yüzden vurgulanacak vakit yok.
        XCTAssertNil(model.currentPrayer(at: date("2026-08-25T00:05:00+03:00")))
    }

    // MARK: - Ayar değişikliği

    func test_changingMadhab_recomputesWithoutAskingForLocationAgain() async {
        let service = StubLocationService(authorization: .whenInUse)
        let model = HomeViewModel(locationService: service, preferences: memoryPreferences())
        await model.refresh()

        let shafiAsr = model.state.schedule?.today.time(for: .asr)
        XCTAssertNotNil(shafiAsr)

        var hanafi = CalculationSettings.defaultForTurkey()
        hanafi.madhab = .hanafi
        model.apply(settings: hanafi)

        let hanafiAsr = model.state.schedule?.today.time(for: .asr)
        XCTAssertNotNil(hanafiAsr)
        // Hanefi ikindi her zaman Şafii'den geç veya eşittir.
        XCTAssertGreaterThan(hanafiAsr ?? .distantPast, shafiAsr ?? .distantFuture)
        // Ve hâlâ hazır durumda: konum tekrar sorulmadı.
        XCTAssertNotNil(model.state.schedule)
    }
}
