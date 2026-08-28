# Güvenlik ve Gizlilik — Faz 7.6

Bu belge Namaz uygulamasının tehdit modelini, denetim bulgularını ve alınan kararları
kaydeder. Faz 7.6 kapsamında yazıldı; her sürümde gözden geçirilmesi gerekiyor.

**Kapanış ölçütü:** CRITICAL veya HIGH risk kalırsa bu faz tamamlanmış sayılmaz.
Aşağıdaki tabloda ikisinden de kalmadı.

---

## 1. Uygulamanın gerçekten ne yaptığı

Tehdit modeli, uygulamanın ne olduğuyla başlar. Buradaki cevaplar denetim sırasında
koddan doğrulandı, varsayılmadı.

| Soru | Cevap |
|---|---|
| Sunucusu var mı? | **Yok.** Backend yok, hesap yok, oturum yok. |
| Ağa çıkıyor mu? | Yalnızca `CLGeocoder` üzerinden — Apple'ın kendi konum servisi. |
| Üçüncü parti bağımlılık? | **Sıfır.** Dört yerel paket, hepsi bu depoda. |
| Gömülü sır / anahtar? | Yok. Olacak bir yer de yok, çünkü sunucu yok. |
| Reklam / analitik SDK? | Yok. |
| Kullanıcı verisi satılıyor/paylaşılıyor mu? | Hayır. Cihazdan çıkan hiçbir kullanıcı verisi yok. |
| Kullanıcı hesabı / kimlik doğrulama? | Yok. |

Ağa çıkan tek yol `CLGeocoder` ve iki yerde kullanılıyor:

1. **Ters coğrafi kodlama** — cihaz konumundan şehir adını çözmek için. Koordinat Apple'a
   gidiyor. Ekranda "Konumunuz" yerine "Gaziantep" yazabilmenin başka yolu yok. Bu çağrı
   `resolvePlaceName: false` ile kapatılabilir hale getirildi (şu an açık).
2. **Şehir arama** — kullanıcının yazdığı metin Apple'a gidiyor.

İkisi de Apple'ın gizlilik politikasına tabi ve kullanıcıya Ayarlar → Gizlilik notunda
açıkça yazılıyor. Bizim sunucumuza hiçbir şey gitmiyor, çünkü sunucumuz yok.

---

## 2. Tehdit modeli

Kimden korunuyoruz, kimden korunmuyoruz. İkincisini yazmak birincisi kadar önemli:
korunmadığın bir şeye karşı koruduğunu sanmak, en pahalı hata türü.

### Kapsam içi

| # | Saldırgan | Senaryo | Karşılık |
|---|---|---|---|
| T1 | Telefonu bulan/çalan kişi, cihaz **kilitli** | Diskten notları, namaz kaydını, konumu okumak | Kullanıcı verisi `FileProtection.complete` altında: cihaz kilitliyken donanım destekli şifreli, okunamıyor. |
| T2 | Telefonu eline alan kişi, cihaz **açık** | Uygulamayı açıp notları okumak | Notlar sekmesine isteğe bağlı Face ID / parola kilidi. Arka plana geçince yeniden kilitleniyor. |
| T3 | Cihaz yedeğine erişen kişi | iCloud/iTunes yedeğinden veriyi çıkarmak | Yedek şifreliyse veri de şifreli. Şifresiz yedek kullanıcının kendi tercihi; uygulama yedeklemeyi engellemiyor (bkz. K3). |
| T4 | Uygulamayı derleyen/dağıtan zincire sızan biri | Kötü niyetli bağımlılık eklemek | Sıfır üçüncü parti bağımlılık; CI'da `.package(url:` araması kırmızı veriyor. |
| T5 | Cihaz günlüğünü okuyan biri (Console.app, sysdiagnose) | Günlükten konum/not sızdırmak | `Diagnostics` serbest metin **almıyor**; hassas veri geçirmek derlenmiyor. CI'da `print`/`NSLog` yasak. |
| T6 | Ağı dinleyen biri | Trafiği okumak | Uygulamanın kendi trafiği yok. `CLGeocoder` Apple'ın kendi güvenli kanalını kullanıyor. |

### Kapsam dışı — ve neden

| # | Tehdit | Neden kapsam dışı |
|---|---|---|
| D1 | Jailbreak'li cihazda kök erişimi olan saldırgan | Data Protection'ı da uygulama içi her önlemi de aşar. Buna karşı koruma iddiası, tutulamayacak bir söz olurdu. |
| D2 | Apple'ın kendisi | Konum servisleri ve geocoder Apple'ın. Alternatifi kendi sunucumuzu kurmak olurdu — yani veriyi Apple yerine **bize** göndermek. Kullanıcı için bu bir iyileşme değil. |
| D3 | Kullanıcının kendi seçtiği kilit ekranı önizlemesi | Bildirim metinleri kilit ekranında görünür. Bu iOS'un genel davranışı ve kullanıcı ayarı (bkz. K2). |
| D4 | Fiziksel omuz sörfü | Uygulama seviyesinde çözülebilecek bir şey değil. |

