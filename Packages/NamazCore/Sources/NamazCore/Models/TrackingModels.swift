import Foundation
import PrayerKit

// MARK: - Zikir

/// Bir zikir tanımı. Ad ve hedef kullanıcıya ait; uygulama içerik dayatmıyor.
public struct TasbihPreset: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    /// Hedef sayı. `nil` ise sayaç serbest — bazı zikirler sayı ile sınırlı değil.
    public var target: Int?

    public init(id: UUID = UUID(), name: String, target: Int?) {
        self.id = id
        self.name = name
        self.target = target
    }
}

/// Zikirmatiğin tüm kalıcı durumu.
public struct TasbihState: Codable, Sendable, Hashable {
    public var presets: [TasbihPreset]
    public var activePresetID: UUID?
    /// O anki sayaç. Hedefe ulaşınca sıfırlanmıyor — kullanıcı isterse devam etsin.
    public var count: Int
    /// Gün anahtarı → o gün toplam kaç kez artırıldı.
    ///
    /// Zikrin türüne göre ayrılmıyor: amaç istatistik değil, "bugün ne kadar" sorusuna
    /// basit bir cevap. Daha fazlası ibadeti tabloya dönüştürmeye başlardı.
    public var dailyTotals: [String: Int]

    public init(
        presets: [TasbihPreset] = [],
        activePresetID: UUID? = nil,
        count: Int = 0,
        dailyTotals: [String: Int] = [:]
    ) {
        self.presets = presets
        self.activePresetID = activePresetID
        self.count = count
        self.dailyTotals = dailyTotals
    }

    public var activePreset: TasbihPreset? {
        guard let activePresetID else { return presets.first }
        return presets.first { $0.id == activePresetID } ?? presets.first
    }

    /// Geçmiş 90 günden eskisini atar. Sınırsız büyüyen bir sözlük, kimsenin bakmayacağı
    /// veriyi sonsuza kadar taşımak demek.
    public mutating func pruneTotals(keepingDaysBefore cutoff: String) {
        dailyTotals = dailyTotals.filter { $0.key >= cutoff }
    }
}

// MARK: - Namaz takibi

/// Hangi gün hangi vakitlerin kılındığı.
///
/// **Kasten oyunlaştırılmadı.** Seri (streak), rozet, yüzde hedefi yok. Kullanıcının kendi
/// kaydını tutması bir hatırlatma aracıdır; ibadeti puanlanan bir performansa çevirmek
/// bu uygulamanın işi değil.
public struct PrayerLog: Codable, Sendable, Hashable {
    /// Gün anahtarı → o gün kılındı işaretlenen vakitler.
    public var days: [String: [Prayer]]

    public init(days: [String: [Prayer]] = [:]) {
        self.days = days
    }

    public func isMarked(_ prayer: Prayer, on dayKey: String) -> Bool {
        days[dayKey]?.contains(prayer) ?? false
    }

    public mutating func toggle(_ prayer: Prayer, on dayKey: String) {
        var marked = days[dayKey] ?? []
        if let index = marked.firstIndex(of: prayer) {
            marked.remove(at: index)
        } else {
            marked.append(prayer)
            marked.sort { $0.rawValue < $1.rawValue }
        }
        // Boş gün saklanmıyor: kayıt yalnızca gerçekten işaretlenmiş günleri taşısın.
        if marked.isEmpty {
            days[dayKey] = nil
        } else {
            days[dayKey] = marked
        }
    }

    public func markedCount(on dayKey: String) -> Int {
        days[dayKey]?.count ?? 0
    }
}

// MARK: - Kaza

/// Tek bir vaktin kaza sayısı. `PrayerOffset` ile aynı desende: sözlük yerine dizi,
/// çünkü anahtarı `String`/`Int` olmayan sözlükler derli toplu JSON üretmiyor.
public struct QadhaEntry: Codable, Sendable, Hashable {
    public var prayer: Prayer
    public var count: Int

    public init(prayer: Prayer, count: Int) {
        self.prayer = prayer
        self.count = count
    }
}

/// Kaza namazı sayaçları.
public struct QadhaCounts: Codable, Sendable, Hashable {
    public var entries: [QadhaEntry]

    public init(entries: [QadhaEntry] = []) {
        self.entries = entries
    }

    public func count(for prayer: Prayer) -> Int {
        entries.first { $0.prayer == prayer }?.count ?? 0
    }

    /// Negatife düşmez. "Kıldım" düğmesine fazladan basmak sayacı eksiye çeviremez —
    /// eksi bir kaza sayısının anlamı yok.
    public mutating func adjust(_ prayer: Prayer, by delta: Int) {
        let updated = max(0, count(for: prayer) + delta)
        entries.removeAll { $0.prayer == prayer }
        if updated > 0 {
            entries.append(QadhaEntry(prayer: prayer, count: updated))
            entries.sort { $0.prayer.rawValue < $1.prayer.rawValue }
        }
    }

    /// Bir günlük kaza eklemek: beş vaktin hepsi birer artar. Güneş kılınacak bir vakit
    /// olmadığı için dışarıda.
    public mutating func addFullDay() {
        for prayer in Prayer.allCases where prayer.isPerformablePrayer {
            adjust(prayer, by: 1)
        }
    }

    public var total: Int {
        entries.reduce(0) { $0 + $1.count }
    }
}
