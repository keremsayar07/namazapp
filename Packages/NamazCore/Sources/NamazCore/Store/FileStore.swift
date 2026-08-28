import Foundation
import PrayerKit

/// Kullanıcının kendi ürettiği verinin kalıcı deposu: zikir sayaçları, namaz kaydı, kaza
/// sayıları, notlar.
///
/// **Neden `UserDefaults` değil.** `Preferences` küçük ayarlar için doğru araç ama
/// `UserDefaults` bir tercih deposu; içine büyüyen kullanıcı verisi koymak hem yanlış
/// kullanım hem de dosya koruma sınıfını seçme imkânı vermiyor. Buradaki veri kullanıcının
/// dini pratiğini ve kişisel notlarını açığa vuruyor — nerede ve nasıl durduğunu açıkça
/// seçmemiz gerekiyor.
///
/// **Neden SwiftData değil.** Veri hacmi küçük: bir yıllık namaz kaydı ~2 KB. Dosya tabanlı
/// depo hem birim testinde hem güvenlik denetiminde tek bakışta anlaşılıyor, göç
/// (migration) riski taşımıyor ve App Group ile sorunsuz çalışıyor. Veritabanı bu ölçekte
/// kazandırdığından fazlasını karmaşıklık olarak geri alırdı.
public protocol FileStoring: Sendable {
    func load<T: Decodable & Sendable>(_ type: T.Type, from name: String) async -> T?
    func save<T: Encodable & Sendable>(_ value: T, to name: String) async
    func delete(_ name: String) async
}

/// Kullanıcı verisi tutan bütün dosyalar, tek listede.
///
/// **Neden merkezî.** "Tüm verilerimi sil" bir dosyayı atlarsa kullanıcıya söylenen şey
/// yanlış olur — sildiğini sandığı notlar diskte kalır. Adlar görünüm modellerinin içine
/// dağılmış olsaydı, yeni bir araç eklendiğinde silme listesine eklemeyi unutmak an
/// meselesiydi. Burada tek bir enum var ve bir testi, `allCases` ile silinen dosya
/// sayısının eşleştiğini doğruluyor.
public enum UserDataFile: String, CaseIterable, Sendable {
    case tasbih
    case prayerLog = "prayer-log"
    case qadha
    case notes
    case timer
}

/// Gerçek depo: App Group konteynerinde, dosya başına bir JSON.
public actor JSONFileStore: FileStoring {

    /// Dosyaların yazıldığı klasör. `nil` ise depo sessizce çalışmaz duruma geçer —
    /// çökmez. App Group yetkilendirmesi kurulmadan önce (ör. önizlemede) bu olabiliyor.
    private let directory: URL?

    private let protection: StoreProtection

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]   // deterministik çıktı, diff'lenebilir
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(
        containerURL: URL? = AppGroup.containerURL,
        subdirectory: String = "UserData",
        protection: StoreProtection = .whileUnlocked
    ) {
        self.protection = protection
        guard let containerURL else {
            self.directory = nil
            return
        }
        let directory = containerURL.appendingPathComponent(subdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: protection.directoryAttributes
        )
        self.directory = directory
    }

    public func load<T: Decodable & Sendable>(_ type: T.Type, from name: String) async -> T? {
        guard let url = url(for: name) else {
            Diagnostics.log(.storeUnavailable)
            return nil
        }
        // Dosyanın hiç olmaması olağan (ilk açılış); onu hata olarak kaydetmiyoruz.
        guard let data = try? Data(contentsOf: url) else { return nil }
        // Bozuk veri çökmeye değil, "veri yok"a dönüşür. Uygulamanın hiçbir koşulda
        // çökmeme kuralı; kullanıcının kaydı bozulduysa uygulamayı açamamak, kaydı
        // kaybetmekten kötü. Ama sessiz de kalmıyor: bu satır olmadan "notlarım kayboldu"
        // şikâyetinin nedenini cihazdan öğrenmenin hiçbir yolu yok.
        guard let decoded = try? decoder.decode(type, from: data) else {
            Diagnostics.log(.storeLoadFailed(store: name))
            return nil
        }
        return decoded
    }

    public func save<T: Encodable & Sendable>(_ value: T, to name: String) async {
        guard let url = url(for: name), let data = try? encoder.encode(value) else {
            Diagnostics.log(.storeWriteFailed(store: name))
            return
        }
        // `.atomic`: yazma yarıda kesilirse (uygulama öldürülürse) eski dosya bozulmadan
        // kalır. Yarım yazılmış bir JSON, hiç yazılmamış olmaktan kötüdür.
        try? data.write(to: url, options: [.atomic])
        // Koruma sınıfı yazmadan SONRA uygulanıyor: `.atomic` yazma dosyayı yeniden
        // oluşturduğu için klasörden miras alınan sınıfa güvenilemez.
        protection.apply(to: url)
    }

    public func delete(_ name: String) async {
        guard let url = url(for: name) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Dosya adları koddan geliyor, kullanıcıdan değil — yine de yol ayracı içeren bir ad
    /// konteynerin dışına çıkabilirdi. Reddediyoruz.
    private func url(for name: String) -> URL? {
        guard let directory, !name.contains("/"), !name.contains("..") else { return nil }
        return directory.appendingPathComponent("\(name).json", isDirectory: false)
    }
}

