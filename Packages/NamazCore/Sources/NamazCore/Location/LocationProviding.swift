import Foundation
import PrayerKit

/// Konum izninin uygulama açısından anlamlı hâli. `CLAuthorizationStatus`'ün tüm varyantları
/// yerine dört duruma indirgenmiş, çünkü Home ekranının ayırt etmesi gereken tek şey
/// "sorabilir miyim / kullanabilir miyim / kalıcı olarak kapalı mı".
public enum LocationAuthorization: String, Sendable, Hashable {
    /// Kullanıcıya henüz sorulmadı.
    case notDetermined
    /// Kullanıcı reddetti veya cihaz politikası engelliyor. Sistem tekrar sormayacak;
    /// tek yol Ayarlar. Uygulama bu durumda elle şehir seçimine yönlendirir.
    case denied
    case whenInUse
    case always

    public var canUseLocation: Bool {
        self == .whenInUse || self == .always
    }
}

/// Konum servisinden dönen ham sonuç. `Coordinate`'e çevrilirken saat dilimi gerekiyor;
/// cihazın anlık konumu için cihazın kendi saat dilimi doğru cevap, çünkü kullanıcı
/// oradadır.
public struct LocationSnapshot: Sendable, Hashable {
    public var latitude: Double
    public var longitude: Double
    /// Ters coğrafi kodlama yapılmışsa şehir/ilçe adı — Home ekranında gösterilir.
    public var placeName: String?

    public init(latitude: Double, longitude: Double, placeName: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
    }

    /// Cihazın anlık saat dilimiyle `Coordinate`'e çevirir.
    ///
    /// Enlem/boylamdan saat dilimi türetmek ya ağ sorgusu ya da gömülü bir coğrafi veritabanı
    /// gerektirir; ikisini de istemiyoruz. Cihazın kendi saat dilimi, "kullanıcı şu an
    /// buradadır" varsayımıyla doğru sonucu veriyor. Elle seçilen şehirlerde ise saat dilimi
    /// şehirle birlikte saklanıyor (bkz. `SavedLocation`).
    public func coordinate(timeZone: TimeZone = .current) -> Coordinate {
        Coordinate(
            latitude: latitude,
            longitude: longitude,
            timeZoneIdentifier: timeZone.identifier
        )
    }
}

public enum LocationError: Error, Sendable, Hashable {
    /// Kullanıcı izin vermedi.
    case unauthorized
    /// Cihazda konum servisleri kapalı.
    case servicesDisabled
    /// Sistem konumu üretemedi (kapalı alan, GPS yok, zaman aşımı).
    case unavailable
}

/// Konum sağlayıcı sözleşmesi. Home akışı yalnızca bunu tanıyor; CoreLocation'ın kendisini
/// değil. Testler ve SwiftUI önizlemeleri gerçek GPS beklemeden çalışabiliyor.
public protocol LocationProviding: Sendable {
    var authorization: LocationAuthorization { get async }
    /// Sistem iznini ister ve sonucu döndürür. Zaten karar verilmişse mevcut durumu döner.
    @discardableResult
    func requestAuthorization() async -> LocationAuthorization
    /// Tek seferlik konum okuması. Home ekranı sürekli takip istemiyor — namaz vakitleri
    /// birkaç yüz metrelik harekete duyarsız, sürekli GPS ise pil yakar.
    func currentLocation() async throws -> LocationSnapshot
}

/// Testler ve SwiftUI önizlemeleri için sabit cevap veren sağlayıcı.
public actor StubLocationService: LocationProviding {
    private var authorizationValue: LocationAuthorization
    private let result: Result<LocationSnapshot, LocationError>
    /// İzin isteği geldiğinde `authorization` bu değere geçer — "kullanıcı kabul etti/etmedi"
    /// senaryolarını test edebilmek için.
    private let authorizationAfterRequest: LocationAuthorization?

    public init(
        authorization: LocationAuthorization = .whenInUse,
        authorizationAfterRequest: LocationAuthorization? = nil,
        result: Result<LocationSnapshot, LocationError> = .success(
            LocationSnapshot(latitude: 41.0082, longitude: 28.9784, placeName: "İstanbul")
        )
    ) {
        self.authorizationValue = authorization
        self.authorizationAfterRequest = authorizationAfterRequest
        self.result = result
    }

    public var authorization: LocationAuthorization {
        get async { authorizationValue }
    }

    @discardableResult
    public func requestAuthorization() async -> LocationAuthorization {
        if let authorizationAfterRequest {
            authorizationValue = authorizationAfterRequest
        }
        return authorizationValue
    }

    public func currentLocation() async throws -> LocationSnapshot {
        guard authorizationValue.canUseLocation else { throw LocationError.unauthorized }
        return try result.get()
    }
}
