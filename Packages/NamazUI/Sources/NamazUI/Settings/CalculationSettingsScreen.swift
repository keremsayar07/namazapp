import SwiftUI
import NamazCore
import PrayerKit

/// Hesaplama ayarları: yöntem, mezhep, yüksek enlem kuralı ve elle dakika düzeltmesi.
///
/// Her seçeneğin yanında ne yaptığı yazıyor. Bir kullanıcı "Karachi" ile "Kuveyt" arasında
/// bilgisiz seçim yapmak zorunda kalmasın diye açılar açıkça gösteriliyor — bunlar zaten
/// yayımlanmış değerler, gizlenecek bir yanları yok.
///
/// "Kaydet" düğmesi yok: her değişiklik anında uygulanıyor ve kalıcı tercihlere yazılıyor.
/// Ayarı değiştirip geri çıkan kullanıcının değişikliği kaybolmasın.
struct CalculationSettingsScreen: View {

    let model: HomeViewModel

    private var settings: CalculationSettings { model.settings }

    var body: some View {
        SettingsPage(title: L.t("calc.title")) {
            methodSection
            madhabSection
            highLatitudeSection
            offsetsSection
            resetSection
        }
    }

    // MARK: - Yöntem

    private var methodSection: some View {
        Group {
            SectionLabel(L.t("calc.section.method"), topPadding: 18)

            ForEach(CalculationMethod.allPresets, id: \.self) { method in
                ChoiceRow(
                    title: L.t(method.localizationKey),
                    caption: caption(for: method),
                    isSelected: settings.method == method,
                    action: { apply { $0.method = method } }
                )
            }

            SectionNote(L.t("calc.method.note"))
        }
    }

    /// Yöntemin kendi açıları. Ölçüm değil, yöntemin tanımı — bu yüzden gösterilmesinde
    /// sakınca yok, aksine seçimi bilgili hâle getiriyor.
    private func caption(for method: CalculationMethod) -> String {
        let parameters = method.parameters
        let fajr = Formatting.angle(parameters.fajrAngle)

        let ishaText: String
        if let angle = parameters.ishaAngle {
            ishaText = L.t("calc.method.angles %@ %@", fajr, Formatting.angle(angle))
        } else if let minutes = parameters.ishaIntervalMinutes {
            ishaText = L.t("calc.method.interval %@ %@", fajr, String(Int(minutes)))
        } else {
            ishaText = fajr
        }

        // Türkiye yöntemi tek istisna: açıların yanında ölçülmüş temkin payları da var ve
        // bunun kullanıcıya söylenmesi gerekiyor.
        guard method == .turkey else { return ishaText }
        return ishaText + " · " + L.t("calc.method.turkey.calibrated")
    }

    // MARK: - Mezhep

    private var madhabSection: some View {
        Group {
            SectionLabel(L.t("calc.section.madhab"))

            ForEach(Madhab.allCases, id: \.self) { madhab in
                ChoiceRow(
                    title: L.t(madhab.localizationKey),
                    caption: L.t(madhab == .shafi ? "calc.madhab.shafi.detail" : "calc.madhab.hanafi.detail"),
                    isSelected: settings.madhab == madhab,
                    action: { apply { $0.madhab = madhab } }
                )
            }

            // Ölçülmüş bir gerçeği söylüyoruz, bir tercihi savunmuyoruz: Diyanet asr-ı evvel
            // yayımlıyor, Hanefi seçimi vakti yaklaşık 52 dakika sonraya alıyor. Kullanıcı
            // bunu bilerek seçsin — takvimiyle uyuşmayan bir uygulamayı bozuk sanmasın.
            if settings.method == .turkey && settings.madhab == .hanafi {
                SectionNote(L.t("calc.madhab.diyanet.warning"))
            } else {
                SectionNote(L.t("calc.madhab.note"))
            }
        }
    }

    // MARK: - Yüksek enlem

    private var highLatitudeSection: some View {
        Group {
            SectionLabel(L.t("calc.section.highLatitude"))

            ForEach(HighLatitudeRule.allCases, id: \.self) { rule in
                ChoiceRow(
                    title: L.t(rule.localizationKey),
                    caption: L.t(detailKey(for: rule)),
                    isSelected: settings.highLatitudeRule == rule,
                    action: { apply { $0.highLatitudeRule = rule } }
                )
            }

            SectionNote(L.t("calc.highLatitude.note"))
        }
    }

