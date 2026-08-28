import Foundation
import Observation

// MARK: - Notlar

@MainActor
@Observable
public final class NotesViewModel {

    public private(set) var book = NoteBook()
    public var query = ""
    /// Kilit açıldı mı. Uygulama arka plana geçtiğinde tekrar kilitleniyor.
    public private(set) var isUnlocked = false
    /// Kullanıcı kilidi açmayı denedi ve olmadı. Ekranın "tekrar dene" diyebilmesi için.
    public private(set) var didFailToUnlock = false

    private let store: FileStoring
    private let preferences: Preferences
    private let lock: BiometricLocking
    private let clock: @Sendable () -> Date

    static let fileName = "notes"

    public init(
        store: FileStoring,
        preferences: Preferences = Preferences(),
        lock: BiometricLocking = DeviceBiometricLock(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.preferences = preferences
        self.lock = lock
        self.clock = clock
    }

    // MARK: Kilit

    public var isLockAvailable: Bool { lock.isAvailable }

    /// SAKLANAN bir özellik, hesaplanan değil.
    ///
    /// Hesaplanan olsaydı (`preferences.areNotesLocked()` okuyan bir getter) `@Observable`
    /// onu izleyemezdi: gözlem yalnızca saklanan özellikleri takip ediyor. Anahtar
    /// değiştiğinde arayüz yenilenmez, en fazla başka bir özellik değiştiği için tesadüfen
    /// yenilenirdi. Tesadüfe dayanan arayüz, er ya da geç yanlış görünen arayüzdür.
    public private(set) var isLockEnabled = false

    public func setLockEnabled(_ enabled: Bool) {
        isLockEnabled = enabled
        preferences.setNotesLocked(enabled)
        // Kilit açılınca hemen kilitle, kapatılınca hemen aç. Ayarı değiştirip ekranın
        // eski durumda kalması kafa karıştırıcı olurdu.
        isUnlocked = !enabled
    }

    /// Ekran görünürken çağrılıyor. Kilit kapalıysa hiçbir şey sormuyor.
    public func unlockIfNeeded(reason: String) async {
        guard isLockEnabled, lock.isAvailable else {
            isUnlocked = true
            return
        }
        guard !isUnlocked else { return }
        didFailToUnlock = false
        let granted = await lock.authenticate(reason: reason)
        isUnlocked = granted
        didFailToUnlock = !granted
    }

    /// Uygulama arka plana geçtiğinde. Kilidin anlamı bu: telefon elden çıktığında notlar
    /// yeniden kapansın.
    public func relock() {
        guard isLockEnabled, lock.isAvailable else { return }
        isUnlocked = false
        didFailToUnlock = false
    }

    // MARK: Veri

    public func load() async {
        book = await store.load(NoteBook.self, from: Self.fileName) ?? NoteBook()
        isLockEnabled = preferences.areNotesLocked()
        if !isLockEnabled || !lock.isAvailable { isUnlocked = true }
    }

    public var visibleNotes: [Note] { book.search(query) }

    @discardableResult
    public func createNote() -> Note {
        let now = clock()
        let note = Note(createdAt: now, updatedAt: now)
        book.notes.append(note)
        return note
    }

    public func update(_ note: Note, title: String, body: String) async {
        guard let index = book.notes.firstIndex(where: { $0.id == note.id }) else { return }
        // İçerik gerçekten değişmediyse `updatedAt`'i güncelleme: notu açıp kapatmak
        // listedeki sırasını değiştirmemeli.
        guard book.notes[index].title != title || book.notes[index].body != body else { return }
        book.notes[index].title = title
        book.notes[index].body = body
        book.notes[index].updatedAt = clock()
        await save()
    }

    public func delete(_ note: Note) async {
        book.notes.removeAll { $0.id == note.id }
        await save()
    }

    /// Hiç yazılmadan kapatılan notu sessizce atar. Kullanıcı "yeni not"a basıp vazgeçince
    /// listede boş bir satır kalmasın.
    public func discardIfEmpty(_ note: Note) async {
        guard let current = book.notes.first(where: { $0.id == note.id }), current.isEmpty else {
            return
        }
        await delete(note)
    }

    public func save() async {
        await store.save(book, to: Self.fileName)
    }
}

// MARK: - Zamanlayıcı

@MainActor
@Observable
public final class TimerViewModel {

    public private(set) var timer = CountdownTimer()

    private let store: FileStoring
    private let scheduler: NotificationScheduling
    private let clock: @Sendable () -> Date

    static let fileName = "timer"

    /// Bildirim kimliği bilerek `namaz.` ile BAŞLAMIYOR.
    ///
    /// `UserNotificationScheduler.cancelAll()` o ön eke sahip her bekleyen bildirimi
    /// siliyor ve vakit bildirimleri uygulama her öne geldiğinde yeniden kuruluyor.
    /// Zamanlayıcı da aynı ön eki kullansaydı, kullanıcı zamanlayıcıyı başlatıp uygulamayı
    /// kapattığında bildirimi sessizce silinirdi — çöküş yok, hata yok, sadece hiç
    /// çalmayan bir zamanlayıcı. Ayrı ad alanı bunu imkânsız kılıyor.
    public static let notificationID = "nmz-timer.finished"

    public init(
        store: FileStoring,
        scheduler: NotificationScheduling,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.scheduler = scheduler
        self.clock = clock
    }

    public func load() async {
        timer = await store.load(CountdownTimer.self, from: Self.fileName) ?? CountdownTimer()
    }

    public func start(duration: TimeInterval, label: String, body: String) async {
        guard duration > 0 else { return }
        timer.duration = duration
        timer.label = label
        timer.endsAt = clock().addingTimeInterval(duration)
        await persist()
        await scheduleNotification(title: label, body: body)
    }

    public func restart(label: String, body: String) async {
        await start(duration: timer.duration, label: label, body: body)
    }

    public func stop() async {
        timer.endsAt = nil
        await persist()
        await scheduler.cancel(identifier: Self.notificationID)
    }

    public func setDuration(_ duration: TimeInterval) async {
        guard !timer.isRunning(at: clock()) else { return }
        timer.duration = max(0, duration)
        await persist()
    }

    public func remaining(at now: Date) -> TimeInterval { timer.remaining(at: now) }
    public func isRunning(at now: Date) -> Bool { timer.isRunning(at: now) }
    public func isFinished(at now: Date) -> Bool { timer.isFinished(at: now) }
    public func progress(at now: Date) -> Double? { timer.progress(at: now) }

    private func persist() async {
        await store.save(timer, to: Self.fileName)
    }

    private func scheduleNotification(title: String, body: String) async {
        guard let endsAt = timer.endsAt else { return }
        await scheduler.schedule(
            identifier: Self.notificationID,
            at: endsAt,
            title: title.isEmpty ? body : title,
            body: body
        )
    }
}
