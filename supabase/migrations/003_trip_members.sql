-- TripMate: trip_members
-- Membership and roles within a trip

create table public.trip_members (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  unique (trip_id, user_id)
);

comment on table public.trip_members is 'Trip membership; roles are owner or member';
