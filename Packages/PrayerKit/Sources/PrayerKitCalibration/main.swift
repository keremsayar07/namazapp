import Foundation
import PrayerKit

// Diyanet'in yayımladığı vakitlerle PrayerKit'in hesapladığı vakitleri gün gün karşılaştırıp
// her vakit için sistematik farkı (Diyanet'in temkin payı) dakika cinsinden ölçer.
//
// Neden ayrı bir Swift aracı
// --------------------------
// Hesabı Python'a port edip orada ölçmek, "port ettiğim şeyin farkını" ölçmek olurdu.
// Bu araç gerçek PrayerKit kodunu çağırıyor, dolayısıyla raporladığı fark uygulamanın
// gerçekten üreteceği fark.
//
// Koordinat sorunu ve çözümü
// --------------------------
// Ayna verisi enlem/boylam içermiyor, Diyanet de her ilçe için hangi noktayı referans
// aldığını yayımlamıyor. Şehir merkezi koordinatını tahmin edip kullanmak, koordinat
// hatasını temkin payı sanmamıza yol açardı. Bunun yerine etkin koordinatı Diyanet'in
// KENDİ verisinden çıkarıyoruz:
//
//   1. Boylam: Güneş ve Akşam vakitlerinin ORTA NOKTASI güneş öğlesidir. Temkin payı
//      birine eklenip diğerinden çıkarıldığı için ortalamada sadeleşir; geriye sadece
//      boylamın belirlediği güneş öğlesi kalır. Öğle vakti enlemden bağımsız olduğu için
//      bu adım tek başına çözülebiliyor.
//   2. Enlem: Doğru enlemde, hesaplanan gün doğumu ile Diyanet'in Güneş vakti arasındaki
//      fark ay boyunca SABİT kalır (o sabit, temkin payının kendisidir). Yanlış enlemde
//      fark gün uzunluğuyla birlikte kayar. Bu yüzden enlemi, farkın ortalamasını değil
//      SAPMASINI en küçükleyen değer olarak arıyoruz.
//
// Fit edilen koordinatlar, bilinen coğrafi koordinatların yanında raporlanıyor. İkisi
// birbirine yakın çıkıyorsa yöntem kendini doğrulamış olur; uzak çıkarsa rapor bunu
// görünür kılar ve o şehrin sonucuna güvenmeyiz.

// MARK: - Girdi modelleri

struct MirrorMonthFile: Decodable {
    let district: String?
    let province: String?
    let districtId: String
    let month: String
    let days: [String: MirrorDay]
}

struct MirrorDay: Decodable {
    let imsak: String?
    let gunes: String?
    let ogle: String?
    let ikindi: String?
    let aksam: String?
    let yatsi: String?
    let hicriTarihUzun: String?

    enum CodingKeys: String, CodingKey {
        case imsak = "Imsak"
        case gunes = "Gunes"
        case ogle = "Ogle"
        case ikindi = "Ikindi"
        case aksam = "Aksam"
        case yatsi = "Yatsi"
        case hicriTarihUzun = "HicriTarihUzun"
    }
}

// MARK: - Çalışma modelleri

/// Bir günün Diyanet tarafından yayımlanmış hâli, yerel saat dakikasına çevrilmiş olarak.
struct ObservedDay {
    let iso: String
    /// O takvim gününü temsil eden, 12:00 UTC'ye sabitlenmiş tarih.
    let anchor: Date
    /// Gece yarısından itibaren yerel dakika.
    let minutes: [Prayer: Double]
    let hijriLong: String?
}

/// Arama için başlangıç noktası ve rapordaki tutarlılık kontrolü için referans.
/// Bu değerler HESAPLAMADA KULLANILMIYOR — sadece fit'in başlangıç noktası ve
/// sonucun makul olup olmadığını görmek için.
let seedCoordinates: [String: (name: String, latitude: Double, longitude: Double)] = [
    "9541":  ("İstanbul",   41.01, 28.98),
    "9206":  ("Ankara",     39.93, 32.86),
    "9560":  ("İzmir",      38.42, 27.14),
    "9225":  ("Antalya",    36.90, 30.71),
    "9479":  ("Gaziantep",  37.07, 37.38),
    "9402":  ("Diyarbakır", 37.91, 40.23),
    "9451":  ("Erzurum",    39.90, 41.27),
    "9905":  ("Trabzon",    41.00, 39.72),
    "9676":  ("Konya",      37.87, 32.49),
    "20089": ("Hatay",      36.20, 36.16),
    "9930":  ("Van",        38.49, 43.41),
    "9847":  ("Sinop",      42.02, 35.15)
]

