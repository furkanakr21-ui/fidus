-- TEFAS/BEFAS server-side market data setup.
-- Idempotent: safe to run multiple times in Supabase SQL Editor.

-- ─────────────────────────────────────────────────────────────
-- 1. Extend tefas_funds for official TEFAS fields
-- ─────────────────────────────────────────────────────────────

alter table public.tefas_funds
  add column if not exists source_fon_tipi text,
  add column if not exists fund_family_label text,
  add column if not exists price_date date,
  add column if not exists share_count numeric(30, 8),
  add column if not exists investor_count bigint,
  add column if not exists exchange_bulletin_price numeric(20, 8),
  add column if not exists risk_level integer,
  add column if not exists return_3y numeric(18, 6),
  add column if not exists return_5y numeric(18, 6),
  add column if not exists last_seen_at timestamptz,
  add column if not exists is_active boolean not null default true;

alter table public.tefas_funds
  alter column return_1w type numeric(18, 6),
  alter column return_1m type numeric(18, 6),
  alter column return_3m type numeric(18, 6),
  alter column return_6m type numeric(18, 6),
  alter column return_1y type numeric(18, 6),
  alter column return_ytd type numeric(18, 6),
  alter column return_3y type numeric(18, 6),
  alter column return_5y type numeric(18, 6);

update public.tefas_funds
set price = null
where price is not null and price <= 0;

delete from public.prices
where api_source in ('tefas', 'befas') and price <= 0;

do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.tefas_funds'::regclass
      and conname = 'tefas_funds_positive_price_check'
  ) then
    alter table public.tefas_funds
      add constraint tefas_funds_positive_price_check
      check (price is null or price > 0);
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.prices'::regclass
      and conname = 'prices_positive_price_check'
  ) then
    alter table public.prices
      add constraint prices_positive_price_check
      check (price > 0);
  end if;
end $$;

create index if not exists tefas_funds_bucket_name_idx
  on public.tefas_funds (is_befas, lower(name));

create index if not exists tefas_funds_active_bucket_name_idx
  on public.tefas_funds (is_active, is_befas, lower(name));

create index if not exists tefas_funds_source_fon_tipi_idx
  on public.tefas_funds (source_fon_tipi);

create index if not exists tefas_funds_price_date_idx
  on public.tefas_funds (price_date desc);

-- ─────────────────────────────────────────────────────────────
-- 2. Market data run monitoring
-- ─────────────────────────────────────────────────────────────

create table if not exists public.market_data_runs (
  id bigserial primary key,
  source text not null,
  started_at timestamptz not null,
  finished_at timestamptz,
  ok boolean not null default false,
  published boolean not null default false,
  target_date date,
  request_count integer not null default 0,
  retry_count integer not null default 0,
  duration_s numeric generated always as (
    case
      when finished_at is null then null
      else extract(epoch from (finished_at - started_at))
    end
  ) stored,
  family_counts jsonb,
  price_count integer,
  zero_count integer not null default 0,
  null_price_count integer not null default 0,
  error_summary text,
  created_at timestamptz not null default now()
);

create index if not exists market_data_runs_source_started_idx
  on public.market_data_runs (source, started_at desc);

alter table public.market_data_runs enable row level security;

grant select on table public.market_data_runs to authenticated;
grant all privileges on table public.market_data_runs to service_role;
grant usage, select on sequence public.market_data_runs_id_seq to service_role;

-- Service role bypasses RLS. Authenticated read is useful for an internal
-- settings/health screen without exposing secrets.
do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'market_data_runs'
      and policyname = 'market_data_runs authenticated read'
  ) then
    create policy "market_data_runs authenticated read"
      on public.market_data_runs for select
      to authenticated
      using (true);
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────
-- 3. Keep tefas_funds.price synced to prices
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
