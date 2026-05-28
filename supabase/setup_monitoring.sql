-- ═══════════════════════════════════════════════════════════════════
-- Cron Job Monitoring Tablosu
-- Supabase Dashboard → SQL Editor'de veya CLI ile çalıştırın.
-- İdempotent: tekrar çalıştırılabilir, mevcut veriyi silmez.
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.cron_runs (
  id            bigserial primary key,
  function_name text        not null,
  started_at    timestamptz not null,
  finished_at   timestamptz not null,
  duration_s    numeric     generated always as (
    extract(epoch from (finished_at - started_at))
  ) stored,
  funds_fetched integer,
  prices_written integer,
  asset_count   integer,
  error_count   integer     not null default 0,
  errors        jsonb,
  ok            boolean     not null default true
);

-- Eski kayıtları temizlemek için index (isteğe bağlı retention policy)
create index if not exists cron_runs_started_at_idx
  on public.cron_runs (started_at desc);

-- Row Level Security: sadece service role yazabilir/okuyabilir
alter table public.cron_runs enable row level security;

-- Doğrulama
select count(*) as cron_runs_row_count from public.cron_runs;
