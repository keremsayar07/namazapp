import SwiftUI
import PrayerKit

/// Altı vaktin saç teli çizgilerle ayrılmış listesi.
///
/// Hem ana ekran hem takvim aynı defteri çiziyor. Ortak bir dosyaya çıkarılmasının sebebi
/// görsel tutarlılıktan fazlası: satır yüksekliği, erişilebilirlik metni ve büyük yazı
/// tipinde alt alta geçme davranışı tek yerde tanımlı kalıyor. İki kopya olsaydı biri
/// değişir, diğeri unutulurdu.
struct PrayerLedger: View {
    let times: [PrayerTime]
    /// Vurgulanacak vakit. Takvimde başka bir güne bakılırken `nil`.
    let currentPrayer: Prayer?
    /// Geçmiş/gelecek ayrımının ölçüldüğü an. `nil` ise ayrım yapılmıyor — 12 Eylül'e
    /// bakarken hangi vaktin "geçtiği" anlamsız bir bilgi, hepsi eşit ağırlıkta durmalı.
    let now: Date?
    let timeZone: TimeZone

    var body: some View {
        VStack(spacing: 0) {
            ForEach(times) { time in
                LedgerRow(
                    time: time,
                    isCurrent: time.prayer == currentPrayer,
                    isPast: now.map { time.date <= $0 } ?? false,
                    timeZone: timeZone
                )
            }
        }
    }
}

struct LedgerRow: View {
    let time: PrayerTime
    let isCurrent: Bool
    let isPast: Bool
    let timeZone: TimeZone

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var name: String { Formatting.prayerName(time.prayer) }
    private var clock: String { Formatting.clock(time.date, in: timeZone) }

    private var foreground: Color { isCurrent ? Palette.mark : Palette.ink }
    /// Geçmiş vakitler gizlenmiyor, geri çekiliyor — içinde bulunulan vakit hariç, o her
    /// hâlükârda vurgulu kalmalı.
    private var opacity: Double { (isPast && !isCurrent) ? Palette.pastOpacity : 1 }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Erişilebilirlik boyutlarında ad ve saat yan yana sığmıyor; çakışmak
                // yerine alt alta geçiyorlar.
                VStack(alignment: .leading, spacing: 2) {
                    nameText
                    clockText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    nameText
                    Spacer(minLength: 12)
                    clockText
                }
            }
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
        .opacity(opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenRow)
    }

    private var nameText: some View {
        Text(name)
            .font(Typography.prayerName)
            .fontWeight(isCurrent ? .medium : .regular)
            .foregroundStyle(foreground)
    }

    private var clockText: some View {
        Text(clock)
            .font(Typography.prayerTime)
            .fontWeight(isCurrent ? .medium : .regular)
            .foregroundStyle(foreground)
    }

    /// VoiceOver satırı tek parça okur ve durumu da söyler — görsel soluklaştırma ekran
    /// okuyucuya hiçbir şey anlatmaz, o bilgi metne girmek zorunda.
    private var spokenRow: String {
        if isCurrent {
            return L.t("home.accessibility.current %@ %@", name, clock)
        }
        return isPast
            ? L.t("home.accessibility.passed %@ %@", name, clock)
            : L.t("home.accessibility.upcoming %@ %@", name, clock)
    }
}
