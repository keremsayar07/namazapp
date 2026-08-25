#!/usr/bin/env python3
"""
Diyanet İşleri Başkanlığı resmi namaz vakti REST servisinden (awqatsalah.diyanet.gov.tr)
referans verisi toplar ve repoya ham JSON olarak yazar.

Neden bu script var
-------------------
PrayerKit'in hesaplama motorunun Diyanet'in yayımladığı vakitlerle dakika hassasiyetinde
karşılaştırılması gerekiyor. Bu veriyi elle toplamak yüzlerce satırlık kopyala-yapıştır
demek. Bu script, GitHub Actions üzerinde çalışarak aynı işi kimse dokunmadan yapar.

Servisin iki kısıtı bu tasarımı belirledi:

1. `/api/PrayerTime/Monthly/{cityId}` **parametre almıyor** — sadece içinde bulunulan ayı
   döndürüyor. Yani geçmiş/gelecek ay çekilemiyor. Çözüm: script her ay çalışır ve o ayı
   arşive ekler. 12 ay sonra tam mevsimsel kapsama kendiliğinden oluşur; ilk çalıştırmada
   bile birden çok şehir için bir aylık gerçek veri elde edilir ve kalibrasyona başlanabilir.

2. Standart kullanıcı rolünde **endpoint başına günde 5 istek** hakkı var (geliştirici
   rolünde 100). Script bu yüzden kota-farkında: her endpoint için tur başına en fazla
   MAX_CALLS_PER_ENDPOINT istek atar, daha önce indirilmiş dosyaları atlar ve kalan işleri
   bir sonraki çalıştırmaya bırakır. Kota yetmezse iş kaybolmaz, sadece ertelenir.

Provenance
----------
Her dosya, servisten dönen ham gövdeyi olduğu gibi saklar; üstüne endpoint yolu ve UTC
indirme zaman damgası eklenir. Hiçbir değer türetilmez, yuvarlanmaz veya tahmin edilmez.

Ortam değişkenleri
------------------
AWQATSALAH_EMAIL / AWQATSALAH_PASSWORD : Diyanet'ten alınan kimlik bilgileri (GitHub Secrets)
MAX_CALLS_PER_ENDPOINT                 : varsayılan 5
REFERENCE_DIR                          : varsayılan Reference/diyanet
"""

from __future__ import annotations

import json
import os
import ssl
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

BASE_URL = "https://awqatsalah.diyanet.gov.tr"
SOURCE_NOTE = "Diyanet İşleri Başkanlığı — Din İşleri Yüksek Kurulu, Awqat Salah REST servisi"

REPO_ROOT = Path(__file__).resolve().parents[2]
REFERENCE_DIR = REPO_ROOT / os.environ.get("REFERENCE_DIR", "Reference/diyanet")

MAX_CALLS_PER_ENDPOINT = int(os.environ.get("MAX_CALLS_PER_ENDPOINT", "5") or "5")
TIMEOUT_SECONDS = 30

# Hedef şehirler: (il adı, tercih edilen ilçe adları).
# Servis Türkiye için State = il, City = ilçe hiyerarşisi kullanıyor. Enlem ve boylam
# yayılımı bilinçli: kuzey-güney farkı (Erzurum 39.9°K / Gaziantep 37.1°K) fajr-isha
# açı hatalarını, doğu-batı farkı (İzmir 27°D / Erzurum 41°D) saat dilimi düzeltmesindeki
# hataları ortaya çıkarır. İkisi de tek şehirle görülemez.
TARGET_PROVINCES: list[tuple[str, list[str]]] = [
    ("İSTANBUL", ["FATİH", "MERKEZ", "İSTANBUL"]),
    ("ANKARA", ["ÇANKAYA", "MERKEZ", "ANKARA"]),
    ("İZMİR", ["KONAK", "MERKEZ", "İZMİR"]),
    ("GAZİANTEP", ["ŞAHİNBEY", "MERKEZ", "GAZİANTEP"]),
    ("ERZURUM", ["YAKUTİYE", "MERKEZ", "ERZURUM"]),
    ("TRABZON", ["ORTAHISAR", "MERKEZ", "TRABZON"]),
]


# ---------------------------------------------------------------------------
# Küçük yardımcılar
# ---------------------------------------------------------------------------

def log(message: str) -> None:
    print(message, flush=True)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def normalize(text: str) -> str:
    """Türkçe'ye duyarlı kaba normalizasyon — isim eşleştirmesi için yeterli."""
    mapping = str.maketrans("ıİşŞğĞüÜöÖçÇ", "iisSgGuUoOcC")
    return text.translate(mapping).upper().strip()


