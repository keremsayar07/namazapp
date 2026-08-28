import SwiftUI
import NamazCore
import PrayerKit

// MARK: - İmsakiye

/// Ramazan ayının imsak ve iftar tablosu.
///
/// Ayrı bir "ramazan sekmesi" yok. Ramazan yılın on bir ayında boş duran bir sekme demek
/// olurdu; burası Araçlar'ın altında, arandığında bulunan bir tablo. Ramazan yaklaşınca
/// Ana ekranda kendiliğinden görünen şerit, kullanıcıyı zaten buraya hazırlıyor.
struct ImsakiyeScreen: View {

    let location: SavedLocation?
    let calculationSettings: CalculationSettings

    @State private var model: RamadanViewModel

    /// Konum ve hesaplama ayarı takvim ekranındaki gibi dışarıdan geliyor: tek gerçek
    /// `HomeViewModel` içinde. Kullanıcı şehri Vakit sekmesinde değiştirdiğinde imsakiye de
    /// aynı anda değişmeli — kendi kopyasını tutsaydı biri eski şehirde kalırdı.
    @MainActor
    init(location: SavedLocation?, calculationSettings: CalculationSettings) {
        self.location = location
        self.calculationSettings = calculationSettings
        _model = State(
            initialValue: RamadanViewModel(location: location, settings: calculationSettings)
        )
    }

    var body: some View {
        SettingsPage(title: L.t("ramadan.imsakiye.title")) {
            if model.days.isEmpty {
                SectionNote(L.t("ramadan.unavailable"))
            } else {
                header
                if !model.isVerified { unverifiedNotice }
                columnTitles
                table
                SectionNote(L.t("ramadan.imsakiye.note"))
            }
        }
        // Konum ilk açılışta asenkron çözülüyor; ekran kurulduğunda genelde hâlâ nil.
        .onChange(of: location) { model.update(location: location, settings: calculationSettings) }
        .onChange(of: calculationSettings) { model.update(location: location, settings: calculationSettings) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.t("ramadan.heading %@", String(model.period?.hijriYear ?? 0)))
                .font(Font.system(.title3, design: .serif))
                .foregroundStyle(Palette.ink)

            Text(subtitle)
                .font(Typography.dateline)
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
    }

    private var subtitle: String {
        guard let first = model.days.first, let last = model.days.last else { return "" }
        let span = L.t(
            "ramadan.span %@ %@",
            Formatting.gregorianLine(first.date, in: model.timeZone),
            Formatting.gregorianLine(last.date, in: model.timeZone)
        )
        if let remaining = model.daysUntilStart(from: Date()) {
            return "\(span) · \(L.t("ramadan.starts_in %@", String(remaining)))"
        }
        if let today = model.today {
            return "\(span) · \(L.t("ramadan.day %@", String(today.number)))"
        }
        return span
    }

    /// Doğrulanmamış tablo uyarısı.
    ///
    /// Bu ekran için en önemli metin. Ramazanın başlangıcı bir gün kayarsa tablodaki
    /// **her satır** yanlış olur — 12. gün diye bakılan satır aslında 11. gündür. Bunu
    /// yazmadan tablo göstermek, tam olarak kaçındığımız şeyi yapmak olurdu.
    private var unverifiedNotice: some View {
        Text(L.t("ramadan.unverified"))
            .font(Typography.dateline)
            .foregroundStyle(Palette.mark)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
    }

