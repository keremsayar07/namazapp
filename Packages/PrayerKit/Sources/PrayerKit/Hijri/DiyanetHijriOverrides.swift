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
// Bu çalışmada 36 gün incelendi, 12 ilçe karşılaştırıldı,
// 0 günde fark bulundu.

import Foundation

/// Diyanet'in resmi takviminin Ümmü'l-Kura tablosundan ayrıldığı, doğrulanmış günler.
public enum DiyanetHijriOverrides {

    /// Miladi gün → Diyanet'in o gün için yayımladığı hicri tarih.
    ///
    /// Kapsanan aralıkta Ümmü'l-Kura ile Diyanet arasında fark bulunmadı. Bu, hiç
    /// ayrılmayacakları anlamına gelmiyor: ayrışma ay başlarında yoğunlaşıyor ve
    /// pencere dar. Arşiv genişledikçe tablo dolabilir.
    public static let table: [GregorianDay: HijriDate] = [:]

    /// Arşivin kapsadığı ilk ve son miladi gün. Bu aralığın dışındaki tarihlerde
    /// `DiyanetHijriDateConverter` doğrulanmamış bir tahmin (Ümmü'l-Kura) döndürür —
    /// arayüzün bunu kullanıcıya söyleyebilmesi için aralık burada duruyor.
    ///
    /// `...` çevresinde boşluk YOK: boşluklu yazımda Swift'in operatörü sonek mi ek mi
    /// çözmesi satır sonuyla birlikte belirsizleşebiliyor.
    public static let coverage: ClosedRange<GregorianDay>? =
        GregorianDay(year: 2026, month: 8, day: 18)...GregorianDay(year: 2026, month: 9, day: 22)

    /// Tabloyu üreten çalışmanın kaç günlük veriyi incelediği. Kapsamın ne kadar dar
    /// olduğunu görünür kılmak için — sıfır olması "fark yok" değil, "veri yok" demektir.
    public static let examinedDayCount: Int = 36
}
