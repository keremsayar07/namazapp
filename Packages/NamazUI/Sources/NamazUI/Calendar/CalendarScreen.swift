import SwiftUI
import NamazCore
import PrayerKit

/// Takvim sekmesi — "Dizgi" yönü.
///
/// Düzen ana ekranın kardeşi: kalın kural çizgisi, serif ay başlığı, altında italik hicri
/// aralık, sonra yedi sütunlu ızgara ve seçili günün defteri. İkon yok; ay değiştirme okları
/// bile tipografik (‹ ›), çünkü bu ekranın dili harflerden ibaret.
///
/// Konum ve hesaplama ayarı burada tutulmuyor, dışarıdan geliyor: tek gerçek `HomeViewModel`
/// içinde. Kullanıcı şehri Vakit sekmesinde değiştirdiğinde takvim de aynı anda değişmeli;
/// iki ayrı kopya tutulsaydı biri eski şehirde kalırdı.
struct CalendarScreen: View {

    let location: SavedLocation?
    let calculationSettings: CalculationSettings

    @State private var model: CalendarViewModel

    /// `CalendarViewModel` `@MainActor` izole; onu burada kurduğumuz için init'in de öyle
    /// olduğunu açıkça yazıyoruz. SwiftUI'ın `View`'undan zaten çıkarım geliyor ama
    /// çıkarıma güvenmek, ileride eşzamanlılık kontrolü sıkılaştığında sessizce kırılır.
    @MainActor
    init(location: SavedLocation?, calculationSettings: CalculationSettings) {
        self.location = location
        self.calculationSettings = calculationSettings
        _model = State(
            initialValue: CalendarViewModel(location: location, settings: calculationSettings)
        )
    }

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()

            if let month = model.month, let timeZone = location?.coordinate.timeZone {
                content(month: month, timeZone: timeZone)
            } else {
                CalendarEmptyView()
            }
        }
        // Konum ilk açılışta asenkron çözülüyor: ekran kurulduğunda `location` genelde hâlâ
        // nil oluyor, birkaç yüz milisaniye sonra doluyor. Bu yüzden ikisini de izliyoruz.
        .onChange(of: location) { model.update(location: location, settings: calculationSettings) }
        .onChange(of: calculationSettings) { model.update(location: location, settings: calculationSettings) }
    }

    private func content(month: CalendarMonth, timeZone: TimeZone) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(Palette.ink)
                    .frame(height: 2)
                    .accessibilityHidden(true)

                MonthHeader(
                    month: month,
                    timeZone: timeZone,
                    onPrevious: model.goToPreviousMonth,
                    onNext: model.goToNextMonth
                )

                MonthGrid(
                    month: month,
                    timeZone: timeZone,
                    selected: model.selectedDay,
                    onSelect: model.select
                )
                .padding(.top, 14)

                if let day = model.selectedDay {
                    DayDetail(day: day, timeZone: timeZone)
                        .padding(.top, 26)
                } else {
                    // Kullanıcı başka bir aya geçtiğinde seçim düşüyor. Boş bırakmak yerine
                    // ne yapması gerektiğini söylüyoruz.
                    Text(L.t("calendar.hint"))
                        .font(Typography.prayerName)
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.top, 26)
                }

                if !month.days.contains(where: \.isToday) {
                    Button(L.t("calendar.today"), action: model.goToToday)
                        .microLabelStyle(color: Palette.mark)
                        .padding(.top, 24)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Başlık

private struct MonthHeader: View {
    let month: CalendarMonth
    let timeZone: TimeZone
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Formatting.monthLine(month.anchor, in: timeZone))
                    .font(Font.system(.title, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(Formatting.hijriSpanLine(month.hijriSpan))
                    .font(Typography.dateline)
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            ArrowButton(glyph: "‹", label: L.t("calendar.previous"), action: onPrevious)
            ArrowButton(glyph: "›", label: L.t("calendar.next"), action: onNext)
        }
        .padding(.top, 14)
    }
}

