import Foundation
import PrayerKit

// Diyanet ayna arşivindeki `HicriTarihUzun` alanlarından hicri düzeltme tablosunu üretir.
//
// Neden bu araç var
// -----------------
// Uygulama hicri tarihi Ümmü'l-Kura tablosundan alıyor. Ümmü'l-Kura günlerin büyük
// çoğunluğunda Diyanet'le aynı sonucu veriyor ama AY BAŞLARINDA bir gün ayrılabiliyor —
// yani tam olarak Ramazan'ın ve bayramların başladığı yerde. Kullanıcının en çok güvendiği
// tarihler, hesabın en zayıf olduğu tarihler.
//
// Çözüm, Diyanet'in kendi yayımladığı hicri tarihi veri olarak taşımak. Ama elle yazılmış
// bir tablo, tam da kaçındığımız şey olurdu: doğrulanmamış referans verisi. Bu araç tabloyu
// arşivden ÜRETİYOR ve üretemediği hiçbir günü tahmin etmiyor.
//
// Neden Swift, neden CI'da
// ------------------------
// Karşılaştırma `UmmAlQuraHijriDateConverter`'ın kendisiyle yapılmalı. Onu Python'a port
// etmek, "port ettiğim şeyle farkı" ölçmek olurdu; üstelik Apple'ın Ümmü'l-Kura verisi
// ICU'dan geliyor ve basit bir tablo algoritmasıyla birebir aynı değil. Bu araç gerçek
// dönüştürücüyü çağırıyor, dolayısıyla ürettiği tablo uygulamanın gerçekten göreceği farkı
// yansıtıyor.
//
// Sessiz başarısızlık yok
// -----------------------
// Üç durumda araç kırmızı biter ve dosyayı YAZMAZ:
//   1. Bir `HicriTarihUzun` alanı ayrıştırılamazsa (bilinmeyen ay adı, bozuk biçim),
//   2. Aynı miladi gün için iki ilçe farklı hicri tarih bildirirse,
//   3. Arşiv hiç okunamazsa.
// Üçü de "veriyi anlamıyoruz" demek. Anlamadığımız veriden tablo üretmek, uydurmakla
// aynı kapıya çıkar.

// MARK: - Girdi modelleri

struct MirrorMonthFile: Decodable {
    let province: String?
    let districtId: String
    let days: [String: MirrorDay]
}

struct MirrorDay: Decodable {
    let hicriTarihUzun: String?

    enum CodingKeys: String, CodingKey {
        case hicriTarihUzun = "HicriTarihUzun"
    }
}

// MARK: - Sorunlar

/// Ayrıştırılamayan bir kayıt. Atlanmıyor, biriktiriliyor ve rapora yazılıyor.
struct ParseFailure {
    let districtId: String
    let districtName: String
    let iso: String
    let rawText: String
}

/// Aynı gün için farklı hicri tarih bildiren ilçeler. Aynanın tek bir kaynaktan geldiği
/// varsayımının testi: Diyanet tüm Türkiye için tek bir dini takvim yayımlıyor, dolayısıyla
/// ilçeler arasında fark ÇIKMAMALI. Çıkarsa varsayım yanlış demektir ve tabloyu
/// üretemeyiz.
struct Disagreement {
    let iso: String
    /// Hicri tarih → o tarihi bildiren ilçe adları.
    let readings: [String: [String]]
}

// MARK: - Yardımcılar

/// ISO gününü `GregorianDay`'e çevirir. Ayrıştırma tamamen dizgisel: `Date`'e uğramıyor,
/// dolayısıyla saat dilimi hiçbir aşamada devreye girmiyor.
func gregorianDay(iso: String) -> GregorianDay? {
    let parts = iso.split(separator: "-")
    guard parts.count == 3,
          let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
          (1...12).contains(month), (1...31).contains(day)
    else { return nil }
    return GregorianDay(year: year, month: month, day: day)
}

