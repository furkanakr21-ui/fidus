-- Rollback for setup_total_view.sql.
-- Removes only total-view configuration introduced by that migration.

begin;

alter table public.user_settings
  drop column if exists total_view_active;

alter table public.portfolios
  drop column if exists include_in_total;

commit;
