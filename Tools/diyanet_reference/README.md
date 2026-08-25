# Diyanet referans verisi — otomatik toplama

Bu klasör, namaz vakti referans verisini **elle veri girişi olmadan** toplayan iki işi içerir.
Toplanan her şey `Reference/diyanet/` altına, servisten dönen gövde **hiç değiştirilmeden**,
kaynak ve UTC indirme zaman damgasıyla birlikte yazılır.

| Betik | Kaynak | Kimlik bilgisi | Durum |
|---|---|---|---|
| `fetch_mirror.py` | `ezanvakti.emushaf.net` (Diyanet vakitlerinin açık aynası) | Gerekmiyor | **Bugün çalışır** |
| `fetch.py` | `awqatsalah.diyanet.gov.tr` (Diyanet resmi REST servisi) | Başvuru ile | Kimlik bilgisi bekliyor |

İkisinin güven seviyesi farklı ve bu fark önemli — **`PROVENANCE.md` dosyasını okuyun.**
Aynadan gelen veriyle üretilen fixture'lar, oradaki elle doğrulama adımı tamamlanmadan
"Diyanet doğrulamalı" sayılmaz.

## Hemen başlayan iş: ayna

`.github/workflows/diyanet-mirror.yml` haftada iki kez (Pazartesi ve Perşembe) çalışır,
12 ilçe için vakitleri ve **Diyanet'in resmi hicri tarihini** toplar. Hiçbir ayar
gerekmiyor — dosyalar repoda olduğu anda çalışmaya başlar.

Hemen denemek için: **Actions** → **Diyanet Vakitleri (ayna)** → **Run workflow**.

## Sonra devreye girecek iş: resmi API + kimlik bilgisi

Servis kimlik doğrulaması istiyor ve kayıt otomatikleştirilemiyor. Bir kereliğine:

1. `https://awqatsalah.diyanet.gov.tr` adresini tarayıcıdan açın.
   **Site açılmıyorsa acele etmeyin** — ayna işi zaten veri topluyor. Alan adı yurt dışı
   IP'lerden sık sık zaman aşımına uğruyor; birkaç gün sonra, mümkünse Türkiye'deki bir
   bağlantıdan ve mobil veri yerine sabit hattan tekrar deneyin.
2. Sayfadaki **"İstek ve Taahhüt Formu"**nu indirin, doldurun ve sayfada belirtilen adrese
   gönderin. (Form ücretsizdir; kişisel/kurumsal geliştirici başvurusu kabul ediliyor.)
   Başvuruda uygulamanın adını — `Namaz`, iOS — ve verinin yalnızca vakit gösterimi için
   kullanılacağını belirtmeniz yeterli.
3. Onay geldiğinde size bir **e-posta + şifre** verilecek.

## İkinci adım: GitHub'a gizli olarak ekleyin

Kimlik bilgileri koda **yazılmaz**; GitHub'ın şifreli secret deposunda durur.

1. Repo sayfası → üstte **Settings**
2. Sol menü → **Secrets and variables** → **Actions**
3. **New repository secret** → Name: `AWQATSALAH_EMAIL`, Secret: size verilen e-posta → Add
4. Tekrar **New repository secret** → Name: `AWQATSALAH_PASSWORD`, Secret: şifre → Add

Bu kadar. İş ertesi sabah kendiliğinden çalışır; hemen denemek için:
**Actions** sekmesi → soldan **Diyanet Referans Verisi** → sağda **Run workflow**.

> Kimlik bilgileri eklenmeden iş çalışırsa hata vermez — "yapacak bir şey yok" deyip yeşil
> biter. Yani bugünden itibaren repoda durabilir.

## Ne toplanıyor

| Klasör | İçerik |
|---|---|
| `Reference/diyanet/monthly/` | Şehir başına bir ayın tüm günlerinin vakitleri **ve hicri tarihleri** |
| `Reference/diyanet/city-detail/` | Resmi kıble açısı ve Kâbe uzaklığı |
| `Reference/diyanet/religious-days/` | Ramazan imsakiyesi, bayram namazı vakitleri |
| `Reference/diyanet/places/` | Ülke/il/ilçe listeleri (bir kez indirilir, sonra önbellekten) |
| `Reference/diyanet/manifest.json` | Hangi ay/şehir kombinasyonlarının toplandığının envanteri |

Hedef şehirler enlem ve boylam yayılımı gözetilerek seçildi — İstanbul, Ankara, İzmir,
Gaziantep, Erzurum, Trabzon. Kuzey-güney farkı imsak/yatsı açı hatalarını, doğu-batı farkı
saat dilimi düzeltmesindeki hataları ortaya çıkarır; tek şehirle ikisi de görünmez.
Listeyi değiştirmek için `fetch.py` içindeki `TARGET_PROVINCES` sabitini düzenleyin.

## Neden her gün çalışıyor

Servisin `Monthly` endpoint'i tarih parametresi almıyor — sadece içinde bulunulan ayı
döndürüyor. Ayrıca standart rolde endpoint başına günde 5 istek hakkı var. Bu yüzden iş:

- o ay için **eksik** şehirleri tamamlar (6 şehir ≈ 2 gün),
- tamamlandığında **hiç istek harcamadan** çıkar,
- ay değiştiğinde yeni ayı toplamaya başlar.

Böylece bir yıl içinde tam mevsimsel kapsama kendiliğinden oluşur ve sonrasında iş, motorun
çıktısını Diyanet'in güncel verisiyle sürekli karşılaştıran bir regresyon ağı hâline gelir.
Geliştirici rolü (günde 100 istek) verilirse **Run workflow** düğmesine
`max_calls_per_endpoint = 100` girerek aynı gün bitirebilirsiniz.