let timeZoneIdentifier = "Europe/Istanbul"
let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 3 * 3600)!
let service = PrayerCalculationService()

// MARK: - Küçük yardımcılar

func parseClock(_ text: String?) -> Double? {
    guard let text else { return nil }
    let parts = text.split(separator: ":")
    guard parts.count >= 2,
          let hour = Int(parts[0]),
          let minute = Int(parts[1]) else { return nil }
    return Double(hour) * 60 + Double(minute)
}

func anchorDate(iso: String) -> Date? {
    let parts = iso.split(separator: "-")
    guard parts.count == 3,
          let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
        return nil
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return calendar.date(from: components)
}

func localMinutes(_ date: Date) -> Double {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
    return Double(parts.hour ?? 0) * 60 + Double(parts.minute ?? 0) + Double(parts.second ?? 0) / 60
}

func mean(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return .nan }
    return values.reduce(0, +) / Double(values.count)
}

func median(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return .nan }
    let sorted = values.sorted()
    let middle = sorted.count / 2
    return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}

func standardDeviation(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let average = mean(values)
    let variance = values.reduce(0) { $0 + ($1 - average) * ($1 - average) } / Double(values.count - 1)
    return variance.squareRoot()
}

func format(_ value: Double, _ decimals: Int = 1) -> String {
    value.isNaN ? "—" : String(format: "%.\(decimals)f", value)
}

// MARK: - Koordinat fit'i

/// `.turkey` artık ölçülmüş temkin paylarını içeriyor. Koordinat fit'i bu paylardan
/// ETKİLENMEMELİ — yoksa fit, payları koordinat kaymasıyla telafi etmeye çalışır ve
/// boylamı 1.25 derece kaydırır. Bu yüzden fit aşamasında aynı açılara sahip ama temkin
/// payı olmayan `.custom` kullanılıyor; ölçüm aşamasında ise gerçek `.turkey`.
let bareMethod = CalculationMethod.custom(fajrAngle: 18, ishaAngle: 17)

func computedMinutes(
    for day: ObservedDay,
    coordinate: Coordinate,
    madhab: Madhab,
    method: CalculationMethod
) -> [Prayer: Double] {
    var settings = CalculationSettings.defaultForTurkey(latitude: coordinate.latitude)
    settings.madhab = madhab
    settings.method = method
    let daily = service.dailyTimes(for: day.anchor, coordinate: coordinate, settings: settings)
    var result: [Prayer: Double] = [:]
    for prayer in Prayer.allCases {
        if let date = daily.time(for: prayer) {
            result[prayer] = localMinutes(date)
        }
    }
    return result
}

/// Güneş + Akşam orta noktasından boylamı çözer. Öğle vakti enlemden bağımsız olduğu için
/// bu adım tek başına ve doğrudan çözülebiliyor; boylamın 1 derecesi öğleyi 4 dakika kaydırır.
func fitLongitude(days: [ObservedDay], seedLatitude: Double, seedLongitude: Double) -> Double {
    var longitude = seedLongitude
    for _ in 0..<4 {
        var deltas: [Double] = []
        for day in days {
            guard let sunrise = day.minutes[.sunrise], let sunset = day.minutes[.maghrib] else { continue }
            let observedSolarNoon = (sunrise + sunset) / 2
            let coordinate = Coordinate(
                latitude: seedLatitude, longitude: longitude, timeZoneIdentifier: timeZoneIdentifier
            )
            guard let computedNoon = computedMinutes(
                for: day, coordinate: coordinate, madhab: .shafi, method: bareMethod
            )[.dhuhr] else { continue }
            deltas.append(computedNoon - observedSolarNoon)
        }
        guard !deltas.isEmpty else { break }
        // Hesaplanan öğle hedeften Δ dakika geç ise, boylamı Δ/4 derece doğuya kaydır.
        longitude += mean(deltas) / 4
    }
    return longitude
}

