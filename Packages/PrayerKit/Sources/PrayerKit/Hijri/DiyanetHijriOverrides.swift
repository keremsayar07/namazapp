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
// aynı olduğu günler için giriş yazmaya gerek yok, taban dönüştürücü zaten doğru cevabı
// veriyor.
//
// Bu dosya arşiv boşken de derlenebilsin diye boş bir tabloyla başlıyor. Boş tabloyla
// `DiyanetHijriDateConverter`, `UmmAlQuraHijriDateConverter` ile birebir aynı davranır —
// yani her koşulda güvenlidir, sadece henüz Diyanet'e göre düzeltilmemiştir.

import Foundation

/// Diyanet'in resmi takviminin Ümmü'l-Kura tablosundan ayrıldığı, doğrulanmış günler.
public enum DiyanetHijriOverrides {

    /// Miladi gün → Diyanet'in o gün için yayımladığı hicri tarih.
    public static let table: [GregorianDay: HijriDate] = [:]

    /// Arşivin kapsadığı ilk ve son miladi gün. Bu aralığın dışındaki tarihlerde
    /// `DiyanetHijriDateConverter` doğrulanmamış bir tahmin (Ümmü'l-Kura) döndürür —
    /// arayüzün bunu kullanıcıya söyleyebilmesi için aralık burada duruyor.
    public static let coverage: ClosedRange<GregorianDay>? = nil

    /// Tabloyu üreten çalışmanın kaç günlük veriyi incelediği. Kapsamın ne kadar dar
    /// olduğunu görünür kılmak için — sıfır olması "fark yok" değil, "veri yok" demektir.
    public static let examinedDayCount: Int = 0
}
