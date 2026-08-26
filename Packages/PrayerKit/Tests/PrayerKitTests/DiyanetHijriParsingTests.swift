import Foundation
import XCTest
@testable import PrayerKit

/// `DiyanetHijriParsing` — Diyanet'in `HicriTarihUzun` alanını okuyan ayrıştırıcı.
///
/// Bu, Diyanet takvimini veriye çevirme zincirindeki en riskli halka: yanlış okunan bir ay
/// adı Ramazan'ı kaydırır ve bu, çalışma zamanında hiçbir uyarı vermeden olur. O yüzden
/// testler yalnızca "çalışıyor mu"yu değil, **yanlış girdide susmadığını** da kontrol ediyor.
final class DiyanetHijriParsingTests: XCTestCase {

    // MARK: - Ay adları

    func test_allTwelveMonthsAreRecognised() {
        // Aynada aksansız yazım görüldü ("Rebiulahir"); Diyanet'in kendi sitesi aksanlı
        // yazıyor ("Rebiülahir"). İkisi de aynı sayıya çıkmalı.
        let plain = [
            "Muharrem", "Safer", "Rebiulevvel", "Rebiulahir",
            "Cemaziyelevvel", "Cemaziyelahir", "Recep", "Saban",
            "Ramazan", "Sevval", "Zilkade", "Zilhicce"
        ]
        let accented = [
            "Muharrem", "Safer", "Rebiülevvel", "Rebiülahir",
            "Cemaziyelevvel", "Cemaziyelahir", "Recep", "Şaban",
            "Ramazan", "Şevval", "Zilkade", "Zilhicce"
        ]

        for (index, name) in plain.enumerated() {
            XCTAssertEqual(DiyanetHijriParsing.monthNumber(fromName: name), index + 1, name)
        }
        for (index, name) in accented.enumerated() {
            XCTAssertEqual(DiyanetHijriParsing.monthNumber(fromName: name), index + 1, name)
        }
    }

    func test_monthNameIsCaseInsensitiveIncludingTurkishI() {
        // Türkçe'nin klasik tuzağı: "İ".lowercased() → "i" + U+0307 (birleşen nokta).
        // Bu, düz bir "i" ile eşit ÇIKMAZ. Katlama haritası tam bunun için var.
        XCTAssertEqual(DiyanetHijriParsing.monthNumber(fromName: "ZİLHİCCE"), 12)
        XCTAssertEqual(DiyanetHijriParsing.monthNumber(fromName: "zilhicce"), 12)
        XCTAssertEqual(DiyanetHijriParsing.monthNumber(fromName: "REBİÜLEVVEL"), 3)
        XCTAssertEqual(DiyanetHijriParsing.monthNumber(fromName: "ŞABAN"), 8)
    }

    func test_unknownMonthReturnsNil() {
        // Tahmin etmiyor. Yakın yazımlar da dahil: "Rebiul" bir ay adı değil.
        XCTAssertNil(DiyanetHijriParsing.monthNumber(fromName: "Rebiul"))
        XCTAssertNil(DiyanetHijriParsing.monthNumber(fromName: "Ocak"))
        XCTAssertNil(DiyanetHijriParsing.monthNumber(fromName: ""))
        XCTAssertNil(DiyanetHijriParsing.monthNumber(fromName: "3"))
    }

    // MARK: - Tam tarih

    func test_parsesTheFormatSeenInTheArchive() {
        // 12.09.2026 → "1 Rebiulahir 1448". Bu gün PROVENANCE.md'de Diyanet'in kendi
        // sitesine karşı elle doğrulandı; hicri ay sınırı olduğu için özellikle seçilmişti.
        let parsed = DiyanetHijriParsing.hijriDate(fromLongText: "1 Rebiulahir 1448")
        XCTAssertEqual(parsed, HijriDate(year: 1448, month: 4, day: 1))
    }

    func test_parsesAccentedForm() {
        let parsed = DiyanetHijriParsing.hijriDate(fromLongText: "12 Rebiülevvel 1448")
        XCTAssertEqual(parsed, HijriDate(year: 1448, month: 3, day: 12))
    }

    func test_toleratesSurroundingAndRepeatedWhitespace() {
        // Kaynaktaki fazladan bir boşluk, ayrıştırma hatasına dönüşmemeli.
        let parsed = DiyanetHijriParsing.hijriDate(fromLongText: "  30   Ramazan  1447 ")
        XCTAssertEqual(parsed, HijriDate(year: 1447, month: 9, day: 30))
    }

