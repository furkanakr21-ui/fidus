-- Portfolio value snapshots foundation.
-- Idempotent: safe to run multiple times; does not delete existing data.

create table if not exists public.portfolio_value_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  portfolio_id uuid not null,
  snapshot_date date not null,
  value_try numeric(20, 4) not null,
  value_usd numeric(20, 4) not null,
  usd_try_rate numeric(20, 8) not null,
  fx_rates_updated_at timestamptz,
  asset_count integer not null default 0,
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

do $$ begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.portfolio_value_snapshots'::regclass
      and conname = 'portfolio_value_snapshots_portfolio_date_key'
  ) then
    alter table public.portfolio_value_snapshots
      add constraint portfolio_value_snapshots_portfolio_date_key
      unique (portfolio_id, snapshot_date);
  end if;
end $$;

do $$ begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.portfolio_value_snapshots'::regclass
      and conname = 'portfolio_value_snapshots_non_negative_values'
  ) then
    alter table public.portfolio_value_snapshots
      add constraint portfolio_value_snapshots_non_negative_values
      check (
        value_try >= 0
        and value_usd >= 0
        and usd_try_rate > 0
        and asset_count >= 0
      );
  end if;
end $$;

do $$ begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.portfolio_value_snapshots'::regclass
      and conname = 'portfolio_value_snapshots_user_id_fkey'
  ) then
    alter table public.portfolio_value_snapshots
      add constraint portfolio_value_snapshots_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.portfolio_value_snapshots'::regclass
      and conname = 'portfolio_value_snapshots_portfolio_id_fkey'
  ) then
    alter table public.portfolio_value_snapshots
      add constraint portfolio_value_snapshots_portfolio_id_fkey
      foreign key (portfolio_id) references public.portfolios(id)
      on delete cascade;
  end if;
end $$;

create index if not exists portfolio_value_snapshots_user_portfolio_date_idx
  on public.portfolio_value_snapshots (user_id, portfolio_id, snapshot_date desc);

create index if not exists portfolio_value_snapshots_date_idx
  on public.portfolio_value_snapshots (snapshot_date desc);

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
      and tablename = 'portfolio_value_snapshots'
  ) then
    alter publication supabase_realtime
      add table public.portfolio_value_snapshots;
  end if;
end $$;

alter table public.portfolio_value_snapshots enable row level security;

revoke all on table public.portfolio_value_snapshots from anon;
revoke all on table public.portfolio_value_snapshots from authenticated;
grant select on table public.portfolio_value_snapshots to authenticated;
grant all on table public.portfolio_value_snapshots to service_role;

drop policy if exists "portfolio snapshots users can read own rows"
  on public.portfolio_value_snapshots;

