-- TripMate: journal_entries
-- Trip memories / diary entries (coordinates optional)

create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  title text,
  location_name text,
  latitude double precision,
  longitude double precision,
  description text,
  visited_at timestamptz not null default now(),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.journal_entries is 'Trip journal memories; location fields are optional';