/// Doğru enlemde gün doğumu/batımı farkları ay boyunca sabit kalır. Sapmayı en küçükleyen
/// enlemi kaba-ince aramayla buluyoruz.
func fitLatitude(days: [ObservedDay], longitude: Double, seedLatitude: Double) -> Double {
    func spread(at latitude: Double) -> Double {
        let coordinate = Coordinate(
            latitude: latitude, longitude: longitude, timeZoneIdentifier: timeZoneIdentifier
        )
        var sunriseDeltas: [Double] = []
        var sunsetDeltas: [Double] = []
        for day in days {
            let computed = computedMinutes(
                for: day, coordinate: coordinate, madhab: .shafi, method: bareMethod
            )
            if let observed = day.minutes[.sunrise], let value = computed[.sunrise] {
                sunriseDeltas.append(value - observed)
            }
            if let observed = day.minutes[.maghrib], let value = computed[.maghrib] {
                sunsetDeltas.append(value - observed)
            }
        }
        return standardDeviation(sunriseDeltas) + standardDeviation(sunsetDeltas)
    }

    var best = seedLatitude
    var bestScore = Double.infinity
    var low = seedLatitude - 1.5
    var high = seedLatitude + 1.5
    var step = 0.05

    for _ in 0..<3 {
        var candidate = low
        while candidate <= high {
            let score = spread(at: candidate)
            if score < bestScore {
                bestScore = score
                best = candidate
            }
            candidate += step
        }
        low = best - step
        high = best + step
        step /= 10
    }
    return best
}

// MARK: - Rapor modelleri

struct PrayerStats {
    let prayer: Prayer
    let deltas: [Double]

    var count: Int { deltas.count }
    var meanValue: Double { mean(deltas) }
    var medianValue: Double { median(deltas) }
    var minValue: Double { deltas.min() ?? .nan }
    var maxValue: Double { deltas.max() ?? .nan }
    var spread: Double { standardDeviation(deltas) }
}

struct CityReport {
    let districtId: String
    let name: String
    let seedLatitude: Double
    let seedLongitude: Double
    let fittedLatitude: Double
    let fittedLongitude: Double
    let dayCount: Int
    let statsShafi: [Prayer: PrayerStats]
    let statsHanafi: [Prayer: PrayerStats]

    var latitudeDrift: Double { fittedLatitude - seedLatitude }
    var longitudeDrift: Double { fittedLongitude - seedLongitude }
}

func label(_ prayer: Prayer) -> String {
    switch prayer {
    case .fajr: return "İmsak"
    case .sunrise: return "Güneş"
    case .dhuhr: return "Öğle"
    case .asr: return "İkindi"
    case .maghrib: return "Akşam"
    case .isha: return "Yatsı"
    }
}

// MARK: - Yükleme

func loadCity(directory: URL) -> (id: String, name: String, days: [ObservedDay])? {
    let decoder = JSONDecoder()
    let files = (try? FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil
    )) ?? []

    var days: [ObservedDay] = []
    var districtId = directory.lastPathComponent
    var name = districtId

    for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    where file.pathExtension == "json" {
        guard let data = try? Data(contentsOf: file),
              let month = try? decoder.decode(MirrorMonthFile.self, from: data) else { continue }
        districtId = month.districtId
        if let province = month.province, !province.isEmpty { name = province }

        for (iso, record) in month.days {
            guard let anchor = anchorDate(iso: iso) else { continue }
            var minutes: [Prayer: Double] = [:]
            if let value = parseClock(record.imsak) { minutes[.fajr] = value }
            if let value = parseClock(record.gunes) { minutes[.sunrise] = value }
            if let value = parseClock(record.ogle) { minutes[.dhuhr] = value }
            if let value = parseClock(record.ikindi) { minutes[.asr] = value }
            if let value = parseClock(record.aksam) { minutes[.maghrib] = value }
            if let value = parseClock(record.yatsi) { minutes[.isha] = value }
            guard minutes.count == 6 else { continue }
            days.append(ObservedDay(
                iso: iso, anchor: anchor, minutes: minutes, hijriLong: record.hicriTarihUzun
            ))
        }
    }

    guard !days.isEmpty else { return nil }
    return (districtId, name, days.sorted { $0.iso < $1.iso })
}

