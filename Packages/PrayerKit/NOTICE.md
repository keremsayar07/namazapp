# Algoritma kaynağı ve lisans notu

`Sources/PrayerKit/Calculation/SolarTime.swift` ve `PrayerCalculationService.swift` içindeki
güneş deklinasyonu / zaman denklemi / saat açısı formülleri, PrayTimes.org tarafından yayımlanan
ve yıllardır birçok namaz vakti uygulamasında (batoulapps/adhan dahil) kullanılan standart
astronomik yaklaşımı izler.

- PrayTimes.org hesaplama metodolojisi: http://praytimes.org/calculation
- Referans Swift implementasyonu: https://github.com/batoulapps/adhan-swift (MIT License)

Bu pakette yer alan kod, yukarıdaki kaynaklardan satır satır kopyalanmadı; algoritmanın adımları
(Julian date → güneş pozisyonu → saat açısı → yerel saate dönüşüm) referans alınarak bu proje için
sıfırdan Swift ile yazıldı. Yine de köken şeffaflığı için bu notu burada tutuyoruz.
