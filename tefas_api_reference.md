# TEFAS API Referansı

> Kaynak: https://github.com/maku-cpu/fonlar-mcp
> Site: https://www.tefas.gov.tr (Next.js + Akamai TSPD, Nisan 2026 yenileme sonrası)

---

## Temel Bilgiler

```
Base URL    : https://www.tefas.gov.tr
Method      : POST (tüm endpoint'ler)
Content-Type: application/json
Auth        : Yok (public API)
Dil         : "TR"
```

### Zorunlu HTTP Headers

```
User-Agent     : Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36
Accept         : application/json, text/plain, */*
Accept-Language: tr-TR,tr;q=0.9,en;q=0.8
Accept-Encoding: gzip, deflate, br, zstd
Origin         : https://www.tefas.gov.tr
Referer        : https://www.tefas.gov.tr/tr/
Content-Type   : application/json
sec-ch-ua      : "Chromium";v="131", "Not_A Brand";v="24"
sec-ch-ua-mobile    : ?0
sec-ch-ua-platform  : "macOS"
Sec-Fetch-Dest : empty
Sec-Fetch-Mode : cors
Sec-Fetch-Site : same-origin
```

---

## Rate Limiting

| Kural | Değer |
|-------|-------|
| İstek limiti | ~6 istek/dakika |
| Minimum aralık | 10 saniye (ardışık çağrılar arası) |
| Limit aşımı davranışı | HTTP 429 VEYA boş body + HTTP 200 |
| Retry-After header | Var (429 durumunda) |
| Max retry | 5 |
| Backoff | Exponential (`min(2^attempt * 5, 60)` sn) |

**Dikkat:** TEFAS bazen 429 yerine boş body + 200 döner. Her iki durumu da rate-limit olarak ele almak gerekir.

---

## Session Yönetimi (Akamai TSPD Bot Koruması)

TEFAS, Next.js tabanlı yeni sitesinde Akamai TSPD bot koruması kullanıyor. Doğrudan POST yapmadan önce warmup zorunlu:

```
1. GET https://www.tefas.gov.tr/tr/
   → Session cookie alınır

2. GET https://www.tefas.gov.tr/tr/FonAnaliz/FonKarsilastirma.aspx
   → API çağrılarına izin veren ek cookie'ler set edilir

3. POST endpoint'leri artık çalışır
```

**Session TTL:** 600 saniye (10 dakika). Süresi dolan session'ı yenilemeden POST atarsan ilk istek boş döner.

**Neden 2. GET?** Bu olmadan ilk POST boş yanıt verir. Session yenilenirken cookie'leri sıfırlamamak gerekir — aksi halde Akamai challenge döngüsüne girer.

---

## Tarih Formatı

- **Format:** `YYYYMMDD` (örn: `"20260424"`)
- **Kabul edilen alternatifler:** `YYYY-MM-DD`, `DD.MM.YYYY`
- **Tek POST'ta max aralık:** 28 gün (bu limiti aşan aralıklar chunking ile parçalanmalı)

---

## Periyod Kodları

| İnsan-okunur | Sayısal kod |
|-------------|-------------|
| hafta (~5 iş günü) | `13` |
| 1 ay | `1` |
| 3 ay | `3` |
| 6 ay | `6` |
| 1 yıl | `12` |
| 3 yıl | `36` |
| 5 yıl | `60` |

---

## Yanıt Formatı

Tüm endpoint'ler iki yapıdan birini döner:

```json
{ "resultList": [ {...}, {...} ] }
```
```json
{ "data": [ {...}, {...} ] }
```

`/api/fund-returns/export` doğrudan `[...]` döner (üst sarmalayıcı yok).

---

## Endpoint Referansı

### 1. `POST /api/funds/fonFiyatBilgiGetir`
Bir fonun günlük fiyat geçmişi.

**Request:**
```json
{
  "fonKodu": "AAK",
  "dil": "TR",
  "periyod": 12
}
```

**Response item:**
```json
{
  "fonKodu": "AAK",
  "fonUnvan": "AAK Portföy Hisse Senedi Fonu",
  "tarih": "2026-04-24",
  "fiyat": 125.45,
  "kategoriDerece": 1,
  "kategoriFonSay": 42
}
```

**Not:** `periyod` değerleri için Periyod Kodları tablosuna bak.

---

### 2. `POST /api/funds/fonBilgiGetir`
Tek fonun güncel anlık bilgisi.

