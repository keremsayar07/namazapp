# Kalibrasyon raporu

Bu dosya `prayerkit-calibrate` tarafından üretilir, elle düzenlenmez.

- Üretim (UTC): `2026-08-26T13:26:55Z`
- Kaynak: `Reference/diyanet/mirror` — bkz. `Tools/diyanet_reference/PROVENANCE.md`
- Yöntem: `CalculationMethod.turkey` (İmsak 18°, Yatsı 17° + ölçülen temkin payları)
- Şehir sayısı: 12, toplam gün: 384

## ✅ Geçti

Varsayılan yapılandırmada (Şafii ikindi) her vakit için ortalama fark
±0.5 dakikanın, en uç gün ±2.5 dakikanın içinde.

**Fark tanımı:** `Diyanet − PrayerKit`, dakika cinsinden. Pozitif değer,
Diyanet'in vakti daha geç yayımladığı anlamına gelir; yani hesabımıza o kadar
dakika eklememiz gerekir. **Std sapma sütunu asıl önemli olan:** küçükse fark
sistematik bir temkin payıdır ve sabit offset olarak kodlanabilir; büyükse
ortada offset değil, model farkı vardır ve sabit sayı eklemek yanlış olur.

## Tüm şehirler birleşik

### Şafii ikindi

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.0 | -0.0 | -1.8 | 0.9 | 0.51 | 384 |
| Güneş | -0.0 | -0.0 | -0.9 | 0.6 | 0.32 | 384 |
| Öğle | -0.0 | -0.0 | -0.5 | 0.5 | 0.29 | 384 |
| İkindi | 0.0 | 0.0 | -0.6 | 0.7 | 0.32 | 384 |
| Akşam | -0.0 | -0.0 | -0.7 | 0.9 | 0.33 | 384 |
| Yatsı | 0.1 | 0.0 | -0.8 | 1.8 | 0.53 | 384 |

### Hanefi ikindi

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.0 | -0.0 | -1.8 | 0.9 | 0.51 | 384 |
| Güneş | -0.0 | -0.0 | -0.9 | 0.6 | 0.32 | 384 |
| Öğle | -0.0 | -0.0 | -0.5 | 0.5 | 0.29 | 384 |
| İkindi | -56.7 | -56.6 | -63.1 | -51.5 | 2.88 | 384 |
| Akşam | -0.0 | -0.0 | -0.7 | 0.9 | 0.33 | 384 |
| Yatsı | 0.1 | 0.0 | -0.8 | 1.8 | 0.53 | 384 |

## Fit edilen koordinatlar

Coğrafi koordinat yalnızca aramanın başlangıç noktası; hesaplamada fit edilen
değer kullanıldı. İkisi arasındaki fark küçükse yöntem kendini doğrulamış olur.

| Şehir | Fit enlem | Fit boylam | Coğrafi enlem | Coğrafi boylam | Enlem farkı | Boylam farkı |
|---|---|---|---|---|---|---|
| Ankara | 39.950 | 32.810 | 39.930 | 32.860 | 0.020 | -0.050 |
| Antalya | 36.775 | 30.630 | 36.900 | 30.710 | -0.125 | -0.080 |
| Diyarbakır | 37.944 | 40.179 | 37.910 | 40.230 | 0.034 | -0.051 |
| Erzurum | 39.805 | 41.237 | 39.900 | 41.270 | -0.095 | -0.033 |
| Gaziantep | 37.129 | 37.327 | 37.070 | 37.380 | 0.059 | -0.053 |
| Hatay | 36.052 | 36.112 | 36.200 | 36.160 | -0.148 | -0.048 |
| Konya | 37.915 | 32.439 | 37.870 | 32.490 | 0.045 | -0.051 |
| Sinop | 42.089 | 35.111 | 42.020 | 35.150 | 0.069 | -0.039 |
| Trabzon | 40.571 | 39.644 | 41.000 | 39.720 | -0.429 | -0.076 |
| Van | 38.437 | 43.348 | 38.490 | 43.410 | -0.053 | -0.062 |
| İstanbul | 40.652 | 28.942 | 41.010 | 28.980 | -0.358 | -0.038 |
| İzmir | 38.293 | 27.090 | 38.420 | 27.140 | -0.127 | -0.050 |

