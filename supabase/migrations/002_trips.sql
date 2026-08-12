-- TripMate: trips
-- Root entity for expenses and journal memories

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  destination text,
  start_date date,
  end_date date,
  currency text not null default 'VND',
  cover_photo_path text,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date is null or start_date is null or end_date >= start_date)
);

comment on table public.trips is 'Travel trips; amounts use trip currency as integer minor units (e.g. VND)';
