-- TripMate V2: optional trip budget

alter table public.trips
  add column if not exists budget_amount bigint;

alter table public.trips
  drop constraint if exists trips_budget_amount_check;

alter table public.trips
  add constraint trips_budget_amount_check
  check (budget_amount is null or budget_amount > 0);

comment on column public.trips.budget_amount is 'Optional total trip budget in integer currency units';

-- Aggregate budget summary (spent = expenses only, never settlements)
create or replace function public.get_trip_budget_summary(p_trip_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_budget bigint;
  v_spent bigint;
  v_by_category jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_trip_member(p_trip_id) then
    raise exception 'Not a trip member';
  end if;

  select t.budget_amount into v_budget
  from public.trips t
  where t.id = p_trip_id;

  select coalesce(sum(e.amount), 0) into v_spent
  from public.expenses e
  where e.trip_id = p_trip_id;

  select coalesce(jsonb_agg(
    jsonb_build_object('category', x.category, 'amount', x.amount)
    order by x.amount desc
  ), '[]'::jsonb)
  into v_by_category
  from (
    select e.category, sum(e.amount)::bigint as amount
    from public.expenses e
    where e.trip_id = p_trip_id
    group by e.category
  ) x;

  return jsonb_build_object(
    'budget_amount', v_budget,
    'spent', v_spent,
    'by_category', v_by_category
  );
end;
$$;

revoke all on function public.get_trip_budget_summary(uuid) from public;
grant execute on function public.get_trip_budget_summary(uuid) to authenticated;
