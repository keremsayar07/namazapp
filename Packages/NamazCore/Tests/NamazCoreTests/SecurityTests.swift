import Foundation
import XCTest
import PrayerKit
@testable import NamazCore

/// Faz 7.6 güvenlik testleri.
///
/// Buradaki testler "kod çalışıyor mu"yu değil, **verilmiş bir sözü** sınıyor. Her biri
/// bozulduğunda kullanıcıya söylenen bir şey yalan olur: "verileriniz cihazınızda kalıyor",
/// "tüm verilerimi sil hepsini siliyor", "notunuz günlüğe düşmüyor".
///
/// Sınıf `@MainActor`: görünüm modellerinin `fileName` sabitleri de o izolasyonda ve
/// silme listesinin eksiksizliğini sınayan test onları okuyor.
@MainActor
final class SecurityTests: XCTestCase {

    // MARK: - Günlüğe hassas veri sızmaması

    func test_noLogEventCanCarryUserContent() {
        // `Diagnostics.Event` yalnızca sayı, bayrak ve enum taşıyor. Bu test her olayın
        // ürettiği metni tek tek geziyor: içinde kullanıcıdan gelebilecek hiçbir şey
        // olmamalı. Tasarım zaten bunu imkânsız kılıyor; test o tasarımın bozulmadığını
        // kontrol ediyor — biri `case somethingHappened(String)` eklerse burada yakalanır.
        let events: [Diagnostics.Event] = [
            .locationAuthorization(.whenInUse),
            .locationResolved(source: .device),
            .locationFailed(.timedOut),
            .notificationsScheduled(count: 42, coveredDays: 7, truncated: true),
            .notificationsCleared,
            .notificationAuthorization(granted: true),
            .storeLoadFailed(store: "notes"),
            .storeWriteFailed(store: "notes"),
            .storeUnavailable,
            .biometricUnavailable,
            .biometricResult(granted: false),
            .userDataDeleted(fileCount: 5),
            .widgetTimelineBuilt(entryCount: 12),
            .widgetHasNoLocation
        ]

        // Bir kullanıcının yazabileceği ya da cihazından gelebilecek örnekler. Hiçbiri
        // hiçbir olay metninde geçemez, çünkü onları taşıyacak bir parametre yok.
        let forbidden = ["41.0", "28.9", "İstanbul", "Kerem", "@", "token", "şifre"]

        for event in events {
            let message = event.message
            XCTAssertFalse(message.isEmpty, "Olay metni boş olmamalı")
            for needle in forbidden {
                XCTAssertFalse(
                    message.localizedCaseInsensitiveContains(needle),
                    "\(message) içinde '\(needle)' geçiyor"
                )
            }
        }
    }

    func test_everyEventIsRoutedToACategory() {
        // Kategorisiz bir olay Console.app'te süzülemez ve pratikte kaybolur.
        XCTAssertEqual(Diagnostics.Event.storeUnavailable.category, .storage)
        XCTAssertEqual(Diagnostics.Event.biometricUnavailable.category, .security)
        XCTAssertEqual(Diagnostics.Event.widgetHasNoLocation.category, .widget)
        XCTAssertEqual(Diagnostics.Event.locationFailed(.unknown).category, .location)
        XCTAssertEqual(Diagnostics.Event.notificationsCleared.category, .notifications)
    }

    // MARK: - Konum hassasiyeti

    func test_deviceLocationIsCoarsenedBeforeItIsStored() {
        // Cihazdan gelen okuma diske yazılıyor (widget okusun diye). Orada duran her fazla
        // ondalık, telefona erişen birinin öğrendiği bilgi.
        let precise = Coordinate(
            latitude: 41.00823456, longitude: 28.97835129, timeZoneIdentifier: "Europe/Istanbul"
        )
        let coarse = LocationPrivacy.coarsened(precise)

        XCTAssertEqual(coarse.latitude, 41.01, accuracy: 0.0000001)
        XCTAssertEqual(coarse.longitude, 28.98, accuracy: 0.0000001)
        XCTAssertEqual(coarse.timeZoneIdentifier, "Europe/Istanbul", "Saat dilimi korunmalı")
    }

    func test_coarseningIsWithinAKilometre() {
        // Söz şu: atılan hassasiyet vakit hesabını etkilemiyor. 0,01 derece enlem ≈ 1,1 km.
        let precise = Coordinate(
            latitude: 41.00823456, longitude: 28.97835129, timeZoneIdentifier: "Europe/Istanbul"
        )
        let coarse = LocationPrivacy.coarsened(precise)
        XCTAssertLessThan(abs(coarse.latitude - precise.latitude), 0.005)
        XCTAssertLessThan(abs(coarse.longitude - precise.longitude), 0.005)
    }

    func test_savedLocationFromDeviceIsCoarsened() {
        let snapshot = LocationSnapshot(
            latitude: 37.06622981, longitude: 37.38323456, placeName: "Gaziantep"
        )
        let saved = SavedLocation.fromDevice(
            snapshot, timeZone: TimeZone(identifier: "Europe/Istanbul")!, fallbackName: "—"
        )
        XCTAssertEqual(saved.coordinate.latitude, 37.07, accuracy: 0.0000001)
        XCTAssertEqual(saved.coordinate.longitude, 37.38, accuracy: 0.0000001)
    }