    private func detailKey(for rule: HighLatitudeRule) -> String {
        switch rule {
        case .middleOfTheNight: return "calc.highLatitude.middleOfNight.detail"
        case .seventhOfTheNight: return "calc.highLatitude.seventhOfNight.detail"
        case .twilightAngle: return "calc.highLatitude.twilightAngle.detail"
        }
    }

    // MARK: - Elle düzeltme

    private var offsetsSection: some View {
        Group {
            SectionLabel(L.t("calc.section.offsets"))

            ForEach(Prayer.allCases) { prayer in
                SettingRow(title: Formatting.prayerName(prayer)) {
                    Stepper(
                        value: offsetBinding(for: prayer),
                        in: Self.offsetRange,
                        step: 1
                    ) {
                        Text(offsetLabel(for: prayer))
                            .font(Typography.prayerTime)
                            .foregroundStyle(
                                settings.manualOffsetMinutes(for: prayer) == 0 ? Palette.inkSoft : Palette.mark
                            )
                    }
                    // Etiket görünür kalsın diye `labelsHidden` yok; VoiceOver'da vakit
                    // adıyla birlikte okunsun diye satır bir bütün olarak etiketleniyor.
                    .accessibilityLabel(
                        L.t("calc.offset.accessibility %@ %@", Formatting.prayerName(prayer), offsetLabel(for: prayer))
                    )
                }
            }

            SectionNote(L.t("calc.offsets.note"))
        }
    }

    /// ±30 dakika. Daha geniş bir aralık, hesaplamayı düzeltmek yerine tanınmaz hâle
    /// getirmeye başlar; bu bir ince ayar alanı, alternatif bir takvim değil.
    private static let offsetRange = -30...30

    private func offsetLabel(for prayer: Prayer) -> String {
        let minutes = settings.manualOffsetMinutes(for: prayer)
        if minutes == 0 { return L.t("calc.offset.none") }
        // İşaret açıkça yazılıyor: "5 dk" ile "+5 dk" arasındaki fark burada anlamlı.
        let signed = minutes > 0 ? "+\(minutes)" : String(minutes)
        return L.t("calc.offset.value %@", signed)
    }

    private func offsetBinding(for prayer: Prayer) -> Binding<Int> {
        Binding(
            get: { settings.manualOffsetMinutes(for: prayer) },
            set: { newValue in
                apply { updated in
                    updated.manualOffsets.removeAll { $0.prayer == prayer }
                    // Sıfır düzeltme saklanmıyor: liste yalnızca kullanıcının gerçekten
                    // değiştirdiklerini taşısın.
                    guard newValue != 0 else { return }
                    updated.manualOffsets.append(PrayerOffset(prayer: prayer, minutes: newValue))
                    updated.manualOffsets.sort { $0.prayer.rawValue < $1.prayer.rawValue }
                }
            }
        )
    }

    // MARK: - Sıfırlama

    private var resetSection: some View {
        Group {
            Button(L.t("calc.reset")) {
                model.apply(settings: .defaultForTurkey(latitude: latitude))
            }
            .buttonStyle(OutlineActionStyle())
            .padding(.top, 30)

            SectionNote(L.t("calc.reset.note"))
        }
    }

    /// Yüksek enlem kuralının makul varsayılanı konuma bağlı. Konum yoksa Türkiye
    /// ortalaması kullanılıyor — `defaultForTurkey`'in kendi varsayılanıyla aynı.
    private var latitude: Double {
        model.state.schedule?.location.coordinate.latitude ?? 39.0
    }

    // MARK: - Uygulama

    private func apply(_ transform: (inout CalculationSettings) -> Void) {
        var updated = settings
        transform(&updated)
        guard updated != settings else { return }
        // Tek yol bu: view model hem kalıcı tercihlere yazıyor hem de eldeki konumla
        // vakitleri yeniden hesaplıyor. Takvim ve bildirimler de aynı kaynaktan besleniyor.
        model.apply(settings: updated)
    }
}

#Preview {
    NavigationStack {
        CalculationSettingsScreen(model: Dependencies.preview().homeModel)
    }
}
