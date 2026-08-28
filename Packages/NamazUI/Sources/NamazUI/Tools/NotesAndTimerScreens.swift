import SwiftUI
import NamazCore

// MARK: - Notlar

/// Not listesi. Kilit açık değilse içerik hiç çizilmiyor.
struct NotesScreen: View {

    let model: NotesViewModel

    @State private var editing: Note?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        SettingsPage(title: L.t("notes.title")) {
            if model.isUnlocked {
                unlocked
            } else {
                locked
            }
        }
        .task {
            await model.load()
            await model.unlockIfNeeded(reason: L.t("notes.lock.reason"))
        }
        // Kilidin tek anlamı bu: telefon elden çıktığında notlar yeniden kapansın.
        .onChange(of: scenePhase) {
            guard scenePhase != .active else { return }
            model.relock()
        }
        .sheet(item: $editing) { note in
            NoteEditorScreen(model: model, note: note)
        }
    }

    // MARK: Kilitli

    private var locked: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t("notes.locked.title"))
                .font(Font.system(.title3, design: .serif))
                .foregroundStyle(Palette.ink)

            Text(L.t(model.didFailToUnlock ? "notes.locked.failed" : "notes.locked.body"))
                .font(Typography.prayerName)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Button(L.t("notes.locked.unlock")) {
                Task { await model.unlockIfNeeded(reason: L.t("notes.lock.reason")) }
            }
            .buttonStyle(FilledActionStyle())
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    // MARK: Açık

    @ViewBuilder
    private var unlocked: some View {
        Button(L.t("notes.new")) {
            editing = model.createNote()
        }
        .buttonStyle(FilledActionStyle())
        .padding(.top, 18)

        if !model.book.notes.isEmpty {
            TextField(L.t("notes.search"), text: Binding(
                get: { model.query },
                set: { model.query = $0 }
            ))
            .font(Typography.prayerName)
            .foregroundStyle(Palette.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.vertical, 10)
            .padding(.top, 12)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
        }

        list
        lockSetting
    }

    @ViewBuilder
    private var list: some View {
        let notes = model.visibleNotes
        if notes.isEmpty {
            Text(L.t(model.book.notes.isEmpty ? "notes.empty" : "notes.noresults"))
                .font(Typography.prayerName)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 26)
        } else {
            SectionLabel(L.t("notes.section.list"))
            ForEach(notes) { note in
                Button { editing = note } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(note.displayTitle ?? L.t("notes.untitled"))
                            .font(Typography.prayerName)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)

                        Text(Formatting.noteStamp(note.updatedAt))
                            .font(Typography.dateline)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.rule).frame(height: 1)
                }
                .contextMenu {
                    Button(L.t("notes.delete"), role: .destructive) {
                        Task { await model.delete(note) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var lockSetting: some View {
        SectionLabel(L.t("notes.section.security"))
        if model.isLockAvailable {
            SettingRow(title: L.t("notes.lock.toggle"), caption: L.t("notes.lock.caption")) {
                Toggle("", isOn: Binding(
                    get: { model.isLockEnabled },
                    set: { model.setLockEnabled($0) }
                ))
                .labelsHidden()
                .tint(Palette.mark)
            }
        } else {
            // Parolası olmayan bir cihazda kilidi sunmak, çalışmayan bir düğme göstermek olurdu.
            SectionNote(L.t("notes.lock.unavailable"))
        }
        SectionNote(L.t("notes.storage.note"))
    }
}

/// Not düzenleyici. Kaydet düğmesi yok — yazılan her şey kapanışta saklanıyor.
private struct NoteEditorScreen: View {

    let model: NotesViewModel
    let note: Note

    @State private var title = ""
    /// `body` DEĞİL: `View` protokolünün `body`'siyle çakışır ve derlenmez.
    /// Aynı tuzağa Faz 3'te `LocationNoticeView` içinde de düşülmüştü.
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.ground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    TextField(L.t("notes.editor.title"), text: $title)
                        .font(Font.system(.title2, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Palette.rule).frame(height: 1)
                        }

                    TextEditor(text: $text)
                        .font(Typography.prayerName)
                        .foregroundStyle(Palette.ink)
                        .scrollContentBackground(.hidden)
                        .background(Palette.ground)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.ground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("notes.editor.done")) { close() }
                        .foregroundStyle(Palette.mark)
                }
            }
        }
        .onAppear {
            title = note.title
            text = note.body
        }
    }

    private func close() {
        Task {
            await model.update(note, title: title, body: text)
            // Hiç yazılmadan kapatılan not listede boş bir satır bırakmasın.
            await model.discardIfEmpty(note)
            dismiss()
        }
    }
}

