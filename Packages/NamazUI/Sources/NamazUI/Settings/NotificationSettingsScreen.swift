import SwiftUI
import UIKit
import NamazCore
import PrayerKit

/// Bildirim ayarları — şimdilik Ayarlar sekmesinin tamamı. Faz 7'de hesaplama ayarları
/// ve dil seçenekleri de buraya gelecek.
struct NotificationSettingsScreen: View {

    let coordinator: NotificationCoordinator
    /// Bildirimler hangi konum ve hesaplama ayarıyla kurulacak — Home ile aynı gerçek.
    let location: SavedLocation?
    let calculationSettings: CalculationSettings

    @Environment(\.openURL) private var openURL

    /// Seçilebilir hatırlatma süreleri. Serbest sayı girişi yok: 7 dakika gibi bir değerin
    /// kimseye faydası olmadığı gibi, bildirim bütçesini de öngörülemez kılıyor.
    private let reminderChoices: [Int?] = [nil, 10, 15, 20, 30, 45]

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle().fill(Palette.ink).frame(height: 2)
                        .accessibilityHidden(true)

                    Text(L.t("notifications.title"))
                        .font(Font.system(.title, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 14)

                    switch coordinator.authorization {
                    case .notDetermined:
                        permissionPrompt
                    case .denied:
                        deniedNotice
                    case .authorized, .provisional:
                        controls
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .task { await coordinator.refreshAuthorization() }
    }

    // MARK: - İzin durumları

    private var permissionPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t("notifications.permission.title"))
                .font(Font.system(.headline, design: .serif))
                .foregroundStyle(Palette.ink)
            Text(L.t("notifications.permission.body"))
                .font(Typography.prayerName)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Button(L.t("notifications.permission.button")) {
                Task {
                    await coordinator.requestAuthorization()
                    await reschedule()
                }
            }
            .buttonStyle(FilledActionStyle())
            .padding(.top, 6)
        }
        .padding(.top, 24)
    }

    private var deniedNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t("notifications.denied.title"))
                .font(Font.system(.headline, design: .serif))
                .foregroundStyle(Palette.ink)
            // Reddedilmiş izinde "tekrar dene" yok — sistem bir daha sormaz. Home'daki
            // konum akışında verdiğimiz kararın aynısı.
            Text(L.t("notifications.denied.body"))
                .font(Typography.prayerName)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Button(L.t("notifications.denied.settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(OutlineActionStyle())
            .padding(.top, 6)
        }
        .padding(.top, 24)
    }

    // MARK: - Ayarlar

    private var controls: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(L.t("notifications.section.prayers"))

            ForEach(Prayer.allCases.filter(\.isPerformablePrayer)) { prayer in
                SettingRow(title: Formatting.prayerName(prayer)) {
                    Toggle("", isOn: binding(for: prayer))
                        .labelsHidden()
                        .tint(Palette.mark)
                }
            }

            sectionLabel(L.t("notifications.section.timing"))

            SettingRow(title: L.t("notifications.at_time")) {
                Toggle("", isOn: boolBinding(\.notifyAtPrayerTime))
                    .labelsHidden()
                    .tint(Palette.mark)
            }

            SettingRow(title: L.t("notifications.remind_before")) {
                Picker("", selection: reminderBinding) {
                    ForEach(reminderChoices, id: \.self) { choice in
                        Text(label(for: choice)).tag(choice)
                    }
                }
                .labelsHidden()
                .tint(Palette.mark)
            }

            SettingRow(title: L.t("notifications.sound")) {
                Toggle("", isOn: boolBinding(\.playsSound))
                    .labelsHidden()
                    .tint(Palette.mark)
            }

            coverage
        }
    }

    /// Kapsama bilgisi gizlenmiyor. Kayan pencerenin sonlu olduğunu kullanıcı öğrenmeli —
    /// bir hafta sonra bildirimlerin kesilmesini sessizce yaşamaktansa.
    private var coverage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                coordinator.plan.coveredDays > 0
                    ? L.t("notifications.coverage %@", String(coordinator.plan.coveredDays))
                    : L.t("notifications.coverage.none")
            )
            .font(Typography.prayerName)
            .foregroundStyle(Palette.ink)

            Text(L.t("notifications.coverage.note"))
                .font(Typography.dateline)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 28)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .microLabelStyle()
            .padding(.top, 28)
            .padding(.bottom, 6)
    }

    private func label(for minutes: Int?) -> String {
        guard let minutes else { return L.t("notifications.remind_before.off") }
        return L.t("notifications.remind_before.value %@", String(minutes))
    }

    // MARK: - Bağlamalar

    /// Her değişiklik anında kaydediliyor ve plan yeniden kuruluyor — "Kaydet" düğmesi yok.
    /// Ayarı değiştirip çıkan kullanıcının değişikliğini kaybetmemesi için.
    private func apply(_ transform: @escaping (inout NotificationSettings) -> Void) {
        var updated = coordinator.settings
        transform(&updated)
        Task {
            await coordinator.update(
                updated, location: location, calculationSettings: calculationSettings
            )
        }
    }

    private func binding(for prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { coordinator.settings.isEnabled(prayer) },
            set: { isOn in
                apply { settings in
                    if isOn {
                        guard !settings.enabledPrayers.contains(prayer) else { return }
                        settings.enabledPrayers.append(prayer)
                        settings.enabledPrayers.sort { $0.rawValue < $1.rawValue }
                    } else {
                        settings.enabledPrayers.removeAll { $0 == prayer }
                    }
                }
            }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<NotificationSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { coordinator.settings[keyPath: keyPath] },
            set: { newValue in apply { $0[keyPath: keyPath] = newValue } }
        )
    }

    private var reminderBinding: Binding<Int?> {
        Binding(
            get: { coordinator.settings.remindBeforeMinutes },
            set: { newValue in apply { $0.remindBeforeMinutes = newValue } }
        )
    }

    private func reschedule() async {
        await coordinator.reschedule(
            location: location, calculationSettings: calculationSettings
        )
    }
}

// MARK: - Satır ve düğme biçimleri

/// Ad solda, kontrol sağda, altında saç teli çizgi. `Form`/`List` kullanmıyoruz: ikisi de
/// kendi arka planını ve ayırıcılarını getirip "Dizgi" yönünü bozardı.
private struct SettingRow<Control: View>: View {
    let title: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(Typography.prayerName)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 12)
            control
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
    }
}

private struct FilledActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.prayerName)
            .foregroundStyle(Palette.ground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Palette.mark)
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private struct OutlineActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.prayerName)
            .foregroundStyle(Palette.mark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .overlay { Rectangle().stroke(Palette.rule, lineWidth: 1) }
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
