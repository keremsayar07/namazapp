import SwiftUI

/// Ayarlar ekranlarının ortak parçaları.
///
/// `Form` ve `List` kullanılmıyor: ikisi de kendi zeminini, köşe yuvarlamasını ve
/// ayırıcılarını getiriyor; "Dizgi" yönünün kâğıdını ve saç teli çizgilerini bozuyorlar.
/// Onun yerine satır, bölüm başlığı ve düğme biçimleri burada bir kez tanımlı.

/// Ad solda, kontrol sağda, altında saç teli çizgi.
struct SettingRow<Control: View>: View {
    let title: String
    /// Başlığın altındaki açıklama. Bir seçeneğin ne yaptığını söylemek, kullanıcıyı
    /// deneme yanılmaya bırakmaktan iyi.
    var caption: String?
    @ViewBuilder let control: Control

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Büyük yazıda ad ve kontrol yan yana sığmıyor.
                VStack(alignment: .leading, spacing: 8) {
                    label
                    control
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center) {
                    label
                    Spacer(minLength: 12)
                    control
                }
            }
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Typography.prayerName)
                .foregroundStyle(Palette.ink)
            if let caption {
                Text(caption)
                    .font(Typography.dateline)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Tek seçimli listelerde bir seçenek. Onay işareti yerine kiremit renkli bir blok:
/// "Dizgi"nin sözlüğünde ikon yok, seçili gün takvimde de böyle işaretleniyor.
struct ChoiceRow: View {
    let title: String
    var caption: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.prayerName)
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundStyle(isSelected ? Palette.mark : Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if let caption {
                        Text(caption)
                            .font(Typography.dateline)
                            .foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(isSelected ? Palette.mark : Color.clear)
                    .frame(width: 10, height: 10)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
        // Seçim yalnızca renkle anlatılmıyor: ekran okuyucu da "seçili" duyuyor.
        .accessibilityAddTraits(selectionTraits)
    }

    private var selectionTraits: AccessibilityTraits {
        isSelected ? AccessibilityTraits.isSelected : AccessibilityTraits()
    }
}

/// Alt ekrana giden satır. Sağda o an geçerli değerin özeti duruyor — kullanıcı içeri
/// girmeden ne seçili olduğunu görebilsin.
struct DisclosureRow<Destination: View>: View {
    let title: String
    var value: String?
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(Typography.prayerName)
                    .foregroundStyle(Palette.ink)

                Spacer(minLength: 12)

                if let value {
                    Text(value)
                        .font(Typography.dateline)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text("›")
                    .font(Font.system(.body, design: .serif))
                    .foregroundStyle(Palette.inkSoft)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
    }
}

/// Bölüm başlığı: büyük harfli mikro etiket.
struct SectionLabel: View {
    let text: String
    var topPadding: CGFloat = 28

    init(_ text: String, topPadding: CGFloat = 28) {
        self.text = text
        self.topPadding = topPadding
    }

    var body: some View {
        Text(text)
            .microLabelStyle()
            .padding(.top, topPadding)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Bölüm altındaki açıklama paragrafı.
struct SectionNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Typography.dateline)
            .foregroundStyle(Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
    }
}

// MARK: - Düğme biçimleri

struct FilledActionStyle: ButtonStyle {
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

struct OutlineActionStyle: ButtonStyle {
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

// MARK: - Sayfa iskeleti

/// Ayarların alt ekranları: kâğıt zemin, kaydırma, kenar boşlukları ve gezinme çubuğunun
/// zemine uydurulması. Dört ekranda dört kez yazılmasın diye.
struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        // Çubuk sistemin varsayılan zeminiyle gelirse kâğıdın üstünde ayrı bir gri şerit
        // gibi duruyor; aynı renge boyuyoruz.
        .toolbarBackground(Palette.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