// MARK: - Zamanlayıcı

/// Kur'an okuma, zikir ya da herhangi bir şey için geri sayım.
///
/// Ekranda dönen bir sayaç yok; `Text(date, style: .timer)` kendi kendini tazeliyor ve
/// kalan süre her zaman bitiş anından hesaplanıyor. Uygulama kapansa bile bozulacak bir
/// durum olmadığı için "arka planda çalışma" diye bir sorun da yok.
struct TimerScreen: View {

    let model: TimerViewModel

    @State private var label = ""
    @State private var customMinutes = 20

    var body: some View {
        SettingsPage(title: L.t("timer.title")) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                display(now: context.date)
            }
            controls
            SectionNote(L.t("timer.note"))
        }
        .task {
            await model.load()
            label = model.timer.label
        }
    }

    @ViewBuilder
    private func display(now: Date) -> some View {
        let running = model.isRunning(at: now)
        let finished = model.isFinished(at: now)

        VStack(alignment: .leading, spacing: 10) {
            if !model.timer.label.isEmpty {
                Text(model.timer.label)
                    .microLabelStyle(color: running ? Palette.mark : Palette.inkSoft)
            }

            Group {
                if running, let endsAt = model.timer.endsAt {
                    // Kendi kendini tazeleyen sayaç: bizim tikimiz yok.
                    Text(endsAt, style: .timer)
                } else if finished {
                    Text(L.t("timer.finished"))
                } else {
                    Text(Formatting.timerDuration(model.timer.duration))
                }
            }
            .font(Font.system(size: 64, weight: .regular, design: .serif))
            .monospacedDigit()
            .foregroundStyle(finished ? Palette.mark : Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            if let progress = model.progress(at: now), running {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Palette.rule).frame(height: 2)
                        Rectangle()
                            .fill(Palette.mark)
                            .frame(width: geometry.size.width * progress, height: 2)
                    }
                }
                .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 22)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var controls: some View {
        let now = Date()
        if model.isRunning(at: now) {
            Button(L.t("timer.stop")) { Task { await model.stop() } }
                .buttonStyle(OutlineActionStyle())
                .padding(.top, 14)
        } else {
            SectionLabel(L.t("timer.section.presets"))
            ForEach(CountdownTimer.presets, id: \.self) { preset in
                ChoiceRow(
                    title: Formatting.timerPreset(preset),
                    isSelected: model.timer.duration == preset,
                    action: { Task { await model.setDuration(preset) } }
                )
            }

            SettingRow(title: L.t("timer.custom")) {
                Stepper(value: $customMinutes, in: 1...240, step: 1) {
                    Text(L.t("timer.minutes %@", String(customMinutes)))
                        .font(Typography.prayerTime)
                        .foregroundStyle(Palette.mark)
                }
                .onChange(of: customMinutes) {
                    Task { await model.setDuration(TimeInterval(customMinutes * 60)) }
                }
            }

            SectionLabel(L.t("timer.section.label"))
            TextField(L.t("timer.label.placeholder"), text: $label)
                .font(Typography.prayerName)
                .foregroundStyle(Palette.ink)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.rule).frame(height: 1)
                }

            Button(L.t("timer.start")) {
                Task {
                    await model.start(
                        duration: model.timer.duration,
                        label: label,
                        body: L.t("timer.notification.body")
                    )
                }
            }
            .buttonStyle(FilledActionStyle())
            .padding(.top, 22)
        }
    }
}
