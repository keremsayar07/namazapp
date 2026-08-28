import Foundation
import XCTest
@testable import NamazCore

@MainActor
final class NotesAndTimerTests: XCTestCase {

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso) ?? Date()
    }

    private func makeNotes(
        lock: BiometricLocking = StubBiometricLock(),
        store: FileStoring = InMemoryFileStore(),
        preferences: Preferences = Preferences(store: InMemoryPreferenceStore()),
        now: String = "2026-08-28T10:00:00+03:00"
    ) -> NotesViewModel {
        let fixed = date(now)
        return NotesViewModel(store: store, preferences: preferences, lock: lock, clock: { fixed })
    }

    // MARK: - Notlar

    func test_newNoteIsEmptyAndDiscardedIfUntouched() async {
        // "Yeni not"a basıp vazgeçen kullanıcı listede boş bir satır bırakmamalı.
        let model = makeNotes()
        await model.load()
        let note = model.createNote()
        XCTAssertEqual(model.book.notes.count, 1)

        await model.discardIfEmpty(note)
        XCTAssertTrue(model.book.notes.isEmpty)
    }

    func test_noteWithContentIsKept() async {
        let model = makeNotes()
        await model.load()
        let note = model.createNote()
        await model.update(note, title: "Hatırlatma", body: "")

        await model.discardIfEmpty(note)
        XCTAssertEqual(model.book.notes.count, 1)
    }

    func test_openingAndClosingWithoutChangesDoesNotReorderTheList() async {
        // `updatedAt` sadece içerik değiştiğinde ilerlemeli; yoksa nota bakmak onu
        // listenin başına taşır ve sıralama anlamsızlaşır.
        let model = makeNotes()
        await model.load()
        let note = model.createNote()
        await model.update(note, title: "A", body: "B")
        let stamp = model.book.notes[0].updatedAt

        await model.update(model.book.notes[0], title: "A", body: "B")
        XCTAssertEqual(model.book.notes[0].updatedAt, stamp)
    }

    func test_displayTitleFallsBackToTheFirstLine() {
        let now = date("2026-08-28T10:00:00+03:00")
        let titled = Note(title: "Başlık", body: "gövde", createdAt: now, updatedAt: now)
        XCTAssertEqual(titled.displayTitle, "Başlık")

        let untitled = Note(title: "  ", body: "İlk satır\nikinci", createdAt: now, updatedAt: now)
        XCTAssertEqual(untitled.displayTitle, "İlk satır")

        let blank = Note(createdAt: now, updatedAt: now)
        XCTAssertNil(blank.displayTitle, "Boş notun gösterilecek adı olmamalı")
    }

    func test_searchIsTurkishCaseInsensitive() {
        // "İSTANBUL" yazan bir notu "istanbul" araması bulmalı. Düz `lowercased()`
        // Türkçe'de bunu kaçırıyor; `SearchFolding` bunun için var.
        let now = date("2026-08-28T10:00:00+03:00")
        let book = NoteBook(notes: [
            Note(title: "İSTANBUL ziyareti", body: "", createdAt: now, updatedAt: now),
            Note(title: "Alışveriş", body: "ŞEKER al", createdAt: now, updatedAt: now)
        ])
        XCTAssertEqual(book.search("istanbul").count, 1)
        XCTAssertEqual(book.search("seker").count, 1, "Gövdede de aramalı")
        XCTAssertEqual(book.search("  ").count, 2, "Boş arama hepsini döndürmeli")
        XCTAssertTrue(book.search("bulunmayan").isEmpty)
    }

    func test_notesSurviveAReload() async {
        let store = InMemoryFileStore()
        let first = makeNotes(store: store)
        await first.load()
        let note = first.createNote()
        await first.update(note, title: "Kalıcı", body: "metin")

        let second = makeNotes(store: store)
        await second.load()
        XCTAssertEqual(second.book.notes.first?.title, "Kalıcı")
    }

    // MARK: - Kilit

    func test_withoutLockNotesAreVisibleImmediately() async {
        let model = makeNotes()
        await model.load()
        XCTAssertTrue(model.isUnlocked, "Kilit kapalıyken hiçbir şey sorulmamalı")
    }

    func test_lockedNotesStayHiddenUntilAuthenticated() async {
        let preferences = Preferences(store: InMemoryPreferenceStore())
        let model = makeNotes(lock: StubBiometricLock(succeeds: true), preferences: preferences)
        await model.load()
        model.setLockEnabled(true)

        XCTAssertFalse(model.isUnlocked, "Kilit açılınca ekran kapanmalı")
        await model.unlockIfNeeded(reason: "test")
        XCTAssertTrue(model.isUnlocked)
    }

    func test_failedAuthenticationKeepsNotesHidden() async {
        // Doğrulama başarısızsa "aç" tarafına düşmek kilidi anlamsız kılardı.
        let preferences = Preferences(store: InMemoryPreferenceStore())
        let model = makeNotes(lock: StubBiometricLock(succeeds: false), preferences: preferences)
        await model.load()
        model.setLockEnabled(true)

        await model.unlockIfNeeded(reason: "test")
        XCTAssertFalse(model.isUnlocked)
        XCTAssertTrue(model.didFailToUnlock, "Ekran tekrar deneme sunabilmeli")
    }

    func test_lockIsIgnoredWhenTheDeviceCannotAuthenticate() async {
        // Parolası olmayan bir cihazda kilidi zorlamak, kullanıcıyı kendi verisinden
        // kalıcı olarak dışlamak olurdu.
        let preferences = Preferences(store: InMemoryPreferenceStore())
        let model = makeNotes(lock: StubBiometricLock(isAvailable: false), preferences: preferences)
        await model.load()
        model.setLockEnabled(true)

        await model.unlockIfNeeded(reason: "test")
        XCTAssertTrue(model.isUnlocked)
    }

    func test_backgroundingRelocks() async {
        let preferences = Preferences(store: InMemoryPreferenceStore())
        let model = makeNotes(preferences: preferences)
        await model.load()
        model.setLockEnabled(true)
        await model.unlockIfNeeded(reason: "test")
        XCTAssertTrue(model.isUnlocked)

        model.relock()
        XCTAssertFalse(model.isUnlocked, "Arka plana geçince yeniden kilitlenmeli")
    }

    func test_lockPreferenceSurvivesAReload() async {
        let preferences = Preferences(store: InMemoryPreferenceStore())
        let first = makeNotes(preferences: preferences)
        await first.load()
        first.setLockEnabled(true)

        let second = makeNotes(preferences: preferences)
        await second.load()
        XCTAssertTrue(second.isLockEnabled)
        XCTAssertFalse(second.isUnlocked, "Kilitli açılmalı")
    }

    // MARK: - Zamanlayıcı

    private func makeTimer(
        store: FileStoring = InMemoryFileStore(),
        scheduler: StubNotificationScheduler = StubNotificationScheduler(),
        now: String = "2026-08-28T10:00:00+03:00"
    ) -> (TimerViewModel, StubNotificationScheduler, Date) {
        let fixed = date(now)
        return (TimerViewModel(store: store, scheduler: scheduler, clock: { fixed }), scheduler, fixed)
    }

    func test_timerIsNotRunningUntilStarted() async {
        let (model, _, now) = makeTimer()
        await model.load()
        XCTAssertFalse(model.isRunning(at: now))
        XCTAssertFalse(model.isFinished(at: now))
    }

    func test_startingSetsAnEndDateNotACounter() async {
        // Tasarımın özü: saklanan şey bitiş anı. Uygulama kapansa da bozulacak bir sayaç yok.
        let (model, _, now) = makeTimer()
        await model.load()
        await model.start(duration: 600, label: "Kur'an", body: "bitti")

        XCTAssertEqual(model.timer.endsAt, now.addingTimeInterval(600))
        XCTAssertTrue(model.isRunning(at: now))
        XCTAssertEqual(model.remaining(at: now), 600, accuracy: 0.001)
        XCTAssertEqual(model.remaining(at: now.addingTimeInterval(200)), 400, accuracy: 0.001)
    }

    func test_remainingNeverGoesNegative() async {
        let (model, _, now) = makeTimer()
        await model.load()
        await model.start(duration: 60, label: "", body: "bitti")
        XCTAssertEqual(model.remaining(at: now.addingTimeInterval(5000)), 0)
    }

    func test_finishedIsDistinctFromStopped() async {
        // Süresi dolmuş bir zamanlayıcı ile hiç başlatılmamış olan aynı şey değil.
        let (model, _, now) = makeTimer()
        await model.load()
        await model.start(duration: 60, label: "", body: "bitti")

        let after = now.addingTimeInterval(120)
        XCTAssertFalse(model.isRunning(at: after))
        XCTAssertTrue(model.isFinished(at: after))

        await model.stop()
        XCTAssertFalse(model.isFinished(at: after), "Durdurulmuş zamanlayıcı bitmiş sayılmamalı")
    }

    func test_progressIsNilWithoutADuration() async {
        let (model, _, now) = makeTimer()
        await model.load()
        await model.setDuration(0)
        XCTAssertNil(model.progress(at: now), "Sıfır süre için çubuk çizilmemeli")
    }

    func test_startingSchedulesANotificationAndStoppingCancelsIt() async {
        let (model, scheduler, now) = makeTimer()
        await model.load()
        await model.start(duration: 300, label: "Zikir", body: "Süre doldu")

        var pending = await scheduler.standalone
        XCTAssertEqual(pending[TimerViewModel.notificationID], now.addingTimeInterval(300))

        await model.stop()
        pending = await scheduler.standalone
        XCTAssertNil(pending[TimerViewModel.notificationID])
    }

    /// **En önemli test.** Zamanlayıcının bildirim kimliği `namaz.` ile başlarsa, vakit
    /// bildirimleri her yeniden kurulduğunda (uygulama her öne geldiğinde) sessizce
    /// silinirdi. Çökme yok, hata yok — sadece hiç çalmayan bir zamanlayıcı.
    func test_timerNotificationIsOutsideThePrayerNamespace() {
        XCTAssertFalse(
            TimerViewModel.notificationID.hasPrefix("namaz."),
            "Zamanlayıcı kimliği vakit bildirimlerinin ad alanında olmamalı"
        )
    }

    func test_durationCannotChangeWhileRunning() async {
        // Çalışan bir zamanlayıcının süresini değiştirmek, bitiş anıyla süreyi
        // tutarsız hale getirir ve ilerleme çubuğu saçmalar.
        let (model, _, now) = makeTimer()
        await model.load()
        await model.start(duration: 600, label: "", body: "bitti")
        await model.setDuration(60)
        XCTAssertEqual(model.timer.duration, 600)
        XCTAssertTrue(model.isRunning(at: now))
    }

    func test_timerSurvivesAReload() async {
        let store = InMemoryFileStore()
        let (first, _, now) = makeTimer(store: store)
        await first.load()
        await first.start(duration: 900, label: "Okuma", body: "bitti")

        let (second, _, _) = makeTimer(store: store)
        await second.load()
        XCTAssertEqual(second.timer.endsAt, now.addingTimeInterval(900))
        XCTAssertEqual(second.timer.label, "Okuma")
    }
}