func analyze(id: String, name: String, days: [ObservedDay]) -> CityReport {
    let seed = seedCoordinates[id] ?? (name: name, latitude: 39.0, longitude: 35.0)
    let longitude = fitLongitude(
        days: days, seedLatitude: seed.latitude, seedLongitude: seed.longitude
    )
    let latitude = fitLatitude(days: days, longitude: longitude, seedLatitude: seed.latitude)
    let coordinate = Coordinate(
        latitude: latitude, longitude: longitude, timeZoneIdentifier: timeZoneIdentifier
    )

    func collect(madhab: Madhab) -> [Prayer: PrayerStats] {
        var buckets: [Prayer: [Double]] = [:]
        for day in days {
            let computed = computedMinutes(
                for: day, coordinate: coordinate, madhab: madhab, method: .turkey
            )
            for prayer in Prayer.allCases {
                guard let observed = day.minutes[prayer], let value = computed[prayer] else { continue }
                // Pozitif fark = Diyanet daha geç = hesabımıza bu kadar dakika EKLEMELİYİZ.
                buckets[prayer, default: []].append(observed - value)
            }
        }
        var result: [Prayer: PrayerStats] = [:]
        for (prayer, deltas) in buckets {
            result[prayer] = PrayerStats(prayer: prayer, deltas: deltas)
        }
        return result
    }

    return CityReport(
        districtId: id,
        name: seedCoordinates[id]?.name ?? name,
        seedLatitude: seed.latitude,
        seedLongitude: seed.longitude,
        fittedLatitude: latitude,
        fittedLongitude: longitude,
        dayCount: days.count,
        statsShafi: collect(madhab: .shafi),
        statsHanafi: collect(madhab: .hanafi)
    )
}

// MARK: - Rapor üretimi

func statsRow(_ stats: PrayerStats?) -> String {
    guard let stats else { return "| — | — | — | — | — | 0 |" }
    return "| \(format(stats.meanValue)) | \(format(stats.medianValue)) "
        + "| \(format(stats.minValue)) | \(format(stats.maxValue)) "
        + "| \(format(stats.spread, 2)) | \(stats.count) |"
}

