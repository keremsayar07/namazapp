# Kalibrasyon raporu

Bu dosya `prayerkit-calibrate` tarafından üretilir, elle düzenlenmez.

- Üretim (UTC): `2026-08-25T12:05:47Z`
- Kaynak: `Reference/diyanet/mirror` — bkz. `Tools/diyanet_reference/PROVENANCE.md`
- Yöntem: `CalculationMethod.turkey` (İmsak 18°, Yatsı 17°, akşam offseti 0)
- Şehir sayısı: 12, toplam gün: 384

**Fark tanımı:** `Diyanet − PrayerKit`, dakika cinsinden. Pozitif değer,
Diyanet'in vakti daha geç yayımladığı anlamına gelir; yani hesabımıza o kadar
dakika eklememiz gerekir. **Std sapma sütunu asıl önemli olan:** küçükse fark
sistematik bir temkin payıdır ve sabit offset olarak kodlanabilir; büyükse
ortada offset değil, model farkı vardır ve sabit sayı eklemek yanlış olur.

## Tüm şehirler birleşik

### Şafii ikindi

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.4 | -0.4 | -2.2 | 0.5 | 0.51 | 384 |
| Güneş | -7.3 | -7.3 | -8.2 | -6.7 | 0.32 | 384 |
| Öğle | 5.0 | 5.0 | 4.5 | 5.5 | 0.29 | 384 |
| İkindi | 4.4 | 4.4 | 3.8 | 5.1 | 0.32 | 384 |
| Akşam | 8.0 | 8.0 | 7.3 | 8.9 | 0.33 | 384 |
| Yatsı | 1.4 | 1.3 | 0.5 | 3.2 | 0.53 | 384 |

### Hanefi ikindi

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.4 | -0.4 | -2.2 | 0.5 | 0.51 | 384 |
| Güneş | -7.3 | -7.3 | -8.2 | -6.7 | 0.32 | 384 |
| Öğle | 5.0 | 5.0 | 4.5 | 5.5 | 0.29 | 384 |
| İkindi | -52.3 | -52.2 | -58.7 | -47.0 | 2.88 | 384 |
| Akşam | 8.0 | 8.0 | 7.3 | 8.9 | 0.33 | 384 |
| Yatsı | 1.4 | 1.3 | 0.5 | 3.2 | 0.53 | 384 |

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
| İmsak | -0.2 | -0.2 | -0.6 | 0.3 | 0.29 | 32 |
| Güneş | -7.2 | -7.3 | -7.7 | -6.8 | 0.30 | 32 |
| Öğle | 5.0 | 5.0 | 4.5 | 5.5 | 0.29 | 32 |
| İkindi | 4.5 | 4.6 | 4.0 | 4.9 | 0.28 | 32 |
| Akşam | 7.9 | 7.9 | 7.5 | 8.3 | 0.28 | 32 |
| Yatsı | 1.2 | 1.2 | 0.7 | 1.7 | 0.30 | 32 |

### Antalya (`9225`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.5 | -0.6 | -1.0 | 0.1 | 0.37 | 32 |
| Güneş | -7.3 | -7.3 | -7.9 | -6.9 | 0.28 | 32 |
| Öğle | 4.9 | 4.9 | 4.5 | 5.4 | 0.30 | 32 |
| İkindi | 4.4 | 4.4 | 3.9 | 4.9 | 0.33 | 32 |
| Akşam | 7.9 | 7.9 | 7.5 | 8.4 | 0.27 | 32 |
| Yatsı | 1.2 | 1.2 | 0.7 | 1.8 | 0.29 | 32 |

### Diyarbakır (`9402`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.1 | -0.1 | -0.6 | 0.4 | 0.36 | 32 |
| Güneş | -7.2 | -7.2 | -7.7 | -6.7 | 0.28 | 32 |
| Öğle | 5.0 | 5.0 | 4.5 | 5.5 | 0.28 | 32 |
| İkindi | 4.3 | 4.2 | 3.9 | 4.7 | 0.23 | 32 |
| Akşam | 7.8 | 7.8 | 7.4 | 8.3 | 0.28 | 32 |
| Yatsı | 1.0 | 1.0 | 0.5 | 1.5 | 0.30 | 32 |

### Erzurum (`9451`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.4 | -0.4 | -0.8 | 0.1 | 0.28 | 32 |
| Güneş | -7.3 | -7.3 | -7.8 | -6.8 | 0.29 | 32 |
| Öğle | 5.0 | 5.0 | 4.5 | 5.5 | 0.29 | 32 |
| İkindi | 4.4 | 4.4 | 4.0 | 4.9 | 0.25 | 32 |
| Akşam | 8.0 | 8.0 | 7.5 | 8.5 | 0.29 | 32 |
| Yatsı | 1.4 | 1.4 | 0.9 | 1.9 | 0.30 | 32 |

