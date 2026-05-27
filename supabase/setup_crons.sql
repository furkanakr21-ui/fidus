-- ═══════════════════════════════════════════════════════════════════
-- Cron Görevleri ve Trigger Kurulumu
-- Supabase Dashboard → SQL Editor'de çalıştırın.
-- İdempotent: tekrar çalıştırılabilir, mevcut veriyi silmez.
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. tefas_funds.price → prices tablosu otomatik senkron trigger
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
      set price      = excluded.price,
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
-- 2. Tüm mevcut cron görevlerini temizle
-- ─────────────────────────────────────────────────────────────
select cron.unschedule(jobname)
from cron.job
where jobname in (
  -- Eski görevler
  'update-prices-15min',
  'update-tefas-funds-hourly',
  'update-asset-metadata-daily',
  'update-tefas-hourly',
  'update-tefas',
  'update-tefas-prices-seg0',
  'update-tefas-prices-seg1',
  'update-tefas-prices-seg2',
  'update-tefas-prices-seg3',
  'update-tefas-prices-seg4',
  'update-tefas-prices-seg5',
  'update-tefas-prices-seg6',
  'update-tefas-prices-seg7',
  -- TEFAS/BEFAS artık dış Python worker ile çekilir.
  -- Bu eski Edge Function cron'ları tekrar çalıştırılmamalı.
  'update-tefas-funds-0835',
  'update-tefas-funds-0935',
  'update-tefas-funds-1035',
  'update-tefas-funds-1135'
);

-- ─────────────────────────────────────────────────────────────
-- 3. Yeni cron görevleri
-- Türkiye her zaman UTC+3 (yaz saati uygulamaz).
-- ─────────────────────────────────────────────────────────────

-- Hisse, kripto, döviz, emtia — her 15 dakika (değişmedi)
select cron.schedule(
  'update-prices-15min',
  '*/15 * * * *',
  $cron$
  select net.http_post(
    url     := 'https://ighutbzdcqvhjwqvsrzg.supabase.co/functions/v1/update-prices',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body    := '{}'::jsonb
  ) as request_id;
  $cron$
);

-- TEFAS/BEFAS fon metadata + fiyatları
-- Not: Fon verisi artik Supabase Edge Function ile guncellenmez.
-- Resmi TEFAS endpoint'leri bot koruması nedeniyle Python Docker worker
-- üzerinden, sunucu taraflı scheduler ile çalıştırılır.
-- Önerilen worker saatleri TR: 08:35, 09:35, 10:35, 11:35, 13:05.

-- Kripto metadata (CoinGecko kataloğu) — her gece 03:00 UTC (06:00 TR)
select cron.schedule(
  'update-asset-metadata-daily',
  '0 3 * * *',
  $cron$
  select net.http_post(
    url     := 'https://ighutbzdcqvhjwqvsrzg.supabase.co/functions/v1/update-asset-metadata',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body    := '{}'::jsonb
  ) as request_id;
  $cron$
);

-- ─────────────────────────────────────────────────────────────
-- 4. Doğrulama — beklenen 2 aktif Supabase cron görevi
-- TEFAS worker Supabase cron.job içinde görünmez; dış scheduler'da izlenir.
-- ─────────────────────────────────────────────────────────────
select jobname, schedule, active
from cron.job
order by jobname;