**Request:**
```json
{
  "fonKodu": "AAK",
  "dil": "TR"
}
```

**Response item (önemli alanlar):**
```json
{
  "fonKodu": "AAK",
  "fonUnvan": "...",
  "portBuyukluk": 5200000000,
  "yatirimciSayisi": 45000,
  "sonFiyat": 125.45,
  "gunlukGetiri": 0.52
}
```

---

### 3. `POST /api/funds/fonProfilDtyGetir`
Kategori derecesi + fon türü ortalama getirisi.

**Request:**
```json
{
  "fonKodu": "AAK",
  "dil": "TR",
  "periyod": 12
}
```

---

### 4. `POST /api/funds/fonGnlBlgSiraliGetir`
Tarih aralığında tüm fonların günlük detayı — **en hızlı bulk fiyat yöntemi**.

**Request:**
```json
{
  "fonTipi": "YAT",
  "fonKodu": null,
  "aramaMetni": null,
  "fonTurKod": null,
  "fonGrubu": null,
  "sfonTurKod": null,
  "basTarih": "20260424",
  "bitTarih": "20260424",
  "basSira": 1,
  "bitSira": 250,
  "fonTurAciklama": null,
  "dil": "TR",
  "kurucuKod": null
}
```

**Pagination:** `basSira` / `bitSira` ile sayfalanır. Sayfa boyutu max ~250 önerilir. 1000+ fon için 4-10 istek gerekir.

**Response item:**
```json
{
  "fonKodu": "AAK",
  "fonUnvan": "...",
  "tarih": "20260424",
  "fiyat": 125.45,
  "tedPaySayisi": 12345678,
  "kisiSayisi": 45000,
  "portfoyBuyukluk": 5200000000
}
```

**Filtreleme:** `aramaMetni` ile belirli fon kodu aranabilir. `kurucuKod` ile kurucu filtresi.

---

### 5. `POST /api/funds/dagilimSiraliGetirT`
Portföy dağılımı (tek fon veya sayfalı liste).

**Request (tek fon):**
```json
{
  "fonTipi": "YAT",
  "fonKodu": null,
  "aramaMetni": null,
  "fonTurKod": null,
  "fonGrubu": null,
  "sfonTurKod": null,
  "basTarih": "20260424",
  "bitTarih": "20260424",
  "basSira": 1,
  "bitSira": 1,
  "fonTurAciklama": null,
  "dil": "TR",
  "kurucuKod": null,
  "sFonTurKod": "",
  "fonKod": "AAK",
  "fonGrup": "",
  "fonUnvanTip": ""
}
```

**Response item:** Kısa kodlar ve yüzde değerleri içerir:
```json
{
  "fonKodu": "AAK",
  "fonUnvan": "...",
  "tarih": "2026-04-24",
  "hs": 78.5,
  "tr": 15.3,
  "d": 6.2,
  "vint": null,
  "yyf": null
}
```

**Not:** Null olan alanlar = o kategoride varlık yok. Kısa kodların tam listesi aşağıda.

---

### 6. `POST /api/funds/fonGetiriBazliBilgiGetir`
Tüm fonların dönemsel getirileri — **tek istekte** tüm fonlar gelir, sayfalama yok.

**Request (standart dönemler):**
```json
{
  "dil": "TR",
  "fonTipi": "YAT",
  "kurucuKodu": null,
  "sfonTurKod": null,
  "fonTurAciklama": null,
  "islem": 1,
  "fonTurKod": null,
  "fonGrubu": null,
  "donemGetiri1a": "1",
  "donemGetiri3a": "1",
  "donemGetiri6a": "1",
  "donemGetiri1y": "1",
  "donemGetiriyb": "1",
  "donemGetiri3y": "1",
  "donemGetiri5y": "1",
  "basTarih": null,
  "bitTarih": null,
  "calismaTipi": 2,
  "getiriOrani": "1"
}
```

**Request (özel tarih aralığı):**
```json
{
  "dil": "TR",
  "fonTipi": "YAT",
  "donemGetiri1a": "0",
  "donemGetiri3a": "0",
  "donemGetiri6a": "0",
  "donemGetiri1y": "0",
  "donemGetiriyb": "0",
  "donemGetiri3y": "0",
  "donemGetiri5y": "0",
  "basTarih": "20260101",
  "bitTarih": "20260424",
  "calismaTipi": 1,
  "getiriOrani": "1"
}
```