/// Ay değiştirme oku. Glif serif — SF Symbols yerine harf kullanmak bu ekranın dilini
/// bozmuyor. Dokunma alanı gliften büyük tutuldu: 44pt'nin altındaki hedefler ıskalanıyor.
private struct ArrowButton: View {
    let glyph: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(glyph)
                .font(Font.system(.title, design: .serif))
                .foregroundStyle(Palette.mark)
                .frame(width: 34, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Izgara

private struct MonthGrid: View {
    let month: CalendarMonth
    let timeZone: TimeZone
    let selected: CalendarDay?
    let onSelect: (CalendarDay) -> Void

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    /// Türkçe'de kısaltmalar tekrar ediyor (P, S, Ç, P, C, C, P). Bu yüzden kimlik olarak
    /// harfin kendisi kullanılamıyor — indeks kullanılıyor.
    private var initials: [String] { Formatting.weekdayInitials(calendar) }

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(initials.indices, id: \.self) { index in
                    Text(initials[index])
                        .microLabelStyle()
                }
            }
            .accessibilityHidden(true)

            Rectangle()
                .fill(Palette.rule)
                .frame(height: 1)
                .accessibilityHidden(true)

            LazyVGrid(columns: columns, spacing: 2) {
                // Boş hücrelerin kimliği indeksten geliyor; hepsi birbirinin aynı olduğu
                // için `id: \.self` yanlış olurdu.
                ForEach(Array(0..<month.leadingBlanks), id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }
                ForEach(month.days) { day in
                    DayCell(
                        day: day,
                        timeZone: timeZone,
                        isSelected: day.id == selected?.id,
                        action: { onSelect(day) }
                    )
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: CalendarDay
    let timeZone: TimeZone
    let isSelected: Bool
    let action: () -> Void

    private var foreground: Color {
        if isSelected { return Palette.ground }
        return day.isToday ? Palette.mark : Palette.ink
    }

    var body: some View {
        Button(action: action) {
            Text(String(day.dayNumber))
                .font(Typography.prayerTime)
                .fontWeight(day.isToday ? .semibold : .regular)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                // Seçili gün mürekkep lekesi gibi: köşe yuvarlaması yok, tipografik
                // baskıdaki gibi düz bir blok.
                .background(isSelected ? Palette.mark : Color.clear)
                .overlay(alignment: .bottom) {
                    // Bugün seçili değilken de bulunabilmeli: altındaki kısa çizgi onu
                    // renkten bağımsız olarak işaretliyor (renk körlüğü tek başına renge
                    // güvenmeyi güvenilmez kılıyor).
                    if day.isToday && !isSelected {
                        Rectangle()
                            .fill(Palette.mark)
                            .frame(width: 16, height: 2)
                            .padding(.bottom, 5)
                    }
                }
                .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel)
        // `.isButton` zaten Button'dan geliyor; buraya yalnızca seçim durumu ekleniyor.
        .accessibilityAddTraits(extraTraits)
    }

    private var extraTraits: AccessibilityTraits {
        isSelected ? AccessibilityTraits.isSelected : AccessibilityTraits()
    }

    private var accessibilityLabel: String {
        let date = Formatting.weekdayLine(day.date, in: timeZone)
        return day.isToday ? L.t("calendar.accessibility.today %@", date) : date
    }
}

// MARK: - Seçili gün

private struct DayDetail: View {
    let day: CalendarDay
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Formatting.weekdayLine(day.date, in: timeZone))
                .font(Font.system(.headline, design: .serif))
                .foregroundStyle(Palette.ink)

            if let hijri = day.hijri {
                Text(Formatting.hijriLine(hijri))
                    .font(Typography.dateline)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.top, 3)
            }

            ledger.padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var ledger: some View {
        if day.isToday {
            // Yalnızca bugüne bakarken "şu anki vakit" vurgusu anlamlı; ana ekrandaki
            // gibi dakikaya hizalı yenileniyor.
            TimelineView(.everyMinute) { context in
                PrayerLedger(
                    times: day.times.times,
                    currentPrayer: day.times.currentPrayer(at: context.date),
                    now: context.date,
                    timeZone: timeZone
                )
            }
        } else {
            // Başka bir günde vurgu da soluklaştırma da yok: 12 Eylül'ün hangi vakti
            // "geçti" sorusunun bir karşılığı yok.
            PrayerLedger(
                times: day.times.times,
                currentPrayer: nil,
                now: nil,
                timeZone: timeZone
            )
        }
    }
}

// MARK: - Konum yok

/// Takvim, vakitleri hesaplayabilmek için bir konuma muhtaç. Konum henüz çözülmediyse ya da
/// izin yoksa boş ızgara çizmek yerine durumu söylüyoruz — kullanıcı Vakit sekmesinde
/// şehir seçtiğinde burası kendiliğinden doluyor.
private struct CalendarEmptyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Palette.ink)
                .frame(height: 2)
                .padding(.bottom, 12)
                .accessibilityHidden(true)

            Text(L.t("calendar.empty.title"))
                .font(Font.system(.title2, design: .serif))
                .foregroundStyle(Palette.ink)

            Text(L.t("calendar.empty.body"))
                .font(Typography.prayerName)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }
}

// MARK: - Önizlemeler

#Preview("Takvim") {
    CalendarScreen(
        location: SavedLocation(
            name: "İstanbul",
            coordinate: Coordinate(
                latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"
            ),
            source: .manual
        ),
        calculationSettings: .defaultForTurkey()
    )
}

#Preview("Konum yok") {
    CalendarScreen(location: nil, calculationSettings: .defaultForTurkey())
}
