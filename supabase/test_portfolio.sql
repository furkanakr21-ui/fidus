-- Test portföyü oluşturma scripti
-- Her varlık türünü ve fiyat güncelleme yolunu kapsar.
--
-- KULLANIM:
--   1. Supabase Dashboard → SQL Editor'ü aç
--   2. Aşağıdaki USER_ID değerini kendi kullanıcı ID'nle değiştir
--      (Authentication → Users sayfasında UUID sütunu)
--   3. Scripti çalıştır — sonuçta portfolio_id'yi not al
--   4. Ardından update-prices fonksiyonunu tetikle.
--      TEFAS/BEFAS fon verisi Supabase fonksiyonu ile degil,
--      workers/tefas_ingest sunucu worker'i ile guncellenir.

DO $$
DECLARE
  v_user_id    UUID := 'USER_ID_BURAYA_YAZ';   -- <-- bunu değiştir
  v_pid        UUID := gen_random_uuid();
BEGIN

  INSERT INTO public.portfolios (id, user_id, name, emoji)
  VALUES (v_pid, v_user_id, 'Test Portföyü', '🧪');

  INSERT INTO public.assets
    (portfolio_id, user_id, name, symbol, type, quantity, buy_price, buy_date,
     api_source, api_id, currency, commission)
  VALUES

  -- ── 1. BIST Hissesi — Yahoo Finance / TRY ────────────────────────────────
  -- Güncelleme: update-prices (her 15 dk)
  -- Fiyat yolu: yahoo → prices(TRY) → asset.currentPrice(TRY)
  (v_pid, v_user_id, 'Garanti BBVA',      'GARAN',        'stock',     100,    72.50, '2025-01-15', 'yahoo',        'GARAN.IS',   'TRY',  50.00),
  (v_pid, v_user_id, 'Türk Hava Yolları', 'THYAO',        'stock',      50,   365.00, '2025-02-10', 'yahoo',        'THYAO.IS',   'TRY',  30.00),

  -- ── 2. Yabancı Hisse — Yahoo Finance / USD → usdToTry ────────────────────
  -- Güncelleme: update-prices (her 15 dk)
  -- Fiyat yolu: yahoo → prices(USD) → asset.currentPrice(USD) × usdToTry
  (v_pid, v_user_id, 'Apple',             'AAPL',         'stock',       5,   192.50, '2025-01-20', 'yahoo',        'AAPL',       'USD',   0.00),

  -- ── 3. Yabancı ETF — Yahoo Finance / USD / fund tipi ─────────────────────
  -- Güncelleme: update-prices (her 15 dk)
  -- Not: fund tipi ama api_source=yahoo — stock'tan farklı tip, aynı fiyat yolu
  (v_pid, v_user_id, 'S&P 500 ETF',       'SPY',          'fund',        3,   510.00, '2025-01-20', 'yahoo',        'SPY',        'USD',   0.00),

  -- ── 4. Kripto — CoinGecko / USD → usdToTry ───────────────────────────────
  -- Güncelleme: update-prices (her 15 dk)
  -- Fiyat yolu: coingecko → prices(USD) → asset.currentPrice(USD) × usdToTry
  (v_pid, v_user_id, 'Bitcoin',           'BTC',          'crypto',   0.05, 88000.00, '2025-02-01', 'coingecko',    'bitcoin',    'USD',   0.00),
  (v_pid, v_user_id, 'Ethereum',          'ETH',          'crypto',      1,  2400.00, '2025-02-01', 'coingecko',    'ethereum',   'USD',   0.00),

  -- ── 5. Döviz — ExchangeRate / TRY ────────────────────────────────────────
  -- Güncelleme: update-prices (her 15 dk)
  -- Fiyat yolu: exchangerate → prices(TRY) → asset.currentPrice(TRY)
  -- currentValue = price × quantity (AssetType.currency özel dalı)
  (v_pid, v_user_id, 'Amerikan Doları',   'USD',          'currency', 1000,    36.00, '2025-01-10', 'exchangerate', 'USD',        'TRY',   0.00),
  (v_pid, v_user_id, 'Euro',              'EUR',          'currency',  500,    39.50, '2025-01-10', 'exchangerate', 'EUR',        'TRY',   0.00),

  -- ── 6. Emtia TRY — gram & sikke (GoldAPI → Yahoo Futures → TRY) ──────────
  -- Güncelleme: update-prices (her 15 dk)
  -- Fiyat yolu: GC=F USD/ons → gram dönüşümü × usdToTry → prices(TRY)
  (v_pid, v_user_id, 'Gram Altın',        'GRAM_ALTIN',   'commodity',  10,  3200.00, '2025-01-05', 'goldapi',      'XAU_GRAM',   'TRY',   0.00),
  (v_pid, v_user_id, 'Çeyrek Altın',      'CEYREK_ALTIN', 'commodity',   5,  6100.00, '2025-01-05', 'goldapi',      'XAU_CEYREK', 'TRY',   0.00),

  -- ── 7. Emtia USD — ons (GoldAPI → Yahoo Futures → USD) ───────────────────
  -- Güncelleme: update-prices (her 15 dk)
  -- Fiyat yolu: GC=F → prices(USD) → asset.currentPrice(USD) × usdToTry
  -- Not: currency='USD' → currentValue farklı hesaplar (TRY gram ile karşılaştır)
  (v_pid, v_user_id, 'Ons Altın',         'ONS_ALTIN',    'commodity',   1,  2800.00, '2025-01-05', 'goldapi',      'XAU',        'USD',   0.00),

  -- ── 8. TEFAS Fonu — resmi TEFAS worker / gunluk ─────────────────────────
  -- Guncelleme: workers/tefas_ingest (sunucu scheduler)
  -- Fiyat yolu: resmi TEFAS API → tefas_funds → DB trigger → prices(TRY)
  (v_pid, v_user_id, 'İş Portföy Hisse Fonu',  'TI2', 'fund', 10000,    0.12, '2025-01-15', 'tefas', 'TI2', 'TRY', 0.00),
  (v_pid, v_user_id, 'Ata Portföy Para Piy.',   'AAL', 'fund',  5000,    3.00, '2025-03-01', 'tefas', 'AAL', 'TRY', 0.00),

  -- ── 9. Nakit — güncellenmez (statik) ─────────────────────────────────────
  -- api_source='manual', api_id=NULL → prices tablosunda eşleşme aranmaz
  -- currentValue = buyPrice × quantity (currentPrice her zaman null)
  (v_pid, v_user_id, 'Nakit TRY',         'TRY',          'cash',    50000,     1.00, '2025-01-01', 'manual',       NULL,         'TRY',   0.00),

  -- ── 10. Gayrimenkul — güncellenmez (statik) ──────────────────────────────
  -- Nakit ile aynı mekanizma; sadece tip farklı
  (v_pid, v_user_id, 'İstanbul Daire',    'DAIRE',        'realEstate',  1, 4500000, '2024-06-01',  'manual',       NULL,         'TRY',   0.00);

  RAISE NOTICE 'Test portföyü oluşturuldu → portfolio_id: %', v_pid;
END $$;