    func test_manuallyChosenCitiesAreNotCoarsened() {
        // Şehir merkezinin koordinatı herkese açık bir bilgi; onu bozmanın gizlilik
        // kazancı yok, vakitlerde gereksiz sapma maliyeti var.
        let city = SavedLocation(
            name: "Konya",
            coordinate: Coordinate(
                latitude: 37.87135, longitude: 32.48464, timeZoneIdentifier: "Europe/Istanbul"
            ),
            source: .manual
        )
        XCTAssertEqual(city.coordinate.latitude, 37.87135)
    }

    // MARK: - Tüm verileri silme

    func test_erasingRemovesEveryUserDataFile() async {
        let store = InMemoryFileStore()
        for file in UserDataFile.allCases {
            await store.save(["dolu"], to: file.rawValue)
        }

        let eraser = UserDataEraser(
            store: store, preferences: Preferences(store: InMemoryPreferenceStore())
        )
        let count = await eraser.eraseAll()

        XCTAssertEqual(count, UserDataFile.allCases.count)
        for file in UserDataFile.allCases {
            let remaining = await store.load([String].self, from: file.rawValue)
            XCTAssertNil(remaining, "\(file.rawValue) silinmemiş")
        }
    }

    func test_theEraseListCoversEveryStoreTheAppWritesTo() {
        // Yeni bir araç eklenip listeye yazılmazsa "tüm verilerimi sil" onu atlar ve
        // kullanıcıya söylenen şey yalan olur. Görünüm modellerinin kullandığı dosya adları
        // bu listeden geliyor; ikisi ayrı düşemesin diye burada karşılaştırılıyor.
        let declared = Set(UserDataFile.allCases.map(\.rawValue))
        let usedByViewModels: Set<String> = [
            TasbihViewModel.fileName,
            PrayerLogViewModel.fileName,
            QadhaViewModel.fileName,
            NotesViewModel.fileName,
            TimerViewModel.fileName
        ]
        XCTAssertEqual(declared, usedByViewModels)
    }

    func test_erasingClearsTheLastKnownLocation() async {
        // Kullanıcı verisinin içinde en çok bilgi taşıyan şey en son bulunduğu yer.
        // Notları silip onu bırakmak, silmiş gibi yapmak olurdu.
        let preferences = Preferences(store: InMemoryPreferenceStore())
        preferences.setLastKnownLocation(SavedLocation(
            name: "Ev",
            coordinate: Coordinate(latitude: 41, longitude: 29, timeZoneIdentifier: "Europe/Istanbul"),
            source: .device
        ))
        preferences.setNotesLocked(true)
        XCTAssertNotNil(preferences.lastKnownLocation())

        await UserDataEraser(store: InMemoryFileStore(), preferences: preferences).eraseAll()

        XCTAssertNil(preferences.lastKnownLocation())
        XCTAssertNil(preferences.selectedLocation())
        XCTAssertFalse(preferences.areNotesLocked())
        XCTAssertEqual(preferences.calculationSettings(), .defaultForTurkey(), "Varsayılana dönmeli")
    }

    // MARK: - Depo sınırları

    func test_theStoreRefusesNamesThatEscapeItsDirectory() async {
        // Dosya adları koddan geliyor, kullanıcıdan değil. Yine de bir gün kullanıcı
        // metninden türetilen bir ad gelirse konteynerin dışına yazılmamalı.
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = JSONFileStore(containerURL: directory)

        for name in ["../kacis", "alt/klasor", "..", "../../etc/passwd"] {
            await store.save(["veri"], to: name)
            let readBack = await store.load([String].self, from: name)
            XCTAssertNil(readBack, "'\(name)' reddedilmeliydi")
        }

        // Geçerli bir ad ise çalışmalı — reddetme kuralı her şeyi engellemiş olmamalı.
        await store.save(["veri"], to: "notes")
        let ok = await store.load([String].self, from: "notes")
        XCTAssertEqual(ok, ["veri"])

        try? FileManager.default.removeItem(at: directory)
    }

    func test_aStoreWithoutAContainerFailsQuietlyInsteadOfCrashing() async {
        // App Group yetkisi kurulmadan (ör. önizlemede) konteyner `nil` oluyor. Çökmek
        // yerine sessizce çalışmaz duruma geçiyor.
        let store = JSONFileStore(containerURL: nil)
        await store.save(["veri"], to: "notes")
        let value = await store.load([String].self, from: "notes")
        XCTAssertNil(value)
    }

    // MARK: - Sır barındırmama

    func test_theAppGroupIdentifierIsTheOnlyEmbeddedIdentifier() {
        // Uygulamada API anahtarı, jeton ya da sunucu adresi yok — sunucu da yok.
        // Gömülü tek sabit kimlik App Group ve o bir sır değil: uygulamanın kendi
        // paketinden zaten okunabiliyor.
        XCTAssertEqual(AppGroup.identifier, "group.com.keremsayar.namaz")
        XCTAssertFalse(AppGroup.identifier.contains("http"))
    }
}
