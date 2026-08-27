import Foundation
import Observation
import PrayerKit

// MARK: - Zikirmatik

/// Zikirmatiğin beyni.
///
/// Sayaç her dokunuşta diske yazılmıyor — hızlı dokunuşta bu saniyede onlarca dosya yazma
/// demek olurdu. Bellek içinde artıyor, kaydetme ekran kapanırken ve belirli aralıklarla
/// yapılıyor. Kayıp riski en fazla birkaç dokunuş; buna karşılık pil ve disk ömrü korunuyor.
@MainActor
@Observable
public final class TasbihViewModel {

    public private(set) var state = TasbihState()
    /// Hedefe bu dokunuşla ulaşıldı mı — ekran titreşim vermek için buna bakıyor.
    public private(set) var didReachTarget = false

    private let store: FileStoring
    private let clock: @Sendable () -> Date
    private let timeZone: TimeZone

    static let fileName = "tasbih"

    public init(
        store: FileStoring,
        timeZone: TimeZone = .current,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.timeZone = timeZone
        self.clock = clock
    }

    public func load() async {
        var loaded = await store.load(TasbihState.self, from: Self.fileName) ?? TasbihState()
        if loaded.presets.isEmpty {
            loaded.presets = Self.defaultPresets
            loaded.activePresetID = loaded.presets.first?.id
        }
        state = loaded
    }

    public func save() async {
        await store.save(state, to: Self.fileName)
    }

    /// Sayacı bir artırır ve günlük toplamı işler.
    public func increment() {
        state.count += 1
        let key = DayKey.string(for: clock(), in: timeZone)
        state.dailyTotals[key, default: 0] += 1

        if let target = state.activePreset?.target {
            didReachTarget = state.count == target
        } else {
            didReachTarget = false
        }
    }

    /// Yalnızca sayacı sıfırlar. Günlük toplam silinmiyor — o gün gerçekten çekilmiş
    /// zikri, sayaç sıfırlandı diye yok saymak yanlış olurdu.
    public func reset() {
        state.count = 0
        didReachTarget = false
    }

    public func select(_ preset: TasbihPreset) {
        state.activePresetID = preset.id
        state.count = 0
        didReachTarget = false
    }

    public func addPreset(name: String, target: Int?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let preset = TasbihPreset(name: trimmed, target: target)
        state.presets.append(preset)
        select(preset)
    }

    public func deletePreset(_ preset: TasbihPreset) {
        // Son zikir silinemesin: boş bir zikirmatik ekranı hiçbir şey yapamaz.
        guard state.presets.count > 1 else { return }
        state.presets.removeAll { $0.id == preset.id }
        if state.activePresetID == preset.id {
            state.activePresetID = state.presets.first?.id
            state.count = 0
        }
    }

    public var todayTotal: Int {
        state.dailyTotals[DayKey.string(for: clock(), in: timeZone)] ?? 0
    }

    /// Hedefe ne kadar kaldığı, 0...1. Hedef yoksa `nil` — ilerleme çubuğu çizilmez.
    public var progress: Double? {
        guard let target = state.activePreset?.target, target > 0 else { return nil }
        return min(1, Double(state.count) / Double(target))
    }

    /// Varsayılan zikirler. Yalnızca ad ve sayı; kullanıcı hepsini silip kendininkini
    /// ekleyebilir. Uygulama bir zikir listesi dayatmıyor, boş bir ekranla da başlatmıyor.
    static let defaultPresets: [TasbihPreset] = [
        TasbihPreset(name: "Sübhanallah", target: 33),
        TasbihPreset(name: "Elhamdülillah", target: 33),
        TasbihPreset(name: "Allahu ekber", target: 33)
    ]
}

// MARK: - Namaz takibi

@MainActor
@Observable
public final class PrayerLogViewModel {

    public private(set) var log = PrayerLog()
    /// Ekranda görüntülenen gün. Kullanıcı dün unuttuğunu bugün işaretleyebilsin.
    public private(set) var displayedDate: Date

    private let store: FileStoring
    private let clock: @Sendable () -> Date
    /// Görünür: ekran başlığı da bu saat dilimine göre yazılmalı. İki ayrı saat dilimi
    /// kullanılırsa başlıkta bir tarih, kayıtta başka bir gün olur.
    public private(set) var timeZone: TimeZone

    static let fileName = "prayer-log"

    public init(
        store: FileStoring,
        timeZone: TimeZone = .current,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.timeZone = timeZone
        self.clock = clock
        self.displayedDate = clock()
    }

    public func load() async {
        log = await store.load(PrayerLog.self, from: Self.fileName) ?? PrayerLog()
    }

    public func update(timeZone: TimeZone) {
        self.timeZone = timeZone
    }

    public var displayedDayKey: String {
        DayKey.string(for: displayedDate, in: timeZone)
    }

    public var isShowingToday: Bool {
        displayedDayKey == DayKey.string(for: clock(), in: timeZone)
    }

    public func isMarked(_ prayer: Prayer) -> Bool {
        log.isMarked(prayer, on: displayedDayKey)
    }

    public func toggle(_ prayer: Prayer) async {
        log.toggle(prayer, on: displayedDayKey)
        await store.save(log, to: Self.fileName)
    }

    public func showPreviousDay() { shiftDay(by: -1) }

    /// Bugünün ötesine geçilemez. Gelecekteki bir namazı "kılındı" işaretlemek anlamsız.
    public func showNextDay() {
        guard !isShowingToday else { return }
        shiftDay(by: 1)
    }

    public func showToday() {
        displayedDate = clock()
    }

    private func shiftDay(by delta: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let shifted = calendar.date(byAdding: .day, value: delta, to: displayedDate) else {
            return
        }
        displayedDate = shifted
    }

    /// Son yedi günün özeti — en eskiden bugüne. Her gün için kaç vakit işaretlendiği.
    ///
    /// Yüzde, seri veya hedef yok; yalnızca ham sayı. Kullanıcı kendi kaydına baksın,
    /// uygulama onu notlandırmasın.
    public func recentDays(count: Int = 7) -> [(dayKey: String, marked: Int)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = clock()
        return (0..<count).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let key = DayKey.string(for: date, in: timeZone)
            return (key, log.markedCount(on: key))
        }
    }
}

// MARK: - Kaza

@MainActor
@Observable
public final class QadhaViewModel {

    public private(set) var counts = QadhaCounts()

    private let store: FileStoring
    static let fileName = "qadha"

    public init(store: FileStoring) {
        self.store = store
    }

    public func load() async {
        counts = await store.load(QadhaCounts.self, from: Self.fileName) ?? QadhaCounts()
    }

    public func count(for prayer: Prayer) -> Int {
        counts.count(for: prayer)
    }

    public func adjust(_ prayer: Prayer, by delta: Int) async {
        counts.adjust(prayer, by: delta)
        await store.save(counts, to: Self.fileName)
    }

    public func addFullDay() async {
        counts.addFullDay()
        await store.save(counts, to: Self.fileName)
    }

    public var total: Int { counts.total }
}
