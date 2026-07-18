# "Portföyler Toplamı" Görünümü — Tasarım Dokümanı

- **Tarih:** 2026-07-18
- **Durum:** Kullanıcı incelemesinde
- **Kapsadığı sürüm:** Fidus 1.0.0 (main dalı, temiz analiz + 66/66 test)

---

## 1. Amaç

Kullanıcının aktif portföy seçim listesine **"Portföyler Toplamı"** adında sanal bir seçenek eklemek. Seçildiğinde, kullanıcıya ait ve "toplama dahil" işaretli **tüm portföylerin verisi tek bir portföymüş gibi** mevcut ekran mantığıyla gösterilir. Kullanıcı hangi portföylerin toplama dahil olmayacağını bir ayar sayfasından yönetebilir.

## 2. Verilen kararlar (kullanıcı onaylı)

| Karar | Seçim |
|---|---|
| Toplam görünümde yazma işlemleri | **İşlem anında portföy seçtir** — ekleme formlarında hedef portföy alanı, satışta portföy seçim adımı |
| Birleştirme kapsamı | **Her şey** — varlıklar, nakit akışları, hedefler, işlem geçmişi, günlük değişim, grafik |
| Dahil/hariç ayarının yeri | **Toplam satırındaki ayar ikonu → alttan açılan sayfa** (anahtar listesi) |
| Mimari | **Sanal portföy kimliği (sentinel)** — veri katmanında dallanma, ekranlar değişmez |
| Durum saklama | **Sunucuda** (`user_settings` + `portfolios`), cihazlar arası senkron |

## 3. Kavramsal model

- Dart tarafında yeni sabit: `kTotalPortfolioId = '__total__'` (yeni dosya `lib/core/constants/app_constants.dart`).
- `activePortfolioProvider` state'i bu sentinel değeri alabilir. Sentinel hiçbir zaman sunucuya `active_portfolio_id` olarak yazılmaz (UUID FK bozulmaz).
- Veri sağlayıcıları sentinel'i görünce "dahil edilen portföyler" kümesi üzerinden yükleme yapar; ekran katmanı hiçbir özel durum bilmez.
- Toplam görünümün geçmişi ve günlük değişimi, **portföy bazlı gece snapshotlarının istemcide toplanmasıyla** hesaplanır. Sunucudaki snapshot fonksiyonu değişmez. Sonuç: dahil/hariç ayarı sonradan değiştirilirse grafik geçmişi de otomatik olarak yeni seçime göre hesaplanır.

## 4. Sunucu değişiklikleri

Tek idempotent migration dosyası: `supabase/setup_total_view.sql`

```sql
alter table public.portfolios
  add column if not exists include_in_total boolean not null default true;

alter table public.user_settings
  add column if not exists total_view_active boolean not null default false;
```

- **RLS/grant:** Mevcut `own_portfolios` ve `own_settings` politikaları (FOR ALL) ile `setup_data_api_grants.sql`'deki authenticated yazma izinleri bu kolonları zaten kapsar. Yeni politika/grant gerekmez.
- **Realtime:** `portfolios` tablosu publication'a **eklenmez** (bugün de portföy listesi realtime değil; YAGNI). Diğer tabloların mevcut publication'ı yeterli — toplam modda kanallar `user_id` filtresiyle kurulur, bu sadece istemci değişikliğidir.
- **Snapshot fonksiyonu (`record_portfolio_value_snapshots`):** değişmez.

## 5. Veri katmanı (Flutter)

### 5.1 Model ve servis

- `PortfolioModel`: `includeInTotal` alanı eklenir (`include_in_total`, fromJson varsayılan `true`).
- `PortfolioService`:
  - `setIncludeInTotal(String id, bool value)` → `portfolios` update.
  - `setTotalViewActive()` → `user_settings` upsert `{total_view_active: true}` (`active_portfolio_id` korunur).
  - `setActivePortfolio(id)` → mevcut upsert'e `total_view_active: false` eklenir.
  - `getSettings()` dönüşüne `total_view_active` eklenir.
- `AssetService`, `CashFlowService`, `GoalService`: `getByPortfolios(List<String> ids)` (`.inFilter('portfolio_id', ids)`).
- `TransactionService.getByPortfolios(ids)`: varlık kimlikleri `assets.portfolio_id in ids` ile bulunur, işlemler `asset_id in (...)` ile çekilir.
- `PortfolioSnapshotService`: `getTodayForPortfolios(ids)`, `getHistoryForPortfolios(ids)`.
- `PortfolioAssetSnapshotService`: `getTodayForPortfolios(ids)`.

### 5.2 Provider'lar (`lib/shared/providers.dart`)