def display_path(path: Path) -> str:
    """Log için kısa yol. REFERENCE_DIR repo dışına ayarlanmışsa mutlak yola düşer."""
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


class QuotaExhausted(Exception):
    """Bu tur için endpoint kotası doldu; kalan iş bir sonraki çalıştırmaya bırakılır."""


# ---------------------------------------------------------------------------
# HTTP istemcisi
# ---------------------------------------------------------------------------

class AwqatSalahClient:
    def __init__(self, email: str, password: str) -> None:
        self._email = email
        self._password = password
        self._token: str | None = None
        self._context = ssl.create_default_context()
        # Endpoint ailesi başına bu turda harcanan istek sayısı.
        self.calls: dict[str, int] = {}

    # -- düşük seviye ------------------------------------------------------

    def _request(self, method: str, path: str, body: dict | None = None,
                 authorized: bool = True) -> dict:
        url = BASE_URL + path
        data = json.dumps(body).encode("utf-8") if body is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("Accept", "application/json")
        if data is not None:
            request.add_header("Content-Type", "application/json")
        if authorized:
            if self._token is None:
                raise RuntimeError("Yetkili istek öncesi giriş yapılmadı.")
            request.add_header("Authorization", f"Bearer {self._token}")

        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS,
                                        context=self._context) as response:
                payload = response.read().decode("utf-8")
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")[:400]
            # 429 = kota; servis bazı durumlarda 403 ile de yanıt verebiliyor.
            if error.code in (403, 429):
                raise QuotaExhausted(f"HTTP {error.code}: {detail}") from error
            raise RuntimeError(f"{method} {path} → HTTP {error.code}: {detail}") from error
        except urllib.error.URLError as error:
            raise RuntimeError(f"{method} {path} → ağ hatası: {error.reason}") from error

        try:
            return json.loads(payload)
        except json.JSONDecodeError as error:
            raise RuntimeError(f"{method} {path} → JSON çözümlenemedi: {payload[:200]}") from error

    def _budgeted_get(self, endpoint_family: str, path: str) -> dict:
        """Endpoint ailesi kotasını gözeterek GET yapar.

        Servisin kotası endpoint bazında ve parametreli varyantlar aynı havuzu paylaşıyor,
        bu yüzden sayacı `path` yerine `endpoint_family` üzerinden tutuyoruz.
        """
        spent = self.calls.get(endpoint_family, 0)
        if spent >= MAX_CALLS_PER_ENDPOINT:
            raise QuotaExhausted(
                f"{endpoint_family}: bu tur için ayrılan {MAX_CALLS_PER_ENDPOINT} istek doldu."
            )
        self.calls[endpoint_family] = spent + 1
        return self._request("GET", path)

    # -- yüksek seviye -----------------------------------------------------

    def login(self) -> None:
        response = self._request(
            "POST", "/api/Auth/Login",
            body={"email": self._email, "password": self._password},
            authorized=False,
        )
        data = response.get("data") or {}
        token = data.get("accessToken")
        if not token:
            raise RuntimeError(
                "Giriş yanıtında accessToken yok. Kimlik bilgileri hatalı olabilir. "
                f"Yanıt: {json.dumps(response)[:300]}"
            )
        self._token = token
        log("Giriş başarılı, access token alındı.")

    def countries(self) -> dict:
        return self._budgeted_get("Place/Countries", "/api/Place/Countries")

    def states(self) -> dict:
        return self._budgeted_get("Place/States", "/api/Place/States")

    def cities(self) -> dict:
        return self._budgeted_get("Place/Cities", "/api/Place/Cities")

    def cities_of_state(self, state_id: int) -> dict:
        return self._budgeted_get("Place/Cities", f"/api/Place/Cities/{state_id}")

    def city_detail(self, city_id: int) -> dict:
        return self._budgeted_get("Place/CityDetail", f"/api/Place/CityDetail/{city_id}")

    def monthly(self, city_id: int) -> dict:
        return self._budgeted_get("PrayerTime/Monthly", f"/api/PrayerTime/Monthly/{city_id}")

    def eid(self, city_id: int) -> dict:
        return self._budgeted_get("PrayerTime/Eid", f"/api/PrayerTime/Eid/{city_id}")

    def ramadan(self, city_id: int) -> dict:
        return self._budgeted_get("PrayerTime/Ramadan", f"/api/PrayerTime/Ramadan/{city_id}")


# ---------------------------------------------------------------------------
# Diske yazma
# ---------------------------------------------------------------------------

