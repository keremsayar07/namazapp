# Verinin kaynağı ve doğrulama durumu

Kuralımız net: **tahmini veya uydurma referans verisi kullanılmaz.** Bu dosya, elimizdeki
verinin nereden geldiğini ve hangi aşamada "Diyanet doğrulamalı" sayılacağını kayda geçirir.

## İki kaynak, iki güven seviyesi

| Kaynak | Betik | Kimlik bilgisi | Güven |
|---|---|---|---|
| `awqatsalah.diyanet.gov.tr` — Diyanet'in resmi REST servisi | `fetch.py` | Gerekli (başvuru ile) | **Birincil** |
| `ezanvakti.emushaf.net` — Diyanet vakitlerini yeniden yayımlayan açık ayna | `fetch_mirror.py` | Gerekmiyor | **İkincil** |

Ayna bugün çalıştığı için veri toplamaya oradan başlıyoruz. Resmi servisin kimlik bilgisi
geldiğinde `fetch.py` devreye girer ve aynı günler için birincil kayıtlar da birikmeye başlar;
iki kaynak çakışırsa birincil kazanır.

### Aynanın Diyanet kaynaklı olduğuna dair göstergeler

- İlçe kimlikleri Diyanet'in kendi site adresleriyle birebir aynı: İSTANBUL = `9541`,
  ki bu da `namazvakitleri.diyanet.gov.tr/tr-TR/9541/...` adresinin kimliği.
- Yanıttaki `AyinSekliURL` alanı doğrudan `namazvakti.diyanet.gov.tr/images/...` adreslerini
  gösteriyor — kayıtlar Diyanet'in kendi servisinden geçiyor.
- Alan adları Diyanet'in kendi terminolojisi: `Imsak`, `Gunes`, `Ogle`, `Ikindi`, `Aksam`,
  `Yatsi`, `KibleSaati`, `HicriTarihKisa`, `HicriTarihUzun`.

Bunlar güçlü göstergeler, ama **kanıt değil**. Aradaki katman bir gün veriyi değiştirebilir
ya da eskitebilir.

## Doğrulama adımı (bir kereliğine, ~10 dakika)

Aşağıdaki kontrol yapılmadan bu veriden üretilen hiçbir test fixture'ı "Diyanet doğrulamalı"
etiketiyle işaretlenmeyecek.

1. Tarayıcıdan `https://namazvakitleri.diyanet.gov.tr` adresini açın ve İstanbul'u seçin
   (doğrudan adres: `namazvakitleri.diyanet.gov.tr/tr-TR/9541/istanbul-icin-namaz-vakti`).
2. Repoda `Reference/diyanet/mirror/9541/<bu-ay>.json` dosyasını açın.
3. **Rastgele 5 gün** seçip altı vakti de karşılaştırın: İmsak, Güneş, Öğle, İkindi, Akşam,
   Yatsı. Ayrıca aynı günlerin **hicri tarihini** (`HicriTarihUzun`) de karşılaştırın.
4. Aynı işlemi ikinci bir şehirde (ör. Erzurum) **2 gün** için tekrarlayın.

**Hepsi birebir tutuyorsa:** ayna sadık kabul edilir. Bu dosyanın altındaki tabloyu doldurun;
fixture üretimi serbest.

**Bir tanesi bile tutmuyorsa:** aynayı kullanmayı bırakırız, tutmayan günü not eder ve
resmi API kimlik bilgisi gelene kadar bekleriz. Yaklaşık değerle ilerlemek yok.

### Doğrulama kaydı

| Tarih (kontrol günü) | Şehir | Kontrol edilen günler | Sonuç | Kontrol eden |
|---|---|---|---|---|
| _(henüz yapılmadı)_ | | | | |

## Neden bu kadar titiz

Namaz vakti yanlış gösteren bir uygulama, kullanıcısına ibadetini yanlış vakitte yaptırır.
Bu, "yaklaşık doğru"nun kabul edilebilir olmadığı ender yazılım problemlerinden biri.
Hesaplama motorunun kendi iç tutarlılığı test edilebilir — ve ediliyor — ama gerçek vakitlere
uygunluğu yalnızca gerçek referans veriyle kanıtlanabilir.
