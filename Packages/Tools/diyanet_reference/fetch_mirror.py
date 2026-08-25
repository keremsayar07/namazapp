#!/usr/bin/env python3
"""
Diyanet vakitlerini, Diyanet'in kendi servisini yeniden yayımlayan açık bir ayna üzerinden
toplar: https://ezanvakti.emushaf.net

Neden ayna
----------
Diyanet'in resmi REST servisi (`awqatsalah.diyanet.gov.tr`) kimlik bilgisi istiyor ve başvuru
süreci günler sürebiliyor; ayrıca `*.diyanet.gov.tr` alan adları yurt dışı IP'lerden sık sık
zaman aşımına uğruyor (GitHub Actions koşucuları da yurt dışında). Bu ayna kimlik bilgisi
istemiyor, kotası yok ve bugün çalışıyor.

Verinin Diyanet kaynaklı olduğuna dair göstergeler
--------------------------------------------------
- İlçe kimlikleri Diyanet'in kendi site adresleriyle birebir aynı
  (İSTANBUL = 9541 → namazvakitleri.diyanet.gov.tr/tr-TR/9541/istanbul-icin-namaz-vakti).
- Yanıttaki `AyinSekliURL` alanı doğrudan `namazvakti.diyanet.gov.tr/images/...` adreslerini
  gösteriyor — yani kayıtlar Diyanet'in kendi servisinden geçiyor.
- Alan adları Diyanet'in kendi terminolojisi: Imsak, Gunes, Ogle, Ikindi, Aksam, Yatsi,
  KibleSaati, HicriTarihKisa/Uzun.

Buna rağmen bu **birincil kaynak değil**. Bu yüzden her dosyaya `provenance` alanı yazılıyor
ve `PROVENANCE.md` içindeki elle doğrulama adımı tamamlanmadan bu veriden üretilen hiçbir
fixture "Diyanet doğrulamalı" sayılmayacak.

Kapsama
-------
Servis, kayan bir ~31 günlük pencere döndürüyor (bugünden birkaç gün öncesi + bir ay sonrası).
Script kayıtları tarih bazında biriktirdiği için, düzenli çalıştıkça arşiv kendiliğinden
büyüyor ve bir yıl içinde tam mevsimsel kapsama oluşuyor.

Ortam değişkenleri
------------------
MIRROR_BASE_URL : varsayılan https://ezanvakti.emushaf.net
REFERENCE_DIR   : varsayılan Reference/diyanet
REQUEST_DELAY   : istekler arası bekleme, saniye (varsayılan 1.0 — aynaya nazik olmak için)
"""

from __future__ import annotations

import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

BASE_URL = os.environ.get("MIRROR_BASE_URL", "https://ezanvakti.emushaf.net").rstrip("/")
REPO_ROOT = Path(__file__).resolve().parents[2]
REFERENCE_DIR = REPO_ROOT / os.environ.get("REFERENCE_DIR", "Reference/diyanet")
MIRROR_DIR = REFERENCE_DIR / "mirror"
REQUEST_DELAY = float(os.environ.get("REQUEST_DELAY", "1.0"))
TIMEOUT_SECONDS = 30

PROVENANCE = (
    "Diyanet İşleri Başkanlığı vakitlerini yeniden yayımlayan üçüncü taraf ayna "
    "(ezanvakti.emushaf.net). Birincil kaynak değildir — bkz. PROVENANCE.md."
)

# Hedef iller ve tercih edilen ilçeler. Enlem-boylam yayılımı bilinçli: kuzey-güney farkı
# imsak/yatsı açı hatalarını, doğu-batı farkı saat dilimi düzeltmesi hatalarını ortaya
# çıkarır. Aynanın kotası olmadığı için resmi API planındaki 6 şehirden fazlasını alabiliyoruz.
TARGET_PROVINCES: list[tuple[str, list[str]]] = [
    ("İSTANBUL", ["İSTANBUL", "FATİH"]),
    ("ANKARA", ["ANKARA", "ÇANKAYA"]),
    ("İZMİR", ["İZMİR", "KONAK"]),
    ("ANTALYA", ["ANTALYA", "MURATPAŞA"]),
    ("GAZİANTEP", ["GAZİANTEP", "ŞAHİNBEY"]),
    ("DİYARBAKIR", ["DİYARBAKIR", "BAĞLAR"]),
    ("ERZURUM", ["ERZURUM", "YAKUTİYE"]),
    ("TRABZON", ["TRABZON", "ORTAHISAR"]),
    ("KONYA", ["KONYA", "SELÇUKLU"]),
    ("HATAY", ["HATAY", "ANTAKYA"]),
    ("VAN", ["VAN", "İPEKYOLU"]),
    ("SİNOP", ["SİNOP", "MERKEZ"]),
]