    private var columnTitles: some View {
        HStack(spacing: 0) {
            Text(L.t("ramadan.column.day"))
                .frame(width: 34, alignment: .leading)
            Text(L.t("ramadan.column.date"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L.t("ramadan.column.imsak"))
                .frame(width: 62, alignment: .trailing)
            Text(L.t("ramadan.column.iftar"))
                .frame(width: 62, alignment: .trailing)
        }
        .microLabelStyle()
        .padding(.top, 22)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.ink).frame(height: 1)
        }
    }

    private var table: some View {
        ForEach(model.days) { day in
            HStack(spacing: 0) {
                Text(String(day.number))
                    .font(Typography.prayerTime)
                    .frame(width: 34, alignment: .leading)

                Text(Formatting.shortDayLine(day.date, in: model.timeZone))
                    .font(Typography.prayerName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(Formatting.clock(day.imsak, in: model.timeZone))
                    .font(Typography.prayerTime)
                    .frame(width: 62, alignment: .trailing)

                Text(Formatting.clock(day.iftar, in: model.timeZone))
                    .font(Typography.prayerTime)
                    .frame(width: 62, alignment: .trailing)
            }
            // Bugünün satırı kalın değil, işaretli: kalınlaştırmak tabloyu zıplatır.
            .foregroundStyle(day.isToday ? Palette.mark : Palette.ink)
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Ana ekran şeridi

/// Ana ekranda ramazan boyunca görünen tek satır: kaçıncı gün ve sıradaki eşiğe kalan süre.
///
/// **Neden ayrı bir hesap yok.** İmsak = sabah (fecr-i sadık) vakti, iftar = akşam vakti.
/// İkisi de zaten ekrandaki defterde duruyor; bu şerit onları başka bir başlıkla,
/// oruç tutan birinin baktığı sırayla gösteriyor. Ayrı hesaplasaydık aynı günün iki farklı
/// iftar saatini gösterme riski doğardı.
///
/// Ramazan tespiti de taramaya değil, günün kendi hicri tarihine dayanıyor: `hijriDate.month`
/// zaten hesaplanmış durumda ve uygulamanın her yerinde aynı dönüştürücüden geliyor.
struct RamadanStrip: View {

    let schedule: PrayerSchedule
    let now: Date

    /// Ramazan günü numarası; ramazanda değilsek `nil`.
    private var dayNumber: Int? {
        guard let hijri = schedule.today.hijriDate, hijri.month == 9 else { return nil }
        return hijri.day
    }

    /// Sıradaki eşik: sahurun sonu (imsak) mu, iftar mı?
    private enum Milestone {
        case imsak(Date)
        case iftar(Date)
    }

    private var milestone: Milestone? {
        guard
            let fajr = schedule.today.time(for: .fajr),
            let maghrib = schedule.today.time(for: .maghrib)
        else { return nil }

        if now < fajr { return .imsak(fajr) }
        if now < maghrib { return .iftar(maghrib) }

        // Akşamdan sonra sıradaki eşik yarının imsağı. Bugünün imsağını göstermek geçmişe
        // sayan bir geri sayım olurdu.
        //
        // Ama yarın bayramın ilk günüyse oruç yok: arefe akşamı "sahura kalan süre"
        // göstermek, kullanıcıyı tutulmayacak bir oruca kaldırmak olurdu.
        guard
            schedule.tomorrow.hijriDate?.month == 9,
            let tomorrowFajr = schedule.tomorrow.time(for: .fajr)
        else { return nil }
        return .imsak(tomorrowFajr)
    }

    var body: some View {
        if let dayNumber {
            // Geri sayım yoksa (ramazanın son akşamı) gün yazısı yine de duruyor. Şeridin
            // tamamen kaybolması, ekranın o akşam sebepsizce zıplaması demek olurdu.
            let remaining = milestone.map { max(0, target(of: $0).timeIntervalSince(now)) }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(L.t("ramadan.day %@", String(dayNumber)))
                    .microLabelStyle(color: Palette.mark)

                Spacer(minLength: 8)

                if let milestone, let remaining {
                    Text(label(for: milestone))
                        .microLabelStyle()

                    Text(Formatting.countdown(remaining))
                        .font(Typography.prayerTime)
                        .foregroundStyle(Palette.ink)
                }
            }
            .padding(.top, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText(dayNumber: dayNumber, remaining: remaining))
        }
    }

    private func accessibilityText(dayNumber: Int, remaining: TimeInterval?) -> String {
        guard let milestone, let remaining else {
            return L.t("ramadan.day %@", String(dayNumber))
        }
        return L.t(
            "ramadan.accessibility %@ %@ %@",
            String(dayNumber),
            label(for: milestone),
            Formatting.spokenCountdown(remaining)
        )
    }

    private func target(of milestone: Milestone) -> Date {
        switch milestone {
        case .imsak(let date): return date
        case .iftar(let date): return date
        }
    }

    private func label(for milestone: Milestone) -> String {
        switch milestone {
        case .imsak: return L.t("ramadan.until_imsak")
        case .iftar: return L.t("ramadan.until_iftar")
        }
    }
}