### Gaziantep (`9479`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.2 | -0.3 | -0.5 | 0.5 | 0.32 | 32 |
| Güneş | -7.2 | -7.2 | -7.6 | -6.7 | 0.29 | 32 |
| Öğle | 5.0 | 5.0 | 4.5 | 5.4 | 0.29 | 32 |
| İkindi | 4.3 | 4.3 | 3.8 | 4.8 | 0.33 | 32 |
| Akşam | 7.8 | 7.8 | 7.3 | 8.3 | 0.31 | 32 |
| Yatsı | 0.9 | 0.9 | 0.5 | 1.4 | 0.29 | 32 |

### Hatay (`20089`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.5 | -0.5 | -1.0 | 0.0 | 0.23 | 32 |
| Güneş | -7.4 | -7.4 | -7.9 | -6.9 | 0.29 | 32 |
| Öğle | 5.0 | 5.0 | 4.5 | 5.5 | 0.30 | 32 |
| İkindi | 4.4 | 4.4 | 3.9 | 4.9 | 0.31 | 32 |
| Akşam | 7.9 | 7.9 | 7.4 | 8.4 | 0.29 | 32 |
| Yatsı | 1.3 | 1.3 | 0.7 | 1.9 | 0.33 | 32 |

### Konya (`9676`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.1 | -0.1 | -0.6 | 0.4 | 0.36 | 32 |
| Güneş | -7.2 | -7.2 | -7.7 | -6.8 | 0.28 | 32 |
| Öğle | 5.0 | 5.0 | 4.5 | 5.5 | 0.29 | 32 |
| İkindi | 4.3 | 4.2 | 3.8 | 4.8 | 0.24 | 32 |
| Akşam | 7.8 | 7.8 | 7.3 | 8.3 | 0.29 | 32 |
| Yatsı | 1.0 | 1.0 | 0.5 | 1.5 | 0.29 | 32 |

### Sinop (`9847`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.0 | 0.0 | -0.5 | 0.5 | 0.29 | 32 |
| Güneş | -7.2 | -7.2 | -7.6 | -6.7 | 0.27 | 32 |
| Öğle | 5.0 | 5.0 | 4.5 | 5.5 | 0.29 | 32 |
| İkindi | 4.4 | 4.4 | 3.9 | 5.0 | 0.28 | 32 |
| Akşam | 7.9 | 7.9 | 7.5 | 8.4 | 0.29 | 32 |
| Yatsı | 1.2 | 1.4 | 0.7 | 1.6 | 0.33 | 32 |

### Trabzon (`9905`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -1.3 | -1.3 | -2.2 | -0.5 | 0.40 | 32 |
| Güneş | -7.6 | -7.6 | -8.0 | -7.1 | 0.28 | 32 |
| Öğle | 4.9 | 4.9 | 4.5 | 5.4 | 0.29 | 32 |
| İkindi | 4.6 | 4.7 | 3.9 | 5.1 | 0.33 | 32 |
| Akşam | 8.3 | 8.2 | 7.6 | 8.8 | 0.32 | 32 |
| Yatsı | 2.3 | 2.2 | 1.3 | 3.2 | 0.45 | 32 |

### Van (`9930`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.3 | -0.2 | -0.8 | 0.2 | 0.30 | 32 |
| Güneş | -7.3 | -7.3 | -7.8 | -6.8 | 0.29 | 32 |
| Öğle | 5.0 | 5.0 | 4.5 | 5.5 | 0.30 | 32 |
| İkindi | 4.5 | 4.5 | 3.9 | 4.9 | 0.33 | 32 |
| Akşam | 7.9 | 7.9 | 7.4 | 8.4 | 0.28 | 32 |
| Yatsı | 1.3 | 1.2 | 0.7 | 1.8 | 0.30 | 32 |

### İstanbul (`9541`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -1.2 | -1.2 | -1.9 | -0.6 | 0.35 | 32 |
| Güneş | -7.7 | -7.7 | -8.2 | -7.2 | 0.31 | 32 |
| Öğle | 5.0 | 5.1 | 4.5 | 5.5 | 0.29 | 32 |
| İkindi | 4.6 | 4.6 | 4.1 | 5.1 | 0.33 | 32 |
| Akşam | 8.4 | 8.4 | 7.8 | 8.9 | 0.31 | 32 |
| Yatsı | 2.2 | 2.3 | 1.5 | 3.0 | 0.36 | 32 |

### İzmir (`9560`) — 32 gün

| Vakit | Ortalama | Medyan | En az | En çok | Std sapma | Gün |
|---|---|---|---|---|---|---|
| İmsak | -0.6 | -0.5 | -1.1 | -0.1 | 0.29 | 32 |
| Güneş | -7.4 | -7.4 | -7.9 | -6.9 | 0.29 | 32 |
| Öğle | 5.0 | 5.0 | 4.5 | 5.4 | 0.29 | 32 |
| İkindi | 4.5 | 4.5 | 3.9 | 4.9 | 0.35 | 32 |
| Akşam | 8.0 | 8.0 | 7.6 | 8.5 | 0.29 | 32 |
| Yatsı | 1.4 | 1.4 | 0.8 | 1.9 | 0.31 | 32 |