func buildReport(cities: [CityReport], generatedAt: String) -> String {
    var lines: [String] = []
    lines.append("# Kalibrasyon raporu")
    lines.append("")
    lines.append("Bu dosya `prayerkit-calibrate` tarafından üretilir, elle düzenlenmez.")
    lines.append("")
    lines.append("- Üretim (UTC): `\(generatedAt)`")
    lines.append("- Kaynak: `Reference/diyanet/mirror` — bkz. `Tools/diyanet_reference/PROVENANCE.md`")
    lines.append("- Yöntem: `CalculationMethod.turkey` (İmsak 18°, Yatsı 17°, akşam offseti 0)")
    lines.append("- Şehir sayısı: \(cities.count), toplam gün: \(cities.reduce(0) { $0 + $1.dayCount })")
    lines.append("")
    lines.append("**Fark tanımı:** `Diyanet − PrayerKit`, dakika cinsinden. Pozitif değer,")
    lines.append("Diyanet'in vakti daha geç yayımladığı anlamına gelir; yani hesabımıza o kadar")
    lines.append("dakika eklememiz gerekir. **Std sapma sütunu asıl önemli olan:** küçükse fark")
    lines.append("sistematik bir temkin payıdır ve sabit offset olarak kodlanabilir; büyükse")
    lines.append("ortada offset değil, model farkı vardır ve sabit sayı eklemek yanlış olur.")
    lines.append("")

    // Birleşik özet
    lines.append("## Tüm şehirler birleşik")
    lines.append("")
    let variants: [(title: String, useShafi: Bool)] = [
        ("Şafii ikindi", true),
        ("Hanefi ikindi", false)
    ]
    for variant in variants {
        lines.append("### \(variant.title)")
        lines.append("")
        lines.append("| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |")
        lines.append("|---|---|---|---|---|---|---|")
        for prayer in Prayer.allCases {
            var pooled: [Double] = []
            for city in cities {
                let source = variant.useShafi ? city.statsShafi : city.statsHanafi
                pooled.append(contentsOf: source[prayer]?.deltas ?? [])
            }
            let stats = pooled.isEmpty ? nil : PrayerStats(prayer: prayer, deltas: pooled)
            lines.append("| \(label(prayer)) \(statsRow(stats))")
        }
        lines.append("")
    }

    // Koordinat fit'i
    lines.append("## Fit edilen koordinatlar")
    lines.append("")
    lines.append("Coğrafi koordinat yalnızca aramanın başlangıç noktası; hesaplamada fit edilen")
    lines.append("değer kullanıldı. İkisi arasındaki fark küçükse yöntem kendini doğrulamış olur.")
    lines.append("")
    lines.append("| Şehir | Fit enlem | Fit boylam | Coğrafi enlem | Coğrafi boylam | Enlem farkı | Boylam farkı |")
    lines.append("|---|---|---|---|---|---|---|")
    for city in cities.sorted(by: { $0.name < $1.name }) {
        lines.append(
            "| \(city.name) | \(format(city.fittedLatitude, 3)) | \(format(city.fittedLongitude, 3)) "
            + "| \(format(city.seedLatitude, 3)) | \(format(city.seedLongitude, 3)) "
            + "| \(format(city.latitudeDrift, 3)) | \(format(city.longitudeDrift, 3)) |"
        )
    }
    lines.append("")

    // Şehir bazında
    lines.append("## Şehir bazında (Şafii ikindi)")
    lines.append("")
    for city in cities.sorted(by: { $0.name < $1.name }) {
        lines.append("### \(city.name) (`\(city.districtId)`) — \(city.dayCount) gün")
        lines.append("")
        lines.append("| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |")
        lines.append("|---|---|---|---|---|---|---|")
        for prayer in Prayer.allCases {
            lines.append("| \(label(prayer)) \(statsRow(city.statsShafi[prayer]))")
        }
        lines.append("")
    }

    return lines.joined(separator: "\n") + "\n"
}

// MARK: - Giriş noktası

let arguments = CommandLine.arguments
let repoRoot = URL(
    fileURLWithPath: arguments.count > 1 ? arguments[1] : FileManager.default.currentDirectoryPath
)
let mirrorRoot = repoRoot.appendingPathComponent("Reference/diyanet/mirror")
let outputURL = repoRoot.appendingPathComponent("Reference/diyanet/calibration-report.md")

guard let entries = try? FileManager.default.contentsOfDirectory(
    at: mirrorRoot, includingPropertiesForKeys: [.isDirectoryKey]
) else {
    FileHandle.standardError.write(
        Data("HATA: \(mirrorRoot.path) okunamadı.\n".utf8)
    )
    exit(1)
}

var reports: [CityReport] = []
for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDirectory),
          isDirectory.boolValue,
          entry.lastPathComponent != "places" else { continue }
    guard let city = loadCity(directory: entry) else {
        print("atlandı: \(entry.lastPathComponent) (kullanılabilir gün yok)")
        continue
    }
    let report = analyze(id: city.id, name: city.name, days: city.days)
    reports.append(report)
    let fajrMean = report.statsShafi[.fajr]?.meanValue ?? Double.nan
    print("\(report.name) (\(report.districtId)): \(report.dayCount) gün, "
          + "fit \(format(report.fittedLatitude, 3))/\(format(report.fittedLongitude, 3)), "
          + "imsak farkı ort \(format(fajrMean)) dk")
}

guard !reports.isEmpty else {
    FileHandle.standardError.write(Data("HATA: hiçbir şehir işlenemedi.\n".utf8))
    exit(1)
}

let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
formatter.timeZone = TimeZone(identifier: "UTC")
formatter.locale = Locale(identifier: "en_US_POSIX")

let markdown = buildReport(cities: reports, generatedAt: formatter.string(from: Date()))
do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
    print("\nRapor yazıldı: \(outputURL.path)")
} catch {
    FileHandle.standardError.write(Data("HATA: rapor yazılamadı → \(error)\n".utf8))
    exit(1)
}
