-- ═══════════════════════════════════════════════════════════════════
-- Sunucu Mimarisi Geçiş SQL'i
-- Supabase Dashboard → SQL Editor'de çalıştırın.
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. asset_metadata — Varlık Arama Kataloğu
-- ─────────────────────────────────────────────────────────────

create table if not exists public.asset_metadata (
  id uuid default gen_random_uuid() primary key,
  symbol text not null,
  name text not null,
  api_source text not null,
  api_id text not null,
  asset_type text not null,  -- 'stock', 'etf', 'crypto'
  market text not null,       -- 'bist', 'us', 'crypto'
  currency text default 'USD',
  updated_at timestamptz default now(),
  unique(api_id, api_source)
);

create index if not exists asset_metadata_market_idx on public.asset_metadata(market);
create index if not exists asset_metadata_symbol_lower_idx on public.asset_metadata(lower(symbol));
create index if not exists asset_metadata_name_lower_idx on public.asset_metadata(lower(name));

alter table public.asset_metadata enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies where tablename = 'asset_metadata' and policyname = 'asset_metadata herkes okuyabilir'
  ) then
    create policy "asset_metadata herkes okuyabilir"
      on public.asset_metadata for select using (true);
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────
-- 2. Initial Data — BIST Hisseleri
-- ─────────────────────────────────────────────────────────────