def log(message: str) -> None:
    print(message, flush=True)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def normalize(text: str) -> str:
    """Türkçe'ye duyarlı kaba normalizasyon — isim eşleştirmesi için yeterli."""
    mapping = str.maketrans("ıİşŞğĞüÜöÖçÇâÂîÎ", "iisSgGuUoOcCaAiI")
    return text.translate(mapping).upper().strip()


def display_path(path: Path) -> str:
    """Log için kısa yol. REFERENCE_DIR repo dışına ayarlanmışsa mutlak yola düşer."""
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


_ssl_context = ssl.create_default_context()

# Ayna Cloudflare arkasında. Varsayılan Python User-Agent'ı ile gelen istekler "Just a
# moment…" ara sayfasına düşüyor. Sıradan bir tarayıcı başlık seti çoğu zaman yeterli
# oluyor; olmuyorsa iş burada BİTER — challenge çözmeye çalışmıyoruz, veriyi kullanıcının
# kendi makinesinden toplama yoluna geçiyoruz (bkz. fetch_mirror.ps1).
BROWSER_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Connection": "keep-alive",
}


class MirrorBlocked(Exception):
    """Ayna, Cloudflare bot korumasıyla isteği reddetti."""


def get_json(path: str, attempts: int = 3) -> list | dict:
    url = BASE_URL + path
    last_error: Exception | None = None

    for attempt in range(1, attempts + 1):
        request = urllib.request.Request(url, method="GET")
        for header, value in BROWSER_HEADERS.items():
            request.add_header(header, value)
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS,
                                        context=_ssl_context) as response:
                payload = response.read().decode("utf-8")
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            if error.code in (403, 503) and "Just a moment" in detail:
                raise MirrorBlocked(
                    f"GET {path} → HTTP {error.code}: Cloudflare bot koruması. "
                    "Bu ağdan (GitHub Actions koşucusu) aynaya erişilemiyor."
                ) from error
            last_error = RuntimeError(f"GET {path} → HTTP {error.code}: {detail[:300]}")
        except urllib.error.URLError as error:
            last_error = RuntimeError(f"GET {path} → ağ hatası: {error.reason}")
        else:
            time.sleep(REQUEST_DELAY)
            try:
                return json.loads(payload)
            except json.JSONDecodeError as error:
                raise RuntimeError(
                    f"GET {path} → JSON çözümlenemedi: {payload[:200]}"
                ) from error

        if attempt < attempts:
            time.sleep(2 ** attempt)

    raise last_error or RuntimeError(f"GET {path} → bilinmeyen hata")


# ---------------------------------------------------------------------------
# Yer çözümleme (bir kez yapılır, sonra repoda önbelleklenir)
# ---------------------------------------------------------------------------

