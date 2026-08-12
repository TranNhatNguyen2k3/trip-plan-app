-- TripMate development seed
-- =============================================================================
-- REQUIRES EXISTING auth.users ROWS.
-- Replace the four placeholder UUIDs below with real auth.users.id values
-- (and matching profiles created by handle_new_user) before running.
--
-- NEVER run this seed against production.
-- =============================================================================

-- Placeholder auth user IDs — REPLACE THESE
-- Nguyen (owner): aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
-- Minh:           bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
-- An:             cccccccc-cccc-cccc-cccc-cccccccccccc
-- Tuan:           dddddddd-dddd-dddd-dddd-dddddddddddd

do $$
declare
  -- >>> REPLACE with real auth.users IDs <<<
  v_nguyen uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_minh   uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_an     uuid := 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  v_tuan   uuid := 'dddddddd-dddd-dddd-dddd-dddddddddddd';

  v_trip_id uuid := '11111111-1111-1111-1111-111111111111';

  v_expense_hotel  uuid := '22222222-2222-2222-2222-222222222201';
  v_expense_dinner uuid := '22222222-2222-2222-2222-222222222202';
  v_expense_taxi   uuid := '22222222-2222-2222-2222-222222222203';
  v_expense_coffee uuid := '22222222-2222-2222-2222-222222222204';
  v_expense_tickets uuid := '22222222-2222-2222-2222-222222222205';

  v_entry_datanla uuid := '33333333-3333-3333-3333-333333333301';
  v_entry_market  uuid := '33333333-3333-3333-3333-333333333302';
  v_entry_langbiang uuid := '33333333-3333-3333-3333-333333333303';
  v_entry_xuan    uuid := '33333333-3333-3333-3333-333333333304';

  v_photo_1 uuid := '44444444-4444-4444-4444-444444444401';
  v_photo_2 uuid := '44444444-4444-4444-4444-444444444402';
  v_photo_3 uuid := '44444444-4444-4444-4444-444444444403';
