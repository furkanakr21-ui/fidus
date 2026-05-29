-- Portfolio asset value snapshots foundation.
-- Idempotent: safe to run multiple times; does not delete existing data.

create table if not exists public.portfolio_asset_value_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  portfolio_id uuid not null,
  snapshot_date date not null,
  symbol text not null,
  name text not null,
  type text not null,
  api_source text,
  api_id text,
  quantity numeric(28, 8) not null default 0,
  value_try numeric(20, 4) not null,
  value_usd numeric(20, 4) not null,
  usd_try_rate numeric(20, 8) not null,
  fx_rates_updated_at timestamptz,
  asset_row_count integer not null default 0,
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

do $$ begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.portfolio_asset_value_snapshots'::regclass
      and conname = 'portfolio_asset_value_snapshots_portfolio_date_symbol_key'
  ) then
    alter table public.portfolio_asset_value_snapshots
      add constraint portfolio_asset_value_snapshots_portfolio_date_symbol_key
      unique (portfolio_id, snapshot_date, symbol);
  end if;
end $$;

do $$ begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.portfolio_asset_value_snapshots'::regclass
      and conname = 'portfolio_asset_value_snapshots_non_negative_values'
  ) then
    alter table public.portfolio_asset_value_snapshots
      add constraint portfolio_asset_value_snapshots_non_negative_values
      check (
        quantity >= 0
        and value_try >= 0
        and value_usd >= 0
        and usd_try_rate > 0
        and asset_row_count >= 0
      );
  end if;
end $$;

do $$ begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.portfolio_asset_value_snapshots'::regclass
      and conname = 'portfolio_asset_value_snapshots_user_id_fkey'
  ) then
    alter table public.portfolio_asset_value_snapshots
      add constraint portfolio_asset_value_snapshots_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.portfolio_asset_value_snapshots'::regclass
      and conname = 'portfolio_asset_value_snapshots_portfolio_id_fkey'
  ) then
    alter table public.portfolio_asset_value_snapshots
      add constraint portfolio_asset_value_snapshots_portfolio_id_fkey
      foreign key (portfolio_id) references public.portfolios(id)
      on delete cascade;
  end if;
end $$;

create index if not exists portfolio_asset_value_snapshots_user_portfolio_date_idx
  on public.portfolio_asset_value_snapshots (
    user_id,
    portfolio_id,
    snapshot_date desc
  );

create index if not exists portfolio_asset_value_snapshots_date_idx
  on public.portfolio_asset_value_snapshots (snapshot_date desc);

do $$ begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'portfolio_asset_value_snapshots'
  ) then
    alter publication supabase_realtime
      add table public.portfolio_asset_value_snapshots;
  end if;
end $$;

alter table public.portfolio_asset_value_snapshots enable row level security;

revoke all on table public.portfolio_asset_value_snapshots from anon;
revoke all on table public.portfolio_asset_value_snapshots from authenticated;
grant select on table public.portfolio_asset_value_snapshots to authenticated;
grant all on table public.portfolio_asset_value_snapshots to service_role;

drop policy if exists "asset snapshots users can read own rows"
  on public.portfolio_asset_value_snapshots;

create policy "asset snapshots users can read own rows"
  on public.portfolio_asset_value_snapshots
  for select
  to authenticated
  using (auth.uid() = user_id);

-- Verification queries for Supabase SQL Editor:
select to_regclass('public.portfolio_asset_value_snapshots')
  as asset_snapshot_table;

select conname, contype
from pg_constraint
where conrelid = 'public.portfolio_asset_value_snapshots'::regclass
order by conname;

select indexname
from pg_indexes
where schemaname = 'public'
  and tablename = 'portfolio_asset_value_snapshots'
order by indexname;

select policyname, cmd, roles, qual
from pg_policies
where schemaname = 'public'
  and tablename = 'portfolio_asset_value_snapshots'
order by policyname;