/// O takvim gününü temsil eden, 12:00 UTC'ye sabitlenmiş tarih.
///
/// Öğle vakti seçildi ki hangi saat diliminden bakılırsa bakılsın gün değişmesin — gece
/// yarısına yakın bir an, UTC'de bir önceki güne düşebilirdi.
func utcNoon(_ day: GregorianDay) -> Date? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    var components = DateComponents()
    components.year = day.year
    components.month = day.month
    components.day = day.day
    components.hour = 12
    return calendar.date(from: components)
}

func write(_ text: String) {
    FileHandle.standardOutput.write(Data(text.utf8))
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("HATA: \(message)\n".utf8))
    exit(1)
}

// MARK: - Arşivi oku

let arguments = CommandLine.arguments
let repoRoot = URL(
    fileURLWithPath: arguments.count > 1 ? arguments[1] : FileManager.default.currentDirectoryPath
)
let mirrorRoot = repoRoot.appendingPathComponent("Reference/diyanet/mirror")

guard let entries = try? FileManager.default.contentsOfDirectory(
    at: mirrorRoot, includingPropertiesForKeys: [.isDirectoryKey]
) else {
    fail("\(mirrorRoot.path) okunamadı.")
}

/// ISO gün → (hicri tarih → o tarihi bildiren ilçe adları)
var readingsByDay: [String: [HijriDate: [String]]] = [:]
var parseFailures: [ParseFailure] = []
var districtNames: Set<String> = []
var recordCount = 0

let decoder = JSONDecoder()

for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDirectory),
          isDirectory.boolValue else { continue }

    let files = (try? FileManager.default.contentsOfDirectory(
        at: entry, includingPropertiesForKeys: nil
    )) ?? []

    for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    where file.pathExtension == "json" {
        guard let data = try? Data(contentsOf: file),
              let month = try? decoder.decode(MirrorMonthFile.self, from: data) else { continue }

        // İl adı varsa onu kullan; yoksa ilçe kimliği yeterli bir kimliktir.
        let province = month.province ?? ""
        let name = province.isEmpty ? month.districtId : province
        districtNames.insert(name)

        for (iso, record) in month.days {
            guard gregorianDay(iso: iso) != nil else { continue }
            // Hicri alanı olmayan kayıt bir hata değil: eski dökümler bu alanı taşımıyor
            // olabilir. Sadece bu araç için bilgi taşımıyor.
            guard let raw = record.hicriTarihUzun, !raw.isEmpty else { continue }
            recordCount += 1

            guard let hijri = DiyanetHijriParsing.hijriDate(fromLongText: raw) else {
                parseFailures.append(ParseFailure(
                    districtId: month.districtId, districtName: name, iso: iso, rawText: raw
                ))
                continue
            }
            readingsByDay[iso, default: [:]][hijri, default: []].append(name)
        }
    }
}

guard !readingsByDay.isEmpty || !parseFailures.isEmpty else {
    fail("Arşivde hiç `HicriTarihUzun` alanı bulunamadı. Ayna dökümü güncel mi?")
}

// MARK: - Tutarlılık

if !parseFailures.isEmpty {
    let sample = parseFailures.prefix(10)
        .map { "  \($0.iso) · \($0.districtName) · \"\($0.rawText)\"" }
        .joined(separator: "\n")
    fail("""
    \(parseFailures.count) kayıttaki hicri tarih ayrıştırılamadı. Tablo üretilmedi.
    Ay adı listesi (`DiyanetHijriParsing`) eksik ya da aynanın biçimi değişmiş olabilir.
    İlk örnekler:
    \(sample)
    """)
}

var disagreements: [Disagreement] = []
/// ISO gün → üzerinde uzlaşılan hicri tarih.
var agreed: [String: HijriDate] = [:]

for (iso, readings) in readingsByDay {
    if readings.count == 1, let only = readings.first {
        agreed[iso] = only.key
    } else {
        var described: [String: [String]] = [:]
        for (hijri, districts) in readings {
            described["\(hijri.day)/\(hijri.month)/\(hijri.year)"] = districts.sorted()
        }
        disagreements.append(Disagreement(iso: iso, readings: described))
    }
}

