-- TripMate V3: community RPCs (sanitized public access)

create or replace function public._public_plan_card(t public.trips, p public.profiles)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'trip_id', t.id,
    'title', t.name,
    'destination', t.destination,
    'description', t.description,
    'cover_image', t.cover_photo_path,
    'start_date', t.start_date,
    'end_date', t.end_date,
    'duration_days', case
      when t.start_date is not null and t.end_date is not null
        then (t.end_date - t.start_date) + 1
      else null
    end,
    'trip_type', t.trip_type,
    'estimated_budget', coalesce(t.estimated_budget, t.budget_amount),
    'currency', t.currency,
    'created_at', t.created_at,
    'updated_at', t.updated_at,
    'published_at', t.published_at,
    'creator_id', t.created_by,
    'creator_display_name', p.display_name,
    'creator_avatar', p.avatar_url,
    'like_count', t.like_count,
    'save_count', t.save_count,
    'view_count', t.view_count,
    'clone_count', t.clone_count,
    'place_count', (
      select count(distinct je.location_name)
      from public.journal_entries je
      where je.trip_id = t.id
        and je.location_name is not null
        and length(trim(je.location_name)) > 0
    ),
    'memory_count', (
      select count(*) from public.journal_entries je where je.trip_id = t.id
    )
  );
$$;

-- ---------------------------------------------------------------------------
-- publish / unpublish
-- ---------------------------------------------------------------------------

