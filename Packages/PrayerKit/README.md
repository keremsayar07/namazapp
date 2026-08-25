# PrayerKit

Cihaz üzerinde çalışan, ağ bağımlılığı olmayan namaz vakti hesaplama çekirdeği. Namaz (iOS app) ve
NamazWidget (WidgetKit extension) target'larının ikisi de bu paketi import eder — hesaplama mantığı
tek bir yerde yaşar.

## İçerik

- `Models/` — saf değer tipleri (Prayer, Coordinate, CalculationSettings, ...). CoreLocation'a,
  SwiftData'ya veya herhangi bir sistem framework'üne bağımlı değil.
- `Calculation/` — `PrayerCalculationService`: `Coordinate + Date + CalculationSettings → DailyPrayerTimes`.
  Saf fonksiyon, I/O yok.
- `Hijri/` — Hicri tarih dönüştürücüler. Bkz. `VERIFICATION_NEEDED.md`.
- `Qibla/` — Kıble açısı hesabı (büyük daire bearing).
- `SharedStore/` — App Group üzerinden App ↔ Widget arasında paylaşılan snapshot modeli.

## Test çalıştırma

Bu ortamda (bulut sandbox) Swift toolchain kurulu değil, bu yüzden kod burada derlenip
çalıştırılamadı. Mac'inizde:

```bash
cd Packages/PrayerKit
swift test
```

Hata alırsanız çıktısını paylaşın, hemen düzeltelim.

## Algoritma kaynağı

`Calculation/SolarTime.swift` içindeki güneş konumu formülleri, PrayTimes.org'un yayımladığı ve
`batoulapps/adhan` başta olmak üzere birçok açık kaynak namaz vakti kütüphanesinin temel aldığı
standart düşük hassasiyetli güneş konumu algoritmasını izler. Kod satır satır kopya değil, bu
paket için sıfırdan Swift olarak yazıldı — ama algoritmanın kökenini burada açıkça belirtiyoruz.
Bkz. `NOTICE.md`.
