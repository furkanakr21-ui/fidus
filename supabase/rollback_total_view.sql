-- Rollback for setup_total_view.sql.
-- Removes only total-view configuration introduced by that migration.

begin;

drop index if exists public.transactions_user_asset_date_idx;
drop index if exists public.goals_user_portfolio_created_idx;
drop index if exists public.cashflows_user_portfolio_date_idx;
drop index if exists public.assets_user_portfolio_created_idx;

alter table public.user_settings
  drop column if exists total_view_active;

alter table public.portfolios
  drop column if exists include_in_total;

commit;