def save(relative_path: str, endpoint: str, payload: dict) -> Path:
    target = REFERENCE_DIR / relative_path
    target.parent.mkdir(parents=True, exist_ok=True)
    document = {
        "source": SOURCE_NOTE,
        "baseUrl": BASE_URL,
        "endpoint": endpoint,
        "fetchedAtUTC": utc_now_iso(),
        "note": "Servisten dönen gövde olduğu gibi saklanmıştır; hiçbir değer türetilmemiştir.",
        "response": payload,
    }
    target.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")
    log(f"  yazıldı: {display_path(target)}")
    return target


def exists(relative_path: str) -> bool:
    return (REFERENCE_DIR / relative_path).exists()


def load_json(relative_path: str) -> dict | None:
    target = REFERENCE_DIR / relative_path
    if not target.exists():
        return None
    return json.loads(target.read_text(encoding="utf-8"))


# ---------------------------------------------------------------------------
# Şehir çözümleme
# ---------------------------------------------------------------------------

def resolve_targets(client: AwqatSalahClient) -> list[dict]:
    """Hedef illeri servisin cityId değerlerine çevirir; sonucu diske önbellekler.

    Yer listeleri yılda bir bile değişmiyor, bu yüzden bir kez indirilip repoda saklanıyor.
    Sonraki çalıştırmalar tek bir istek bile harcamıyor.
    """
    cached = load_json("places/resolved-targets.json")
    if cached:
        log("Hedef şehirler önbellekten okundu (istek harcanmadı).")
        return cached["response"]

    if not exists("places/countries.json"):
        save("places/countries.json", "/api/Place/Countries", client.countries())
    if not exists("places/states.json"):
        save("places/states.json", "/api/Place/States", client.states())

    states_doc = load_json("places/states.json") or {}
    states = (states_doc.get("response") or {}).get("data") or []
    if not states:
        raise RuntimeError("İl listesi boş döndü; hedefler çözümlenemiyor.")

    # İl adı → id eşlemesi.
    state_ids: dict[str, int] = {}
    for state in states:
        name = state.get("name") or state.get("stateName") or ""
        if name:
            state_ids[normalize(name)] = state.get("id")

    resolved: list[dict] = []
    for province_name, preferred_districts in TARGET_PROVINCES:
        state_id = state_ids.get(normalize(province_name))
        if state_id is None:
            log(f"  UYARI: '{province_name}' il listesinde bulunamadı, atlanıyor.")
            continue

        cache_key = f"places/cities-state-{state_id}.json"
        if not exists(cache_key):
            save(cache_key, f"/api/Place/Cities/{state_id}", client.cities_of_state(state_id))

        cities_doc = load_json(cache_key) or {}
        districts = (cities_doc.get("response") or {}).get("data") or []
        chosen = None
        for preferred in preferred_districts:
            for district in districts:
                if normalize(district.get("name", "")) == normalize(preferred):
                    chosen = district
                    break
            if chosen:
                break
        if chosen is None and districts:
            chosen = districts[0]
        if chosen is None:
            log(f"  UYARI: '{province_name}' için ilçe bulunamadı, atlanıyor.")
            continue

        resolved.append({
            "province": province_name,
            "district": chosen.get("name"),
            "cityId": chosen.get("id"),
            "stateId": state_id,
        })
        log(f"  çözümlendi: {province_name} / {chosen.get('name')} → cityId={chosen.get('id')}")

    if resolved:
        save("places/resolved-targets.json", "(yerel çözümleme)", resolved)
    return resolved


# ---------------------------------------------------------------------------
# Ana akış
# ---------------------------------------------------------------------------