## Şehir bazında (Şafii ikindi)

### Ankara (`9206`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | 0.2 | 0.2 | -0.2 | 0.7 | 0.29 | 32 |
| Güneş | 0.1 | 0.0 | -0.4 | 0.6 | 0.30 | 32 |
| Öğle | -0.0 | -0.0 | -0.5 | 0.5 | 0.29 | 32 |
| İkindi | 0.1 | 0.1 | -0.4 | 0.5 | 0.28 | 32 |
| Akşam | -0.1 | -0.1 | -0.5 | 0.3 | 0.28 | 32 |
| Yatsı | -0.1 | -0.1 | -0.6 | 0.4 | 0.30 | 32 |

### Antalya (`9225`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.1 | -0.2 | -0.6 | 0.5 | 0.37 | 32 |
| Güneş | -0.0 | -0.0 | -0.6 | 0.4 | 0.28 | 32 |
| Öğle | -0.1 | -0.1 | -0.5 | 0.4 | 0.30 | 32 |
| İkindi | 0.0 | -0.0 | -0.5 | 0.5 | 0.33 | 32 |
| Akşam | -0.1 | -0.1 | -0.5 | 0.4 | 0.27 | 32 |
| Yatsı | -0.1 | -0.1 | -0.6 | 0.5 | 0.29 | 32 |

### Diyarbakır (`9402`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | 0.3 | 0.3 | -0.2 | 0.8 | 0.36 | 32 |
| Güneş | 0.1 | 0.1 | -0.4 | 0.6 | 0.28 | 32 |
| Öğle | 0.0 | 0.0 | -0.5 | 0.5 | 0.28 | 32 |
| İkindi | -0.1 | -0.2 | -0.5 | 0.3 | 0.23 | 32 |
| Akşam | -0.2 | -0.2 | -0.6 | 0.3 | 0.28 | 32 |
| Yatsı | -0.3 | -0.3 | -0.8 | 0.2 | 0.30 | 32 |

### Erzurum (`9451`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | 0.0 | 0.0 | -0.4 | 0.5 | 0.28 | 32 |
| Güneş | 0.0 | 0.0 | -0.5 | 0.5 | 0.29 | 32 |
| Öğle | -0.0 | -0.0 | -0.5 | 0.5 | 0.29 | 32 |
| İkindi | 0.0 | -0.0 | -0.4 | 0.5 | 0.25 | 32 |
| Akşam | -0.0 | -0.0 | -0.5 | 0.5 | 0.29 | 32 |
| Yatsı | 0.1 | 0.1 | -0.4 | 0.6 | 0.30 | 32 |

### Gaziantep (`9479`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | 0.2 | 0.1 | -0.1 | 0.9 | 0.32 | 32 |
| Güneş | 0.1 | 0.1 | -0.3 | 0.6 | 0.29 | 32 |
| Öğle | -0.0 | -0.0 | -0.5 | 0.4 | 0.29 | 32 |
| İkindi | -0.1 | -0.1 | -0.6 | 0.4 | 0.33 | 32 |
| Akşam | -0.2 | -0.2 | -0.7 | 0.3 | 0.31 | 32 |
| Yatsı | -0.4 | -0.4 | -0.8 | 0.1 | 0.29 | 32 |

### Hatay (`20089`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.1 | -0.1 | -0.6 | 0.4 | 0.23 | 32 |
| Güneş | -0.1 | -0.1 | -0.6 | 0.4 | 0.29 | 32 |
| Öğle | -0.0 | -0.0 | -0.5 | 0.5 | 0.30 | 32 |
| İkindi | -0.0 | -0.0 | -0.5 | 0.5 | 0.31 | 32 |
| Akşam | -0.1 | -0.1 | -0.6 | 0.4 | 0.29 | 32 |
| Yatsı | 0.0 | -0.0 | -0.7 | 0.6 | 0.33 | 32 |

