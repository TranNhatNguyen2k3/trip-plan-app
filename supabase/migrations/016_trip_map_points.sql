-- TripMate V2: map points from journal entries with coordinates

create or replace function public.get_trip_map_points(p_trip_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_trip_member(p_trip_id) then
    raise exception 'Not a trip member';
  end if;

  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.visited_at, x.created_at), '[]'::jsonb)
  into v_result
  from (
    select
      je.id,
      je.title,
      je.location_name,
      je.latitude,
      je.longitude,
      je.visited_at,
      je.created_at,
      (
        select jp.storage_path
        from public.journal_photos jp
        where jp.journal_entry_id = je.id
        order by jp.display_order, jp.created_at
        limit 1
      ) as photo_path
    from public.journal_entries je
    where je.trip_id = p_trip_id
      and je.latitude is not null
      and je.longitude is not null
      and je.latitude between -90 and 90
      and je.longitude between -180 and 180
  ) x;

  return v_result;
end;
$$;

revoke all on function public.get_trip_map_points(uuid) from public;
grant execute on function public.get_trip_map_points(uuid) to authenticated;
