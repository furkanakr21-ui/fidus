-- Portfolio total view foundation.
-- Additive and idempotent: does not delete or rewrite existing data.

begin;

alter table public.portfolios
  add column if not exists include_in_total boolean not null default true;

comment on column public.portfolios.include_in_total is
  'Whether this real portfolio participates in the virtual total view.';

alter table public.user_settings
  add column if not exists total_view_active boolean not null default false;

comment on column public.user_settings.total_view_active is
  'Whether the client should open the virtual total portfolio view.';

create index if not exists assets_user_portfolio_created_idx
  on public.assets (user_id, portfolio_id, created_at, id);

create index if not exists cashflows_user_portfolio_date_idx
  on public.cashflows (user_id, portfolio_id, date desc, id);

create index if not exists goals_user_portfolio_created_idx
  on public.goals (user_id, portfolio_id, created_at, id);

create index if not exists transactions_user_asset_date_idx
  on public.transactions (user_id, asset_id, date desc, id);

commit;
