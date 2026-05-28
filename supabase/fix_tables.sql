-- ═══════════════════════════════════════════════════════════════════
-- Tablo şemaları + kısıtlamalar — Supabase Dashboard → SQL Editor
-- İdempotent: tekrar çalıştırılabilir, mevcut veriyi silmez.
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- prices tablosu
-- ─────────────────────────────────────────────────────────────

create table if not exists public.prices (
  id            uuid        default gen_random_uuid() primary key,
  symbol        text        not null,
  api_source    text        not null,
  price         numeric     not null,
  price_currency text       not null default 'TRY',
  updated_at    timestamptz default now()
);

-- Unique constraint yoksa ekle (upsert için zorunlu)
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.prices'::regclass
      and contype = 'u'
      and conname = 'prices_symbol_api_source_key'
  ) then
    alter table public.prices
      add constraint prices_symbol_api_source_key unique (symbol, api_source);
  end if;
end $$;

alter table public.prices enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'prices' and policyname = 'prices herkes okuyabilir'
  ) then
    create policy "prices herkes okuyabilir"
      on public.prices for select using (true);
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────
-- exchange_rates tablosu
-- ─────────────────────────────────────────────────────────────

create table if not exists public.exchange_rates (
  id           uuid        default gen_random_uuid() primary key,
  currency     text        not null,
  rate_per_usd numeric     not null,
  updated_at   timestamptz default now()
);

-- Unique constraint yoksa ekle (upsert için zorunlu)
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.exchange_rates'::regclass
      and contype = 'u'
      and conname = 'exchange_rates_currency_key'
  ) then
    alter table public.exchange_rates
      add constraint exchange_rates_currency_key unique (currency);
  end if;
end $$;

alter table public.exchange_rates enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'exchange_rates' and policyname = 'exchange_rates herkes okuyabilir'
  ) then
    create policy "exchange_rates herkes okuyabilir"
      on public.exchange_rates for select using (true);
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────
-- Anında fiyat güncelleme — assets'e yeni varlık eklenince
-- pg_net üzerinden update-prices'ı tetikler (sunucu taraflı)
-- ─────────────────────────────────────────────────────────────

create or replace function public.trigger_price_update_on_asset_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url     := 'https://ighutbzdcqvhjwqvsrzg.supabase.co/functions/v1/update-prices',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body    := '{}'::jsonb
  );
  return new;
end;
$$;

drop trigger if exists fetch_price_on_asset_insert on public.assets;
create trigger fetch_price_on_asset_insert
  after insert on public.assets
  for each statement
  execute function public.trigger_price_update_on_asset_insert();

-- ─────────────────────────────────────────────────────────────
-- Doğrulama — çalıştıktan sonra aşağıdaki satırları kontrol et
-- ─────────────────────────────────────────────────────────────

-- prices unique constraint kontrolü
select conname, contype
from pg_constraint
where conrelid = 'public.prices'::regclass and contype = 'u';

-- exchange_rates unique constraint kontrolü
select conname, contype
from pg_constraint
where conrelid = 'public.exchange_rates'::regclass and contype = 'u';

-- trigger kontrolü
select tgname, tgenabled from pg_trigger
where tgrelid = 'public.assets'::regclass and tgname = 'fetch_price_on_asset_insert';