**Response item:**
```json
{
  "fonKodu": "AAK",
  "fonUnvan": "...",
  "fonTurAciklama": "Hisse Senedi Fonu",
  "riskDegeri": 6,
  "getiri1a": 2.34,
  "getiri3a": 5.67,
  "getiri6a": 12.1,
  "getiriyb": 8.9,
  "getiri1y": 22.5,
  "getiri3y": 85.3,
  "getiri5y": 210.7
}
```

---

### 7. `POST /api/funds/fonBuyuklukBazliBilgiGetir`
Portföy büyüklüğü ve pay adedi değişimi.

**Request:**
```json
{
  "dil": "TR",
  "fonTipi": "YAT",
  "islem": 1,
  "kurucuKodu": null,
  "sfonTurKod": null,
  "fonTurKod": null,
  "fonGrubu": null,
  "fonTurAciklama": null,
  "basTarih": "20260424",
  "bitTarih": "20260424",
  "calismaTipi": 1
}
```

---

### 8. `POST /api/funds/fonYonetimBazliBilgiGetir`
Yönetim ücreti ve toplam gider kesintisi.

**Request:** `fonBuyuklukBazliBilgiGetir` ile aynı yapı.

---

### 9. `POST /api/funds/fonUnvanAra`
Fon kodu veya ünvanına göre arama.

**Request:**
```json
{
  "aramaMetni": "altın"
}
```

**Response item:**
```json
{
  "fonKodu": "GLD",
  "fonUnvan": "Garanti BBVA Portföy Altın Fonu",
  "kurucuAd": "Garanti BBVA Portföy",
  "kurucuKod": "GBP"
}
```

**Not:** Boş `aramaMetni` tüm fonları döndürebilir.

---

### 10. `POST /api/funds/fonGrupGetir`
Fon grup listesi.

**Request:** `{}`

---

### 11. `POST /api/funds/fonTurGetir`
Fon tür listesi.

**Request:** `{}`

---

### 12. `POST /api/statistics/tefas/getFplFonList`
Tüm fonların kod / ünvan / kurucu listesi.

**Request:**
```json
{
  "fonTipi": "YAT"
}
```

**Yanıt alanı:** `data` (resultList değil)

---

### 13. `POST /api/statistics/tefas/getFplDovizList/v2`
Döviz listesi.

**Request:** `{}`
**Yanıt alanı:** `data`

---

### 14. `POST /api/statistics/tefas/getFplToplamIslemHacmi`
Toplam işlem hacmi raporu.

**Request:**
```json
{
  "basYil": "2026",
  "basAy": "01",
  "basHafta": "",
  "bitYil": "2026",
  "bitAy": "04",
  "bitHafta": "",
  "paraBirimi": "TL",
  "dil": "TR"
}
```

**Yanıt alanı:** `data`

---

### 15. `POST /api/statistics/tefas/getFplMkkStokBakiye`
Üye stok bakiyeleri.

**Request:**
```json
{
  "yil": "2026",
  "ay": "04",
  "fonTuru": "",
  "uye": "",
  "paraBirimi": "TL",
  "dil": "TR"
}
```

**Yanıt alanı:** `data`

---

### 16. `POST /api/statistics/tefas/getFplHaftaList`
Hafta listesi.

**Request:** `{}`
**Yanıt alanı:** `data`

---

### 17. `POST /api/statistics/tefas/getFplFonBazliIslemHacmi`
Fon bazlı işlem hacmi.

**Request:** `{}`
**Yanıt alanı:** `data`

---

### 18. `POST /api/statistics/tefas/getFplUyeBazliIslemHacmi`
Üye bazlı işlem hacmi.

**Request:** `{}`
**Yanıt alanı:** `data`

---

### 19. `POST /api/announcements/fonTefasDuyuruGetir`
Duyurular.

**Request:** `{}`
**Yanıt alanı:** `data`

---

### 20. `POST /api/fund-returns/export`
Getiri / yönetim / gider / büyüklük tabloları (JSON export).

**Request:**
```json
{
  "format": "json",
  "listingType": "return",
  "fundType": "YAT",
  "locale": "tr"
}
```

| `listingType` | Açıklama |
|---------------|----------|
| `return` | Getiri tablosu |
| `management` | Yönetim ücreti |
| `operatingExpense` | Faaliyet gideri |
| `size` | Büyüklük |

