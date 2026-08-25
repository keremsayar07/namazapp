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


def get_json(path: str) -> list | dict:
    url = BASE_URL + path
    request = urllib.request.Request(url, method="GET")
    request.add_header("Accept", "application/json")
    request.add_header("User-Agent", "namaz-app-reference-collector/1.0")
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS,
                                    context=_ssl_context) as response:
            payload = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[:300]
        raise RuntimeError(f"GET {path} → HTTP {error.code}: {detail}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"GET {path} → ağ hatası: {error.reason}") from error
    finally:
        time.sleep(REQUEST_DELAY)

    try:
        return json.loads(payload)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"GET {path} → JSON çözümlenemedi: {payload[:200]}") from error


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
    """Bir ilçenin kayan penceresini indirir, aya göre böler ve mevcut arşive birleştirir.

    Aynı gün için zaten kayıt varsa dokunulmaz — arşiv yalnızca büyür, geçmiş yeniden
    yazılmaz. Böylece bir gün ayna hatalı veri dönerse eski doğru kayıt korunur ve fark
    `conflicts` olarak raporlanır.
    """
    entries = get_json(f"/vakitler/{target['districtId']}")
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


def main() -> int:
    MIRROR_DIR.mkdir(parents=True, exist_ok=True)

    try:
        targets = resolve_targets()
    except Exception as error:  # noqa: BLE001
        log(f"HATA: hedefler çözümlenemedi → {error}")
        return 1

    if not targets:
        log("Çözümlenmiş hedef yok.")
        return 1

    log(f"\n— {len(targets)} ilçe için vakitler toplanıyor —")
    total_added = total_conflicts = failures = 0
    for target in targets:
        try:
            added, conflicts = collect(target)
        except Exception as error:  # noqa: BLE001
            log(f"  HATA ({target['province']}): {error}")
            failures += 1
            continue
        total_added += added
        total_conflicts += conflicts
        log(f"  {target['province']:<12} +{added} yeni gün")

    write_manifest(targets)

    log(f"\nÖzet: +{total_added} yeni günlük kayıt, {total_conflicts} çakışma, "
        f"{failures} başarısız ilçe.")
    # Tek tük ilçe hatası işi kırmızıya düşürmesin; hepsi başarısızsa düşsün.
    return 1 if failures == len(targets) else 0


if __name__ == "__main__":
    sys.exit(main())
