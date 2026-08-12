-- TripMate: indexes
-- Spec section 84

create index idx_expenses_trip_id
  on public.expenses (trip_id);

create index idx_expenses_expense_date
  on public.expenses (expense_date);

create index idx_expenses_paid_by
  on public.expenses (paid_by);

create index idx_expense_participants_expense_id
  on public.expense_participants (expense_id);

create index idx_expense_participants_user_id
  on public.expense_participants (user_id);

create index idx_trip_members_trip_id
  on public.trip_members (trip_id);

create index idx_trip_members_user_id
  on public.trip_members (user_id);

create index idx_settlements_trip_id
  on public.settlements (trip_id);

create index idx_journal_entries_trip_id
  on public.journal_entries (trip_id);

create index idx_journal_entries_visited_at
  on public.journal_entries (visited_at);

create index idx_journal_entries_created_by
  on public.journal_entries (created_by);

create index idx_journal_photos_entry_id
  on public.journal_photos (journal_entry_id);

-- Helpful extras for invitations and settlements lookups
create index idx_trip_invitations_trip_id
  on public.trip_invitations (trip_id);

create index idx_trip_invitations_token
  on public.trip_invitations (token);

create index idx_settlements_from_user_id
  on public.settlements (from_user_id);

create index idx_settlements_to_user_id
  on public.settlements (to_user_id);