**Yanıt:** Doğrudan `[...]` (sarmalayıcı yok)

---

## Fon Tipi Kodları

| Kod | Açıklama |
|-----|----------|
| `YAT` | Yatırım Fonu (standart) |

---

## Portföy Kısa Kod → Kategori Eşlemesi

`dagilimSiraliGetirT` response'unda gelen kısa kod alanları:

| Kısa Kod | Kategori |
|----------|----------|
| `hs` | Hisse Senedi |
| `tr` | Ters Repo |
| `vint` | Vadeli İşlemler Nakit Teminatları |
| `yyf` | Yatırım Fonları Katılma Payları |
| `fb` | Finansman Bonosu |
| `ost` | Özel Sektör Tahvili |
| `d` | Diğer |
| `bb` | Banka Bonosu |
| `byf` | Borsa Yatırım Fonu |
| `db` | Devlet Tahvili |
| `bpp` | Borsa Para Piyasası |
| `dt` | Devlet Tahvili |
| `dot` | Dövize Endeksli Tahvil |
| `eut` | Eurobond |
| `fkb` | Fon Katılma Belgesi |
| `gas` | Gümüş |
| `gsykb` | Girişim Sermayesi YF Katılma Belgesi |
| `gsyy` | Girişim Sermayesi YO |
| `gykb` | Gayrimenkul Yatırım Fonu Katılma Belgesi |
| `gyy` | Gayrimenkul Yatırım Ortaklığı |
| `hb` | Hazine Bonosu |
| `kba` | Kamu Borçlanma Aracı |
| `kh` | Katılım Hesabı |
| `khau` | Altın Katılma Hesabı |
| `khd` | Döviz Katılma Hesabı |
| `khtl` | TL Katılma Hesabı |
| `kks` | Kamu Kira Sertifikası |
| `kksd` | Kamu Kira Sertifikası (Döviz) |
| `kkstl` | Kamu Kira Sertifikası (TL) |
| `kksyd` | Kamu Kira Sertifikası (YD) |
| `km` | Kıymetli Madenler |
| `kmbyf` | Kıymetli Maden BYF |
| `kmkba` | Kıymetli Maden Kamu Borçlanma |
| `kmkks` | Kıymetli Maden Kamu Kira Sert. |
| `kibd` | Kira Sertifikası İhracı Borçlanma |
| `osks` | Özel Sektör Kira Sertifikası |
| `osdb` | Özel Sektör Dövize Endeksli |
| `r` | Repo |
| `t` | Takasbank |
| `tpp` | Takasbank Para Piyasası |
| `vdm` | Vadeli Mevduat |
| `vm` | Vadeli Mevduat |
| `vmau` | Altın Vadeli Mevduat |
| `vmd` | Döviz Vadeli Mevduat |
| `vmtl` | TL Vadeli Mevduat |
| `yba` | Yabancı Borçlanma Aracı |
| `ybkb` | Yabancı Kamu Borçlanma |
| `ybosb` | Yabancı Özel Sektör Borçlanma |
| `ybyf` | Yabancı Borsa Yatırım Fonu |
| `yhs` | Yabancı Hisse Senedi |
| `ymk` | Yabancı Menkul Kıymet |
| `oksyd` | Özel Sektör Kira Sert. (YD) |

---

## Önemli Davranış Notları

**Boş yanıt sorunu:** İlk POST'ta session warmup yapılmadıysa TEFAS boş body + HTTP 200 döner. Session'ı resetleyip yeniden warmup yapmak gerekir — ama bunu yaparken cookie'leri kaybetmemek kritik (sonsuz döngü riski).

**28 günlük pencere:** Tek istekte 28 günden fazla tarih aralığı verilirse TEFAS sessizce kırpar. Yanıt hata vermez, sadece eksik veri gelir.

**Deduplicate:** Uzun aralık çekimlerinde aynı `(fonKodu, tarih)` çifti birden gelebilir — client tarafında dedupe şart.

**`resultList` vs `data`:** `/api/funds/*` endpoint'leri `resultList`, `/api/statistics/*` endpoint'leri `data` döner. `/api/fund-returns/export` doğrudan array döner.

**Fon kodu büyük harf:** API kodu büyük harfe (`AAK` değil `aak`) normalleştirmeli. Response'larda da büyük gelir.
