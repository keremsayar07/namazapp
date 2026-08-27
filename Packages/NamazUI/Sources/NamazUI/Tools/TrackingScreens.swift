import SwiftUI
import NamazCore
import PrayerKit

// MARK: - Namaz takibi

/// Günün beş vakti, işaretlenebilir.
///
/// **Oyunlaştırma yok.** Seri, rozet, yüzde, kutlama animasyonu yok. Son yedi gün ham sayı
/// olarak gösteriliyor, üzerine bir not verilmiyor. Kullanıcının kendi kaydına bakması bir
/// hatırlatma; uygulamanın onu puanlaması başka bir şey olurdu.
struct PrayerLogScreen: View {

    let model: PrayerLogViewModel

    var body: some View {
        SettingsPage(title: L.t("log.title")) {
            dayHeader
            prayers
            summary
            SectionNote(L.t("log.note"))
        }
        .task { await model.load() }
    }

    private var dayHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatting.weekdayLine(model.displayedDate, in: model.timeZone))
                    .font(Font.system(.headline, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if model.isShowingToday {
                    Text(L.t("log.today")).microLabelStyle(color: Palette.mark)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { model.showPreviousDay() } label: {
                Text("‹")
                    .font(Font.system(.title, design: .serif))
                    .foregroundStyle(Palette.mark)
                    .frame(width: 34, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(L.t("log.previous"))

            Button { model.showNextDay() } label: {
                Text("›")
                    .font(Font.system(.title, design: .serif))
                    // Bugündeyken ileri gidilemiyor; düğme görünür ama sönük.
                    .foregroundStyle(model.isShowingToday ? Palette.rule : Palette.mark)
                    .frame(width: 34, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(model.isShowingToday)
            .accessibilityLabel(L.t("log.next"))
        }
        .padding(.top, 18)
    }

    private var prayers: some View {
        Group {
            SectionLabel(L.t("log.section.prayers"))
            ForEach(Prayer.allCases.filter(\.isPerformablePrayer)) { prayer in
                let marked = model.isMarked(prayer)
                ChoiceRow(
                    title: Formatting.prayerName(prayer),
                    isSelected: marked,
                    action: { Task { await model.toggle(prayer) } }
                )
                .accessibilityLabel(
                    L.t(
                        marked ? "log.accessibility.done %@" : "log.accessibility.notDone %@",
                        Formatting.prayerName(prayer)
                    )
                )
            }
        }
    }

    /// Son yedi gün. Her gün için işaretlenen vakit sayısı — yorum yok, hedef yok.
    private var summary: some View {
        Group {
            SectionLabel(L.t("log.section.recent"))
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(model.recentDays(), id: \.dayKey) { day in
                    VStack(spacing: 6) {
                        // Beş kutucuk, işaretlenen kadarı dolu. Sayıyı okumadan da
                        // görülebilsin; ama bir "başarı" göstergesi değil, ham kayıt.
                        VStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { index in
                                Rectangle()
                                    .fill(index < day.marked ? Palette.mark : Palette.rule)
                                    .frame(height: 5)
                            }
                        }
                        Text(String(day.dayKey.suffix(2)))
                            .font(Typography.microLabel)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        L.t("log.accessibility.day %@ %@", day.dayKey, String(day.marked))
                    )
                }
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - Kaza

/// Kaza sayaçları. Vakit başına artır/azalt, bir de "bir gün ekle".
struct QadhaScreen: View {

    let model: QadhaViewModel

    var body: some View {
        SettingsPage(title: L.t("qadha.title")) {
            total
            counters
            Button(L.t("qadha.addDay")) { Task { await model.addFullDay() } }
                .buttonStyle(OutlineActionStyle())
                .padding(.top, 26)
            SectionNote(L.t("qadha.note"))
        }
        .task { await model.load() }
    }

    private var total: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.t("qadha.total")).microLabelStyle()
            Text(String(model.total))
                .font(Typography.place)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
        .accessibilityElement(children: .combine)
    }

    private var counters: some View {
        Group {
            SectionLabel(L.t("qadha.section.prayers"))
            ForEach(Prayer.allCases.filter(\.isPerformablePrayer)) { prayer in
                SettingRow(title: Formatting.prayerName(prayer)) {
                    HStack(spacing: 14) {
                        stepButton("−", prayer: prayer, delta: -1,
                                   label: L.t("qadha.accessibility.decrease %@",
                                              Formatting.prayerName(prayer)))

                        Text(String(model.count(for: prayer)))
                            .font(Typography.prayerTime)
                            .monospacedDigit()
                            .foregroundStyle(model.count(for: prayer) > 0 ? Palette.ink : Palette.inkSoft)
                            .frame(minWidth: 34)

                        stepButton("+", prayer: prayer, delta: 1,
                                   label: L.t("qadha.accessibility.increase %@",
                                              Formatting.prayerName(prayer)))
                    }
                }
            }
        }
    }

    private func stepButton(
        _ glyph: String, prayer: Prayer, delta: Int, label: String
    ) -> some View {
        Button {
            Task { await model.adjust(prayer, by: delta) }
        } label: {
            Text(glyph)
                .font(Font.system(.title3, design: .serif))
                .foregroundStyle(Palette.mark)
                // 44pt'nin altındaki hedefler ıskalanıyor.
                .frame(width: 34, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
