import Foundation

/// Parses the long Hijri date string Diyanet publishes alongside each day's prayer times
/// (the `HicriTarihUzun` field), e.g. `"12 Rebiülevvel 1448"`.
///
/// This lives in PrayerKit rather than in the generator tool for one reason: it is the single
/// riskiest step in turning Diyanet's calendar into data we ship. A month name silently
/// misread as the wrong month would move Ramazan. Here it is unit-tested; inside a
/// command-line tool it would not be.
///
/// The parser is deliberately **strict about failure and lenient about spelling**. It accepts
/// the same month written with or without Turkish diacritics (the mirror publishes
/// `"Rebiulahir"`, Diyanet's own site writes `"Rebiülahir"`), but it returns `nil` — never a
/// guess — for anything it does not recognise. The caller is expected to treat `nil` as a
/// hard error rather than skip the day.
public enum DiyanetHijriParsing {

    /// `"12 Rebiülevvel 1448"` → `HijriDate(year: 1448, month: 3, day: 12)`.
    /// Returns `nil` if the day, month name or year cannot be read with certainty.
    public static func hijriDate(fromLongText text: String) -> HijriDate? {
        // Split on any whitespace run; the mirror has been seen to use ordinary spaces, but
        // a non-breaking space in the source must not turn into a parse failure.
        let parts = text
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard parts.count == 3 else { return nil }

        guard let day = Int(parts[0]), (1...30).contains(day) else { return nil }
        guard let month = monthNumber(fromName: parts[1]) else { return nil }
        // No upper bound invented here: any positive year is accepted. The archive covers a
        // narrow window and an out-of-range check would only ever produce false failures.
        guard let year = Int(parts[2]), year > 0 else { return nil }

        return HijriDate(year: year, month: month, day: day)
    }

    /// `"Rebiülevvel"` / `"rebiulevvel"` / `"REBİÜLEVVEL"` → `3`. `nil` if unrecognised.
    public static func monthNumber(fromName name: String) -> Int? {
        let folded = fold(name)
        guard let index = foldedMonthNames.firstIndex(of: folded) else { return nil }
        return index + 1
    }

    /// Canonical folded spellings, in calendar order. Every entry is the result of running
    /// `fold` over the month's Turkish name, so comparison is spelling-insensitive.
    private static let foldedMonthNames: [String] = [
        "muharrem",
        "safer",
        "rebiulevvel",
        "rebiulahir",
        "cemaziyelevvel",
        "cemaziyelahir",
        "recep",
        "saban",
        "ramazan",
        "sevval",
        "zilkade",
        "zilhicce"
    ]

    /// Lowercases and strips Turkish diacritics, so `"Rebiülahir"` and `"Rebiulahir"` collapse
    /// to the same key.
    ///
    /// The mapping is written out by code point rather than using `lowercased()` plus
    /// `folding(options:)`. Turkish is exactly where those shortcuts break: `"İ".lowercased()`
    /// produces `"i"` followed by a combining dot above (U+0307), which then compares unequal
    /// to a plain `"i"` — a bug that would silently reject every month containing `İ`.
    static func fold(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            if let replacement = foldingMap[scalar.value] {
                result.append(replacement)
            } else if scalar.properties.isAlphabetic {
                // ASCII harfler için güvenli: Türkçe'ye özgü olmayan büyük harfler.
                result.append(Character(scalar).lowercased())
            }
            // Harf olmayan her şey (nokta, tire, boşluk kalıntısı) düşürülüyor.
        }
        return result
    }

    private static let foldingMap: [UInt32: Character] = [
        0x0131: "i", 0x0130: "i", 0x0049: "i", 0x0069: "i",   // ı İ I i
        0x015F: "s", 0x015E: "s",                             // ş Ş
        0x011F: "g", 0x011E: "g",                             // ğ Ğ
        0x00FC: "u", 0x00DC: "u",                             // ü Ü
        0x00F6: "o", 0x00D6: "o",                             // ö Ö
        0x00E7: "c", 0x00C7: "c",                             // ç Ç
        0x00E2: "a", 0x00C2: "a",                             // â Â
        0x00EE: "i", 0x00CE: "i",                             // î Î
        0x00FB: "u", 0x00DB: "u"                              // û Û
    ]
}