create policy "portfolio snapshots users can read own rows"
  on public.portfolio_value_snapshots
  for select
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.record_portfolio_value_snapshots(
  p_snapshot_date date default ((now() at time zone 'Europe/Istanbul')::date)
)
returns table (
  target_date date,
  portfolio_count integer,
  inserted_count integer,
  skipped_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_snapshot_date date := coalesce(
    p_snapshot_date,
    ((now() at time zone 'Europe/Istanbul')::date)
  );
  v_usd_try_rate numeric;
  v_fx_rates_updated_at timestamptz;
begin
  select er.rate_per_usd, er.updated_at
    into v_usd_try_rate, v_fx_rates_updated_at
  from public.exchange_rates er
  where er.currency = 'TRY';

  if v_usd_try_rate is null or v_usd_try_rate <= 0 then
    raise exception 'USD/TRY rate is missing or invalid for portfolio snapshots';
  end if;

  return query
  with priced_assets as (
    select
      p.user_id,
      p.id as portfolio_id,
      v_snapshot_date as snapshot_date,
      a.id as asset_id,
      a.symbol,
      a.name,
      a.type,
      a.api_source,
      a.api_id,
      a.quantity,
      a.created_at,
      case
        when a.id is null then 0
        else
          case
            when a.type = 'currency' then priced.asset_price
            when a.currency = 'USD' then priced.asset_price * v_usd_try_rate
            else priced.asset_price
          end * a.quantity
      end as value_try
    from public.portfolios p
    left join public.assets a
      on a.portfolio_id = p.id
     and a.user_id = p.user_id
    left join lateral (
      select
        case
          when pr.price is null then a.buy_price
          when pr.price_currency = 'USD' and a.currency = 'TRY' then pr.price * v_usd_try_rate
          else pr.price
        end as asset_price
      from (
        select
          pr.price,
          pr.price_currency
        from public.prices pr
        where pr.symbol = coalesce(a.api_id, a.symbol)
          and pr.api_source in (
            coalesce(a.api_source, 'manual'),
            case
              when coalesce(a.api_source, 'manual') = 'tefas' then 'befas'
              when coalesce(a.api_source, 'manual') = 'befas' then 'tefas'
              when a.type = 'fund'
                and coalesce(a.api_source, 'manual') = 'finance-api'
                then 'tefas'
              else coalesce(a.api_source, 'manual')
            end
          )
          and pr.price > 0
        order by
          case
            when pr.api_source = coalesce(a.api_source, 'manual') then 0
            else 1
          end
        limit 1
      ) pr
      union all
      select a.buy_price
      where not exists (
        select 1
        from public.prices pr
        where pr.symbol = coalesce(a.api_id, a.symbol)
          and pr.api_source in (
            coalesce(a.api_source, 'manual'),
            case
              when coalesce(a.api_source, 'manual') = 'tefas' then 'befas'
              when coalesce(a.api_source, 'manual') = 'befas' then 'tefas'
              when a.type = 'fund'
                and coalesce(a.api_source, 'manual') = 'finance-api'
                then 'tefas'
              else coalesce(a.api_source, 'manual')
            end
          )
          and pr.price > 0
      )
      limit 1
    ) priced on a.id is not null
  ),
  portfolio_calculated as (
    select
      pa.user_id,
      pa.portfolio_id,
      pa.snapshot_date,
      coalesce(round(sum(pa.value_try), 4), 0) as value_try,
      count(pa.asset_id)::integer as asset_count
    from priced_assets pa
    group by pa.user_id, pa.portfolio_id, pa.snapshot_date
  ),
  asset_calculated as (
    select
      pa.user_id,
      pa.portfolio_id,
      pa.snapshot_date,
      pa.symbol,
      (array_agg(pa.name order by pa.created_at, pa.asset_id))[1] as name,
      (array_agg(pa.type order by pa.created_at, pa.asset_id))[1] as type,
      (array_agg(pa.api_source order by pa.created_at, pa.asset_id))[1]
        as api_source,
      (array_agg(pa.api_id order by pa.created_at, pa.asset_id))[1] as api_id,
      sum(pa.quantity) as quantity,
      round(sum(pa.value_try), 4) as value_try,
      count(pa.asset_id)::integer as asset_row_count
    from priced_assets pa
    where pa.asset_id is not null
    group by pa.user_id, pa.portfolio_id, pa.snapshot_date, pa.symbol
  ),
  inserted as (
    insert into public.portfolio_value_snapshots (
      user_id,
      portfolio_id,
      snapshot_date,
      value_try,
      value_usd,
      usd_try_rate,
      fx_rates_updated_at,
      asset_count,
      captured_at
    )
    select
      c.user_id,
      c.portfolio_id,
      c.snapshot_date,
      c.value_try::numeric(20, 4),
      round(c.value_try / v_usd_try_rate, 4)::numeric(20, 4),
      v_usd_try_rate::numeric(20, 8),
      v_fx_rates_updated_at,
      c.asset_count,
      now()
    from portfolio_calculated c
    on conflict (portfolio_id, snapshot_date) do nothing
    returning 1
  ),
  inserted_asset_snapshots as (
    insert into public.portfolio_asset_value_snapshots (
      user_id,
      portfolio_id,
      snapshot_date,
      symbol,
      name,
      type,
      api_source,
      api_id,
      quantity,
      value_try,
      value_usd,
      usd_try_rate,
      fx_rates_updated_at,
      asset_row_count,
      captured_at
    )
    select
      ac.user_id,
      ac.portfolio_id,
      ac.snapshot_date,
      ac.symbol,
      ac.name,
      ac.type,
      ac.api_source,
      ac.api_id,
      ac.quantity::numeric(28, 8),
      ac.value_try::numeric(20, 4),
      round(ac.value_try / v_usd_try_rate, 4)::numeric(20, 4),
      v_usd_try_rate::numeric(20, 8),
      v_fx_rates_updated_at,
      ac.asset_row_count,
      now()
    from asset_calculated ac
    on conflict (portfolio_id, snapshot_date, symbol) do nothing
    returning 1
  ),
  deleted_old_asset_snapshots as (
    delete from public.portfolio_asset_value_snapshots pavs
    where pavs.snapshot_date < (v_snapshot_date - 2)
    returning 1
  )
  select
    v_snapshot_date,
    (select count(*)::integer from portfolio_calculated),
    (select count(*)::integer from inserted),
    (
      (select count(*)::integer from portfolio_calculated)
      - (select count(*)::integer from inserted)
      + ((select count(*)::integer from inserted_asset_snapshots) * 0)
      + ((select count(*)::integer from deleted_old_asset_snapshots) * 0)
    );
end;
$$;

revoke all on function public.record_portfolio_value_snapshots(date)
  from public, anon, authenticated;
grant execute on function public.record_portfolio_value_snapshots(date)
  to service_role;

-- Verification queries for Supabase SQL Editor:
select to_regclass('public.portfolio_value_snapshots') as snapshot_table;

select conname, contype
from pg_constraint
where conrelid = 'public.portfolio_value_snapshots'::regclass
order by conname;

select indexname
from pg_indexes
where schemaname = 'public'
  and tablename = 'portfolio_value_snapshots'
order by indexname;

select policyname, cmd, roles, qual
from pg_policies
where schemaname = 'public'
  and tablename = 'portfolio_value_snapshots'
order by policyname;

select to_regprocedure('public.record_portfolio_value_snapshots(date)')
  as record_snapshot_function;