insert into public.asset_metadata (symbol, name, api_source, api_id, asset_type, market, currency) values
  ('AKBNK', 'Akbank T.A.Ş.', 'yahoo', 'AKBNK.IS', 'stock', 'bist', 'TRY'),
  ('GARAN', 'Garanti BBVA', 'yahoo', 'GARAN.IS', 'stock', 'bist', 'TRY'),
  ('ISCTR', 'Türkiye İş Bankası (C)', 'yahoo', 'ISCTR.IS', 'stock', 'bist', 'TRY'),
  ('VAKBN', 'T. Vakıflar Bankası', 'yahoo', 'VAKBN.IS', 'stock', 'bist', 'TRY'),
  ('YKBNK', 'Yapı ve Kredi Bankası', 'yahoo', 'YKBNK.IS', 'stock', 'bist', 'TRY'),
  ('HALKB', 'Türkiye Halk Bankası', 'yahoo', 'HALKB.IS', 'stock', 'bist', 'TRY'),
  ('ALBRK', 'Albaraka Türk Katılım Bankası', 'yahoo', 'ALBRK.IS', 'stock', 'bist', 'TRY'),
  ('SKBNK', 'Şekerbank T.A.Ş.', 'yahoo', 'SKBNK.IS', 'stock', 'bist', 'TRY'),
  ('QNBFB', 'QNB Finansbank A.Ş.', 'yahoo', 'QNBFB.IS', 'stock', 'bist', 'TRY'),
  ('KCHOL', 'Koç Holding A.Ş.', 'yahoo', 'KCHOL.IS', 'stock', 'bist', 'TRY'),
  ('SAHOL', 'Sabancı Holding A.Ş.', 'yahoo', 'SAHOL.IS', 'stock', 'bist', 'TRY'),
  ('DOHOL', 'Doğan Şirketler Grubu', 'yahoo', 'DOHOL.IS', 'stock', 'bist', 'TRY'),
  ('SISE', 'Türkiye Şişe ve Cam Fab.', 'yahoo', 'SISE.IS', 'stock', 'bist', 'TRY'),
  ('TOASO', 'Tofaş Türk Otomobil Fab.', 'yahoo', 'TOASO.IS', 'stock', 'bist', 'TRY'),
  ('FROTO', 'Ford Otosan A.Ş.', 'yahoo', 'FROTO.IS', 'stock', 'bist', 'TRY'),
  ('OTKAR', 'Otokar Otomotiv ve Savunma', 'yahoo', 'OTKAR.IS', 'stock', 'bist', 'TRY'),
  ('TTRAK', 'Türk Traktör ve Ziraat Mak.', 'yahoo', 'TTRAK.IS', 'stock', 'bist', 'TRY'),
  ('ARCLK', 'Arçelik A.Ş.', 'yahoo', 'ARCLK.IS', 'stock', 'bist', 'TRY'),
  ('DOAS', 'Doğuş Otomotiv Servis', 'yahoo', 'DOAS.IS', 'stock', 'bist', 'TRY'),
  ('TOGG', 'Togg A.Ş.', 'yahoo', 'TOGG.IS', 'stock', 'bist', 'TRY'),
  ('TCELL', 'Turkcell İletişim Hizmetleri', 'yahoo', 'TCELL.IS', 'stock', 'bist', 'TRY'),
  ('TTKOM', 'Türk Telekomünikasyon A.Ş.', 'yahoo', 'TTKOM.IS', 'stock', 'bist', 'TRY'),
  ('THYAO', 'Türk Hava Yolları A.O.', 'yahoo', 'THYAO.IS', 'stock', 'bist', 'TRY'),
  ('PGSUS', 'Pegasus Hava Taşımacılığı', 'yahoo', 'PGSUS.IS', 'stock', 'bist', 'TRY'),
  ('TUPRS', 'Tüpraş-Türkiye Petrol Raf.', 'yahoo', 'TUPRS.IS', 'stock', 'bist', 'TRY'),
  ('AKSEN', 'Aksa Enerji Üretim A.Ş.', 'yahoo', 'AKSEN.IS', 'stock', 'bist', 'TRY'),
  ('AYGAZ', 'Aygaz A.Ş.', 'yahoo', 'AYGAZ.IS', 'stock', 'bist', 'TRY'),
  ('ENJSA', 'Enerjisa Enerji A.Ş.', 'yahoo', 'ENJSA.IS', 'stock', 'bist', 'TRY'),
  ('ZOREN', 'Zorlu Enerji Elektrik Üretim', 'yahoo', 'ZOREN.IS', 'stock', 'bist', 'TRY'),
  ('ENKAI', 'Enka İnşaat ve Sanayi', 'yahoo', 'ENKAI.IS', 'stock', 'bist', 'TRY'),
  ('EREGL', 'Ereğli Demir ve Çelik', 'yahoo', 'EREGL.IS', 'stock', 'bist', 'TRY'),
  ('KRDMD', 'Kardemir (D) Karabük Demir', 'yahoo', 'KRDMD.IS', 'stock', 'bist', 'TRY'),
  ('ISDMR', 'İskenderun Demir ve Çelik', 'yahoo', 'ISDMR.IS', 'stock', 'bist', 'TRY'),
  ('KOZAL', 'Koza Altın İşletmeleri', 'yahoo', 'KOZAL.IS', 'stock', 'bist', 'TRY'),
  ('ASELS', 'Aselsan Elektronik San.', 'yahoo', 'ASELS.IS', 'stock', 'bist', 'TRY'),
  ('PETKM', 'Petkim Petrokimya Holding', 'yahoo', 'PETKM.IS', 'stock', 'bist', 'TRY'),
  ('EKGYO', 'Emlak Konut GYO', 'yahoo', 'EKGYO.IS', 'stock', 'bist', 'TRY'),
  ('BIMAS', 'BİM Birleşik Mağazalar', 'yahoo', 'BIMAS.IS', 'stock', 'bist', 'TRY'),
  ('MGROS', 'Migros Ticaret A.Ş.', 'yahoo', 'MGROS.IS', 'stock', 'bist', 'TRY'),
  ('SOKM', 'Şok Marketler Ticaret', 'yahoo', 'SOKM.IS', 'stock', 'bist', 'TRY'),
  ('MAVI', 'Mavi Giyim Sanayi', 'yahoo', 'MAVI.IS', 'stock', 'bist', 'TRY'),
  ('ULKER', 'Ülker Bisküvi Sanayi', 'yahoo', 'ULKER.IS', 'stock', 'bist', 'TRY'),
  ('CCOLA', 'Coca-Cola İçecek A.Ş.', 'yahoo', 'CCOLA.IS', 'stock', 'bist', 'TRY'),
  ('AEFES', 'Anadolu Efes Biracılık', 'yahoo', 'AEFES.IS', 'stock', 'bist', 'TRY'),
  ('TATGD', 'Tat Gıda Sanayi A.Ş.', 'yahoo', 'TATGD.IS', 'stock', 'bist', 'TRY'),
  ('TRKCM', 'Trakya Cam Sanayii', 'yahoo', 'TRKCM.IS', 'stock', 'bist', 'TRY'),
  ('CIMSA', 'Çimsa Çimento Sanayi', 'yahoo', 'CIMSA.IS', 'stock', 'bist', 'TRY'),
  ('AKCNS', 'Akçansa Çimento', 'yahoo', 'AKCNS.IS', 'stock', 'bist', 'TRY'),
  ('ECILC', 'Eczacıbaşı İlaç San. ve Tic.', 'yahoo', 'ECILC.IS', 'stock', 'bist', 'TRY'),
  ('DEVA', 'Deva Holding A.Ş.', 'yahoo', 'DEVA.IS', 'stock', 'bist', 'TRY'),
  ('LOGO', 'Logo Yazılım Sanayi', 'yahoo', 'LOGO.IS', 'stock', 'bist', 'TRY'),
  ('NETAS', 'Netaş Telekomünikasyon', 'yahoo', 'NETAS.IS', 'stock', 'bist', 'TRY'),
  ('ANHYT', 'Anadolu Hayat Emeklilik', 'yahoo', 'ANHYT.IS', 'stock', 'bist', 'TRY'),
  ('AKGRT', 'Aksigorta A.Ş.', 'yahoo', 'AKGRT.IS', 'stock', 'bist', 'TRY'),
  ('TURSG', 'Türkiye Sigorta A.Ş.', 'yahoo', 'TURSG.IS', 'stock', 'bist', 'TRY'),
  ('KOZAA', 'Koza Anadolu Metal Mad.', 'yahoo', 'KOZAA.IS', 'stock', 'bist', 'TRY'),
  ('ODAS', 'Odaş Elektrik Üretim', 'yahoo', 'ODAS.IS', 'stock', 'bist', 'TRY'),
  ('TAVHL', 'TAV Havalimanları Holding', 'yahoo', 'TAVHL.IS', 'stock', 'bist', 'TRY'),
  ('VESBE', 'Vestel Beyaz Eşya', 'yahoo', 'VESBE.IS', 'stock', 'bist', 'TRY'),
  ('VESTL', 'Vestel Elektronik', 'yahoo', 'VESTL.IS', 'stock', 'bist', 'TRY'),
  ('SASA', 'SASA Polyester Sanayi', 'yahoo', 'SASA.IS', 'stock', 'bist', 'TRY'),
  ('TKFEN', 'Tekfen Holding A.Ş.', 'yahoo', 'TKFEN.IS', 'stock', 'bist', 'TRY'),
  ('KARSN', 'Karsan Otomotiv', 'yahoo', 'KARSN.IS', 'stock', 'bist', 'TRY'),
  ('BANVT', 'Bandırma Vitaminli Yem', 'yahoo', 'BANVT.IS', 'stock', 'bist', 'TRY'),
  ('GUBRF', 'Gübre Fabrikaları T.A.Ş.', 'yahoo', 'GUBRF.IS', 'stock', 'bist', 'TRY')
