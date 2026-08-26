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

/// Türkçe metinde arama karşılaştırması.
///
/// `localizedCaseInsensitiveContains` bu iş için yetmiyor ve nedeni sinsi: Unicode kuralı
/// gereği "İ" küçük harfe indiğinde tek bir karaktere değil, **iki koda** dönüşüyor —
/// `i` artı birleşen nokta (U+0307). Yani "İstanbul" küçük harfte "i̇stanbul" oluyor ve
/// kullanıcının yazdığı "ista" ile eşleşmiyor. Aramada hiçbir sonuç dönmüyor, ortada da
/// görünür bir hata yok.
///
/// Çözüm, karşılaştırmadan önce her iki tarafı da ASCII'ye indirmek. Tablo kod
/// noktalarıyla kuruluyor ki bu dosyada tek bir Türkçe karakter geçmesin — kaynak dosya
/// kodlaması ne olursa olsun çalışsın.
enum SearchFolding {
    private static let map: [UInt32: Character] = [
        0x0131: "i", 0x0130: "i", 0x0049: "i", 0x0069: "i",   // ı İ I i
        0x015F: "s", 0x015E: "s",                             // ş Ş
        0x011F: "g", 0x011E: "g",                             // ğ Ğ
        0x00FC: "u", 0x00DC: "u",                             // ü Ü
        0x00F6: "o", 0x00D6: "o",                             // ö Ö
        0x00E7: "c", 0x00C7: "c",                             // ç Ç
        0x00E2: "a", 0x00C2: "a",                             // â Â
        0x00EE: "i", 0x00CE: "i",                             // î Î
        0x00FB: "u", 0x00DB: "u"                              // û Û
    ]

    static func fold(_ text: String) -> String {
        String(text.unicodeScalars.map { scalar in
            map[scalar.value] ?? Character(scalar)
        }).lowercased()
    }

    static func contains(_ haystack: String, _ needle: String) -> Bool {
        fold(haystack).contains(fold(needle))
    }
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
            SearchFolding.contains($0.name, trimmed)
                || SearchFolding.contains($0.region, trimmed)
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