if !disagreements.isEmpty {
    let sample = disagreements.sorted { $0.iso < $1.iso }.prefix(10)
        .map { item in
            let detail = item.readings
                .map { "\($0.key): \($0.value.joined(separator: ", "))" }
                .sorted()
                .joined(separator: " | ")
            return "  \(item.iso) → \(detail)"
        }
        .joined(separator: "\n")
    fail("""
    \(disagreements.count) günde ilçeler farklı hicri tarih bildiriyor. Tablo üretilmedi.
    Diyanet tüm Türkiye için tek bir dini takvim yayımlar; fark çıkması aynanın tek
    kaynaktan gelmediği anlamına gelir ve bu veriden tablo üretilemez.
    İlk örnekler:
    \(sample)
    """)
}

// MARK: - Ümmü'l-Kura ile karşılaştır

let base = UmmAlQuraHijriDateConverter()
var overrides: [GregorianDay: HijriDate] = [:]
var days: [GregorianDay] = []

for (iso, hijri) in agreed {
    guard let day = gregorianDay(iso: iso), let anchor = utcNoon(day) else { continue }
    days.append(day)
    let computed = base.hijriDate(from: anchor)
    guard computed != hijri else { continue }
    overrides[day] = hijri
}

days.sort()
guard let first = days.first, let last = days.last else {
    fail("Karşılaştırılabilir gün kalmadı.")
}

// MARK: - Swift kaynağını yaz

let sortedOverrides = overrides.sorted { $0.key < $1.key }
let entriesText: String = sortedOverrides.isEmpty
    ? "        // Kapsanan aralıkta Ümmü'l-Kura ile Diyanet arasında fark bulunmadı."
    : sortedOverrides.map { day, hijri in
        "        GregorianDay(year: \(day.year), month: \(day.month), day: \(day.day)): "
            + "HijriDate(year: \(hijri.year), month: \(hijri.month), day: \(hijri.day)),"
            + "  // \(day)"
    }.joined(separator: "\n")

let source = """
// ÜRETİLMİŞ DOSYA — elle düzenlemeyin.
//
// `prayerkit-hijri-table` aracı üretir; `Reference/diyanet/mirror` altındaki Diyanet ayna
// arşivinin `HicriTarihUzun` alanlarından okunur. Yeniden üretmek için:
//
//     swift run -c release prayerkit-hijri-table <repo-kökü>
//
// GitHub Actions'ta `Hicri Düzeltme Tablosu` iş akışı bunu her arşiv güncellemesinde
// çalıştırıp değişiklik varsa commit'liyor.
//
// Tablo yalnızca Diyanet'in takviminin Ümmü'l-Kura'dan AYRILDIĞI günleri içerir; ikisinin
// aynı olduğu günlerde taban dönüştürücü zaten doğru cevabı veriyor.
//
// Anahtarlar Diyanet'in yayımladığı takvim günüdür (Türkiye yerel günü). `DiyanetHijriDateConverter`
// aramayı UTC gün alanlarıyla yapıyor; Türkiye UTC+3 olduğu ve arama noktası yerel öğle
// olduğu için ikisi çakışıyor.
//
// Bu çalışmada \(agreed.count) gün incelendi, \(districtNames.count) ilçe karşılaştırıldı,
// \(overrides.count) günde fark bulundu.

import Foundation

/// Diyanet'in resmi takviminin Ümmü'l-Kura tablosundan ayrıldığı, doğrulanmış günler.
public enum DiyanetHijriOverrides {

    /// Miladi gün → Diyanet'in o gün için yayımladığı hicri tarih.
    public static let table: [GregorianDay: HijriDate] = [
\(entriesText)
    ]

    /// Arşivin kapsadığı ilk ve son miladi gün. Bu aralığın dışındaki tarihlerde
    /// `DiyanetHijriDateConverter` doğrulanmamış bir tahmin (Ümmü'l-Kura) döndürür —
    /// arayüzün bunu kullanıcıya söyleyebilmesi için aralık burada duruyor.
    public static let coverage: ClosedRange<GregorianDay>? =
        GregorianDay(year: \(first.year), month: \(first.month), day: \(first.day))
        ... GregorianDay(year: \(last.year), month: \(last.month), day: \(last.day))

    /// Tabloyu üreten çalışmanın kaç günlük veriyi incelediği. Kapsamın ne kadar dar
    /// olduğunu görünür kılmak için — sıfır olması "fark yok" değil, "veri yok" demektir.
    public static let examinedDayCount: Int = \(agreed.count)
}

"""

