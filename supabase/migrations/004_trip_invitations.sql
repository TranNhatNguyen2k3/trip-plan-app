-- TripMate: trip_invitations
-- Shareable invitation links (no email infrastructure)

create table public.trip_invitations (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  token text unique not null,
  invited_by uuid not null references public.profiles (id),
  expires_at timestamptz,
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.trip_invitations is 'Shareable trip invite tokens; join via /join/{token}';
