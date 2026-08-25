# Namaz — iOS uygulaması

Bu depo, Faz 1 çıktısını içerir: **PrayerKit** — namaz vakti hesaplama, kıble açısı ve hicri
tarih dönüştürme mantığını barındıran, bağımsız test edilebilir bir Swift paketi. Henüz bir
Xcode App/Widget target'ı **yok** — bunları aşağıdaki adımlarla siz oluşturacaksınız, çünkü bu
oturum Linux tabanlı bir bulut ortamında çalışıyor ve Xcode/iOS SDK'sına erişimi yok.

## 1. PrayerKit'i test edin

**Mac'iniz varsa (Terminal, Xcode'suz da olur):**

```bash
cd Packages/PrayerKit
swift test
```

**Mac'iniz yoksa (GitHub Actions ile, tarayıcıdan):** Bu depoya `.github/workflows/prayerkit-tests.yml`
eklendi — bu, kodu GitHub'a her yüklediğinizde/güncellediğinizde GitHub'ın ücretsiz sağladığı
gerçek bir macOS + Xcode makinesinde `swift test`'i otomatik çalıştırır. Adım adım:

1. github.com'da (hesabınız yoksa ücretsiz) yeni bir **private** repo oluşturun, ör. `namaz-app`.
2. Repo sayfasında **Add file → Upload files**'a tıklayın, bu zip'i açtığınız `namaz-app` klasörünün
   İÇİNDEKİ her şeyi (README.md, Packages/, .github/ dahil) sürükleyip bırakın — modern
   tarayıcılarda klasör sürükleyince alt klasör yapısı korunur. "Commit changes" ile onaylayın.
3. Üstteki **Actions** sekmesine geçin. "PrayerKit Tests" adında bir iş otomatik başlamış
   olmalı (başlamadıysa soldaki listeden seçip **Run workflow** düğmesine basın).
4. İş bitince yeşil ✓ = testler geçti, kırmızı ✗ = bir hata var. Kırmızıysa işin üstüne tıklayıp
   "Run PrayerKit tests" adımının log'unu kopyalayıp bana yapıştırın, hemen düzeltirim.

Her şey yolundaysa `PrayerCalculationServiceTests`, `QiblaMathTests`, `HijriDateTests` içindeki
testler geçer. Bu testler **iç tutarlılık** doğrular (vakitlerin sırası, determinizm, kıble
açısının makul aralıkta olması); Diyanet'in gerçek vakitleriyle dakika hassasiyetinde
karşılaştırma henüz yapılamadı — bkz. `Packages/PrayerKit/VERIFICATION_NEEDED.md`.

> Not: Repo'yu **public** yaparsanız GitHub Actions dakikaları tamamen ücretsiz/sınırsızdır.
> Private tutarsanız da ücretsiz kotanız (aylık ~200 macOS dakikası) bu küçük paket için fazlasıyla
> yeter. Bundle ID'niz (`com.keremsayar.namaz`) dışında kodda kişisel/gizli bir bilgi yok.

## 1b. Diyanet referans verisini otomatik toplatın

Motorun Diyanet'in vakitleriyle dakika hassasiyetinde karşılaştırılması için gerçek referans
verisi gerekiyor. Bu veri **elle toplanmıyor** — iki GitHub Actions işi topluyor:

- `diyanet-mirror.yml` — Diyanet vakitlerini yeniden yayımlayan açık ayna üzerinden.
  Kimlik bilgisi istemez, **hemen çalışır**. 12 ilçe için vakitler ve Diyanet'in resmi
  hicri tarihi.
- `diyanet-reference.yml` — Diyanet'in resmi REST servisinden. Bir kereliğine API kimlik
  bilgisi alıp GitHub Secrets'a eklemenizi bekler; eklenene kadar sessizce yeşil biter.

İkisinin güven seviyesi farklı ve aynadan gelen verinin bir doğrulama adımı var:
`Tools/diyanet_reference/PROVENANCE.md`. Kurulum adımları: `Tools/diyanet_reference/README.md`.

## 2. Xcode App projesini oluşturun (Mac edindiğinizde)

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
