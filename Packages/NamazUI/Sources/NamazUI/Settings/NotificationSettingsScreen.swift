import SwiftUI
import UIKit
import NamazCore
import PrayerKit

/// Bildirim ayarları. Ayarlar sekmesinin altına itilen bir sayfa.
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
        SettingsPage(title: L.t("notifications.title")) {
            switch coordinator.authorization {
            case .notDetermined:
                permissionPrompt
            case .denied:
                deniedNotice
            case .authorized, .provisional:
                controls
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
        .padding(.top, 18)
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
        .padding(.top, 18)
    }

    // MARK: - Ayarlar

    private var controls: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(L.t("notifications.section.prayers"), topPadding: 18)

            ForEach(Prayer.allCases.filter(\.isPerformablePrayer)) { prayer in
                SettingRow(title: Formatting.prayerName(prayer)) {
                    Toggle("", isOn: binding(for: prayer))
                        .labelsHidden()
                        .tint(Palette.mark)
                }
            }

            SectionLabel(L.t("notifications.section.timing"))

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
