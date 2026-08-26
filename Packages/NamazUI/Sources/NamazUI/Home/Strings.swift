import Foundation

/// Paketin kendi kaynak paketinden yerelleştirilmiş metin okur.
///
/// Değişken sayıda argüman alan tek bir fonksiyon yerine ayrı imzalar var: `L("x")`
/// çağrısı variadic bir aşırı yükle belirsiz hâle gelirdi. Ayrıca argümanlı biçimlerde
/// `%1$@` sıralı yer tutucuları kullanılıyor — Türkçe ve İngilizce'de sözcük sırası
/// farklı olabildiği için çevirmenin sırayı değiştirebilmesi gerekiyor.
enum L {
    static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }

    static func t(_ key: String, _ first: String) -> String {
        String(format: t(key), first)
    }

    static func t(_ key: String, _ first: String, _ second: String) -> String {
        String(format: t(key), first, second)
    }

    static func t(_ key: String, _ first: String, _ second: String, _ third: String) -> String {
        String(format: t(key), first, second, third)
    }
}
