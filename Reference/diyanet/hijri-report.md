# Hicri düzeltme tablosu

Bu dosya `prayerkit-hijri-table` tarafından üretildi; elle düzenlemeyin.

## Kapsam

| Ölçü | Değer |
|---|---|
| İncelenen gün | 36 |
| Karşılaştırılan kayıt | 384 |
| İlçe | 12 |
| Aralık | 2026-08-18 – 2026-09-22 |
| Ümmü'l-Kura'dan farklı gün | 0 |

Kapsanan aralıkta iki takvim hiç ayrılmadı. Bu, ayrılmayacakları anlamına
**gelmiyor**: ayrışma ay başlarında yoğunlaşıyor ve bu pencere yalnızca
36 gün. Arşiv genişledikçe tablo dolabilir.

## Yöntem

Her miladi gün için arşivdeki tüm ilçelerin `HicriTarihUzun` alanı okunuyor ve
hepsinin aynı hicri tarihi bildirdiği doğrulanıyor — Diyanet tüm Türkiye için tek
bir dini takvim yayımladığı için fark çıkmamalı. Uzlaşılan tarih, uygulamanın
kendi `UmmAlQuraHijriDateConverter`'ıyla karşılaştırılıyor ve yalnızca farklı olan
günler tabloya yazılıyor.

Ayrıştırılamayan tek bir kayıt ya da ilçeler arası tek bir uyuşmazlık, aracın
kırmızı bitmesine ve tablonun hiç yazılmamasına yol açar. Anlaşılmayan veriden
tablo üretmek, uydurmakla aynı şey olurdu.

- Kaynak: `Reference/diyanet/mirror` — bkz. `Tools/diyanet_reference/PROVENANCE.md`
