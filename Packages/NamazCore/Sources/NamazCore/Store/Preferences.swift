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
        static let lastKnownLocation = "namaz.lastKnownLocation"
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

    /// Cihaz konumundan en son çözülen yer.
    ///
    /// **Widget için var.** Widget ayrı bir süreçte çalışıyor ve CoreLocation'ı güvenilir
    /// biçimde kullanamıyor: konum izni uygulamaya ait, GPS uyandırmak pil bütçesinin
    /// dışında ve zaman çizelgesi üretilirken beklenecek bir şey yok. Kullanıcı elle şehir
    /// seçmemişse widget'ın elinde başka hiçbir konum bilgisi olmazdı.
    ///
    /// Bu yüzden uygulama her konum çözdüğünde sonucu buraya yazıyor. Widget "seçili şehir
    /// yoksa en son bilinen konumu kullan" diyerek çalışmaya devam ediyor.
    public func lastKnownLocation() -> SavedLocation? {
        decode(SavedLocation.self, forKey: Key.lastKnownLocation)
    }

    public func setLastKnownLocation(_ location: SavedLocation?) {
        encode(location, forKey: Key.lastKnownLocation)
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

    // MARK: - Notlar kilidi

    private static let notesLockedKey = "namaz.notesLocked"

    /// Depo yalnızca `Data` tutuyor; tek bir Bool için ayrı bir tip açmak yerine küçük bir
    /// sarmalayıcı. Üst düzey `Bool`'u doğrudan JSON'a yazmak bazı Foundation sürümlerinde
    /// "fragment" sayılıp reddedilebiliyor — sarmalayıcı o belirsizliği tamamen kaldırıyor.
    private struct Flag: Codable { var value: Bool }

    /// Notlar sekmesi Face ID / parola ile kilitli mi.
    ///
    /// Varsayılan KAPALI. Açık gelseydi, kilidin ne olduğunu bilmeyen kullanıcı kendi
    /// notlarına ulaşamadığını sanırdı; koruduğundan fazlasını engellemek olurdu.
    public func areNotesLocked() -> Bool {
        decode(Flag.self, forKey: Self.notesLockedKey)?.value ?? false
    }

    public func setNotesLocked(_ locked: Bool) {
        encode(Flag(value: locked), forKey: Self.notesLockedKey)
    }

    // MARK: - Silme

    /// Uygulamanın yazdığı bütün tercih anahtarları.
    ///
    /// Elle sayılıyor, `UserDefaults`'un tamamı silinmiyor. Paylaşılan kap bize ait olsa da
    /// "içindeki her şeyi sil" demek, ileride oraya başka bir şey yazan bir bileşeni sessizce
    /// bozmanın en kısa yolu. Ne yazdıysak onu siliyoruz.
    private static var allKeys: [String] {
        [Key.location, Key.settings, Key.notifications, Key.lastKnownLocation, notesLockedKey]
    }

    /// Kullanıcının "tüm verilerimi sil" isteğinde tercihler kısmı.
    ///
    /// Konum ve ayarlar da gidiyor: kullanıcı verisinin içinde en çok bilgi taşıyan şey
    /// **en son bulunduğu yer**. Onu bırakıp notları silmek, silmiş gibi yapmak olurdu.
    public func removeAll() {
        for key in Self.allKeys {
            store.setData(nil, forKey: key)
        }
    }

}
