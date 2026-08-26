import Foundation
import PrayerKit

/// Arama sonucundaki tek bir yer.
public struct CityCandidate: Sendable, Hashable, Identifiable {
    public var id: String { "\(name)|\(region)|\(latitude),\(longitude)" }
    /// İlçe veya şehir adı — listede kalın gösterilen.
    public var name: String
    /// Ayırt edici bağlam: "Ankara, Türkiye" gibi. Aynı adı taşıyan yerleri ayırmaya yarıyor.
    public var region: String
    public var latitude: Double
    public var longitude: Double
    /// Yerin **kendi** saat dilimi.
    ///
    /// Bu alan bu tasarımın can damarı: enlem/boylamdan saat dilimi türetmek normalde ya
    /// ağ sorgusu ya da gömülü bir coğrafi veritabanı gerektirir. `CLPlacemark` bunu zaten
    /// veriyor, dolayısıyla ne üçüncü taraf paket ne de sunucu gerekiyor.
    public var timeZoneIdentifier: String

    public init(
        name: String, region: String,
        latitude: Double, longitude: Double,
        timeZoneIdentifier: String
    ) {
        self.name = name
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public func asSavedLocation() -> SavedLocation {
        SavedLocation(
            name: name,
            coordinate: Coordinate(
                latitude: latitude,
                longitude: longitude,
                timeZoneIdentifier: timeZoneIdentifier
            ),
            source: .manual
        )
    }
}

public enum CitySearchError: Error, Sendable, Hashable {
    /// Sorgu için sonuç yok.
    case noResults
    /// Sistem coğrafi kodlama servisi geçici olarak kullanılamıyor (ağ yok, kota doldu).
    case unavailable
}

public protocol CitySearching: Sendable {
    func search(_ query: String) async throws -> [CityCandidate]
}

/// Test ve önizleme için sabit sonuç dönen arama.
public struct StubCitySearch: CitySearching {
    private let results: [CityCandidate]
    private let error: CitySearchError?

    public init(results: [CityCandidate] = StubCitySearch.sample, error: CitySearchError? = nil) {
        self.results = results
        self.error = error
    }

    public func search(_ query: String) async throws -> [CityCandidate] {
        if let error { throw error }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return results.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.region.localizedCaseInsensitiveContains(trimmed)
        }
    }

    public static let sample: [CityCandidate] = [
        CityCandidate(name: "İstanbul", region: "Türkiye",
                      latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"),
        CityCandidate(name: "Ankara", region: "Türkiye",
                      latitude: 39.9334, longitude: 32.8597, timeZoneIdentifier: "Europe/Istanbul"),
        CityCandidate(name: "Berlin", region: "Almanya",
                      latitude: 52.52, longitude: 13.405, timeZoneIdentifier: "Europe/Berlin")
    ]
}