begin
  -- Ensure profiles exist (safe if handle_new_user already created them)
  insert into public.profiles (id, display_name, avatar_url)
  values
    (v_nguyen, 'Nguyen', null),
    (v_minh, 'Minh', null),
    (v_an, 'An', null),
    (v_tuan, 'Tuan', null)
  on conflict (id) do update
  set display_name = excluded.display_name;

  -- Trip: Da Lat 2026
  -- Note: on_trip_created trigger adds Nguyen as owner member automatically
  insert into public.trips (
    id,
    name,
    description,
    destination,
    start_date,
    end_date,
    currency,
    created_by
  )
  values (
    v_trip_id,
    'Da Lat 2026',
    'Weekend getaway with friends — expenses + memories.',
    'Da Lat, Vietnam',
    '2026-08-20',
    '2026-08-23',
    'VND',
    v_nguyen
  )
  on conflict (id) do nothing;

  -- Remaining members
  insert into public.trip_members (trip_id, user_id, role)
  values
    (v_trip_id, v_minh, 'member'),
    (v_trip_id, v_an, 'member'),
    (v_trip_id, v_tuan, 'member')
  on conflict (trip_id, user_id) do nothing;

  -- Sample invitation (unused / open)
  insert into public.trip_invitations (trip_id, token, invited_by, expires_at)
  values (
    v_trip_id,
    'dalat-2026-invite-demo-token',
    v_nguyen,
    now() + interval '14 days'
  )
  on conflict (token) do nothing;

  -- Expenses (equal 4-way splits unless noted)
  -- Hotel 4,000,000 — paid by Nguyen
  insert into public.expenses (
    id, trip_id, description, amount, category, paid_by, expense_date, note, created_by
  ) values (
    v_expense_hotel, v_trip_id, 'Hotel', 4000000, 'hotel',
    v_nguyen, '2026-08-20 14:00:00+07', '2 nights downtown', v_nguyen
  ) on conflict (id) do nothing;

  insert into public.expense_participants (expense_id, user_id, share_amount)
  values
    (v_expense_hotel, v_nguyen, 1000000),
    (v_expense_hotel, v_minh, 1000000),
    (v_expense_hotel, v_an, 1000000),
    (v_expense_hotel, v_tuan, 1000000)
  on conflict (expense_id, user_id) do nothing;

  -- Dinner 1,000,000 — paid by Minh
  insert into public.expenses (
    id, trip_id, description, amount, category, paid_by, expense_date, note, created_by
  ) values (
    v_expense_dinner, v_trip_id, 'Dinner', 1000000, 'food',
    v_minh, '2026-08-20 19:30:00+07', 'Night market dinner', v_minh
  ) on conflict (id) do nothing;

  insert into public.expense_participants (expense_id, user_id, share_amount)
  values
    (v_expense_dinner, v_nguyen, 250000),
    (v_expense_dinner, v_minh, 250000),
    (v_expense_dinner, v_an, 250000),
    (v_expense_dinner, v_tuan, 250000)
  on conflict (expense_id, user_id) do nothing;

  -- Taxi 400,000 — paid by An
  insert into public.expenses (
    id, trip_id, description, amount, category, paid_by, expense_date, note, created_by
  ) values (
    v_expense_taxi, v_trip_id, 'Taxi', 400000, 'transport',
    v_an, '2026-08-21 09:00:00+07', 'Airport to hotel', v_an
  ) on conflict (id) do nothing;

  insert into public.expense_participants (expense_id, user_id, share_amount)
  values
    (v_expense_taxi, v_nguyen, 100000),
    (v_expense_taxi, v_minh, 100000),
    (v_expense_taxi, v_an, 100000),
    (v_expense_taxi, v_tuan, 100000)
  on conflict (expense_id, user_id) do nothing;

  -- Coffee 200,000 — paid by Tuan
  insert into public.expenses (
    id, trip_id, description, amount, category, paid_by, expense_date, note, created_by
  ) values (
    v_expense_coffee, v_trip_id, 'Coffee', 200000, 'food',
    v_tuan, '2026-08-21 15:00:00+07', 'Cafe street', v_tuan
  ) on conflict (id) do nothing;

  insert into public.expense_participants (expense_id, user_id, share_amount)
  values
    (v_expense_coffee, v_nguyen, 50000),
    (v_expense_coffee, v_minh, 50000),
    (v_expense_coffee, v_an, 50000),
    (v_expense_coffee, v_tuan, 50000)
  on conflict (expense_id, user_id) do nothing;

  -- Tickets 1,200,000 — paid by Nguyen
  insert into public.expenses (
    id, trip_id, description, amount, category, paid_by, expense_date, note, created_by
  ) values (
    v_expense_tickets, v_trip_id, 'Tickets', 1200000, 'tickets',
    v_nguyen, '2026-08-22 10:00:00+07', 'Langbiang entrance', v_nguyen
  ) on conflict (id) do nothing;

  insert into public.expense_participants (expense_id, user_id, share_amount)
  values
    (v_expense_tickets, v_nguyen, 300000),
    (v_expense_tickets, v_minh, 300000),
    (v_expense_tickets, v_an, 300000),
    (v_expense_tickets, v_tuan, 300000)
  on conflict (expense_id, user_id) do nothing;

  -- Sample settlement: Minh → Nguyen 300,000
  insert into public.settlements (
    trip_id, from_user_id, to_user_id, amount, note, status, created_by
  ) values (
    v_trip_id, v_minh, v_nguyen, 300000, 'Partial hotel share', 'completed', v_minh
  );

  -- Journal memories
  insert into public.journal_entries (
    id, trip_id, title, location_name, latitude, longitude,
    description, visited_at, created_by
  ) values
    (
      v_entry_datanla, v_trip_id, 'Datanla Waterfall', 'Datanla Waterfall',
      11.9005, 108.4482,
      'Beautiful waterfall and super cold water.',
      '2026-08-20 10:30:00+07', v_nguyen
    ),
    (
      v_entry_market, v_trip_id, 'Da Lat Night Market', 'Da Lat Night Market',
      11.9404, 108.4583,
      'Amazing food tonight.',
      '2026-08-20 19:45:00+07', v_minh
    ),
    (
      v_entry_langbiang, v_trip_id, 'Langbiang Peak', 'Langbiang Mountain',
      12.0472, 108.4369,
      'Cloudy views and chilly wind at the top.',
      '2026-08-22 11:15:00+07', v_an
    ),
    (
      v_entry_xuan, v_trip_id, 'Xuan Huong Lake', 'Xuan Huong Lake',
      11.9447, 108.4449,
      'Evening walk around the lake.',
      '2026-08-22 17:30:00+07', v_tuan
    )
  on conflict (id) do nothing;

  -- Photo metadata (storage objects themselves are not seeded)
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
    ),
    (
      v_photo_3,
      v_entry_langbiang,
      v_trip_id::text || '/' || v_entry_langbiang::text || '/' || v_photo_3::text || '.jpg',
      0,
      'Summit selfie'
    )
  on conflict (id) do nothing;

  -- Optional: set cover from first journal photo path
  update public.trips
  set cover_photo_path = v_trip_id::text || '/' || v_entry_datanla::text || '/' || v_photo_1::text || '.jpg'
  where id = v_trip_id
    and cover_photo_path is null;
end $$;
