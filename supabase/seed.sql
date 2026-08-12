-- TripMate development seed (single-user demo)
-- =============================================================================
-- Prerequisite: at least one user in Auth. If auth.users is empty, run first:
--   supabase/seed_dev_user.sql   (demo@tripmate.dev / Demo123456!)
-- Or sign up in the app, or Dashboard → Authentication → Users → Add user.
--
-- By default this seed uses the newest auth.users row. To target a specific
-- account, set v_owner_override below to that user's id.
--
--   select id, email from auth.users order by created_at desc;
--
-- NEVER run against production.
-- =============================================================================

do $$
declare
  -- Optional: set to a specific auth.users.id; leave null for newest user
  v_owner_override uuid := null;

  v_owner uuid;

  v_trip_id uuid := '11111111-1111-1111-1111-111111111111';

  v_expense_hotel   uuid := '22222222-2222-2222-2222-222222222201';
  v_expense_dinner  uuid := '22222222-2222-2222-2222-222222222202';
  v_expense_taxi    uuid := '22222222-2222-2222-2222-222222222203';

  v_entry_datanla   uuid := '33333333-3333-3333-3333-333333333301';
  v_entry_market    uuid := '33333333-3333-3333-3333-333333333302';

  v_photo_1 uuid := '44444444-4444-4444-4444-444444444401';
  v_photo_2 uuid := '44444444-4444-4444-4444-444444444402';
begin
  v_owner := v_owner_override;

  if v_owner is null then
    select u.id
    into v_owner
    from auth.users u
    order by u.created_at desc nulls last
    limit 1;
  end if;

  if v_owner is null then
    raise exception
      'No users in auth.users. Either: (1) sign up in the TripMate app, or (2) run supabase/seed_dev_user.sql in SQL Editor, then run seed.sql again.';
  end if;

  if not exists (select 1 from auth.users u where u.id = v_owner) then
    raise exception
      'auth.users has no row for %. Check v_owner_override or run: select id, email from auth.users;',
      v_owner;
  end if;

  raise notice 'Seeding demo trip for user %', v_owner;

  -- Profile row is created by handle_new_user on signup; optional display name tweak
  update public.profiles
  set display_name = coalesce(nullif(trim(display_name), ''), 'Demo Traveler')
  where id = v_owner;

  insert into public.trips (
    id,
    name,
    description,
    destination,
    start_date,
    end_date,
    currency,
    budget_amount,
    created_by
  )
  values (
    v_trip_id,
    'Da Lat 2026',
    'Weekend demo trip — expenses + memories.',
    'Da Lat, Vietnam',
    '2026-08-20',
    '2026-08-23',
    'VND',
    8000000,
    v_owner
  )
  on conflict (id) do nothing;

  -- Owner member is added by on_trip_created trigger; ensure row exists if trigger skipped
  insert into public.trip_members (trip_id, user_id, role)
  values (v_trip_id, v_owner, 'owner')
  on conflict (trip_id, user_id) do nothing;

  insert into public.trip_invitations (trip_id, token, invited_by, expires_at)
  values (
    v_trip_id,
    'dalat-2026-invite-demo-token',
    v_owner,
    now() + interval '14 days'
  )
  on conflict (token) do nothing;

  insert into public.expenses (
    id, trip_id, description, amount, category, paid_by, expense_date, note, created_by
  ) values
    (
      v_expense_hotel, v_trip_id, 'Hotel', 4000000, 'hotel',
      v_owner, '2026-08-20 14:00:00+07', '2 nights downtown', v_owner
    ),
    (
      v_expense_dinner, v_trip_id, 'Dinner', 1000000, 'food',
      v_owner, '2026-08-20 19:30:00+07', 'Night market dinner', v_owner
    ),
    (
      v_expense_taxi, v_trip_id, 'Taxi', 400000, 'transport',
      v_owner, '2026-08-21 09:00:00+07', 'Airport to hotel', v_owner
    )
  on conflict (id) do nothing;

  insert into public.expense_participants (expense_id, user_id, share_amount)
  values
    (v_expense_hotel, v_owner, 4000000),
    (v_expense_dinner, v_owner, 1000000),
    (v_expense_taxi, v_owner, 400000)
  on conflict (expense_id, user_id) do nothing;

  insert into public.journal_entries (
    id, trip_id, title, location_name, latitude, longitude,
    description, visited_at, created_by
  ) values
    (
      v_entry_datanla, v_trip_id, 'Datanla Waterfall', 'Datanla Waterfall',
      11.9005, 108.4482,
      'Beautiful waterfall and super cold water.',
      '2026-08-20 10:30:00+07', v_owner
    ),
    (
      v_entry_market, v_trip_id, 'Da Lat Night Market', 'Da Lat Night Market',
      11.9404, 108.4583,
      'Amazing food tonight.',
      '2026-08-20 19:45:00+07', v_owner
    )
  on conflict (id) do nothing;

  insert into public.journal_photos (
    id, journal_entry_id, storage_path, display_order, caption
  ) values
    (
      v_photo_1,
      v_entry_datanla,
      v_trip_id::text || '/' || v_entry_datanla::text || '/' || v_photo_1::text || '.jpg',
      0,
      'From the bridge'
    ),
    (
      v_photo_2,
      v_entry_market,
      v_trip_id::text || '/' || v_entry_market::text || '/' || v_photo_2::text || '.jpg',
      0,
      'Street food stalls'
    )
  on conflict (id) do nothing;

  update public.trips
  set cover_photo_path = v_trip_id::text || '/' || v_entry_datanla::text || '/' || v_photo_1::text || '.jpg'
  where id = v_trip_id
    and cover_photo_path is null;
end $$;