---

## 3. Bulgular

Denetim 28.08.2026'da yapıldı. Sınıflandırma: CRITICAL / HIGH / MEDIUM / LOW / BİLGİ.

### Düzeltilenler

| # | Risk | Bulgu | Düzeltme |
|---|---|---|---|
| B1 | **MEDIUM** | `PrayerTimesSnapshotStore`, kullanıcının koordinatlarını App Group kabına **dosya koruma sınıfı belirtmeden** yazan bir kod yoluydu. Uygulamanın hiçbir yerinden çağrılmıyordu (widget veriyi `Preferences` üzerinden okuyor), yani ölü koddu. | Tamamen kaldırıldı. `AppGroup` kendi dosyasına taşındı. Çağrılmayan kod da saldırı yüzeyidir; bir gün biri onu çağırır ve o gün kimse koruma sınıfını hatırlamaz. |
| B2 | **LOW** | Cihaz konumu diske tam ondalık hassasiyetle yazılıyordu. Konum servisinden zaten `kCLLocationAccuracyKilometer` isteniyor, yani fazladan basamaklar gerçek bilgi taşımıyordu — ama diskte duruyorlardı. | `LocationPrivacy.coarsened` ile iki ondalığa (≈1,1 km) yuvarlanıyor. Vakitlere etkisi saniyeler, kıble açısına 0,05 dereceden az. Elle seçilen şehirlere uygulanmıyor: onlar zaten herkese açık koordinatlar. |
| B3 | **LOW** | Uygulamada hiç günlükleme yoktu. Bu "sızıntı yok" demek ama aynı zamanda "cihazda ne olduğunu öğrenmenin yolu yok" demek: TestFlight'ta "notlarım kayboldu" diyen bir kullanıcıya sorulacak hiçbir şey olmazdı. | `Diagnostics` eklendi. Serbest metin almıyor; kaydedilebilen her şey sayılı bir olay ve yanında yalnızca sayı/bayrak/enum taşıyor. Not gövdesi, koordinat veya arama metni geçirilebilecek bir parametre **yok** — yanlış kullanım derlenmiyor. |
| B4 | **LOW** | "Tüm verilerimi sil" yoktu. Uygulamayı silmek aynı işi görür ama kullanıcı çoğu zaman uygulamayı tutup veriyi bırakmak ister. | Ayarlar → Gizlilik → Tüm verileri sil. Onay istiyor, geri alınamadığını yazıyor. Silinecek dosyalar `UserDataFile.allCases` ile tek yerden geliyor; bir testi görünüm modellerinin kullandığı adlarla karşılaştırıyor, böylece yeni bir araç listeye eklenmeyi unutamıyor. |

### Kabul edilen riskler

| # | Risk | Durum | Gerekçe |
|---|---|---|---|
| K1 | **LOW** | Şehir arama metni ve cihaz koordinatı `CLGeocoder` üzerinden Apple'a gidiyor. | Kaçınılmaz: alternatifi kendi geocoding sunucumuz, yani veriyi Apple yerine bize göndermek. Kullanıcıya Ayarlar'daki gizlilik notunda açıkça yazıyor. |
| K2 | **LOW** | Zamanlayıcı bildiriminin başlığı kullanıcının yazdığı etiket ve kilit ekranında görünebiliyor. | Kullanıcının kendi yazdığı metin, kendi zamanlayıcısına. Kilit ekranı önizlemesi iOS'un genel ayarı. Uygulamanın burada kullanıcı adına karar vermesi gereksiz bir kısıt olurdu. |
| K3 | **LOW** | Kullanıcı verisi iCloud yedeğine dahil. | Bilinçli: yedekten çıkarmak, telefon değiştiren kullanıcının bir yıllık namaz kaydını kaybetmesi demek. Yedeğin şifreli olup olmadığı kullanıcının kendi kararı. |
| K4 | BİLGİ | Vakit bildirimleri, kullanıcının hangi vakitleri takip ettiğini kilit ekranında gösteriyor. | Uygulamanın işi bu. Kapatmak isteyen her vakti tek tek kapatabiliyor. |

### CRITICAL / HIGH

**Yok.** Denetimde bu seviyelerde bulgu çıkmadı. Bunun temel sebebi mimari: sunucu yok,
hesap yok, sır yok, üçüncü parti kod yok. Bu boşlukların hiçbiri sonradan kapatılmış
değil — baştan böyle kuruldu.

---

## 4. Uygulanan kontroller

### Depolama

- Kullanıcı verisi (notlar, namaz kaydı, kaza, zikir, zamanlayıcı) App Group kabında,
  dosya başına bir JSON.
