# Mac oturumu — adım adım

Bu belge kuzeninin Mac'inde tek oturumda uygulanacak. Hedef: uygulamayı **çalışır halde
görmek** — simülatörde, sonra gerçek iPhone'da. Bugüne kadar her şey CI'da derlendi ama
hiç çalıştırılmadı.

Tahmini süre: kurulum 20 dk, doğrulama 30 dk.

---

## Önce: ne getiriyorsun

- Apple ID'n (Individual Developer hesabın)
- iPhone'un ve kablosu
- Bu depo (Mac'te `git clone https://github.com/keremsayar07/namazapp.git`)

---

## 1. Projeyi üret

Terminal'de deponun kökünde:

```bash
brew install xcodegen        # Homebrew yoksa: brew.sh
xcodegen generate
open Namaz.xcodeproj
```

Bu kadar. `Namaz.xcodeproj` depoda tutulmuyor — `project.yml`'den üretiliyor. Bir şey
bozulursa `rm -rf Namaz.xcodeproj && xcodegen generate` her şeyi geri getirir.

**Homebrew yoksa ve kurmak istemiyorsan** bu adımı atlayıp bölüm 7'deki elle kurulum
tarifini izle. Ama XcodeGen yolu hem hızlı hem tekrarlanabilir; tercih o.

---

## 2. İmzalama (tek yapılandırma adımı)

Xcode'da her iki hedef için ayrı ayrı:

1. Sol panelde **Namaz** projesi → **TARGETS** → **Namaz**
2. **Signing & Capabilities** sekmesi
3. **Team**: Apple ID'ni seç (yoksa Xcode → Settings → Accounts → +)
4. Aynısını **NamazWidgetsExtension** hedefi için tekrarla — **aynı takımı seç**

`project.yml` App Group'u zaten iki hedefe de yazdı; Signing sekmesinde
**App Groups → group.com.keremsayar.namaz** satırını görmelisin. Görmüyorsan orada
manuel ekle, aksi halde widget hiçbir zaman veri bulamaz.

> **Bundle ID zaten alınmışsa** Xcode "failed to register" der. `project.yml` içinde
> `com.keremsayar.namaz` yazan iki yeri değiştir, `xcodegen generate` tekrar çalıştır.

---

## 3. Simülatörde çalıştır

Şema: **Namaz**, hedef cihaz: **iPhone 15 Pro** (veya herhangi bir iPhone). ⌘R.

### Kontrol listesi — sırayla

| # | Kontrol | Beklenen |
|---|---|---|
| 1 | Uygulama açılıyor | Vakit sekmesi, kâğıt zemin, serif tipografi |
| 2 | Konum izni soruluyor | Türkçe metin: "Namaz vakitlerini bulunduğunuz yere göre…" |
| 3 | **İzni reddet** | Ekran "Konum izni kapalı" + "Şehir seç" / "Ayarlar'ı aç" düğmeleri |
| 4 | "Şehir seç" → `ista` yaz | **İstanbul çıkmalı** — çıkmazsa `SearchFolding` bozuk demektir |
| 5 | İstanbul'u seç | Altı vakit + geri sayım görünüyor |
| 6 | Vakitleri karşılaştır | namazvakitleri.diyanet.gov.tr ile **birebir aynı olmalı** |
| 7 | Takvim sekmesi | Ay ızgarası, bugün işaretli, gün seçilince defter açılıyor |
| 8 | Kıble sekmesi | Simülatörde pusula yok → "Bu cihazda pusula yok" + açı yine de görünüyor |
| 9 | Ayarlar → Hesaplama | 12 yöntem, açılarıyla; Türkiye'de "kalibre edildi" notu |
| 10 | Ayarlar → Hakkında | Hicri satırı: 36 gün, 2026-08-18 – 2026-09-22, 0 fark |
| 11 | Karanlık mod (⌘⇧A) | Zemin koyu, kiremit vurgu okunur kalıyor |
| 12 | Dinamik Yazı Tipi | Erişilebilirlik boyutlarında satırlar alt alta geçiyor, çakışmıyor |

**6. madde en önemlisi.** Kalibrasyon CI'da doğrulandı ama ilk kez gerçek bir cihaz saat
diliminde çalışıyor. Bir dakikadan fazla sapma varsa dur ve bana söyle.

---

## 4. Gerçek iPhone'da çalıştır

iPhone'u kabloyla bağla, Xcode'da cihazı seç, ⌘R. İlk seferde telefonda
**Ayarlar → Genel → VPN ve Cihaz Yönetimi** altından geliştirici sertifikasına güven.

### Yalnızca cihazda görülebilenler

| # | Kontrol | Beklenen |
|---|---|---|
| 13 | Konum iznini **ver** | Bulunduğun şehir kendiliğinden geliyor |
| 14 | Bildirim izni ver, Ayarlar → Bildirimler | Kapsama satırı gün sayısı gösteriyor |
| 15 | Kıble sekmesi | İbre dönüyor, kıbleye bakınca **titreşim** ve "Kıble yönündesiniz" |
| 16 | Kıble doğruluğu | Pusula uygulamasıyla kıyasla; sapma payı ekranda yazıyor |
| 17 | **Widget ekle** | Ana ekranda uzun bas → + → Namaz → küçük ve orta boy |
| 18 | Widget veri gösteriyor mu | **Şehir adı ve vakitler görünmeli.** Boşsa App Group yanlış. |
| 19 | Kilit ekranı widget'ı | Kilit ekranını düzenle → Namaz → yuvarlak / dikdörtgen |
| 20 | Uygulamayı kapat, bekle | Widget vakit geçince kendini güncelliyor |

**18. madde App Group'un tek gerçek testi.** Widget boş kalıyorsa: iki hedefin
Signing & Capabilities sekmesinde de App Groups var mı, ikisi de aynı kimliği mi
gösteriyor — önce oraya bak.

---

## 5. Bunları da dene (hata avı)

Bunlar çökmemeli:

- Uçak modunda aç
- Konum servisini tamamen kapat
- Cihaz saat dilimini değiştir (Ayarlar → Genel → Tarih ve Saat → New York)
- Saati bir yıl ileri al
- Uygulamayı kapatıp bir gün sonra aç

Herhangi biri çökerse ekran görüntüsü + Xcode konsolundaki hata metnini gönder.

---

## 6. Arşiv (isteğe bağlı — TestFlight'a hazırsak)

Product → Archive. Şema **Namaz**, hedef **Any iOS Device**. Arşiv açılınca
**Distribute App → TestFlight & App Store**.

`ITSAppUsesNonExemptEncryption` zaten `false` yazıldığı için ihracat uyumluluğu sorusu
sorulmayacak — uygulama yalnızca Apple'ın kendi şifrelemesini kullanıyor.

---

## 7. XcodeGen olmadan elle kurulum (yedek yol)

1. Xcode → **Create New Project** → iOS → **App**
   - Product Name: `Namaz`, Organization Identifier: `com.keremsayar`
   - Interface: **SwiftUI**, Language: **Swift**, Storage: **None**
   - Depo kökünde oluştur
2. Üretilen `ContentView.swift` ve `NamazApp.swift`'i **sil**, depodaki
   `App/NamazApp.swift`'i sürükle (Copy items **kapalı**)
3. `App/Assets.xcassets`, `App/PrivacyInfo.xcprivacy`, `App/tr.lproj`, `App/en.lproj`
   dosyalarını da ekle
4. **File → Add Package Dependencies → Add Local** ile dört paketi ekle:
   `Packages/PrayerKit`, `Packages/NamazCore`, `Packages/NamazUI`, `Packages/NamazWidgets`
5. **File → New → Target → Widget Extension**, adı `NamazWidgetsExtension`,
   "Include Live Activity" **kapalı**, "Include Configuration Intent" **kapalı**
6. Üretilen widget dosyalarını sil, `WidgetExtension/NamazWidgetsBundle.swift` ve
   `WidgetExtension/PrivacyInfo.xcprivacy` dosyalarını ekle
7. Her iki hedefte **Signing & Capabilities → + Capability → App Groups** →
   `group.com.keremsayar.namaz`
8. Uygulama hedefinin **Info** sekmesinde
   `Privacy - Location When In Use Usage Description` anahtarını ekle
9. Uygulama hedefi → **General → Frameworks, Libraries, and Embedded Content** →
   widget uzantısının **Embed & Sign** olduğunu doğrula

---

## Sorun çıkarsa

| Belirti | Muhtemel sebep |
|---|---|
| Widget galeride yok | Uzantı uygulamaya gömülmemiş (adım 9) |
| Widget var ama boş | App Group iki hedefte aynı değil, ya da uygulama hiç açılmadı |
| "No such module 'NamazUI'" | Yerel paketler eklenmemiş ya da hedefe bağlanmamış |
| Konum izni metni İngilizce | `App/tr.lproj/InfoPlist.strings` hedefe dahil değil |
| Vakitler bir saat kaymış | Cihaz saat dilimi ile seçili şehrin saat dilimi farklı — beklenen davranış |
| Bildirim gelmiyor | Simülatörde beklenen; cihazda izin verilmiş mi kontrol et |
