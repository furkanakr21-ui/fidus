-- ============================================================================
-- Explicit Data API grants for Supabase public schema tables.
--
-- Purpose:
--   Supabase will require explicit GRANT statements for public tables exposed
--   through the Data API. This script makes the intended access model explicit
--   without deleting data, dropping objects, or changing application behavior.
--
-- Safe to run multiple times.
-- ============================================================================

grant usage on schema public to anon, authenticated, service_role;

do $$
declare
  v_table text;
  v_sequence text;
  v_user_rw_tables text[] := array[
    'profiles',
    'user_settings',
    'portfolios',
    'assets',
    'transactions',
    'cashflows',
    'goals'
  ];
  v_public_read_tables text[] := array[
    'prices',
    'exchange_rates',
    'asset_metadata',
    'tefas_funds'
  ];
  v_authenticated_read_tables text[] := array[
    'portfolio_value_snapshots',
    'portfolio_asset_value_snapshots',
    'market_data_runs'
  ];
  v_service_only_tables text[] := array[
    'cron_runs'
  ];
begin
  foreach v_table in array v_user_rw_tables loop
    if to_regclass(format('public.%I', v_table)) is not null then
      execute format(
        'grant select, insert, update, delete on table public.%I to authenticated',
        v_table
      );
      execute format(
        'grant all privileges on table public.%I to service_role',
        v_table
      );
    end if;
  end loop;

  foreach v_table in array v_public_read_tables loop
    if to_regclass(format('public.%I', v_table)) is not null then
      execute format(
        'grant select on table public.%I to anon, authenticated',
        v_table
      );
      execute format(
        'grant all privileges on table public.%I to service_role',
        v_table
      );
    end if;
  end loop;

  foreach v_table in array v_authenticated_read_tables loop
    if to_regclass(format('public.%I', v_table)) is not null then
      execute format(
        'grant select on table public.%I to authenticated',
        v_table
      );
      execute format(
        'grant all privileges on table public.%I to service_role',
        v_table
      );
    end if;
  end loop;

  foreach v_table in array v_service_only_tables loop
    if to_regclass(format('public.%I', v_table)) is not null then
      execute format(
        'grant all privileges on table public.%I to service_role',
        v_table
      );
    end if;
  end loop;

  for v_sequence in
    select quote_ident(sequence_schema) || '.' || quote_ident(sequence_name)
    from information_schema.sequences
    where sequence_schema = 'public'
  loop
    execute format(
      'grant usage, select on sequence %s to service_role',
      v_sequence
    );
  end loop;
end $$;

-- Verification helpers. These are read-only and can be run after the script.
select
  table_name,
  grantee,
  privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated', 'service_role')
order by table_name, grantee, privilege_type;
