import Foundation
import PrayerKit

/// Anahtar-değer saklama sözleşmesi.
///
/// `UserDefaults` doğrudan kullanılmıyor, çünkü testlerin gerçek kullanıcı ayarlarına
/// dokunmaması gerekiyor — bir test koştuğunda geliştiricinin seçtiği şehir silinmemeli.
public protocol PreferenceStoring: Sendable {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data?, forKey key: String)
}

/// Üretimdeki depo. **App Group** kullanıyor, standart `UserDefaults` değil.
///
/// Sebep Faz 4'te belli olacak: widget ayrı bir süreçte çalışıyor ve uygulamanın normal
/// `UserDefaults`'ını göremiyor. Paylaşılan kabı baştan kullanmak, sonradan taşıma
/// zahmetinden ve "widget yanlış şehri gösteriyor" sınıfı hatalardan kurtarıyor.
public struct UserDefaultsPreferenceStore: PreferenceStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    /// App Group erişilemezse (yanlış yapılandırma, entitlement eksik) standart depoya
    /// düşüyor. Çökmek yerine çalışmaya devam etmek doğru davranış — kullanıcı en fazla
    /// widget'ta eski şehri görür, uygulama açılmamazlık etmez.
    public init(suiteName: String? = AppGroup.identifier) {
        if let suiteName, let suite = UserDefaults(suiteName: suiteName) {
            self.defaults = suite
        } else {
            self.defaults = .standard
        }
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func setData(_ data: Data?, forKey key: String) {
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Test ve önizleme deposu.
public final class InMemoryPreferenceStore: PreferenceStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    public init() {}

    public func data(forKey key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }

    public func setData(_ data: Data?, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        storage[key] = data
    }
}

/// Kullanıcının kalıcı tercihleri.
///
/// Bozuk veya eski biçimdeki kayıtlar sessizce yok sayılıyor ve varsayılana dönülüyor.
/// Alternatif — çözümleme hatasında çökmek — bir uygulama güncellemesinden sonra
/// açılmayan bir uygulama demek olurdu.
public struct Preferences: Sendable {

    private enum Key {
        static let location = "namaz.selectedLocation"
        static let settings = "namaz.calculationSettings"
        static let notifications = "namaz.notificationSettings"
    }

    private let store: PreferenceStoring

    public init(store: PreferenceStoring = UserDefaultsPreferenceStore()) {
        self.store = store
    }

    // MARK: - Seçili şehir

    /// Kullanıcının elle seçtiği şehir. `nil` ise cihaz konumu kullanılıyor demektir.
    public func selectedLocation() -> SavedLocation? {
        decode(SavedLocation.self, forKey: Key.location)
    }

    public func setSelectedLocation(_ location: SavedLocation?) {
        encode(location, forKey: Key.location)
    }

    // MARK: - Hesaplama ayarları

    public func calculationSettings() -> CalculationSettings {
        decode(CalculationSettings.self, forKey: Key.settings) ?? .defaultForTurkey()
    }

    public func setCalculationSettings(_ settings: CalculationSettings) {
        encode(settings, forKey: Key.settings)
    }

    // MARK: - Bildirim ayarları

    public func notificationSettings() -> NotificationSettings {
        decode(NotificationSettings.self, forKey: Key.notifications) ?? .default
    }

    public func setNotificationSettings(_ settings: NotificationSettings) {
        encode(settings, forKey: Key.notifications)
    }

    // MARK: - Kodlama

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else {
            store.setData(nil, forKey: key)
            return
        }
        store.setData(try? JSONEncoder().encode(value), forKey: key)
    }
}
