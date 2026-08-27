import SwiftUI
// UINotificationFeedbackGenerator için.
import UIKit
import NamazCore
import PrayerKit

/// Beşinci sekme: Araçlar.
///
/// Zikirmatik, namaz takibi ve kaza sayacı ayrı sekmeler olmadı — sekme çubuğunda yedi
/// sekme, hiçbirini bulunamaz hale getirirdi. Vakit / Takvim / Kıble günlük bakılan
/// ekranlar; buradakiler ise aranıp girilen araçlar. Ayrım bilinçli.
struct ToolsScreen: View {

    let dependencies: Dependencies

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.ground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(Palette.ink)
                            .frame(height: 2)
                            .accessibilityHidden(true)

                        Text(L.t("tab.tools"))
                            .font(Font.system(.title, design: .serif))
                            .foregroundStyle(Palette.ink)
                            .padding(.top, 14)

                        SectionLabel(L.t("tools.section.practice"), topPadding: 24)

                        DisclosureRow(title: L.t("tasbih.title")) {
                            TasbihScreen(model: dependencies.tasbih)
                        }

                        DisclosureRow(title: L.t("log.title")) {
                            PrayerLogScreen(model: dependencies.prayerLog)
                        }

                        DisclosureRow(title: L.t("qadha.title")) {
                            QadhaScreen(model: dependencies.qadha)
                        }

                        SectionNote(L.t("tools.note"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Zikirmatik

/// Büyük sayaç, tek dokunuş, sakin ekran.
///
/// Sayaç alanı ekranın yarısı: kullanıcı bakmadan da isabet ettirebilsin. Titreşim yalnızca
/// hedefe ulaşınca — her dokunuşta titreten bir sayaç, zikri makineleştirir.
struct TasbihScreen: View {

    let model: TasbihViewModel

    @State private var isAddingPreset = false
    @State private var newName = ""
    @State private var newTarget = 33
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        SettingsPage(title: L.t("tasbih.title")) {
            header
            counter
            controls
            presetList
        }
        .task { await model.load() }
        // Sayaç her dokunuşta diske yazılmıyor; ekrandan çıkarken ve uygulama arka plana
        // geçerken kaydediliyor. Aradaki kayıp riski birkaç dokunuş, kazanç ise saniyede
        // onlarca dosya yazmamak.
        .onDisappear { Task { await model.save() } }
        .onChange(of: scenePhase) {
            guard scenePhase != .active else { return }
            Task { await model.save() }
        }
        .sheet(isPresented: $isAddingPreset) { addPresetSheet }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.state.activePreset?.name ?? "—")
                .font(Font.system(.title, design: .serif))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(L.t("tasbih.today %@", String(model.todayTotal)))
                .microLabelStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
    }

    private var counter: some View {
        Button {
            model.increment()
            if model.didReachTarget {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } label: {
            VStack(spacing: 10) {
                Text(String(model.state.count))
                    .font(Font.system(size: 96, weight: .regular, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(model.didReachTarget ? Palette.mark : Palette.ink)
                    .contentTransition(.numericText())

                if let target = model.state.activePreset?.target {
                    Text(L.t("tasbih.of %@", String(target)))
                        .font(Typography.prayerTime)
                        .foregroundStyle(Palette.inkSoft)
                }

                if let progress = model.progress {
                    // İlerleme çubuğu değil, dolan bir kural çizgisi — ekranın diline sadık.
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Palette.rule).frame(height: 2)
                            Rectangle()
                                .fill(Palette.mark)
                                .frame(width: geometry.size.width * progress, height: 2)
                        }
                    }
                    .frame(height: 2)
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 20)
        .accessibilityLabel(L.t("tasbih.accessibility.tap"))
        .accessibilityValue(String(model.state.count))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(L.t("tasbih.reset")) { model.reset() }
                .buttonStyle(OutlineActionStyle())
            Button(L.t("tasbih.add")) { isAddingPreset = true }
                .buttonStyle(OutlineActionStyle())
        }
        .padding(.top, 8)
    }

    private var presetList: some View {
        Group {
            SectionLabel(L.t("tasbih.section.presets"))
            ForEach(model.state.presets) { preset in
                ChoiceRow(
                    title: preset.name,
                    caption: preset.target.map { L.t("tasbih.of %@", String($0)) },
                    isSelected: preset.id == model.state.activePreset?.id,
                    action: { model.select(preset) }
                )
                // Silme yalnızca kaydırarak değil, uzun basıp menüden de erişilebilir olsun
                // diye bağlam menüsü; kaydırma jesti burada listede değil.
                .contextMenu {
                    Button(L.t("tasbih.delete"), role: .destructive) {
                        model.deletePreset(preset)
                    }
                }
            }
            SectionNote(L.t("tasbih.note"))
        }
    }

    private var addPresetSheet: some View {
        NavigationStack {
            SettingsPage(title: L.t("tasbih.add")) {
                SectionLabel(L.t("tasbih.new.name"), topPadding: 18)
                TextField(L.t("tasbih.new.placeholder"), text: $newName)
                    .font(Typography.prayerName)
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Palette.rule).frame(height: 1)
                    }

                SectionLabel(L.t("tasbih.new.target"))
                SettingRow(title: L.t("tasbih.new.target")) {
                    Stepper(value: $newTarget, in: 1...1000, step: 1) {
                        Text(String(newTarget))
                            .font(Typography.prayerTime)
                            .foregroundStyle(Palette.mark)
                    }
                }

                Button(L.t("tasbih.new.save")) {
                    model.addPreset(name: newName, target: newTarget)
                    newName = ""
                    isAddingPreset = false
                }
                .buttonStyle(FilledActionStyle())
                .padding(.top, 24)
            }
        }
    }
}
