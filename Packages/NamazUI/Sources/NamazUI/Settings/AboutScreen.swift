import SwiftUI
import PrayerKit

/// Hakkında — asıl işi künye değil, **açıklık**.
///
/// Bir namaz vakti uygulamasının en kritik özelliği doğruluğu ve kullanıcının bunu
/// denetleyebilecek bir yolu yok: ekranda yazan saatin nereden geldiğini göremiyor. O yüzden
/// burada yöntem, ölçüm ve bilinen eksikler açıkça yazıyor. Özellikle bilinen eksikler —
/// hicri takvim düzeltme tablosu henüz boş ve bunu saklamak, kullanıcının Ramazan'ın
/// başlangıcını yanlış öğrenmesi anlamına gelirdi.
struct AboutScreen: View {

    var body: some View {
        SettingsPage(title: L.t("about.title")) {
            paragraph(L.t("about.intro"))

            SectionLabel(L.t("about.section.calculation"))
            paragraph(L.t("about.calculation.body"))

            SectionLabel(L.t("about.section.hijri"))
            paragraph(L.t("about.hijri.body"))

            SectionLabel(L.t("about.section.privacy"))
            paragraph(L.t("about.privacy.body"))

            SectionLabel(L.t("about.section.version"))
            SettingRow(title: L.t("about.version")) {
                Text(Self.version)
                    .font(Typography.prayerTime)
                    .foregroundStyle(Palette.inkSoft)
            }
            SettingRow(title: L.t("about.kaaba")) {
                Text(Self.kaabaCoordinates)
                    .font(Typography.prayerTime)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(Typography.prayerName)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
    }

    /// Sürüm bilgisi uygulama paketinden okunuyor. `NamazUI` bir kütüphane; `Bundle.module`
    /// kaynak paketi, sürüm ise uygulamanın kendisinde — bu yüzden `Bundle.main`.
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        switch (short, build) {
        case let (.some(short), .some(build)):
            return "\(short) (\(build))"
        case let (.some(short), .none):
            return short
        default:
            // Önizlemede ve testte uygulama paketi yok; uydurma bir sürüm yazmaktansa
            // boş olduğunu söylüyoruz.
            return L.t("about.version.unknown")
        }
    }

    /// Kıble hesabının dayandığı nokta. Kullanıcı isterse kendi kaynağıyla karşılaştırabilsin.
    private static var kaabaCoordinates: String {
        let coordinate = QiblaMath.kaaba
        let latitude = coordinate.latitude.formatted(.number.precision(.fractionLength(4)))
        let longitude = coordinate.longitude.formatted(.number.precision(.fractionLength(4)))
        return "\(latitude), \(longitude)"
    }
}

#Preview {
    NavigationStack {
        AboutScreen()
    }
}