- Dosya koruma sınıfı **`.complete`** (`StoreProtection.whileUnlocked`): cihaz kilitliyken
  okunamaz. Sınıf, `.atomic` yazmadan **sonra** yeniden uygulanıyor — atomik yazma dosyayı
  yeniden oluşturduğu için klasörden miras alınan sınıfa güvenilemez.
- Dosya adları koddan geliyor; yine de `/` ve `..` içeren adlar reddediliyor ve bunun bir
  testi var.
- Bozuk veri çökme değil, "veri yok" üretiyor — ama artık sessizce değil, `Diagnostics`
  üzerinden iz bırakarak.

### Kimlik doğrulama

- Notlar sekmesinde isteğe bağlı kilit, `LAPolicy.deviceOwnerAuthentication`.
- Bilerek `...WithBiometrics` **değil**: Face ID birkaç kez başarısız olduğunda ya da
  kullanıcı maskeliyken parolaya düşebilsin. Aksi halde kullanıcı kendi verisinden
  kalıcı olarak dışlanabilirdi.
- Cihazda parola tanımlı değilse kilit zorlanmıyor — aynı gerekçe.
- Her doğrulamada **yeni** bir `LAContext`: aynı bağlamın yeniden kullanılması iOS'un önceki
  doğrulamayı bir süre geçerli saymasına ve kilidin hiç sorulmadan açılmasına yol açardı.
- Doğrulama başarısızsa "açık" tarafına düşülmüyor.

### Günlükleme

- Tek yüzey: `Diagnostics`. Kategori bazlı `OSLog`.
- API serbest metin almıyor. Yasak liste (parola, anahtar, jeton, kesin konum, özel not,
  kişisel içerik) bir hatırlatma değil, tip sisteminin sorunu.
- CI'da dağıtılan kodda `print` / `NSLog` / `debugPrint` / `dump` yasak.

### Ağ

- Uygulamanın kendi ağ çağrısı yok. `URLSession` hiç kullanılmıyor.
- ATS istisnası yok, `NSAllowsArbitraryLoads` yok.
- CI'da kaynakta `http://` araması kırmızı veriyor.

### Bağımlılıklar

- Üçüncü parti sıfır. Dört yerel paket: `PrayerKit`, `NamazCore`, `NamazUI`, `NamazWidgets`.
- CI'da `.package(url:` araması kırmızı veriyor — bir bağımlılık eklenecekse karar bilerek
  verilmiş olacak.

### Gizlilik beyanı

- Her iki hedefte de `PrivacyInfo.xcprivacy`.
- `NSPrivacyTracking = false`, izleme alan adı yok.
- `NSPrivacyCollectedDataTypes` **boş**: Apple'ın tanımıyla "toplama", verinin cihazdan
  çıkıp bize veya üçüncü tarafa ulaşması demek. Konum cihazda hesaplanıyor ve bize hiç
  gelmiyor.
- Gerekçe bildirimi: `UserDefaults` için `CA92.1` (yalnızca kendi App Group'u içinde,
  widget ile tercih paylaşmak).
- CI beyanın tutarlılığını denetliyor: manifesto ile App Store gizlilik etiketinin ayrı
  düşmesi, kullanıcıya yanlış bilgi vermek olurdu.

---

## 5. Otomatik denetimler

`.github/workflows/security.yml` her push'ta koşuyor:

1. Dağıtılan kodda serbest günlükleme yok
2. Koda gömülü sır benzeri dize yok
3. Şifresiz `http://` adresi yok
4. Üçüncü parti bağımlılık yok
5. Gizlilik manifestosu her iki hedefte de var
6. Manifesto izleme yapılmadığını beyan ediyor
7. Bu belge duruyor

`.github/workflows/app-build.yml` ayrıca App Group kimliğinin üç yerde (iki entitlement +
`AppGroup.identifier`) birebir aynı olduğunu denetliyor.

Birim testleri (`SecurityTests.swift`): günlük olaylarının kullanıcı verisi taşımaması,
konum yuvarlama, silme listesinin eksiksizliği, depo dizin sınırı, konteyner yokken
çökmeme.

**Bu denetimler bir garanti değil.** Yaptıkları şey, insanın gözden kaçırdığı sınıfta
hataları yakalamak. Tehdit modelinin kendisi bu belgede ve elle gözden geçirilmesi gerekiyor.

---

## 6. Sonraki sürümlerde gözden geçirilecek

- **Live Activity** eklendiğinde: kilit ekranında sürekli görünen içerik yeni bir yüzey.
- **iCloud senkronizasyonu** eklenirse: T3 ve K3 baştan değerlendirilmeli, veri artık
  cihazdan çıkacak.
- **Ayet/hadis içeriği** eklenirse: içerik paketinin bütünlüğü (imza/karma doğrulaması) ve
  kaynak lisansı ayrı bir denetim konusu.
- **Herhangi bir backend** eklenirse bu belgenin tamamı yeniden yazılmalı; mevcut
  bulguların çoğu "sunucu yok" varsayımına dayanıyor.