- `includedPortfolioIdsProvider = Provider<List<String>>` → `portfoliosProvider`'dan `includeInTotal == true` olanların kimlikleri.
- `isTotalViewProvider = Provider<bool>` → `activePortfolioProvider == kTotalPortfolioId`.
- `ActivePortfolioNotifier`:
  - `_loadFromServer`: ayarlarda `total_view_active == true` ise state = sentinel; değilse mevcut mantık.
  - `switchPortfolio(id)`: id sentinel ise `setTotalViewActive()`, değilse `setActivePortfolio(id)`; state güncellenir.
- `PortfoliosNotifier`: `setIncludeInTotal(id, value)` → servis çağrısı + yerel state'te ilgili portföyü günceller (anahtarlar anında tepki verir).
- **Veri notifier'ları ortak deseni** (Assets, CashFlow, Goals, Transactions, TodayPortfolioSnapshot, PortfolioSnapshotHistory, TodayAssetSnapshots):
  - `build()` içinde sentinel görülürse `ref.watch(includedPortfolioIdsProvider)` izlenir → liste değişince otomatik yeniden yükleme.
  - Realtime kanalı `portfolio_id=eq.X` yerine `user_id=eq.<uid>` filtresiyle kurulur (tüm bu tablolarda `user_id` kolonu mevcut).
  - Yükleme `getByPortfolios(ids)` ile yapılır; `ids` boşsa sorgu atılmadan boş state yazılır ve ilgili `InitialDataLoadTracker` bölümü `markReady` yapılır (açılış kapısı asılı kalmaz).
- Snapshot notifier'ları toplam modda ham satırları çekip **birleştirme fonksiyonlarına** verir; state türleri değişmez (`PortfolioValueSnapshot?`, `List<PortfolioValueSnapshot>`, `Map<String, PortfolioAssetValueSnapshot>?`). Böylece `dailyPortfolioChangeProvider`, `dailyAssetChangesProvider` ve grafik kodu **hiç değişmez**.

### 5.3 Birleştirme fonksiyonları (saf, test edilebilir)

Yeni dosya `lib/shared/models/total_view_aggregation.dart`:

- `PortfolioValueSnapshot? aggregateTodaySnapshots(List<PortfolioValueSnapshot> rows)` — `value_try`, `value_usd`, `asset_count` toplanır; `usd_try_rate` ve tarih ilk satırdan (aynı gece cron'u, kur tüm satırlarda aynı); `portfolioId = kTotalPortfolioId`. Boş listede `null`.
- `List<PortfolioValueSnapshot> aggregateSnapshotHistory(List<PortfolioValueSnapshot> rows)` — `snapshot_date` bazında gruplanıp toplanır, tarihe göre sıralı döner.
- `Map<String, PortfolioAssetValueSnapshot> aggregateAssetSnapshotsBySymbol(List<PortfolioAssetValueSnapshot> rows)` — sembol bazında `quantity`, `value_try`, `value_usd`, `asset_row_count` toplanır; ad/tip alanları ilk satırdan.

**Kısmi snapshot kuralı:** Dahil bir portföyün o güne snapshot'ı yoksa var olan satırlar yine toplanır. Bu, tek portföyde gün içinde varlık eklendiğindeki mevcut davranışla ("Yeni" rozeti, baz dışı artış) aynıdır ve bilinçli tercihtir.

## 6. Yazma akışları

- **Yeni ortak parçalar:** `PortfolioPickerSheet` (portföyleri emoji+adla listeler, seçim döndürür) ve formlarda kullanılacak `TargetPortfolioField` (zorunlu seçim alanı; dahil/hariç fark etmeksizin tüm gerçek portföyler seçilebilir).
- **AddAssetScreen / AddCashFlowScreen / AddGoalSheet:** toplam moddayken formun üstünde "Hedef Portföy" alanı görünür; boş bırakılırsa kaydetme engellenir ve uyarı gösterilir. Normal modda alan hiç render edilmez, davranış bugünkü ile birebir aynı kalır.
- **AddBuySheet (yalnızca toplam modda):** sembolün lotları tek portföydeyse hedef otomatik odur; birden fazla portföydeyse alan gösterilir. Yeni lot seçilen portföye yazılır. Normal modda davranış değişmez.
- **AddSellSheet:** `portfolioId` parametresi alır. Normal modda aktif portföy geçilir (davranış değişmez). Toplam modda `PositionSheet`, satış öncesi sembolün lot bulundurduğu portföyleri **eldeki miktarlarıyla** listeler; kullanıcı birini seçince `AddSellSheet` o portföyle açılır. Sembol tek portföyde lot bulunduruyorsa seçim adımı atlanır, doğrudan o portföyle açılır. `_fetchSortedLots` ve miktar üst sınırı yalnızca o portföyün lotlarını kullanır → **FIFO asla portföyler arası lot karıştırmaz.**
- **PositionSheet (toplam modda):** lot sayısı satırında portföy dağılımı belirtilir; lot seçim listesinde her lotun yanında portföy adı görünür; toplu silme onay metni "X portföyündeki N alım kaydı silinecek" der.
- **EditAssetScreen:** değişmez (zaten lot bazlı; lot hangi portföydeyse onu günceller).

## 7. Arayüz

- **Ayarlar → Portföyler bölümü:** listenin en üstüne `Portföyler Toplamı` satırı:
  - Sol: özel ikon (`Icons.donut_large_rounded`), başlık, alt yazı "N portföy dahil".
  - Sağ: aktifse onay işareti, değilse "Seç" butonu; ayrıca her durumda **ayar (tune) ikonu**.
  - Ayar ikonu → `TotalViewSettingsSheet`: tüm portföyler `Switch` ile listelenir, değişiklik anında sunucuya yazılır. Tüm portföyler hariç bırakılabilir; bu durumda sheet içinde "Hiçbir portföy dahil değil — toplam görünüm boş görünür" bilgi notu belirir (engel yok).
- **Aktif portföy hero kartı (Ayarlar):** toplam aktifken ad "Portföyler Toplamı", rozet "N portföy dahil".
- **Anasayfa ve Portföy sekmesi:** toplam aktifken başlığın hemen altında ince rozet: "Toplam görünüm · N portföy". Başka görsel değişiklik yok.
- **Silme koruması:** `user_settings.active_portfolio_id`'nin işaret ettiği portföy silindiğinde mevcut davranış korunur; toplam görünüm aktifse seçim etkilenmez.

## 8. Uç durumlar

| Durum | Davranış |
|---|---|
| Dahil liste boş | Tüm sekmeler mevcut boş durumlarını gösterir; açılış kapısı takılmaz (markReady garantisi) |
| Toplam aktifken dahil anahtarı değişir | Provider'lar `includedPortfolioIdsProvider`'ı izlediği için anında yeniden yükleme |
| Toplam aktifken başka cihazdan varlık eklenir | `user_id` filtreli Realtime kanalı yakalar, liste canlı güncellenir |
| Hesap aktarma (sync kodu) | Ayarlar sunucudan okunduğu için toplam/dahil durumu yeni hesapla birlikte gelir; mevcut `ref.invalidate` akışı yeterli |
| Aynı sembol birden çok portföyde | `mergedAssetsProvider` mevcut mantığıyla birleştirir; varlık snapshotları sembol bazında toplanır — günlük değişim tutarlı |
| Sunucu yazma hatası (dahil anahtarı / görünüm seçimi) | Snackbar ile bildirilir, yerel state geri alınır |

## 9. Test stratejisi

**Yeni birim testleri** (`test/` altında):
- `total_view_aggregation_test.dart`: bugün toplamı (2-3 portföy, USD değerleri, boş liste → null); geçmiş serisi (eksik günlü portföy, tarih sıralaması, tek portföy = kimlik dönüşümü); sembol birleştirme (çakışan sembol, farklı semboller, quantity/value toplamları).
- `included_portfolios_test.dart`: dahil-liste türetme; `setIncludeInTotal` sonrası state; tümü hariçken boş liste.
- `active_portfolio_total_test.dart`: sentinel'e geçiş/çıkış, ayar okuma (`total_view_active`) dönüşümleri.

**Yeni widget testleri:**
- `settings_total_view_test.dart`: toplam satırının varlığı, "N portföy dahil" metni, ayar ikonundan sheet açılması, anahtar değişiminin çağrısı.
- `target_portfolio_field_test.dart`: toplam modda ekleme formlarında alanın görünmesi/zorunluluğu, normal modda hiç render edilmemesi.
- `sell_portfolio_selection_test.dart`: çok portföylü sembolde satış öncesi portföy seçim adımı; tek portföyde adımın atlanması.
- `total_view_badge_test.dart`: Anasayfa/Portföy rozetlerinin yalnızca toplam modda görünmesi.

**Regresyon:** mevcut 66 test değişiklik sonrası geçmeli; `flutter analyze` sıfır sorun. Snapshot ve fiyat akışına dokunulmadığı için sunucu tarafında regresyon riski yok; migration idempotent ve geri alınabilir (`drop column` ile).

## 10. Kapsam dışı (bilinçli)

- `transactions.asset_id` cascade-delete sorunu (satış geçmişinin kaybı) — **ayrı bir iş** olarak ele alınacak; bu tasarım onu çözmez ama kötüleştirmez de.
- Gerçekleşen kâr/zarar hesabı.
- Sunucu tarafında toplam snapshot üretimi (istemci toplaması yeterli ve daha esnek).
- `portfolios` tablosunun Realtime publication'a eklenmesi.