let outputURL = repoRoot.appendingPathComponent(
    "Packages/PrayerKit/Sources/PrayerKit/Hijri/DiyanetHijriOverrides.swift"
)
do {
    try source.write(to: outputURL, atomically: true, encoding: .utf8)
} catch {
    fail("Kaynak dosya yazılamadı: \(error)")
}

// MARK: - Rapor

var report: [String] = []
report.append("# Hicri düzeltme tablosu")
report.append("")
report.append("Bu dosya `prayerkit-hijri-table` tarafından üretildi; elle düzenlemeyin.")
report.append("")
report.append("## Kapsam")
report.append("")
report.append("| Ölçü | Değer |")
report.append("|---|---|")
report.append("| İncelenen gün | \(agreed.count) |")
report.append("| Karşılaştırılan kayıt | \(recordCount) |")
report.append("| İlçe | \(districtNames.count) |")
report.append("| Aralık | \(first) – \(last) |")
report.append("| Ümmü'l-Kura'dan farklı gün | \(overrides.count) |")
report.append("")

if sortedOverrides.isEmpty {
    report.append("Kapsanan aralıkta iki takvim hiç ayrılmadı. Bu, ayrılmayacakları anlamına")
    report.append("**gelmiyor**: ayrışma ay başlarında yoğunlaşıyor ve bu pencere yalnızca")
    report.append("\(agreed.count) gün. Arşiv genişledikçe tablo dolabilir.")
} else {
    report.append("## Farklı günler")
    report.append("")
    report.append("| Miladi | Diyanet | Ümmü'l-Kura |")
    report.append("|---|---|---|")
    for (day, hijri) in sortedOverrides {
        let computed = utcNoon(day).map { base.hijriDate(from: $0) }
        let computedText = computed.map { "\($0.day).\($0.month).\($0.year)" } ?? "—"
        report.append("| \(day) | \(hijri.day).\(hijri.month).\(hijri.year) | \(computedText) |")
    }
}

report.append("")
report.append("## Yöntem")
report.append("")
report.append("Her miladi gün için arşivdeki tüm ilçelerin `HicriTarihUzun` alanı okunuyor ve")
report.append("hepsinin aynı hicri tarihi bildirdiği doğrulanıyor — Diyanet tüm Türkiye için tek")
report.append("bir dini takvim yayımladığı için fark çıkmamalı. Uzlaşılan tarih, uygulamanın")
report.append("kendi `UmmAlQuraHijriDateConverter`'ıyla karşılaştırılıyor ve yalnızca farklı olan")
report.append("günler tabloya yazılıyor.")
report.append("")
report.append("Ayrıştırılamayan tek bir kayıt ya da ilçeler arası tek bir uyuşmazlık, aracın")
report.append("kırmızı bitmesine ve tablonun hiç yazılmamasına yol açar. Anlaşılmayan veriden")
report.append("tablo üretmek, uydurmakla aynı şey olurdu.")
report.append("")
report.append("- Kaynak: `Reference/diyanet/mirror` — bkz. `Tools/diyanet_reference/PROVENANCE.md`")
report.append("")

let reportURL = repoRoot.appendingPathComponent("Reference/diyanet/hijri-report.md")
try? FileManager.default.createDirectory(
    at: reportURL.deletingLastPathComponent(), withIntermediateDirectories: true
)
try? report.joined(separator: "\n").write(to: reportURL, atomically: true, encoding: .utf8)

write("""
Hicri tablo üretildi.
  İncelenen gün : \(agreed.count)
  İlçe          : \(districtNames.count)
  Aralık        : \(first) – \(last)
  Farklı gün    : \(overrides.count)
  Kaynak dosya  : \(outputURL.path)
  Rapor         : \(reportURL.path)

""")
