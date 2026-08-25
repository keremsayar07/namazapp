# Namaz — iOS uygulaması

Bu depo, Faz 1 çıktısını içerir: **PrayerKit** — namaz vakti hesaplama, kıble açısı ve hicri
tarih dönüştürme mantığını barındıran, bağımsız test edilebilir bir Swift paketi. Henüz bir
Xcode App/Widget target'ı **yok** — bunları aşağıdaki adımlarla siz oluşturacaksınız, çünkü bu
oturum Linux tabanlı bir bulut ortamında çalışıyor ve Xcode/iOS SDK'sına erişimi yok.

## 1. PrayerKit'i test edin (Xcode'suz, sadece Terminal)

```bash
cd Packages/PrayerKit
swift test
```

Her şey yolundaysa `PrayerCalculationServiceTests`, `QiblaMathTests`, `HijriDateTests` içindeki
testler geçer. Bu testler **iç tutarlılık** doğrular (vakitlerin sırası, determinizm, kıble
açısının makul aralıkta olması); Diyanet'in gerçek vakitleriyle dakika hassasiyetinde
karşılaştırma henüz yapılamadı — bkz. `Packages/PrayerKit/VERIFICATION_NEEDED.md`.

Bir hata alırsanız çıktısını olduğu gibi paylaşın, birlikte düzeltelim.

## 2. Xcode App projesini oluşturun

1. Xcode → **File → New → Project → iOS → App**
   - Product Name: `Namaz`
   - Team: Apple Developer hesabınız
   - Organization Identifier: `com.keremsayar`
   - Bundle Identifier otomatik: `com.keremsayar.namaz`
   - Interface: **SwiftUI**, Language: **Swift**
   - Bu depo klasörünün İÇİNE kaydedin (ör. proje kök dizini `namaz-app/` olacak şekilde, bu
     `Packages/` klasörüyle aynı seviyede).
2. Projeyi oluşturduktan sonra: **File → Add Package Dependencies → Add Local...** ve
   `Packages/PrayerKit` klasörünü seçin. Bu, PrayerKit'i App target'ına local Swift package
   olarak bağlar.
3. `Namaz` target'ının **Signing & Capabilities** sekmesinden minimum deployment target'ı
   **iOS 17.0** yapın.
4. Herhangi bir SwiftUI View içinde `import PrayerKit` yazıp derleyerek bağlantıyı doğrulayın —
   örnek:

   ```swift
   import SwiftUI
   import PrayerKit

   struct ContentView: View {
       var body: some View {
           let service = PrayerCalculationService()
           let times = service.dailyTimes(
               for: .now,
               coordinate: Coordinate(latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"),
               settings: .defaultForTurkey()
           )
           Text("Öğle: \(times.time(for: .dhuhr)?.formatted() ?? "—")")
       }
   }
   ```

Bu derlenip simülatörde çalışırsa Faz 1'in App-tarafı entegrasyonu tamam demektir. Widget
extension target'ı (App Groups dahil) Faz 4'te ekleniyor — şimdilik gerekmiyor.

## Klasör yapısı

```
namaz-app/
├── Packages/
│   └── PrayerKit/            ← Faz 1: tamamlandı (derleme + testler sizde doğrulanacak)
│       ├── Package.swift
│       ├── Sources/PrayerKit/
│       ├── Tests/PrayerKitTests/
│       ├── README.md
│       ├── NOTICE.md          ← algoritma kaynağı
│       └── VERIFICATION_NEEDED.md  ← eksik doğrulama verisi, ne gerektiği
└── README.md                  ← bu dosya
```