on conflict (api_id, api_source) do update set name = excluded.name, updated_at = now();

-- ─────────────────────────────────────────────────────────────
-- 3. Initial Data — Yabancı Hisse ve ETF
-- ─────────────────────────────────────────────────────────────

insert into public.asset_metadata (symbol, name, api_source, api_id, asset_type, market, currency) values
  -- Büyük Teknoloji
  ('AAPL', 'Apple Inc.', 'yahoo', 'AAPL', 'stock', 'us', 'USD'),
  ('MSFT', 'Microsoft Corporation', 'yahoo', 'MSFT', 'stock', 'us', 'USD'),
  ('NVDA', 'NVIDIA Corporation', 'yahoo', 'NVDA', 'stock', 'us', 'USD'),
  ('TSLA', 'Tesla Inc.', 'yahoo', 'TSLA', 'stock', 'us', 'USD'),
  ('GOOGL', 'Alphabet Inc.', 'yahoo', 'GOOGL', 'stock', 'us', 'USD'),
  ('GOOG', 'Alphabet Inc. (C)', 'yahoo', 'GOOG', 'stock', 'us', 'USD'),
  ('AMZN', 'Amazon.com Inc.', 'yahoo', 'AMZN', 'stock', 'us', 'USD'),
  ('META', 'Meta Platforms Inc.', 'yahoo', 'META', 'stock', 'us', 'USD'),
  ('NFLX', 'Netflix Inc.', 'yahoo', 'NFLX', 'stock', 'us', 'USD'),
  ('AMD', 'Advanced Micro Devices', 'yahoo', 'AMD', 'stock', 'us', 'USD'),
  ('INTC', 'Intel Corporation', 'yahoo', 'INTC', 'stock', 'us', 'USD'),
  ('ORCL', 'Oracle Corporation', 'yahoo', 'ORCL', 'stock', 'us', 'USD'),
  ('CRM', 'Salesforce Inc.', 'yahoo', 'CRM', 'stock', 'us', 'USD'),
  ('ADBE', 'Adobe Inc.', 'yahoo', 'ADBE', 'stock', 'us', 'USD'),
  ('PYPL', 'PayPal Holdings Inc.', 'yahoo', 'PYPL', 'stock', 'us', 'USD'),
  ('SQ', 'Block Inc.', 'yahoo', 'SQ', 'stock', 'us', 'USD'),
  ('UBER', 'Uber Technologies', 'yahoo', 'UBER', 'stock', 'us', 'USD'),
  ('COIN', 'Coinbase Global Inc.', 'yahoo', 'COIN', 'stock', 'us', 'USD'),
  -- Finans
  ('V', 'Visa Inc.', 'yahoo', 'V', 'stock', 'us', 'USD'),
  ('MA', 'Mastercard Inc.', 'yahoo', 'MA', 'stock', 'us', 'USD'),
  ('JPM', 'JPMorgan Chase & Co.', 'yahoo', 'JPM', 'stock', 'us', 'USD'),
  ('BAC', 'Bank of America Corp.', 'yahoo', 'BAC', 'stock', 'us', 'USD'),
  ('GS', 'Goldman Sachs Group Inc.', 'yahoo', 'GS', 'stock', 'us', 'USD'),
  ('MS', 'Morgan Stanley', 'yahoo', 'MS', 'stock', 'us', 'USD'),
  -- Enerji & Sağlık & Tüketim
  ('XOM', 'Exxon Mobil Corp.', 'yahoo', 'XOM', 'stock', 'us', 'USD'),
  ('CVX', 'Chevron Corporation', 'yahoo', 'CVX', 'stock', 'us', 'USD'),
  ('JNJ', 'Johnson & Johnson', 'yahoo', 'JNJ', 'stock', 'us', 'USD'),
  ('PFE', 'Pfizer Inc.', 'yahoo', 'PFE', 'stock', 'us', 'USD'),
  ('KO', 'Coca-Cola Company', 'yahoo', 'KO', 'stock', 'us', 'USD'),
  ('PEP', 'PepsiCo Inc.', 'yahoo', 'PEP', 'stock', 'us', 'USD'),
  ('MCD', 'McDonald''s Corporation', 'yahoo', 'MCD', 'stock', 'us', 'USD'),
  ('NKE', 'Nike Inc.', 'yahoo', 'NKE', 'stock', 'us', 'USD'),
  ('WMT', 'Walmart Inc.', 'yahoo', 'WMT', 'stock', 'us', 'USD'),
  ('BABA', 'Alibaba Group Holding', 'yahoo', 'BABA', 'stock', 'us', 'USD'),
  -- ETF
  ('SPY', 'SPDR S&P 500 ETF', 'yahoo', 'SPY', 'etf', 'us', 'USD'),
  ('QQQ', 'Invesco Nasdaq 100 ETF', 'yahoo', 'QQQ', 'etf', 'us', 'USD'),
  ('IWM', 'iShares Russell 2000 ETF', 'yahoo', 'IWM', 'etf', 'us', 'USD'),
  ('VOO', 'Vanguard S&P 500 ETF', 'yahoo', 'VOO', 'etf', 'us', 'USD'),
  ('VTI', 'Vanguard Total Stock Market ETF', 'yahoo', 'VTI', 'etf', 'us', 'USD'),
  ('GLD', 'SPDR Gold Shares ETF', 'yahoo', 'GLD', 'etf', 'us', 'USD'),
  ('TLT', 'iShares 20+ Year Treasury Bond ETF', 'yahoo', 'TLT', 'etf', 'us', 'USD'),
  ('XLK', 'Technology Select Sector SPDR', 'yahoo', 'XLK', 'etf', 'us', 'USD'),
  ('XLF', 'Financial Select Sector SPDR', 'yahoo', 'XLF', 'etf', 'us', 'USD'),
  ('ARKK', 'ARK Innovation ETF', 'yahoo', 'ARKK', 'etf', 'us', 'USD'),
  ('SCHD', 'Schwab US Dividend Equity ETF', 'yahoo', 'SCHD', 'etf', 'us', 'USD')
