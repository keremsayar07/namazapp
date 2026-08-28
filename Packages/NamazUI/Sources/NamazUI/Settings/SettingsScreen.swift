import SwiftUI
import UIKit
import NamazCore
import PrayerKit

/// Ayarlar sekmesinin kökü.
///
/// Her şeyi tek sayfaya yığmak yerine üç alt ekrana ayrıldı: 12 yöntem, 6 bildirim anahtarı
/// ve 6 dakika düzeltmesi aynı sayfada uçsuz bucaksız bir kaydırma olurdu. Kök sayfa yalnızca
/// hangi ayarın şu an ne olduğunu özetliyor — içeri girmeden görülebilsin.
struct SettingsScreen: View {

    let dependencies: Dependencies

    @State private var isPickingCity = false
    @State private var isConfirmingErase = false
    @State private var didErase = false
    @Environment(\.openURL) private var openURL

    private var model: HomeViewModel { dependencies.homeModel }
    private var location: SavedLocation? { model.state.schedule?.location }

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

                        Text(L.t("settings.title"))
                            .font(Font.system(.title, design: .serif))
                            .foregroundStyle(Palette.ink)
                            .padding(.top, 14)

                        locationSection
                        preferencesSection
                        languageSection
                        privacySection
                        aboutSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
            // Kökte gezinme çubuğu boş dururdu; gizliyoruz. Alt ekranlar kendi çubuklarını
            // ve geri düğmesini getiriyor.
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isPickingCity) {
            CityPickerScreen(
                model: CityPickerViewModel(search: dependencies.citySearch),
                onSelect: { model.selectManualLocation($0) }
            )
        }
    }

    // MARK: - Konum

    private var locationSection: some View {
        Group {
            SectionLabel(L.t("settings.section.location"), topPadding: 24)

            SettingRow(
                title: location?.name ?? L.t("settings.location.none"),
                caption: locationCaption
            ) {
                Button(L.t("home.change_location")) { isPickingCity = true }
                    .microLabelStyle(color: Palette.mark)
            }

            // Cihaz konumuna dönüş yalnızca elle seçim varken anlamlı; yoksa düğme hiçbir
            // şey yapmayan bir düğme olurdu.
            if model.manualLocation != nil {
                SettingRow(title: L.t("settings.location.useDevice")) {
                    Button(L.t("settings.location.useDevice.action")) {
                        Task { await model.useDeviceLocation() }
                    }
                    .microLabelStyle(color: Palette.mark)
                }
            }
        }
    }

    private var locationCaption: String? {
        guard let location else { return nil }
        return location.source == .manual
            ? L.t("settings.location.source.manual")
            : L.t("settings.location.source.device")
    }

    // MARK: - Ayarlar

    private var preferencesSection: some View {
        Group {
            SectionLabel(L.t("settings.section.preferences"))

            DisclosureRow(
                title: L.t("calc.title"),
                value: L.t(model.settings.method.localizationKey)
            ) {
                CalculationSettingsScreen(model: model)
            }

            DisclosureRow(
                title: L.t("notifications.title"),
                value: notificationsSummary
            ) {
                NotificationSettingsScreen(
                    coordinator: dependencies.notifications,
                    location: location,
                    calculationSettings: model.settings
                )
            }
        }
    }

    /// "4 vakit" ya da "Kapalı". İçeri girmeden durumu görebilmek için.
    private var notificationsSummary: String {
        let coordinator = dependencies.notifications
        guard coordinator.authorization == .authorized || coordinator.authorization == .provisional else {
            return L.t("settings.notifications.off")
        }
        let count = coordinator.settings.enabledPrayers.count
        return count == 0
            ? L.t("settings.notifications.off")
            : L.t("settings.notifications.count %@", String(count))
    }

    // MARK: - Dil

    /// Uygulama içinde dil seçici yok: uygulama sistem dilini izliyor (Türkçe'ye düşerek).
    /// iOS'un kendi uygulama başına dil ayarı bunu zaten karşılıyor ve iki ayrı yerde iki
    /// ayrı dil tercihi tutmak kaçınılmaz olarak çelişirdi. Yapılacak tek doğru şey oraya
    /// giden yolu göstermek.
    private var languageSection: some View {
        Group {
            SectionLabel(L.t("settings.section.language"))

            SettingRow(
                title: L.t("settings.language"),
                caption: L.t("settings.language.note")
            ) {
                Button(L.t("settings.language.open")) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .microLabelStyle(color: Palette.mark)
            }
        }
    }

    // MARK: - Gizlilik

    /// "Tüm verilerimi sil".
    ///
    /// Uygulamanın hesabı yok, sunucusu yok; silinecek uzak bir kopya da yok. Ama cihazdaki
    /// veri kullanıcının dini pratiğini ve özel notlarını taşıyor. Telefonu devretmeden ya da
    /// sadece baştan başlamak istediğinde bunu tek yerden yapabilmeli. "Uygulamayı silin"
    /// demek de çözüm olurdu ama kullanıcı çoğu zaman uygulamayı tutup veriyi bırakmak
    /// istiyor.
    ///
    /// Onay kutusu var ve geri alınamadığı açıkça yazıyor: tek dokunuşla silinen bir yıllık
    /// namaz kaydının telafisi yok.
    private var privacySection: some View {
        Group {
            SectionLabel(L.t("settings.section.privacy"))

            SettingRow(
                title: L.t("settings.erase"),
                caption: L.t("settings.erase.caption")
            ) {
                Button(L.t("settings.erase.action"), role: .destructive) {
                    isConfirmingErase = true
                }
                .microLabelStyle(color: Palette.mark)
            }

            SectionNote(L.t("settings.privacy.note"))
        }
        .alert(L.t("settings.erase.confirm.title"), isPresented: $isConfirmingErase) {
            Button(L.t("settings.erase.confirm.cancel"), role: .cancel) {}
            Button(L.t("settings.erase.confirm.ok"), role: .destructive) {
                Task { await erase() }
            }
        } message: {
            Text(L.t("settings.erase.confirm.body"))
        }
        .alert(L.t("settings.erase.done"), isPresented: $didErase) {
            Button(L.t("settings.erase.confirm.cancel")) {}
        }
    }

    /// Sildikten sonra ekranı yeniden kuruyoruz: bellekte duran görünüm modelleri diski
    /// bilmiyor ve silinmiş bir notu göstermeye devam ederdi.
    private func erase() async {
        await dependencies.eraser.eraseAll()
        await dependencies.reloadAfterErase()
        didErase = true
    }

    // MARK: - Hakkında

    private var aboutSection: some View {
        Group {
            SectionLabel(L.t("settings.section.about"))

            DisclosureRow(title: L.t("about.title")) {
                AboutScreen()
            }
        }
    }
}

#Preview {
    SettingsScreen(dependencies: .preview())
}
