-- Adds a narrowly scoped legacy finance-api -> TEFAS fallback to the live
-- snapshot function without changing user assets, prices, or snapshot rows.
do $patch$
declare
  v_function_definition text;
  v_old_fragment constant text := $old$
              when coalesce(a.api_source, 'manual') = 'befas' then 'tefas'
              else coalesce(a.api_source, 'manual')
$old$;
  v_new_fragment constant text := $new$
              when coalesce(a.api_source, 'manual') = 'befas' then 'tefas'
              when a.type = 'fund'
                and coalesce(a.api_source, 'manual') = 'finance-api'
                then 'tefas'
              else coalesce(a.api_source, 'manual')
$new$;
begin
  select pg_get_functiondef(
    'public.record_portfolio_value_snapshots(date)'::regprocedure
  )
    into v_function_definition;

  if v_function_definition is null then
    raise exception 'record_portfolio_value_snapshots(date) does not exist';
  end if;

  if position('finance-api' in v_function_definition) > 0 then
    if position(v_new_fragment in v_function_definition) = 0 or (
      length(v_function_definition)
      - length(replace(v_function_definition, 'finance-api', ''))
    ) <> (2 * length('finance-api')) then
      raise exception 'Snapshot function has an unexpected partial legacy fallback';
    end if;
    return;
  end if;

  if position(v_old_fragment in v_function_definition) = 0 then
    raise exception 'Snapshot function does not match the expected source-selection structure';
  end if;

  v_function_definition := replace(
    v_function_definition,
    v_old_fragment,
    v_new_fragment
  );

  if (
    length(v_function_definition)
    - length(replace(v_function_definition, 'finance-api', ''))
  ) <> (2 * length('finance-api')) then
    raise exception 'Expected to add exactly two legacy fund fallbacks';
  end if;

  execute v_function_definition;
end;
$patch$;

select
  (
    length(pg_get_functiondef(
      'public.record_portfolio_value_snapshots(date)'::regprocedure
    ))
    - length(replace(
      pg_get_functiondef(
        'public.record_portfolio_value_snapshots(date)'::regprocedure
      ),
      'finance-api',
      ''
    ))
  ) / length('finance-api') as legacy_fallback_count;