create or replace function public.publish_trip_plan(
  p_trip_id uuid,
  p_trip_type text default null,
  p_estimated_budget bigint default null,
  p_photo_paths text[] default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_trip public.trips;
  v_entry_count int;
  v_path text;
  v_ord int := 0;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if not public.is_trip_owner(p_trip_id) then raise exception 'Only the owner can publish'; end if;

  select * into v_trip from public.trips where id = p_trip_id;
  if v_trip.id is null then raise exception 'Trip not found'; end if;
  if v_trip.name is null or length(trim(v_trip.name)) = 0 then
    raise exception 'Trip title is required';
  end if;
  if v_trip.destination is null or length(trim(v_trip.destination)) = 0 then
    raise exception 'Destination is required to publish';
  end if;

  select count(*) into v_entry_count
  from public.journal_entries je where je.trip_id = p_trip_id;
  if v_entry_count < 1 then
    raise exception 'Add at least one memory or place before publishing';
  end if;

  delete from public.trip_plan_photos where trip_id = p_trip_id;
  if p_photo_paths is not null then
    foreach v_path in array p_photo_paths loop
      insert into public.trip_plan_photos (trip_id, storage_path, display_order)
      values (p_trip_id, v_path, v_ord)
      on conflict (trip_id, storage_path) do update set display_order = excluded.display_order;
      v_ord := v_ord + 1;
    end loop;
  end if;

  update public.trips set
    visibility = 'public',
    trip_type = p_trip_type,
    estimated_budget = coalesce(p_estimated_budget, estimated_budget, budget_amount),
    published_at = coalesce(published_at, now()),
    updated_at = now()
  where id = p_trip_id;

  return jsonb_build_object('trip_id', p_trip_id, 'visibility', 'public');
end;
$$;

create or replace function public.unpublish_trip_plan(p_trip_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if not public.is_trip_owner(p_trip_id) then raise exception 'Only the owner can unpublish'; end if;

  update public.trips set
    visibility = 'private',
    updated_at = now()
  where id = p_trip_id;

  return jsonb_build_object('trip_id', p_trip_id, 'visibility', 'private');
end;
$$;

-- ---------------------------------------------------------------------------
-- list / search / get
-- ---------------------------------------------------------------------------

create or replace function public.list_public_trip_plans(
  p_destination text default null,
  p_trip_type text default null,
  p_sort text default 'popular',
  p_limit int default 20,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset int := greatest(coalesce(p_offset, 0), 0);
  v_result jsonb;
begin
  select coalesce(jsonb_agg(public._public_plan_card(t, p) order by
    case when coalesce(p_sort, 'popular') = 'recent' then extract(epoch from t.published_at) end desc nulls last,
    case when coalesce(p_sort, 'popular') = 'trending' then (t.like_count * 3 + t.save_count * 2 + t.view_count + t.clone_count * 4) end desc nulls last,
    case when coalesce(p_sort, 'popular') = 'popular' then (t.like_count * 2 + t.save_count * 3 + t.clone_count * 4) end desc nulls last,
    t.published_at desc
  ), '[]'::jsonb)
  into v_result
  from (
    select t.*
    from public.trips t
    where t.visibility = 'public'
      and (p_destination is null or t.destination ilike '%' || p_destination || '%')
      and (p_trip_type is null or t.trip_type = p_trip_type)
    order by
      case when coalesce(p_sort, 'popular') = 'recent' then t.published_at end desc nulls last,
      case when coalesce(p_sort, 'popular') = 'trending'
        then (t.like_count * 3 + t.save_count * 2 + t.view_count + t.clone_count * 4) end desc nulls last,
      case when coalesce(p_sort, 'popular') = 'popular'
        then (t.like_count * 2 + t.save_count * 3 + t.clone_count * 4) end desc nulls last,
      t.published_at desc
    limit v_limit offset v_offset
  ) t
  join public.profiles p on p.id = t.created_by;

  return v_result;
end;
$$;

create or replace function public.get_public_trip_plan(p_trip_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_trip public.trips;
  v_profile public.profiles;
  v_uid uuid := auth.uid();
  v_card jsonb;
  v_itinerary jsonb;
  v_photos jsonb;
  v_liked boolean := false;
  v_saved boolean := false;
begin
  select * into v_trip from public.trips where id = p_trip_id and visibility = 'public';
  if v_trip.id is null then raise exception 'Public plan not found'; end if;

  select * into v_profile from public.profiles where id = v_trip.created_by;
  v_card := public._public_plan_card(v_trip, v_profile);

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', je.id,
      'title', je.title,
      'location_name', je.location_name,
      'description', je.description,
      'visited_at', je.visited_at,
      'latitude', je.latitude,
      'longitude', je.longitude
    ) order by je.visited_at, je.created_at
  ), '[]'::jsonb)
  into v_itinerary
  from public.journal_entries je
  where je.trip_id = p_trip_id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'storage_path', tp.storage_path,
      'display_order', tp.display_order
    ) order by tp.display_order
  ), '[]'::jsonb)
  into v_photos
  from public.trip_plan_photos tp
  where tp.trip_id = p_trip_id;

  if v_uid is not null then
    select exists(
      select 1 from public.trip_plan_likes l
      where l.trip_id = p_trip_id and l.user_id = v_uid
    ) into v_liked;
    select exists(
      select 1 from public.trip_plan_saves s
      where s.trip_id = p_trip_id and s.user_id = v_uid
    ) into v_saved;
  end if;

  return v_card || jsonb_build_object(
    'itinerary', v_itinerary,
    'photos', v_photos,
    'liked_by_me', v_liked,
    'saved_by_me', v_saved,
    'cloned_from_trip_id', v_trip.cloned_from_trip_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- like / save / view
-- ---------------------------------------------------------------------------

create or replace function public.toggle_trip_plan_like(p_trip_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_exists boolean;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if not exists (select 1 from public.trips where id = p_trip_id and visibility = 'public') then
    raise exception 'Public plan not found';
  end if;

  select exists(
    select 1 from public.trip_plan_likes where trip_id = p_trip_id and user_id = v_uid
  ) into v_exists;

  if v_exists then
    delete from public.trip_plan_likes where trip_id = p_trip_id and user_id = v_uid;
    update public.trips set like_count = greatest(like_count - 1, 0) where id = p_trip_id;
    return jsonb_build_object('liked', false);
  else
    insert into public.trip_plan_likes (trip_id, user_id) values (p_trip_id, v_uid);
    update public.trips set like_count = like_count + 1 where id = p_trip_id;
    return jsonb_build_object('liked', true);
  end if;
end;
$$;

create or replace function public.toggle_trip_plan_save(p_trip_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_exists boolean;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if not exists (select 1 from public.trips where id = p_trip_id and visibility = 'public') then
    raise exception 'Public plan not found';
  end if;

  select exists(
    select 1 from public.trip_plan_saves where trip_id = p_trip_id and user_id = v_uid
  ) into v_exists;

  if v_exists then
    delete from public.trip_plan_saves where trip_id = p_trip_id and user_id = v_uid;
    update public.trips set save_count = greatest(save_count - 1, 0) where id = p_trip_id;
    return jsonb_build_object('saved', false);
  else
    insert into public.trip_plan_saves (trip_id, user_id) values (p_trip_id, v_uid);
    update public.trips set save_count = save_count + 1 where id = p_trip_id;
    return jsonb_build_object('saved', true);
  end if;
end;
$$;

create or replace function public.record_plan_view(p_trip_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_key text;
  v_inserted int;
begin
  if not exists (select 1 from public.trips where id = p_trip_id and visibility = 'public') then
    raise exception 'Public plan not found';
  end if;

  v_key := coalesce(v_uid::text, 'anon');
  insert into public.trip_plan_views (trip_id, user_id, viewer_key)
  values (p_trip_id, v_uid, v_key)
  on conflict (trip_id, viewer_key) do nothing;

  get diagnostics v_inserted = row_count;
  if v_inserted > 0 then
    update public.trips set view_count = view_count + 1 where id = p_trip_id;
  end if;

  return jsonb_build_object('ok', true, 'counted', v_inserted > 0);
end;
$$;

create or replace function public.list_saved_trip_plans(
  p_limit int default 20,
  p_offset int default 0
)
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
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select coalesce(jsonb_agg(public._public_plan_card(t, p) order by s.created_at desc), '[]'::jsonb)
  into v_result
  from public.trip_plan_saves s
  join public.trips t on t.id = s.trip_id and t.visibility = 'public'
  join public.profiles p on p.id = t.created_by
  where s.user_id = v_uid
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- clone
-- ---------------------------------------------------------------------------

create or replace function public.clone_trip_plan(p_trip_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_src public.trips;
  v_new_id uuid;
  v_entry record;
  v_new_entry_id uuid;
  v_photo record;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select * into v_src from public.trips where id = p_trip_id and visibility = 'public';
  if v_src.id is null then raise exception 'Public plan not found'; end if;

  insert into public.trips (
    name, description, destination, start_date, end_date, currency,
    cover_photo_path, budget_amount, estimated_budget, trip_type,
    visibility, created_by, cloned_from_trip_id
  ) values (
    v_src.name,
    v_src.description,
    v_src.destination,
    v_src.start_date,
    v_src.end_date,
    v_src.currency,
    v_src.cover_photo_path,
    v_src.estimated_budget,
    v_src.estimated_budget,
    v_src.trip_type,
    'private',
    v_uid,
    v_src.id
  ) returning id into v_new_id;

  -- owner membership via trigger; ensure exists
  insert into public.trip_members (trip_id, user_id, role)
  values (v_new_id, v_uid, 'owner')
  on conflict (trip_id, user_id) do nothing;

  for v_entry in
    select * from public.journal_entries where trip_id = p_trip_id order by visited_at, created_at
  loop
    insert into public.journal_entries (
      trip_id, title, location_name, latitude, longitude, description,
      visited_at, created_by
    ) values (
      v_new_id, v_entry.title, v_entry.location_name, v_entry.latitude, v_entry.longitude,
      v_entry.description, v_entry.visited_at, v_uid
    ) returning id into v_new_entry_id;
  end loop;

  -- Reference selected public photos on new trip journal is optional;
  -- store plan photo paths as trip_plan_photos is only for public; skip re-upload.
  -- Attach cover already copied.

  update public.trips set clone_count = clone_count + 1 where id = p_trip_id;

  return v_new_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- creator profile
-- ---------------------------------------------------------------------------

create or replace function public.get_creator_public_profile(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile public.profiles;
  v_plans jsonb;
  v_likes bigint;
  v_clones bigint;
  v_views bigint;
begin
  select * into v_profile from public.profiles where id = p_user_id;
  if v_profile.id is null then raise exception 'Creator not found'; end if;

  select coalesce(jsonb_agg(public._public_plan_card(t, v_profile) order by t.published_at desc), '[]'::jsonb)
  into v_plans
  from public.trips t
  where t.created_by = p_user_id and t.visibility = 'public';

  select coalesce(sum(like_count), 0), coalesce(sum(clone_count), 0), coalesce(sum(view_count), 0)
  into v_likes, v_clones, v_views
  from public.trips
  where created_by = p_user_id and visibility = 'public';

  return jsonb_build_object(
    'creator_id', v_profile.id,
    'display_name', v_profile.display_name,
    'avatar_url', v_profile.avatar_url,
    'public_plan_count', jsonb_array_length(v_plans),
    'total_likes', v_likes,
    'total_clones', v_clones,
    'total_views', v_views,
    'plans', v_plans
  );
end;
$$;

create or replace function public.list_popular_destinations(p_limit int default 8)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'destination', d.destination,
    'plan_count', d.plan_count
  ) order by d.plan_count desc), '[]'::jsonb)
  from (
    select destination, count(*)::int as plan_count
    from public.trips
    where visibility = 'public'
      and destination is not null
      and length(trim(destination)) > 0
    group by destination
    order by count(*) desc
    limit least(greatest(coalesce(p_limit, 8), 1), 20)
  ) d;
$$;

revoke all on function public.publish_trip_plan(uuid, text, bigint, text[]) from public;
grant execute on function public.publish_trip_plan(uuid, text, bigint, text[]) to authenticated;

revoke all on function public.unpublish_trip_plan(uuid) from public;
grant execute on function public.unpublish_trip_plan(uuid) to authenticated;

revoke all on function public.list_public_trip_plans(text, text, text, int, int) from public;
grant execute on function public.list_public_trip_plans(text, text, text, int, int) to authenticated;

revoke all on function public.get_public_trip_plan(uuid) from public;
grant execute on function public.get_public_trip_plan(uuid) to authenticated;

revoke all on function public.toggle_trip_plan_like(uuid) from public;
grant execute on function public.toggle_trip_plan_like(uuid) to authenticated;

revoke all on function public.toggle_trip_plan_save(uuid) from public;
grant execute on function public.toggle_trip_plan_save(uuid) to authenticated;

revoke all on function public.record_plan_view(uuid) from public;
grant execute on function public.record_plan_view(uuid) to authenticated;

revoke all on function public.list_saved_trip_plans(int, int) from public;
grant execute on function public.list_saved_trip_plans(int, int) to authenticated;

revoke all on function public.clone_trip_plan(uuid) from public;
grant execute on function public.clone_trip_plan(uuid) to authenticated;

revoke all on function public.get_creator_public_profile(uuid) from public;
grant execute on function public.get_creator_public_profile(uuid) to authenticated;

revoke all on function public.list_popular_destinations(int) from public;
grant execute on function public.list_popular_destinations(int) to authenticated;