on conflict (api_id, api_source) do update set name = excluded.name, updated_at = now();

-- ─────────────────────────────────────────────────────────────
-- 4. Initial Data — Popüler Kripto
-- (CoinGecko tam liste update-asset-metadata ile gelir)
-- ─────────────────────────────────────────────────────────────

insert into public.asset_metadata (symbol, name, api_source, api_id, asset_type, market, currency) values
  ('BTC', 'Bitcoin', 'coingecko', 'bitcoin', 'crypto', 'crypto', 'USD'),
  ('ETH', 'Ethereum', 'coingecko', 'ethereum', 'crypto', 'crypto', 'USD'),
  ('BNB', 'BNB', 'coingecko', 'binancecoin', 'crypto', 'crypto', 'USD'),
  ('SOL', 'Solana', 'coingecko', 'solana', 'crypto', 'crypto', 'USD'),
  ('XRP', 'XRP', 'coingecko', 'ripple', 'crypto', 'crypto', 'USD'),
  ('AVAX', 'Avalanche', 'coingecko', 'avalanche-2', 'crypto', 'crypto', 'USD'),
  ('DOGE', 'Dogecoin', 'coingecko', 'dogecoin', 'crypto', 'crypto', 'USD'),
  ('ADA', 'Cardano', 'coingecko', 'cardano', 'crypto', 'crypto', 'USD'),
  ('MATIC', 'Polygon', 'coingecko', 'matic-network', 'crypto', 'crypto', 'USD'),
  ('DOT', 'Polkadot', 'coingecko', 'polkadot', 'crypto', 'crypto', 'USD'),
  ('LINK', 'Chainlink', 'coingecko', 'chainlink', 'crypto', 'crypto', 'USD'),
  ('ATOM', 'Cosmos', 'coingecko', 'cosmos', 'crypto', 'crypto', 'USD'),
  ('UNI', 'Uniswap', 'coingecko', 'uniswap', 'crypto', 'crypto', 'USD'),
  ('LTC', 'Litecoin', 'coingecko', 'litecoin', 'crypto', 'crypto', 'USD'),
  ('SHIB', 'Shiba Inu', 'coingecko', 'shiba-inu', 'crypto', 'crypto', 'USD'),
  ('NEAR', 'NEAR Protocol', 'coingecko', 'near', 'crypto', 'crypto', 'USD'),
  ('FTM', 'Fantom', 'coingecko', 'fantom', 'crypto', 'crypto', 'USD'),
  ('SAND', 'The Sandbox', 'coingecko', 'the-sandbox', 'crypto', 'crypto', 'USD'),
  ('MANA', 'Decentraland', 'coingecko', 'decentraland', 'crypto', 'crypto', 'USD'),
  ('AAVE', 'Aave', 'coingecko', 'aave', 'crypto', 'crypto', 'USD'),
  ('USDT', 'Tether', 'coingecko', 'tether', 'crypto', 'crypto', 'USD'),
  ('USDC', 'USD Coin', 'coingecko', 'usd-coin', 'crypto', 'crypto', 'USD'),
  ('XLM', 'Stellar', 'coingecko', 'stellar', 'crypto', 'crypto', 'USD'),
  ('VET', 'VeChain', 'coingecko', 'vechain', 'crypto', 'crypto', 'USD'),
  ('TRX', 'TRON', 'coingecko', 'tron', 'crypto', 'crypto', 'USD')
