# Diyanet vakitlerini kendi bilgisayarınızdan toplar (Windows, hiçbir kurulum gerektirmez).
#
# Neden bu dosya var
# ------------------
# Ayna (ezanvakti.emushaf.net) Cloudflare bot koruması arkasında ve GitHub Actions
# koşucularının IP'lerini reddediyor ("Just a moment…"). Sizin evinizdeki bağlantı sıradan
# bir tarayıcı bağlantısı olduğu için aynı istek oradan geçiyor.
#
# Bu script sadece veriyi indirip diske yazar. Hiçbir hesaplama, dönüştürme veya yorumlama
# yapmaz — dosyalar servisten geldiği gibi saklanır. Birleştirme işini repodaki
# fetch_mirror.py yapıyor (o adım ağ gerektirmiyor).
#
# Çalıştırma
# ----------
#   1. Bu dosyayı bir klasöre koyun (ör. Masaüstü).
#   2. O klasörde Shift + sağ tık → "Burada PowerShell penceresi aç"
#   3. Şunu yapıştırıp Enter:
#
#        powershell -ExecutionPolicy Bypass -File .\fetch_mirror.ps1
#
#   4. Bitince yanında "namaz-referans" klasörü oluşur. İçindeki dosyaları GitHub'da
#      Reference/diyanet/raw/ klasörüne yükleyin.

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$BaseUrl   = "https://ezanvakti.emushaf.net"
$OutputDir = Join-Path (Get-Location) "namaz-referans"
$Delay     = 1.0   # istekler arası saniye — aynaya nazik olmak için

$Provenance = "Diyanet Isleri Baskanligi vakitlerini yeniden yayimlayan ucuncu taraf ayna " +
              "(ezanvakti.emushaf.net). Birincil kaynak degildir - bkz. PROVENANCE.md."

# Hedef iller ve tercih edilen ilçeler. Enlem-boylam yayılımı bilinçli: kuzey-güney farkı
# imsak/yatsı açı hatalarını, doğu-batı farkı saat dilimi düzeltmesi hatalarını gösterir.
$Targets = @(
    @{ Province = "İSTANBUL";   Districts = @("İSTANBUL", "FATİH") },
    @{ Province = "ANKARA";     Districts = @("ANKARA", "ÇANKAYA") },
    @{ Province = "İZMİR";      Districts = @("İZMİR", "KONAK") },
    @{ Province = "ANTALYA";    Districts = @("ANTALYA", "MURATPAŞA") },
    @{ Province = "GAZİANTEP";  Districts = @("GAZİANTEP", "ŞAHİNBEY") },
    @{ Province = "DİYARBAKIR"; Districts = @("DİYARBAKIR", "BAĞLAR") },
    @{ Province = "ERZURUM";    Districts = @("ERZURUM", "YAKUTİYE") },
    @{ Province = "TRABZON";    Districts = @("TRABZON", "ORTAHISAR") },
    @{ Province = "KONYA";      Districts = @("KONYA", "SELÇUKLU") },
    @{ Province = "HATAY";      Districts = @("HATAY", "ANTAKYA") },
    @{ Province = "VAN";        Districts = @("VAN", "İPEKYOLU") },
    @{ Province = "SİNOP";      Districts = @("SİNOP", "MERKEZ") }
)

$Headers = @{
    "Accept"          = "application/json, text/plain, */*"
    "Accept-Language" = "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7"
}
$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
             "(KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"

function Normalize([string]$Text) {
    # Türkçe'ye duyarlı kaba normalizasyon — isim eşleştirmesi için yeterli.
    if ($null -eq $Text) { return "" }
    $map = @{
        "ı"="i"; "İ"="I"; "ş"="s"; "Ş"="S"; "ğ"="g"; "Ğ"="G"
        "ü"="u"; "Ü"="U"; "ö"="o"; "Ö"="O"; "ç"="c"; "Ç"="C"
    }
    $result = $Text
    foreach ($key in $map.Keys) { $result = $result.Replace($key, $map[$key]) }
    return $result.ToUpperInvariant().Trim()
}

