import Foundation
import XCTest
import PrayerKit
@testable import NamazCore

@MainActor
final class CityPickerViewModelTests: XCTestCase {

    /// Debounce testlerde sıfır: gerçek 300 ms beklemek testi yavaşlatır, üstelik
    /// zamanlamaya bağlı kırılganlık yaratır.
    private func makeModel(
        search: CitySearching = StubCitySearch()
    ) -> CityPickerViewModel {
        CityPickerViewModel(search: search, debounce: .zero)
    }

    func test_shortQuery_doesNotSearch() async {
        let model = makeModel()
        model.query = "i"
        model.queryChanged()
        await model.waitForPendingSearch()

        // Tek harf için arama yapmak hem kotayı harcar hem de yüzlerce alakasız sonuç verir.
        XCTAssertEqual(model.state, .empty)
    }

    func test_matchingQuery_producesResults() async {
        let model = makeModel()
        model.query = "ista"
        model.queryChanged()
        await model.waitForPendingSearch()

        guard case .results(let results) = model.state else {
            return XCTFail("Sonuç bekleniyordu, durum: \(model.state)")
        }
        XCTAssertEqual(results.first?.name, "İstanbul")
    }

    func test_noMatch_isDistinctFromFailure() async {
        let model = makeModel()
        model.query = "zzzzzz"
        model.queryChanged()
        await model.waitForPendingSearch()

        // "Bulunamadı" ile "arama çalışmadı" ayrı durumlar: ilki kullanıcının yazdığıyla,
        // ikincisi sistemle ilgili. Ekranda söylenecek şey de farklı olmalı.
        XCTAssertEqual(model.state, .noResults)
    }

    func test_searchFailure_reportsFailedNotEmpty() async {
        let model = makeModel(search: StubCitySearch(error: .unavailable))
        model.query = "ankara"
        model.queryChanged()
        await model.waitForPendingSearch()

        XCTAssertEqual(model.state, .failed)
    }

    func test_clearingQuery_returnsToEmpty() async {
        let model = makeModel()
        model.query = "ankara"
        model.queryChanged()
        await model.waitForPendingSearch()
        model.query = ""
        model.queryChanged()
        await model.waitForPendingSearch()

        XCTAssertEqual(model.state, .empty)
    }

    func test_candidateCarriesItsOwnTimeZone() async {
        let model = makeModel()
        model.query = "berlin"
        model.queryChanged()
        await model.waitForPendingSearch()

        guard case .results(let results) = model.state, let berlin = results.first else {
            return XCTFail("Berlin bekleniyordu, durum: \(model.state)")
        }
        // Yurt dışındaki şehrin saat dilimi kendisiyle birlikte taşınmalı — cihazınki değil.
        // Aksi hâlde Türkiye'deki bir kullanıcı Berlin'in vakitlerini Türkiye saatiyle görürdü.
        XCTAssertEqual(berlin.asSavedLocation().coordinate.timeZoneIdentifier, "Europe/Berlin")
    }
}

final class PreferencesTests: XCTestCase {

    private func makePreferences() -> Preferences {
        Preferences(store: InMemoryPreferenceStore())
    }

    private let ankara = SavedLocation(
        name: "Ankara",
        coordinate: Coordinate(latitude: 39.93, longitude: 32.86, timeZoneIdentifier: "Europe/Istanbul"),
        source: .manual
    )

    func test_locationRoundTrips() {
        let preferences = makePreferences()
        XCTAssertNil(preferences.selectedLocation())

        preferences.setSelectedLocation(ankara)
        XCTAssertEqual(preferences.selectedLocation(), ankara)

        preferences.setSelectedLocation(nil)
        XCTAssertNil(preferences.selectedLocation(), "nil yazmak kaydı silmeli")
    }

    func test_settingsRoundTripAndDefaultToDiyanet() {
        let preferences = makePreferences()

        // Hiç kayıt yokken Diyanet varsayılanı gelmeli — Şafii ikindi dahil.
        XCTAssertEqual(preferences.calculationSettings().madhab, .shafi)

        var custom = CalculationSettings.defaultForTurkey()
        custom.madhab = .hanafi
        custom.manualOffsets = [PrayerOffset(prayer: .fajr, minutes: -2)]
        preferences.setCalculationSettings(custom)

        XCTAssertEqual(preferences.calculationSettings(), custom)
    }

    func test_corruptStoredData_fallsBackInsteadOfCrashing() {
        let store = InMemoryPreferenceStore()
        store.setData(Data("bu json değil".utf8), forKey: "namaz.selectedLocation")
        store.setData(Data("bu da değil".utf8), forKey: "namaz.calculationSettings")
        let preferences = Preferences(store: store)

        // Bir uygulama güncellemesinden sonra eski biçimdeki kayıt yüzünden açılmayan bir
        // uygulama, kaydı yok saymaktan çok daha kötü.
        XCTAssertNil(preferences.selectedLocation())
        XCTAssertEqual(preferences.calculationSettings(), .defaultForTurkey())
    }
}

@MainActor
final class HomeViewModelPersistenceTests: XCTestCase {

    private let izmir = SavedLocation(
        name: "İzmir",
        coordinate: Coordinate(latitude: 38.42, longitude: 27.14, timeZoneIdentifier: "Europe/Istanbul"),
        source: .manual
    )

    func test_selectedCitySurvivesRelaunch() async {
        let store = InMemoryPreferenceStore()

        let first = HomeViewModel(
            locationService: StubLocationService(),
            preferences: Preferences(store: store)
        )
        first.selectManualLocation(izmir)

        // Aynı depoyla yeni bir model — uygulamanın kapanıp açılmasının karşılığı.
        let second = HomeViewModel(
            locationService: StubLocationService(authorization: .denied),
            preferences: Preferences(store: store)
        )
        await second.refresh()

        XCTAssertEqual(second.state.schedule?.location.name, "İzmir")
    }

    func test_returningToDeviceLocation_clearsTheSavedCity() async {
        let store = InMemoryPreferenceStore()
        let model = HomeViewModel(
            locationService: StubLocationService(),
            preferences: Preferences(store: store)
        )

        model.selectManualLocation(izmir)
        await model.useDeviceLocation()

        XCTAssertNil(Preferences(store: store).selectedLocation())
    }

    func test_settingsChangeIsPersisted() async {
        let store = InMemoryPreferenceStore()
        let model = HomeViewModel(
            locationService: StubLocationService(),
            preferences: Preferences(store: store)
        )
        await model.refresh()

        var hanafi = CalculationSettings.defaultForTurkey()
        hanafi.madhab = .hanafi
        model.apply(settings: hanafi)

        XCTAssertEqual(Preferences(store: store).calculationSettings().madhab, .hanafi)
    }
}