on conflict (api_id, api_source) do update set name = excluded.name, updated_at = now();

-- ─────────────────────────────────────────────────────────────
-- 5. tefas_funds → prices otomatik senkronizasyon tetikleyicisi
-- ─────────────────────────────────────────────────────────────

create or replace function public.sync_tefas_to_prices()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.price is not null and new.price > 0 then
    insert into public.prices (symbol, api_source, price, price_currency, updated_at)
    values (
      new.code,
      case when new.is_befas then 'befas' else 'tefas' end,
      new.price,
      'TRY',
      now()
    )
    on conflict (symbol, api_source) do update
    set price = excluded.price,
        updated_at = excluded.updated_at;
  else
    delete from public.prices
    where symbol = new.code
      and api_source = case when new.is_befas then 'befas' else 'tefas' end;
  end if;
  return new;
end;
$$;

drop trigger if exists tefas_price_sync on public.tefas_funds;
create trigger tefas_price_sync
  after insert or update of price on public.tefas_funds
  for each row execute function public.sync_tefas_to_prices();

-- ─────────────────────────────────────────────────────────────
-- 6. Cron Görevleri
-- Not: pg_cron ve pg_net uzantıları etkin olmalıdır.
-- Supabase projelerinde varsayılan olarak etkindir.
-- ─────────────────────────────────────────────────────────────

