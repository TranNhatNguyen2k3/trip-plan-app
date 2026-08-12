-- TripMate: expense_participants
-- Per-member share of an expense; sum(shares) must equal expense.amount

create table public.expense_participants (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  share_amount bigint not null check (share_amount >= 0),
  unique (expense_id, user_id)
);

comment on table public.expense_participants is 'Expense split shares; unique per expense and user';
