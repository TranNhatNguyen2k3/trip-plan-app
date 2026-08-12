-- TripMate: expenses
-- Trip expenses with integer amounts (never floating point)

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  description text not null,
  amount bigint not null check (amount > 0),
  category text not null default 'other' check (
    category in (
      'food',
      'hotel',
      'transport',
      'activity',
      'shopping',
      'tickets',
      'fuel',
      'other'
    )
  ),
  paid_by uuid not null references public.profiles (id),
  expense_date timestamptz not null default now(),
  note text,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.expenses is 'Trip expenses; amount is integer currency units';