-- Mevcut görevleri temizle (varsa)
select cron.unschedule('update-prices-15min') where exists (
  select 1 from cron.job where jobname = 'update-prices-15min'
);
select cron.unschedule('update-tefas-funds-hourly') where exists (
  select 1 from cron.job where jobname = 'update-tefas-funds-hourly'
);
select cron.unschedule('update-asset-metadata-daily') where exists (
  select 1 from cron.job where jobname = 'update-asset-metadata-daily'
);
select cron.unschedule('record-portfolio-snapshots-daily') where exists (
  select 1 from cron.job where jobname = 'record-portfolio-snapshots-daily'
);

-- update-prices: her 15 dakikada bir (hisse, kripto, emtia, döviz)
select cron.schedule(
  'update-prices-15min',
  '*/15 * * * *',
  $cron$
  select net.http_post(
    url := 'https://ighutbzdcqvhjwqvsrzg.supabase.co/functions/v1/update-prices',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  ) as request_id;
  $cron$
);

-- TEFAS/BEFAS fon verisi Supabase cron ile degil, dis Python worker ile cekilir.
-- Worker: workers/tefas_ingest
-- Onerilen saatler TR: 08:35, 09:35, 10:35, 11:35, 13:05.

-- update-asset-metadata: her gece 03:00'da (kripto arama kataloğu)
select cron.schedule(
  'update-asset-metadata-daily',
  '0 3 * * *',
  $cron$
  select net.http_post(
    url := 'https://ighutbzdcqvhjwqvsrzg.supabase.co/functions/v1/update-asset-metadata',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  ) as request_id;
  $cron$
);

-- portfolio snapshots: her gece 00:05'te (TR) / 21:05 UTC
select cron.schedule(
  'record-portfolio-snapshots-daily',
  '5 21 * * *',
  $cron$
  select public.record_portfolio_value_snapshots(
    ((now() at time zone 'Europe/Istanbul')::date)
  );
  $cron$
);

-- ─────────────────────────────────────────────────────────────
-- 7. Cron görevlerini doğrula
-- ─────────────────────────────────────────────────────────────
select jobname, schedule, command from cron.job order by jobname;
