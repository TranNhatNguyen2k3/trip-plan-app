-- TripMate: aggregate home balance (one RPC instead of N get_trip_balances)

create or replace function public.get_user_home_balance_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owe bigint := 0;
  v_receive bigint := 0;
  v_trip_id uuid;
  v_bal record;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  for v_trip_id in
    select tm.trip_id
    from public.trip_members tm
    where tm.user_id = v_uid
  loop
    for v_bal in
      select * from public.get_trip_balances(v_trip_id)
    loop
      if v_bal.user_id <> v_uid then
        continue;
      end if;
      if v_bal.net_balance < 0 then
        v_owe := v_owe + (-v_bal.net_balance);
      elsif v_bal.net_balance > 0 then
        v_receive := v_receive + v_bal.net_balance;
      end if;
    end loop;
  end loop;

  return jsonb_build_object(
    'owe', v_owe,
    'receive', v_receive
  );
end;
$$;

revoke all on function public.get_user_home_balance_summary() from public;
grant execute on function public.get_user_home_balance_summary() to authenticated;