    func test_rejectsMalformedInput() {
        // Hepsi nil dönmeli: hiçbiri "yakın tahmin"e çevrilmemeli.
        let bad = [
            "",                       // boş
            "Rebiulahir 1448",        // gün yok
            "1 Rebiulahir",           // yıl yok
            "1 Rebiulahir 1448 xx",   // fazladan alan
            "1 Ocak 1448",            // hicri olmayan ay
            "abc Rebiulahir 1448",    // gün sayı değil
            "1 Rebiulahir abc",       // yıl sayı değil
            "0 Rebiulahir 1448",      // gün aralık dışı
            "31 Rebiulahir 1448",     // hicri ay 30 günü geçmez
            "1 Rebiulahir 0"          // yıl pozitif değil
        ]
        for text in bad {
            XCTAssertNil(
                DiyanetHijriParsing.hijriDate(fromLongText: text),
                "\"\(text)\" ayrıştırılmamalıydı"
            )
        }
    }

    // MARK: - Düzeltme tablosu

    func test_generatedTableIsSelfConsistent() {
        // Tablo üretilmiş bir dosyadan geliyor; içeriği burada doğrulanamaz ama biçimi
        // doğrulanabilir. Bozuk bir üretim çalışması bu testten geçemez.
        for (gregorian, hijri) in DiyanetHijriOverrides.table {
            XCTAssertTrue((1...12).contains(gregorian.month), "\(gregorian)")
            XCTAssertTrue((1...31).contains(gregorian.day), "\(gregorian)")
            XCTAssertTrue((1...12).contains(hijri.month), "\(gregorian)")
            XCTAssertTrue((1...30).contains(hijri.day), "\(gregorian)")
            XCTAssertGreaterThan(hijri.year, 1400, "\(gregorian)")
        }
    }

    func test_everyOverrideFallsInsideTheDeclaredCoverage() {
        // Kapsam dışında bir düzeltme, tablonun kapsam bilgisiyle uyuşmadığı anlamına gelir
        // ve `isVerified` yalan söylüyor demektir.
        guard let coverage = DiyanetHijriOverrides.coverage else {
            XCTAssertTrue(DiyanetHijriOverrides.table.isEmpty, "Kapsam yokken tablo dolu olamaz")
            return
        }
        for gregorian in DiyanetHijriOverrides.table.keys {
            XCTAssertTrue(coverage.contains(gregorian), "\(gregorian) kapsam dışında")
        }
    }

    func test_converterAppliesAnOverride() {
        // Üretilmiş tablodan bağımsız olarak mekanizmanın kendisi: verilen bir gün için
        // tablodaki değer taban dönüştürücüyü geçmeli.
        let day = GregorianDay(year: 2026, month: 9, day: 12)
        let forced = HijriDate(year: 1448, month: 4, day: 1)
        let converter = DiyanetHijriDateConverter(
            overrides: [day: forced],
            coverage: day...day
        )

        let anchor = utcNoon(2026, 9, 12)
        XCTAssertEqual(converter.hijriDate(from: anchor), forced)
        XCTAssertTrue(converter.isVerified(anchor))
    }

    func test_converterFallsBackOutsideTheTable() {
        let day = GregorianDay(year: 2026, month: 9, day: 12)
        let converter = DiyanetHijriDateConverter(
            overrides: [day: HijriDate(year: 1448, month: 4, day: 1)],
            coverage: day...day
        )

        let other = utcNoon(2026, 9, 20)
        XCTAssertEqual(
            converter.hijriDate(from: other),
            UmmAlQuraHijriDateConverter().hijriDate(from: other)
        )
        // Kapsam dışı: cevap yine de veriliyor ama "doğrulanmış" denmiyor.
        XCTAssertFalse(converter.isVerified(other))
    }

    func test_gregorianDayOrdersChronologically() {
        XCTAssertLessThan(
            GregorianDay(year: 2026, month: 8, day: 31),
            GregorianDay(year: 2026, month: 9, day: 1)
        )
        XCTAssertLessThan(
            GregorianDay(year: 2025, month: 12, day: 31),
            GregorianDay(year: 2026, month: 1, day: 1)
        )
        XCTAssertEqual(GregorianDay(year: 2026, month: 9, day: 5).description, "2026-09-05")
    }
}
