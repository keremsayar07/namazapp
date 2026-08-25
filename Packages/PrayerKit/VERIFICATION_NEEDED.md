# Doğrulama için gereken veri — henüz eksik

Bu dosya, Faz 1'in "doğruluk doğrulaması" adımının neden tamamlanmadığını ve tamamlanması için
tam olarak neye ihtiyaç olduğunu belirtir. **Hiçbir tahmini/uydurma referans değer koda veya
testlere eklenmedi.**

## 1. Namaz vakti referans verisi

Denenen kaynaklar ve sonuçları:

- `namazvakitleri.diyanet.gov.tr` — otomatik erişim `robots.txt` tarafından engelleniyor; sayfa
  ayrıca vakitleri JavaScript ile sonradan yüklüyor (statik HTML'de sayı yok).
- `www.diyanet.gov.tr`, `vakithesaplama.diyanet.gov.tr` — otomatik erişim aynı şekilde engellendi
  / zaman aşımına uğradı.
- **`awqatsalah.diyanet.gov.tr`** — Diyanet'in **resmi** namaz vakti API'si bulundu
  (bkz. github.com/DinIsleriYuksekKurulu/AwqatSalah, Din İşleri Yüksek Kurulu'nun resmi GitHub
  hesabı). Ancak kullanıcı adı/şifre ile geliştirici kaydı gerektiriyor — bende böyle bir hesap yok.

### İhtiyaç duyulan

Aşağıdakilerden biri:

1. **(Önerilen)** `awqatsalah.diyanet.gov.tr` için ücretsiz geliştirici kaydı oluşturup elde
   ettiğiniz API kimlik bilgilerini (veya doğrudan aşağıdaki şehir/tarih kombinasyonları için
   API'den aldığınız JSON çıktısını) paylaşmanız — tek seferlik, tüm kombinasyonları kapsar.
2. `namazvakitleri.diyanet.gov.tr` üzerinden aşağıdaki şehir/tarih kombinasyonları için İmsak,
   Güneş, Öğle, İkindi, Akşam, Yatsı değerlerini kendinizin kopyalaması (12 veri noktası):

   | Şehir | Tarihler |
   |---|---|
   | İstanbul | 2026-03-20 (ekinoks), 2026-06-21 (yaz gündönümü), 2026-09-23 (ekinoks), 2026-12-21 (kış gündönümü) |
   | Ankara | aynı 4 tarih |
   | Gaziantep | aynı 4 tarih |

Veri geldiğinde `Tests/PrayerKitTests/DiyanetReferenceFixtures.swift` içine şehir, tarih,
kullanılan yöntem (`turkey`) ve Diyanet referansı (kaynak URL/ekran görüntüsü) açıkça belirtilerek
eklenecek ve ±1 dakika toleranslı testler yazılacak.

## 2. Hicri takvim referans verisi (Diyanet ↔ Umm al-Qura farkları)

`HijriDate` mimarisi hazır (`DiyanetHijriDateConverter`, bkz. `Hijri/`), Foundation'ın
`Calendar(identifier: .islamicUmmAlQura)` hesaplamasını temel alıyor ve üzerine Diyanet'in resmi
takviminin farklılaştığı belirli günler için bir "override" tablosu koyabiliyor. Bu tablo şu an
**boş** — çünkü Diyanet'in resmi ay başlangıcı tarihlerine (`vakithesaplama.diyanet.gov.tr/dinigunler.php`,
`www2.diyanet.gov.tr/.../HicridenMiladiye.aspx`) otomatik erişim aynı sebeplerle engellendi.

### İhtiyaç duyulan

2025-2027 için Diyanet'in resmi "Dini Günler" listesinden şu tarihlerin Hicri karşılıkları:

- Ramazan ayı başlangıcı (1 Ramazan)
- Ramazan Bayramı (1 Şevval)
- Kurban Bayramı (10 Zilhicce)
- Hicri Yılbaşı (1 Muharrem)

Bu 4 çapa nokta, yıl içindeki ay başlangıcı belirsizliklerinin büyük kısmını kapatar. Kaynak:
Diyanet'in kendi web sitesi, resmi basın açıklamaları veya Resmî Gazete'de yayımlanan dini
bayram tatili ilanları kabul edilebilir — haber sitelerinin "Diyanet'e göre" diye aktardığı
tarihler ikincil kaynak sayılır, birincil doğrulama için tercih edilmez.

## Bu arada ne yapıldı

- Hesaplama motoru, adhan-swift'in de kullandığı standart açı değerleriyle (İmsak 18°, Yatsı 17°)
  çalışıyor — bunlar Diyanet'e **yaklaşık**, ama dakika hassasiyetinde doğrulanmadı.
- `CalculationSettings.manualOffsetsMinutes` üzerinden her vakit için ince ayar (dakika bazında)
  yapılabiliyor — gerçek veri geldiğinde `turkey` metodunun varsayılan parametrelerini (özellikle
  Akşam/temkin offseti) buna göre güncelleyeceğiz.
- Testlerde şu an sadece "iç tutarlılık" doğrulanıyor (İmsak < Güneş < Öğle < İkindi < Akşam < Yatsı,
  vb.) — bu gerçek dakika hassasiyetini garanti etmez, sadece kaba hataları yakalar.