function Get-Json([string]$Path) {
    $url = "$BaseUrl$Path"
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $Headers `
                        -UserAgent $UserAgent -TimeoutSec 30
            Start-Sleep -Seconds $Delay
            return $response
        } catch {
            $message = $_.Exception.Message
            if ($attempt -eq 3) {
                throw "GET $Path basarisiz: $message"
            }
            Write-Host "    (deneme $attempt basarisiz, tekrar deneniyor...)" -ForegroundColor DarkGray
            Start-Sleep -Seconds ([Math]::Pow(2, $attempt))
        }
    }
}

Write-Host ""
Write-Host "Diyanet vakitleri toplaniyor..." -ForegroundColor Cyan
Write-Host ""

# --- Ülke ve il listeleri --------------------------------------------------

Write-Host "Ulke listesi aliniyor..."
$countries = Get-Json "/ulkeler"
$turkey = $countries | Where-Object {
    (Normalize $_.UlkeAdi) -in @("TURKIYE", "TURKEY")
} | Select-Object -First 1
if ($null -eq $turkey) { throw "Ulke listesinde Turkiye bulunamadi." }
Write-Host "  Turkiye kodu: $($turkey.UlkeID)"

Write-Host "Il listesi aliniyor..."
$provinces = Get-Json "/sehirler/$($turkey.UlkeID)"

# --- Hedefleri çöz ve indir ------------------------------------------------

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$written = 0
$failed  = 0

foreach ($target in $Targets) {
    $provinceName = $target.Province
    $province = $provinces | Where-Object {
        (Normalize $_.SehirAdi) -eq (Normalize $provinceName)
    } | Select-Object -First 1

    if ($null -eq $province) {
        Write-Host "  ATLANDI $provinceName - il listesinde yok" -ForegroundColor Yellow
        $failed++
        continue
    }

    try {
        $districts = Get-Json "/ilceler/$($province.SehirID)"
    } catch {
        Write-Host "  HATA $provinceName - ilce listesi alinamadi: $_" -ForegroundColor Red
        $failed++
        continue
    }

    $chosen = $null
    foreach ($preferred in $target.Districts) {
        $chosen = $districts | Where-Object {
            (Normalize $_.IlceAdi) -eq (Normalize $preferred)
        } | Select-Object -First 1
        if ($null -ne $chosen) { break }
    }
    if ($null -eq $chosen) { $chosen = $districts | Select-Object -First 1 }
    if ($null -eq $chosen) {
        Write-Host "  ATLANDI $provinceName - ilce bulunamadi" -ForegroundColor Yellow
        $failed++
        continue
    }

    try {
        $times = Get-Json "/vakitler/$($chosen.IlceID)"
    } catch {
        Write-Host "  HATA $provinceName - vakitler alinamadi: $_" -ForegroundColor Red
        $failed++
        continue
    }

    $document = [ordered]@{
        provenance      = $Provenance
        mirrorBaseUrl   = $BaseUrl
        endpoint        = "/vakitler/$($chosen.IlceID)"
        province        = $provinceName
        district        = $chosen.IlceAdi
        districtId      = "$($chosen.IlceID)"
        provinceId      = "$($province.SehirID)"
        diyanetPageUrl  = "https://namazvakitleri.diyanet.gov.tr/tr-TR/$($chosen.IlceID)/namaz-vakti"
        fetchedAtLocal  = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        collectedBy     = "fetch_mirror.ps1"
        response        = $times
    }

    $fileName = "$($chosen.IlceID)__$stamp.json"
    $filePath = Join-Path $OutputDir $fileName
    $json = $document | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($filePath, $json, (New-Object System.Text.UTF8Encoding($false)))

    Write-Host ("  {0,-12} {1} gun  ->  {2}" -f $provinceName, $times.Count, $fileName) -ForegroundColor Green
    $written++
}

# --- Özet ------------------------------------------------------------------

Write-Host ""
if ($written -eq 0) {
    Write-Host "Hicbir dosya yazilamadi." -ForegroundColor Red
    Write-Host "Tarayicidan $BaseUrl/ulkeler adresini acip JSON goruyor musunuz, kontrol edin."
} else {
    Write-Host "$written dosya yazildi, $failed basarisiz." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Dosyalar burada:" -ForegroundColor Cyan
    Write-Host "  $OutputDir"
    Write-Host ""
    Write-Host "Simdi GitHub'da: Add file -> Upload files -> bu klasordeki dosyalari surukleyin."
    Write-Host "Hedef klasor: Reference/diyanet/raw/"
}
Write-Host ""
