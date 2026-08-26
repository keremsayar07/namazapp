import CoreLocation
import Foundation

/// `LocationProviding`'in CoreLocation ile gerçek uygulaması.
///
/// CoreLocation delegate tabanlı ve tek seferlik okuma için doğrudan bir async API'si yok.
/// Bu sınıf delegate geri çağrılarını `CheckedContinuation`'a köprülüyor. Dikkat edilen üç
/// nokta:
///
/// 1. **Continuation asla iki kez sonuçlanmamalı** — yoksa çalışma zamanı çöker. Her
///    continuation kullanıldığı anda `nil`'e çekiliyor.
/// 2. **Continuation asla sızmamalı** — konum hiç gelmezse ekran sonsuza kadar yükleniyor
///    gösterir. Bu yüzden bir zaman aşımı var.
/// 3. Delegate geri çağrıları CoreLocation'ın kuyruğundan gelir; durum bir actor içinde
///    tutuluyor.
public final class CoreLocationService: NSObject, LocationProviding, @unchecked Sendable {

    /// Konum okuması bu süre içinde gelmezse `unavailable` sayılır. Kapalı alanda ilk fix
    /// uzun sürebiliyor; kullanıcıyı belirsiz bir yükleniyor ekranında bırakmaktansa elle
    /// şehir seçimine yönlendirmek daha iyi.
    private let timeout: Duration

    private let manager = CLLocationManager()
    private let state = ContinuationBox()
    private let geocoder = CLGeocoder()
    /// Ters coğrafi kodlama başarısız olursa konum yine de kullanılabilir olmalı; yer adı
    /// sadece gösterim içindir.
    private let resolvePlaceName: Bool

    public init(timeout: Duration = .seconds(12), resolvePlaceName: Bool = true) {
        self.timeout = timeout
        self.resolvePlaceName = resolvePlaceName
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - LocationProviding

    public var authorization: LocationAuthorization {
        get async { Self.map(manager.authorizationStatus) }
    }

    @discardableResult
    public func requestAuthorization() async -> LocationAuthorization {
        let current = Self.map(manager.authorizationStatus)
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            Task {
                await state.setAuthorization(continuation)
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    public func currentLocation() async throws -> LocationSnapshot {
        let status = Self.map(manager.authorizationStatus)
        guard status != .denied else { throw LocationError.unauthorized }
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.servicesDisabled
        }
        guard status.canUseLocation else { throw LocationError.unauthorized }

        let location = try await withThrowingTaskGroup(of: CLLocation.self) { group in
            group.addTask { try await self.requestSingleLocation() }
            group.addTask {
                try await Task.sleep(for: self.timeout)
                throw LocationError.unavailable
            }
            // İlk biten kazanır; diğeri iptal edilir.
            guard let first = try await group.next() else { throw LocationError.unavailable }
            group.cancelAll()
            return first
        }

        var placeName: String?
        if resolvePlaceName {
            placeName = try? await reverseGeocode(location)
        }
        return LocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            placeName: placeName
        )
    }

    // MARK: - Yardımcılar

    private func requestSingleLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                await state.setLocation(continuation)
                manager.requestLocation()
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) async throws -> String? {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else { return nil }
        // İlçe (locality) varsa onu, yoksa ili (administrativeArea) göster.
        return placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea
    }

    private static func map(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted, .denied: return .denied
        case .authorizedAlways: return .always
        #if os(iOS)
        case .authorizedWhenInUse: return .whenInUse
        #else
        case .authorized: return .whenInUse
        #endif
        @unknown default: return .denied
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension CoreLocationService: CLLocationManagerDelegate {

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let value = Self.map(manager.authorizationStatus)
        Task { await state.finishAuthorization(with: value) }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            Task { await state.finishLocation(with: .failure(LocationError.unavailable)) }
            return
        }
        Task { await state.finishLocation(with: .success(location)) }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let mapped: LocationError
        if let clError = error as? CLError, clError.code == .denied {
            mapped = .unauthorized
        } else {
            mapped = .unavailable
        }
        Task { await state.finishLocation(with: .failure(mapped)) }
    }
}

// MARK: - Continuation kutusu

/// Bekleyen continuation'ları tek bir yerde, actor korumasında tutar. Amacı tek: bir
/// continuation'ın iki kez sonuçlanmasını (çökme) veya hiç sonuçlanmamasını (donma) önlemek.
private actor ContinuationBox {
    private var authorization: CheckedContinuation<LocationAuthorization, Never>?
    private var location: CheckedContinuation<CLLocation, Error>?

    func setAuthorization(_ continuation: CheckedContinuation<LocationAuthorization, Never>) {
        // Önceki bir istek hâlâ bekliyorsa onu mevcut durumla kapat, sonra yenisini al.
        authorization?.resume(returning: .notDetermined)
        authorization = continuation
    }

    func finishAuthorization(with value: LocationAuthorization) {
        guard value != .notDetermined else { return } // sistem henüz karar bildirmedi
        authorization?.resume(returning: value)
        authorization = nil
    }

    func setLocation(_ continuation: CheckedContinuation<CLLocation, Error>) {
        location?.resume(throwing: LocationError.unavailable)
        location = continuation
    }

    func finishLocation(with result: Result<CLLocation, Error>) {
        guard let pending = location else { return }
        location = nil
        pending.resume(with: result)
    }
}
