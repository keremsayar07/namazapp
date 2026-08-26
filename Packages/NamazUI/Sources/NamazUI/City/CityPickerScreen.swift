import SwiftUI
import NamazCore
import PrayerKit

/// Elle şehir seçme ekranı.
///
/// Sistem `.searchable` görünümü yerine düz bir alan ve altında saç teli çizgi: "Dizgi"
/// yönünün geri kalanıyla aynı dilde kalıyor. Liste de `List` değil — `List`'in kendi
/// ayırıcıları, iç boşlukları ve arka planı bu paleti bozardı.
struct CityPickerScreen: View {

    @State private var model: CityPickerViewModel
    @FocusState private var isFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private let onSelect: (SavedLocation) -> Void

    init(model: CityPickerViewModel, onSelect: @escaping (SavedLocation) -> Void) {
        _model = State(initialValue: model)
        self.onSelect = onSelect
    }

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                searchField
                content
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        // Klavye hemen açılıyor: bu ekranın tek işi yazmak.
        .onAppear { isFieldFocused = true }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L.t("city.title"))
                .font(Font.system(.title2, design: .serif))
                .foregroundStyle(Palette.ink)

            Spacer(minLength: 12)

            Button(L.t("city.cancel")) { dismiss() }
                .font(Typography.prayerName)
                .foregroundStyle(Palette.mark)
        }
        .padding(.bottom, 18)
    }

    private var searchField: some View {
        VStack(spacing: 0) {
            TextField(L.t("city.placeholder"), text: $model.query)
                .font(Font.system(.title3, design: .serif))
                .foregroundStyle(Palette.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFieldFocused)
                .padding(.bottom, 8)
                // Arama, gözlenen bir değerin yan etkisi olarak değil, burada açıkça
                // tetikleniyor — çağrı sırası okunur kalsın diye.
                .onChange(of: model.query) { model.queryChanged() }

            Rectangle()
                .fill(Palette.ink)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .empty:
            Notice(title: nil, message: L.t("city.hint"))

        case .searching:
            Notice(title: nil, message: L.t("city.searching"))

        case .noResults:
            Notice(title: L.t("city.noresults.title"), message: L.t("city.noresults.body"))

        case .failed:
            Notice(title: L.t("city.failed.title"), message: L.t("city.failed.body"))

        case .results(let candidates):
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(candidates) { candidate in
                        CandidateRow(candidate: candidate) {
                            onSelect(candidate.asSavedLocation())
                            dismiss()
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }
}

// MARK: - Satır

private struct CandidateRow: View {
    let candidate: CityCandidate
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.name)
                    .font(Typography.prayerName)
                    .foregroundStyle(Palette.ink)

                if !candidate.region.isEmpty {
                    Text(candidate.region)
                        .microLabelStyle()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("city.accessibility.select %@ %@", candidate.name, candidate.region))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Bilgi metni

/// Boş, aranıyor, sonuç yok ve hata durumlarının ortak biçimi. Dördü de aynı yerde,
/// aynı hizada görünüyor — ekran durum değiştirirken zıplamıyor.
private struct Notice: View {
    let title: String?
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(Font.system(.headline, design: .serif))
                    .foregroundStyle(Palette.ink)
            }
            Text(message)
                .font(Typography.prayerName)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 22)
    }
}

// MARK: - Önizlemeler

#Preview("Sonuçlar") {
    CityPickerScreen(
        model: {
            let model = CityPickerViewModel(search: StubCitySearch(), debounce: .zero)
            model.query = "an"
            model.queryChanged()
            return model
        }(),
        onSelect: { _ in }
    )
}

#Preview("Boş") {
    CityPickerScreen(
        model: CityPickerViewModel(search: StubCitySearch(), debounce: .zero),
        onSelect: { _ in }
    )
}