def main() -> int:
    email = os.environ.get("AWQATSALAH_EMAIL", "").strip()
    password = os.environ.get("AWQATSALAH_PASSWORD", "").strip()

    if not email or not password:
        log(
            "AWQATSALAH_EMAIL / AWQATSALAH_PASSWORD tanımlı değil.\n"
            "Diyanet'ten kimlik bilgisi alınıp GitHub → Settings → Secrets and variables →\n"
            "Actions altına eklenene kadar bu iş yapacak bir şey yok. Hata sayılmıyor."
        )
        return 0

    REFERENCE_DIR.mkdir(parents=True, exist_ok=True)
    client = AwqatSalahClient(email, password)

    try:
        client.login()
    except Exception as error:  # noqa: BLE001 — mesajı kullanıcıya aynen göstermek istiyoruz
        log(f"HATA: giriş yapılamadı → {error}")
        return 1

    now = datetime.now(timezone.utc)
    month_key = now.strftime("%Y-%m")
    year_key = now.strftime("%Y")

    log("\n— Hedef şehirler çözümleniyor —")
    try:
        targets = resolve_targets(client)
    except QuotaExhausted as error:
        log(f"Kota: {error}\nHedef çözümlemesi yarım kaldı, bir sonraki turda devam edecek.")
        return 0
    except Exception as error:  # noqa: BLE001
        log(f"HATA: hedefler çözümlenemedi → {error}")
        return 1

    if not targets:
        log("Çözümlenmiş hedef yok; bir sonraki turda tekrar denenecek.")
        return 0

    # 1) Aylık vakitler — asıl referans veri. Her tur, bu ay için eksik şehirleri tamamlar.
    log(f"\n— {month_key} aylık vakitleri —")
    pending_months = 0
    for target in targets:
        relative = f"monthly/{target['cityId']}-{month_key}.json"
        if exists(relative):
            log(f"  atlandı (zaten var): {target['province']} {month_key}")
            continue
        try:
            payload = client.monthly(target["cityId"])
        except QuotaExhausted as error:
            log(f"  kota doldu: {error}")
            pending_months += 1
            break
        except Exception as error:  # noqa: BLE001
            log(f"  HATA ({target['province']}): {error}")
            continue
        save(relative, f"/api/PrayerTime/Monthly/{target['cityId']}", payload)

    # 2) Kıble açısı ve Kâbe uzaklığı — QiblaMath'i resmi değerle karşılaştırmak için.
    log("\n— Şehir detayları (kıble açısı) —")
    for target in targets:
        relative = f"city-detail/{target['cityId']}.json"
        if exists(relative):
            continue
        try:
            payload = client.city_detail(target["cityId"])
        except QuotaExhausted as error:
            log(f"  kota doldu: {error}")
            break
        except Exception as error:  # noqa: BLE001
            log(f"  HATA ({target['province']}): {error}")
            continue
        save(relative, f"/api/Place/CityDetail/{target['cityId']}", payload)

    # 3) Ramazan ve bayram takvimi — hicri takvimin resmi çapa tarihleri.
    #    Tek şehir yeterli: dini günler ülke genelinde aynı gün.
    anchor = targets[0]
    log("\n— Hicri çapa tarihleri (ramazan / bayram) —")
    for label, relative, call, endpoint in (
        ("ramazan", f"religious-days/ramadan-{anchor['cityId']}-{year_key}.json",
         client.ramadan, f"/api/PrayerTime/Ramadan/{anchor['cityId']}"),
        ("bayram", f"religious-days/eid-{anchor['cityId']}-{year_key}.json",
         client.eid, f"/api/PrayerTime/Eid/{anchor['cityId']}"),
    ):
        if exists(relative):
            log(f"  atlandı (zaten var): {label} {year_key}")
            continue
        try:
            payload = call(anchor["cityId"])
        except QuotaExhausted as error:
            log(f"  kota doldu ({label}): {error}")
            continue
        except Exception as error:  # noqa: BLE001
            log(f"  HATA ({label}): {error}")
            continue
        save(relative, endpoint, payload)

    # 4) Envanter — neyin toplandığı tek bakışta görünsün.
    write_manifest(targets)

    log("\n— Bu turda harcanan istekler —")
    for endpoint_family, count in sorted(client.calls.items()):
        log(f"  {endpoint_family}: {count}")
    if pending_months:
        log("\nBu ay için bazı şehirler kota nedeniyle eksik kaldı; "
            "bir sonraki tur kaldığı yerden devam edecek.")
    return 0


def write_manifest(targets: list[dict]) -> None:
    monthly_dir = REFERENCE_DIR / "monthly"
    months: dict[str, list[str]] = {}
    if monthly_dir.exists():
        for path in sorted(monthly_dir.glob("*.json")):
            city_id, _, month = path.stem.partition("-")
            months.setdefault(month, []).append(city_id)

    manifest = {
        "generatedAtUTC": utc_now_iso(),
        "source": SOURCE_NOTE,
        "targets": targets,
        "monthlyCoverage": {month: sorted(ids) for month, ids in sorted(months.items())},
        "note": (
            "Servisin Monthly endpoint'i yalnızca içinde bulunulan ayı döndürüyor. "
            "Mevsimsel kapsama, bu iş her ay çalıştıkça kendiliğinden birikir."
        ),
    }
    path = REFERENCE_DIR / "manifest.json"
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    log(f"\nEnvanter güncellendi: {display_path(path)}")


if __name__ == "__main__":
    sys.exit(main())