/// Dosya koruma sınıfı — kendi tipimiz, `FileProtectionType` değil.
///
/// Sebep pratik: `FileProtectionType` yalnızca iOS'ta var, `NamazCore` ise CI'da macOS'a da
/// derleniyor. Sebep tasarımsal: iki seçeneğin ne anlama geldiğini isimlerinden okumak,
/// Apple'ın sabitlerini ezberlemekten iyi.
public enum StoreProtection: Sendable {
    /// Cihaz kilitliyken dosya okunamaz. Kullanıcı verisi için doğru varsayılan —
    /// kaybolan bir telefonda notlar ve namaz kaydı açılamaz.
    case whileUnlocked
    /// Cihaz açılıştan sonra bir kez kilidi açıldıysa okunabilir.
    ///
    /// **Yalnızca widget'ın okuması gereken dosyalar için.** Widget kilit ekranında
    /// çalışıyor; `.whileUnlocked` bir dosyayı oradan okumaya kalkarsa hiçbir şey bulamaz.
    /// Bugün böyle bir dosya yok — olduğunda bu seçenek hazır.
    case afterFirstUnlock

    var directoryAttributes: [FileAttributeKey: Any] {
        #if os(iOS)
        return [.protectionKey: fileProtectionType]
        #else
        return [:]
        #endif
    }

    func apply(to url: URL) {
        #if os(iOS)
        try? FileManager.default.setAttributes(
            [.protectionKey: fileProtectionType], ofItemAtPath: url.path
        )
        #endif
    }

    #if os(iOS)
    private var fileProtectionType: FileProtectionType {
        switch self {
        case .whileUnlocked: return .complete
        case .afterFirstUnlock: return .completeUntilFirstUserAuthentication
        }
    }
    #endif
}

/// Test ve önizleme için bellek içi depo. Diske hiç dokunmaz.
public actor InMemoryFileStore: FileStoring {
    private var storage: [String: Data] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}

    public func load<T: Decodable & Sendable>(_ type: T.Type, from name: String) async -> T? {
        guard let data = storage[name] else { return nil }
        return try? decoder.decode(type, from: data)
    }

    public func save<T: Encodable & Sendable>(_ value: T, to name: String) async {
        storage[name] = try? encoder.encode(value)
    }

    public func delete(_ name: String) async {
        storage[name] = nil
    }
}

// MARK: - Gün anahtarı

/// Kullanıcı verisi güne göre saklanıyor ve "gün" **konumun** saat diliminde tanımlı —
/// cihazınkinde değil. Kullanıcı yurt dışındayken memleketinin vaktine bakıyorsa, o günün
/// namaz kaydı da orada geçerli olan güne yazılmalı.
///
/// Bildirim planlayıcısı da aynı biçimi kullanıyor (`yyyy-MM-dd`); ikisi tek yerden
/// gelsin diye burada.
public enum DayKey {

    /// `en_US_POSIX`: kullanıcının takvimi hicri veya Budist olsa bile anahtar hep aynı
    /// biçimde üretilsin. Bu bir depolama anahtarı, gösterim metni değil.
    public static func string(for date: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Anahtardan tarihe geri dönüş — istatistik ekranı gün gün geriye yürürken lazım.
    public static func date(from key: String, in timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }
}