### Konya (`9676`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | 0.3 | 0.3 | -0.2 | 0.8 | 0.36 | 32 |
| Güneş | 0.1 | 0.1 | -0.4 | 0.6 | 0.28 | 32 |
| Öğle | -0.0 | 0.0 | -0.5 | 0.5 | 0.29 | 32 |
| İkindi | -0.1 | -0.2 | -0.6 | 0.4 | 0.24 | 32 |
| Akşam | -0.2 | -0.2 | -0.7 | 0.3 | 0.29 | 32 |
| Yatsı | -0.3 | -0.3 | -0.8 | 0.2 | 0.29 | 32 |

### Sinop (`9847`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | 0.4 | 0.5 | -0.1 | 0.9 | 0.29 | 32 |
| Güneş | 0.1 | 0.1 | -0.3 | 0.6 | 0.27 | 32 |
| Öğle | -0.0 | -0.0 | -0.5 | 0.5 | 0.29 | 32 |
| İkindi | 0.0 | -0.0 | -0.5 | 0.6 | 0.28 | 32 |
| Akşam | -0.1 | -0.1 | -0.5 | 0.4 | 0.29 | 32 |
| Yatsı | -0.1 | 0.1 | -0.7 | 0.3 | 0.33 | 32 |

### Trabzon (`9905`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.9 | -0.9 | -1.8 | -0.1 | 0.40 | 32 |
| Güneş | -0.3 | -0.2 | -0.7 | 0.2 | 0.28 | 32 |
| Öğle | -0.1 | -0.1 | -0.5 | 0.4 | 0.29 | 32 |
| İkindi | 0.2 | 0.3 | -0.5 | 0.7 | 0.33 | 32 |
| Akşam | 0.3 | 0.2 | -0.4 | 0.8 | 0.32 | 32 |
| Yatsı | 1.0 | 0.9 | 0.0 | 1.8 | 0.45 | 32 |

### Van (`9930`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | 0.1 | 0.2 | -0.4 | 0.6 | 0.30 | 32 |
| Güneş | 0.0 | 0.0 | -0.4 | 0.5 | 0.29 | 32 |
| Öğle | -0.0 | 0.0 | -0.5 | 0.5 | 0.30 | 32 |
| İkindi | 0.1 | 0.1 | -0.5 | 0.5 | 0.33 | 32 |
| Akşam | -0.1 | -0.1 | -0.6 | 0.4 | 0.28 | 32 |
| Yatsı | -0.0 | -0.1 | -0.6 | 0.5 | 0.30 | 32 |

### İstanbul (`9541`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.8 | -0.8 | -1.6 | -0.2 | 0.35 | 32 |
| Güneş | -0.4 | -0.4 | -0.9 | 0.1 | 0.31 | 32 |
| Öğle | 0.0 | 0.1 | -0.5 | 0.5 | 0.29 | 32 |
| İkindi | 0.2 | 0.2 | -0.3 | 0.7 | 0.33 | 32 |
| Akşam | 0.4 | 0.4 | -0.2 | 0.9 | 0.31 | 32 |
| Yatsı | 0.9 | 1.0 | 0.2 | 1.7 | 0.36 | 32 |

### İzmir (`9560`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.2 | -0.1 | -0.7 | 0.3 | 0.29 | 32 |
| Güneş | -0.1 | -0.1 | -0.6 | 0.4 | 0.29 | 32 |
| Öğle | -0.0 | -0.0 | -0.5 | 0.4 | 0.29 | 32 |
| İkindi | 0.1 | 0.1 | -0.5 | 0.5 | 0.35 | 32 |
| Akşam | 0.0 | 0.0 | -0.4 | 0.5 | 0.29 | 32 |
| Yatsı | 0.1 | 0.1 | -0.5 | 0.6 | 0.31 | 32 |