def resolve_targets() -> list[dict]:
    cache = MIRROR_DIR / "places" / "resolved-targets.json"
    if cache.exists():
        log("Hedef ilçeler önbellekten okundu (istek harcanmadı).")
        return json.loads(cache.read_text(encoding="utf-8"))["targets"]

    log("Ülke listesi alınıyor…")
    countries = get_json("/ulkeler")
    turkey_code = None
    for country in countries:
        name = country.get("UlkeAdi") or country.get("UlkeAdiEn") or ""
        if normalize(name) in ("TURKIYE", "TURKEY"):
            turkey_code = country.get("UlkeID")
            break
    if turkey_code is None:
        raise RuntimeError("Ülke listesinde Türkiye bulunamadı.")
    log(f"  Türkiye kodu: {turkey_code}")

    log("İl listesi alınıyor…")
    provinces = get_json(f"/sehirler/{turkey_code}")
    province_ids: dict[str, str] = {}
    for province in provinces:
        name = province.get("SehirAdi") or province.get("SehirAdiEn") or ""
        if name:
            province_ids[normalize(name)] = province.get("SehirID")

    targets: list[dict] = []
    for province_name, preferred_districts in TARGET_PROVINCES:
        province_id = province_ids.get(normalize(province_name))
        if province_id is None:
            log(f"  UYARI: '{province_name}' il listesinde yok, atlanıyor.")
            continue

        districts = get_json(f"/ilceler/{province_id}")
        chosen = None
        for preferred in preferred_districts:
            for district in districts:
                if normalize(district.get("IlceAdi", "")) == normalize(preferred):
                    chosen = district
                    break
            if chosen:
                break
        if chosen is None and districts:
            chosen = districts[0]
        if chosen is None:
            log(f"  UYARI: '{province_name}' için ilçe bulunamadı, atlanıyor.")
            continue

        targets.append({
            "province": province_name,
            "district": chosen.get("IlceAdi"),
            "districtId": str(chosen.get("IlceID")),
            "provinceId": str(province_id),
            "diyanetPageUrl": (
                "https://namazvakitleri.diyanet.gov.tr/tr-TR/"
                f"{chosen.get('IlceID')}/namaz-vakti"
            ),
        })
        log(f"  çözümlendi: {province_name} / {chosen.get('IlceAdi')} → {chosen.get('IlceID')}")

    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_text(
        json.dumps({"resolvedAtUTC": utc_now_iso(), "targets": targets},
                   ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return targets


# ---------------------------------------------------------------------------
# Vakit toplama — tarih bazında birikimli
# ---------------------------------------------------------------------------

def iso_date(entry: dict) -> str | None:
    """`MiladiTarihKisa` alanını ("19.08.2026") ISO biçimine çevirir."""
    raw = (entry.get("MiladiTarihKisa") or "").strip()
    parts = raw.split(".")
    if len(parts) != 3:
        return None
    day, month, year = parts
    if not (day.isdigit() and month.isdigit() and year.isdigit()):
        return None
    return f"{int(year):04d}-{int(month):02d}-{int(day):02d}"


def collect(target: dict) -> tuple[int, int]:
    """Bir ilçenin kayan penceresini indirir ve arşive birleştirir."""
    entries = get_json(f"/vakitler/{target['districtId']}")
    return merge_entries(target, entries)


def merge_entries(target: dict, entries: object) -> tuple[int, int]:
    """Kayıtları aya göre böler ve mevcut arşive birleştirir.

    Aynı gün için zaten kayıt varsa dokunulmaz — arşiv yalnızca büyür, geçmiş yeniden
    yazılmaz. Böylece bir gün ayna hatalı veri dönerse eski doğru kayıt korunur ve fark
    `conflicts` olarak raporlanır.
    """
    if not isinstance(entries, list):
        raise RuntimeError(f"Beklenmeyen yanıt biçimi: {type(entries).__name__}")

    by_month: dict[str, dict[str, dict]] = {}
    for entry in entries:
        date_key = iso_date(entry)
        if date_key is None:
            continue
        by_month.setdefault(date_key[:7], {})[date_key] = entry

    added = conflicts = 0
    for month_key, days in sorted(by_month.items()):
        path = MIRROR_DIR / target["districtId"] / f"{month_key}.json"
        path.parent.mkdir(parents=True, exist_ok=True)

        if path.exists():
            document = json.loads(path.read_text(encoding="utf-8"))
            existing: dict = document.get("days", {})
        else:
            document = {
                "provenance": PROVENANCE,
                "mirrorBaseUrl": BASE_URL,
                "endpoint": f"/vakitler/{target['districtId']}",
                "province": target["province"],
                "district": target["district"],
                "districtId": target["districtId"],
                "diyanetPageUrl": target["diyanetPageUrl"],
                "month": month_key,
                "days": {},
            }
            existing = document["days"]

        for date_key, entry in sorted(days.items()):
            if date_key in existing:
                if existing[date_key] != entry:
                    conflicts += 1
                    log(f"    ÇAKIŞMA {target['province']} {date_key}: "
                        "arşivdeki kayıt korundu, aynadan gelen farklıydı.")
                continue
            existing[date_key] = entry
            added += 1

        document["days"] = dict(sorted(existing.items()))
        document["dayCount"] = len(document["days"])
        document["lastUpdatedUTC"] = utc_now_iso()
        path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n",
                        encoding="utf-8")

    return added, conflicts


def write_manifest_from_disk() -> None:
    """Hedef listesi elde yokken (ör. ayna engelliyken) arşivi tarayıp envanter üretir."""
    targets: list[dict] = []
    for directory in sorted(p for p in MIRROR_DIR.iterdir() if p.is_dir()):
        if directory.name == "places":
            continue
        months = sorted(directory.glob("*.json"))
        if not months:
            continue
        sample = json.loads(months[0].read_text(encoding="utf-8"))
        targets.append({
            "province": sample.get("province", "?"),
            "district": sample.get("district", "?"),
            "districtId": directory.name,
            "diyanetPageUrl": sample.get("diyanetPageUrl", ""),
        })
    write_manifest(targets)


def write_manifest(targets: list[dict]) -> None:
    coverage: dict[str, dict] = {}
    total_days = 0
    for target in targets:
        directory = MIRROR_DIR / target["districtId"]
        months: dict[str, int] = {}
        if directory.exists():
            for path in sorted(directory.glob("*.json")):
                document = json.loads(path.read_text(encoding="utf-8"))
                months[path.stem] = document.get("dayCount", 0)
                total_days += document.get("dayCount", 0)
        coverage[target["districtId"]] = {
            "province": target["province"],
            "district": target["district"],
            "diyanetPageUrl": target["diyanetPageUrl"],
            "months": months,
            "totalDays": sum(months.values()),
        }

    manifest = {
        "generatedAtUTC": utc_now_iso(),
        "provenance": PROVENANCE,
        "verificationStatus": "BEKLEMEDE — bkz. PROVENANCE.md",
        "totalDayRecords": total_days,
        "coverage": coverage,
        "note": (
            "Ayna kayan ~31 günlük bir pencere döndürüyor. Bu iş düzenli çalıştıkça arşiv "
            "kendiliğinden büyür; bir yıl sonra tam mevsimsel kapsama oluşur."
        ),
    }
    path = MIRROR_DIR / "manifest.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    log(f"\nEnvanter: {display_path(path)} — toplam {total_days} günlük kayıt")


RAW_DIR_NAME = "raw"


def ingest_raw_dumps() -> tuple[int, int, int]:
    """Elle bırakılmış ham dökümleri arşive işler — ağ erişimi gerektirmez.

    `fetch_mirror.ps1` kullanıcının kendi bilgisayarında çalışıp `Reference/diyanet/raw/`
    altına dosya bırakıyor. Cloudflare bu depodan aynaya erişimi engellediğinde yol bu.
    Ham dosyalar asla silinmez: kaynak kayıt olarak repoda kalır.
    """
    raw_dir = REFERENCE_DIR / RAW_DIR_NAME
    if not raw_dir.exists():
        return 0, 0, 0

    dumps = sorted(raw_dir.glob("*.json"))
    if not dumps:
        return 0, 0, 0

    log(f"\n— {len(dumps)} ham döküm işleniyor (ağ kullanılmıyor) —")
    added = conflicts = processed = 0
    for dump in dumps:
        try:
            document = json.loads(dump.read_text(encoding="utf-8"))
            target = {
                "province": document.get("province", "?"),
                "district": document.get("district", "?"),
                "districtId": str(document["districtId"]),
                "provinceId": str(document.get("provinceId", "")),
                "diyanetPageUrl": document.get(
                    "diyanetPageUrl",
                    "https://namazvakitleri.diyanet.gov.tr/tr-TR/"
                    f"{document['districtId']}/namaz-vakti",
                ),
            }
            day_added, day_conflicts = merge_entries(target, document.get("response"))
        except Exception as error:  # noqa: BLE001
            log(f"  ATLANDI {dump.name}: {error}")
            continue
        processed += 1
        added += day_added
        conflicts += day_conflicts
        log(f"  {dump.name}: +{day_added} yeni gün")

    return processed, added, conflicts


def archive_day_count() -> int:
    """Arşivde şu an kaç günlük kayıt olduğunu sayar."""
    total = 0
    if not MIRROR_DIR.exists():
        return 0
    for directory in MIRROR_DIR.iterdir():
        if not directory.is_dir() or directory.name == "places":
            continue
        for path in directory.glob("*.json"):
            try:
                total += json.loads(path.read_text(encoding="utf-8")).get("dayCount", 0)
            except Exception:  # noqa: BLE001 — bozuk tek dosya sayımı düşürmesin
                continue
    return total


MANUAL_COLLECTION_HINT = (
    "\nYapılacak: Tools/diyanet_reference/fetch_mirror.ps1 dosyasını kendi bilgisayarınızda\n"
    "çalıştırıp oluşan dosyaları GitHub'da Reference/diyanet/raw/ klasörüne yükleyin.\n"
    "Ayrıntılı adımlar: Tools/diyanet_reference/README.md"
)


def offline_exit_code(raw_processed: int, raw_added: int) -> int:
    """Aynaya ulaşılamadığında işin kırmızı mı yeşil mi biteceğine karar verir.

    Ayna bu depodan kalıcı olarak engelli olabilir; bu bir kod hatası değil. Arşivde veri
    varsa (ya da bu turda ham dökümlerden veri geldiyse) tur başarılıdır — aksi hâlde
    haftada iki kez boş yere kırmızı bildirim gelir ve gerçek hatalar gözden kaçar.
    Yalnızca elde hiç veri yokken kırmızı biter, çünkü o zaman gerçekten yapılacak bir iş var.
    """
    archived = archive_day_count()
    if raw_added:
        log(f"Ham dökümlerden +{raw_added} yeni gün işlendi, iş başarılı sayılıyor.")
        return 0
    if archived:
        log(f"Yeni veri yok; arşivde {archived} günlük kayıt duruyor, iş başarılı sayılıyor.")
        if raw_processed == 0:
            log(MANUAL_COLLECTION_HINT)
        return 0
    log("Arşiv boş ve aynaya ulaşılamıyor.")
    log(MANUAL_COLLECTION_HINT)
    return 1


def main() -> int:
    MIRROR_DIR.mkdir(parents=True, exist_ok=True)

    # 1) Önce elle bırakılmış ham dökümler — bunlar ağ gerektirmediği için her zaman işler.
    raw_processed, raw_added, raw_conflicts = ingest_raw_dumps()

    # 2) Sonra doğrudan aynadan çekmeyi dene.
    try:
        targets = resolve_targets()
    except (MirrorBlocked, Exception) as error:  # noqa: B014 — ikisi de aynı şekilde ele alınıyor
        if isinstance(error, MirrorBlocked):
            log(f"\nAYNA ENGELLİ: {error}")
        else:
            log(f"\nAynaya ulaşılamadı → {error}")
        write_manifest_from_disk()
        return offline_exit_code(raw_processed, raw_added)

    if not targets:
        log("Çözümlenmiş hedef yok.")
        write_manifest_from_disk()
        return offline_exit_code(raw_processed, raw_added)

    log(f"\n— {len(targets)} ilçe için vakitler toplanıyor —")
    total_added = total_conflicts = failures = 0
    blocked = False
    for target in targets:
        try:
            added, conflicts = collect(target)
        except MirrorBlocked as error:
            log(f"\nAYNA ENGELLİ: {error}")
            blocked = True
            break
        except Exception as error:  # noqa: BLE001
            log(f"  HATA ({target['province']}): {error}")
            failures += 1
            continue
        total_added += added
        total_conflicts += conflicts
        log(f"  {target['province']:<12} +{added} yeni gün")

    write_manifest(targets)

    log(f"\nÖzet: ağdan +{total_added}, ham dökümlerden +{raw_added} günlük kayıt; "
        f"{total_conflicts + raw_conflicts} çakışma, {failures} başarısız ilçe.")

    if blocked and not total_added:
        return offline_exit_code(raw_processed, raw_added)
    # Tek tük ilçe hatası işi kırmızıya düşürmesin; hiç veri gelmediyse düşsün.
    if failures == len(targets):
        return offline_exit_code(raw_processed, raw_added)
    return 0


if __name__ == "__main__":
    sys.exit(main())
