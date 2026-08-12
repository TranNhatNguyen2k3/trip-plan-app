-- TripMate: settlements
-- Recorded only when a user marks a settlement as paid

create table public.settlements (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  from_user_id uuid not null references public.profiles (id),
  to_user_id uuid not null references public.profiles (id),
  amount bigint not null check (amount > 0),
  note text,
  status text not null default 'completed' check (
    status in ('pending', 'completed', 'cancelled')
  ),
  settled_at timestamptz not null default now(),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  check (from_user_id <> to_user_id)
);

comment on table public.settlements is 'Marked-paid settlements; from_user pays to_user';
