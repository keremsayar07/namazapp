# Doğrulama verisi — durum ve otomatik toplama planı

Bu dosya, PrayerKit'in "doğruluk doğrulaması" adımının nerede durduğunu ve nasıl
tamamlanacağını belirtir. **Hiçbir tahmini/uydurma referans değer koda veya testlere
eklenmedi ve eklenmeyecek.**

## Bulunan resmi kaynak

Diyanet İşleri Başkanlığı Din İşleri Yüksek Kurulu'nun **resmi REST servisi**:
`https://awqatsalah.diyanet.gov.tr` (referans uygulama: Kurul'un resmi GitHub hesabı,
`github.com/DinIsleriYuksekKurulu/AwqatSalah`).

Diğer Diyanet alan adları (`namazvakitleri.diyanet.gov.tr`, `vakithesaplama.diyanet.gov.tr`,
`www.diyanet.gov.tr`) otomatik erişime `robots.txt` ile kapalı ve vakitleri JavaScript ile
yüklüyor — bu yüzden programatik olarak kullanılamıyor. Resmi API tek uygulanabilir yol.

### Servisin bize verdikleri

| Endpoint | Ne veriyor | Neyi doğruluyor |
|---|---|---|
| `GET /api/PrayerTime/Monthly/{cityId}` | Bir ayın tamamı: `fajr`, `sunrise`, `dhuhr`, `asr`, `maghrib`, `isha` | Hesaplama motorunun dakika hassasiyeti |
| aynı yanıt | `hijriDateShort`, `hijriDateLong` (her gün için) | **Diyanet'in resmi hicri tarihi** — override tablosunun kaynağı |
| `GET /api/Place/CityDetail/{cityId}` | Kıble açısı, Kâbe uzaklığı | `QiblaMath` çıktısı |
| `GET /api/PrayerTime/Ramadan/{cityId}` | Ramazan imsakiyesi | 1 Ramazan çapası |
| `GET /api/PrayerTime/Eid/{cityId}` | Bayram namazı vakitleri | 1 Şevval / 10 Zilhicce çapaları |

Hicri tarihin her günlük kayıtta gelmesi, ikinci bir veri toplama işine gerek bırakmıyor:
namaz vakti verisiyle birlikte hicri takvim verisi de aynı istekte geliyor.

### İki kısıt ve bunlara verilen cevap

1. **`Monthly` parametre almıyor** — yalnızca içinde bulunulan ayı döndürüyor. Geçmiş veya
   gelecek bir ay çekilemiyor.
2. **Kota**: standart rolde endpoint başına günde 5 istek (geliştirici rolünde 100).

Çözüm: `Tools/diyanet_reference/fetch.py` + `.github/workflows/diyanet-reference.yml`.
İş her gün çalışır, o ay için eksik şehirleri tamamlar, tamamlandığında hiç istek harcamadan
çıkar, ay değiştiğinde yeni ayı toplamaya başlar. Mevsimsel kapsama kendiliğinden birikir;
kimsenin elle veri girmesi gerekmez.

## İkinci kaynak: açık ayna (kimlik bilgisi beklemeden)

`*.diyanet.gov.tr` alan adları yurt dışı IP'lerden düzenli olarak zaman aşımına uğruyor —
GitHub Actions koşucuları da yurt dışında olduğu için resmi servise erişim, kimlik bilgisi
gelse bile garanti değil. Bu yüzden ikinci bir yol kuruldu: `ezanvakti.emushaf.net`,
Diyanet'in vakitlerini yeniden yayımlayan açık bir ayna. Kimlik bilgisi ve kota yok,
aynı hicri tarih ve kıble saati alanlarını içeriyor, ilçe kimlikleri Diyanet'inkilerle aynı.

Bu **ikincil** bir kaynak. Kullanım koşulu ve elle doğrulama adımı:
`Tools/diyanet_reference/PROVENANCE.md`.

## Şu anki durum

- [x] Resmi kaynak tespit edildi, endpoint'leri ve alan adları doğrulandı
- [x] Resmi API için otomatik toplayıcı ve GitHub Actions işi yazıldı
- [x] Kimlik bilgisi beklemeden çalışan ayna toplayıcısı yazıldı (12 ilçe)
- [ ] **Ayna verisinin Diyanet sitesine karşı elle doğrulanması** (~10 dk, `PROVENANCE.md`)
- [ ] **Diyanet'ten API kimlik bilgisi alınması** (bkz. `Tools/diyanet_reference/README.md`)
- [ ] İlk ayın verisi toplandıktan sonra `turkey` metodunun parametrelerinin kalibrasyonu
- [ ] `Tests/PrayerKitTests/DiyanetReferenceFixtures.swift` içindeki boş dizinin toplanan
      ham JSON'lardan üretilmesi ve ±1 dakika toleranslı testlerin yazılması
- [ ] `DiyanetHijriDateConverter` override tablosunun `hijriDateShort` alanlarından üretilmesi

## Kalibrasyon neyi düzeltecek

Motor şu an standart açı değerleriyle çalışıyor (İmsak 18°, Yatsı 17°) ve
`CalculationMethod.turkey` içinde `maghribOffsetMinutes = 0` — yani Diyanet'in uyguladığı
**temkin** payları henüz uygulanmıyor, çünkü gerçek değerleri doğrulanmadan yazmak tam olarak
kaçındığımız şey olurdu. Gerçek veri geldiğinde her vakit için sistematik fark ölçülecek ve
`turkey` preset'inin parametreleri buna göre güncellenecek.

O zamana kadar testler yalnızca **iç tutarlılık** doğruluyor (vakitlerin sırası, determinizm,
Hanefi ikindisinin Şafii'den erken olmaması, kıble açısının makul aralıkta olması). Bu, kaba
hataları yakalar — nitekim Tromsø testi gerçek bir sıralama hatasını yakaladı — ama dakika
hassasiyetini garanti etmez.
