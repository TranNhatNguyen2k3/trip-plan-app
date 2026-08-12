-- TripMate: Row Level Security
-- Users may only access trip-related data if they are trip members

-- ---------------------------------------------------------------------------
-- Enable RLS on all tables
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.trips enable row level security;
alter table public.trip_members enable row level security;
alter table public.trip_invitations enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_participants enable row level security;
alter table public.settlements enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_photos enable row level security;

-- ---------------------------------------------------------------------------
-- profiles
-- Read: self or trip co-members; update: own profile only
-- ---------------------------------------------------------------------------

drop policy if exists "profiles_select_self_or_co_members" on public.profiles;

create policy "profiles_select_self_or_co_members"
  on public.profiles
  for select
  to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.trip_members tm_self
      join public.trip_members tm_other
        on tm_other.trip_id = tm_self.trip_id
      where tm_self.user_id = auth.uid()
        and tm_other.user_id = profiles.id
    )
  );

drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Insert handled by trigger on auth.users (security definer)

-- ---------------------------------------------------------------------------
-- trips
-- ---------------------------------------------------------------------------

drop policy if exists "trips_select_members" on public.trips;

create policy "trips_select_members"
  on public.trips
  for select
  to authenticated
  using (
    public.is_trip_member(id)
    or created_by = auth.uid()
  );

drop policy if exists "trips_insert_authenticated" on public.trips;

create policy "trips_insert_authenticated"
  on public.trips
  for insert
  to authenticated
  with check (created_by = auth.uid());

drop policy if exists "trips_update_owners" on public.trips;

create policy "trips_update_owners"
  on public.trips
  for update
  to authenticated
  using (public.is_trip_owner(id))
  with check (public.is_trip_owner(id));

drop policy if exists "trips_delete_owners" on public.trips;

create policy "trips_delete_owners"
  on public.trips
  for delete
  to authenticated
  using (public.is_trip_owner(id));

-- ---------------------------------------------------------------------------
-- trip_members
-- ---------------------------------------------------------------------------

drop policy if exists "trip_members_select_members" on public.trip_members;

create policy "trip_members_select_members"
  on public.trip_members
  for select
  to authenticated
  using (public.is_trip_member(trip_id));

drop policy if exists "trip_members_insert_owners" on public.trip_members;

create policy "trip_members_insert_owners"
  on public.trip_members
  for insert
  to authenticated
  with check (
    public.is_trip_owner(trip_id)
    or (
      -- Allow creator bootstrap via trigger / first owner insert during trip create
      user_id = auth.uid()
      and role = 'owner'
      and exists (
        select 1
        from public.trips t
        where t.id = trip_id
          and t.created_by = auth.uid()
      )
    )
  );

drop policy if exists "trip_members_update_owners" on public.trip_members;

create policy "trip_members_update_owners"
  on public.trip_members
  for update
  to authenticated
  using (public.is_trip_owner(trip_id))
  with check (public.is_trip_owner(trip_id));

drop policy if exists "trip_members_delete_owners_or_self" on public.trip_members;

create policy "trip_members_delete_owners_or_self"
  on public.trip_members
  for delete
  to authenticated
  using (
    public.is_trip_owner(trip_id)
    or user_id = auth.uid()
  );

-- ---------------------------------------------------------------------------
-- trip_invitations
-- ---------------------------------------------------------------------------

drop policy if exists "trip_invitations_select_members" on public.trip_invitations;

create policy "trip_invitations_select_members"
  on public.trip_invitations
  for select
  to authenticated
  using (public.is_trip_member(trip_id));

drop policy if exists "trip_invitations_insert_owners" on public.trip_invitations;

create policy "trip_invitations_insert_owners"
  on public.trip_invitations
  for insert
  to authenticated
  with check (
    public.is_trip_owner(trip_id)
    and invited_by = auth.uid()
  );

drop policy if exists "trip_invitations_update_owners" on public.trip_invitations;

create policy "trip_invitations_update_owners"
  on public.trip_invitations
  for update
  to authenticated
  using (public.is_trip_owner(trip_id))
  with check (public.is_trip_owner(trip_id));

drop policy if exists "trip_invitations_delete_owners" on public.trip_invitations;

create policy "trip_invitations_delete_owners"
  on public.trip_invitations
  for delete
  to authenticated
  using (public.is_trip_owner(trip_id));

-- ---------------------------------------------------------------------------
-- expenses
-- ---------------------------------------------------------------------------

drop policy if exists "expenses_select_members" on public.expenses;

create policy "expenses_select_members"
  on public.expenses
  for select
  to authenticated
  using (public.is_trip_member(trip_id));

drop policy if exists "expenses_insert_members" on public.expenses;

create policy "expenses_insert_members"
  on public.expenses
  for insert
  to authenticated
  with check (
    public.is_trip_member(trip_id)
    and created_by = auth.uid()
  );

drop policy if exists "expenses_update_own_or_owner" on public.expenses;

create policy "expenses_update_own_or_owner"
  on public.expenses
  for update
  to authenticated
  using (
    public.is_trip_member(trip_id)
    and (created_by = auth.uid() or public.is_trip_owner(trip_id))
  )
  with check (
    public.is_trip_member(trip_id)
    and (created_by = auth.uid() or public.is_trip_owner(trip_id))
  );

drop policy if exists "expenses_delete_own_or_owner" on public.expenses;

create policy "expenses_delete_own_or_owner"
  on public.expenses
  for delete
  to authenticated
  using (
    public.is_trip_member(trip_id)
    and (created_by = auth.uid() or public.is_trip_owner(trip_id))
  );

-- ---------------------------------------------------------------------------
-- expense_participants
-- ---------------------------------------------------------------------------

drop policy if exists "expense_participants_select_members" on public.expense_participants;

create policy "expense_participants_select_members"
  on public.expense_participants
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.expenses e
      where e.id = expense_participants.expense_id
        and public.is_trip_member(e.trip_id)
    )
  );

drop policy if exists "expense_participants_insert_members" on public.expense_participants;

create policy "expense_participants_insert_members"
  on public.expense_participants
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.expenses e
      where e.id = expense_participants.expense_id
        and public.is_trip_member(e.trip_id)
        and (e.created_by = auth.uid() or public.is_trip_owner(e.trip_id))
    )
  );

drop policy if exists "expense_participants_update_own_expense_or_owner" on public.expense_participants;

create policy "expense_participants_update_own_expense_or_owner"
  on public.expense_participants
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.expenses e
      where e.id = expense_participants.expense_id
        and public.is_trip_member(e.trip_id)
        and (e.created_by = auth.uid() or public.is_trip_owner(e.trip_id))
    )
  )
  with check (
    exists (
      select 1
      from public.expenses e
      where e.id = expense_participants.expense_id
        and public.is_trip_member(e.trip_id)
        and (e.created_by = auth.uid() or public.is_trip_owner(e.trip_id))
    )
  );

drop policy if exists "expense_participants_delete_own_expense_or_owner" on public.expense_participants;

create policy "expense_participants_delete_own_expense_or_owner"
  on public.expense_participants
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.expenses e
      where e.id = expense_participants.expense_id
        and public.is_trip_member(e.trip_id)
        and (e.created_by = auth.uid() or public.is_trip_owner(e.trip_id))
    )
  );

-- ---------------------------------------------------------------------------
-- settlements
-- ---------------------------------------------------------------------------

drop policy if exists "settlements_select_members" on public.settlements;

create policy "settlements_select_members"
  on public.settlements
  for select
  to authenticated
  using (public.is_trip_member(trip_id));

drop policy if exists "settlements_insert_members" on public.settlements;

create policy "settlements_insert_members"
  on public.settlements
  for insert
  to authenticated
  with check (
    public.is_trip_member(trip_id)
    and created_by = auth.uid()
    and public.is_trip_member(trip_id)
    and exists (
      select 1 from public.trip_members tm
      where tm.trip_id = settlements.trip_id
        and tm.user_id = settlements.from_user_id
    )
    and exists (
      select 1 from public.trip_members tm
      where tm.trip_id = settlements.trip_id
        and tm.user_id = settlements.to_user_id
    )
  );

drop policy if exists "settlements_update_own_or_owner" on public.settlements;

create policy "settlements_update_own_or_owner"
  on public.settlements
  for update
  to authenticated
  using (
    public.is_trip_member(trip_id)
    and (created_by = auth.uid() or public.is_trip_owner(trip_id))
  )
  with check (
    public.is_trip_member(trip_id)
    and (created_by = auth.uid() or public.is_trip_owner(trip_id))
  );

drop policy if exists "settlements_delete_own_or_owner" on public.settlements;

create policy "settlements_delete_own_or_owner"
  on public.settlements
  for delete
  to authenticated
  using (
    public.is_trip_member(trip_id)
    and (created_by = auth.uid() or public.is_trip_owner(trip_id))
  );

-- ---------------------------------------------------------------------------
-- journal_entries
-- ---------------------------------------------------------------------------

drop policy if exists "journal_entries_select_members" on public.journal_entries;

create policy "journal_entries_select_members"
  on public.journal_entries
  for select
  to authenticated
  using (public.is_trip_member(trip_id));

drop policy if exists "journal_entries_insert_members" on public.journal_entries;

create policy "journal_entries_insert_members"
  on public.journal_entries
  for insert
  to authenticated
  with check (
    public.is_trip_member(trip_id)
    and created_by = auth.uid()
  );

drop policy if exists "journal_entries_update_own_or_owner" on public.journal_entries;

create policy "journal_entries_update_own_or_owner"
  on public.journal_entries
  for update
  to authenticated
  using (
    public.is_trip_member(trip_id)
    and (created_by = auth.uid() or public.is_trip_owner(trip_id))
  )
  with check (
    public.is_trip_member(trip_id)
    and (created_by = auth.uid() or public.is_trip_owner(trip_id))
  );

drop policy if exists "journal_entries_delete_own_or_owner" on public.journal_entries;

create policy "journal_entries_delete_own_or_owner"
  on public.journal_entries
  for delete
  to authenticated
  using (
    public.is_trip_member(trip_id)
    and (created_by = auth.uid() or public.is_trip_owner(trip_id))
  );

-- ---------------------------------------------------------------------------
-- journal_photos
-- ---------------------------------------------------------------------------

drop policy if exists "journal_photos_select_members" on public.journal_photos;

create policy "journal_photos_select_members"
  on public.journal_photos
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.journal_entries je
      where je.id = journal_photos.journal_entry_id
        and public.is_trip_member(je.trip_id)
    )
  );

drop policy if exists "journal_photos_insert_members" on public.journal_photos;

create policy "journal_photos_insert_members"
  on public.journal_photos
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.journal_entries je
      where je.id = journal_photos.journal_entry_id
        and public.is_trip_member(je.trip_id)
        and (je.created_by = auth.uid() or public.is_trip_owner(je.trip_id))
    )
  );

drop policy if exists "journal_photos_update_own_entry_or_owner" on public.journal_photos;

create policy "journal_photos_update_own_entry_or_owner"
  on public.journal_photos
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.journal_entries je
      where je.id = journal_photos.journal_entry_id
        and public.is_trip_member(je.trip_id)
        and (je.created_by = auth.uid() or public.is_trip_owner(je.trip_id))
    )
  )
  with check (
    exists (
      select 1
      from public.journal_entries je
      where je.id = journal_photos.journal_entry_id
        and public.is_trip_member(je.trip_id)
        and (je.created_by = auth.uid() or public.is_trip_owner(je.trip_id))
    )
  );

drop policy if exists "journal_photos_delete_own_entry_or_owner" on public.journal_photos;

create policy "journal_photos_delete_own_entry_or_owner"
  on public.journal_photos
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.journal_entries je
      where je.id = journal_photos.journal_entry_id
        and public.is_trip_member(je.trip_id)
        and (je.created_by = auth.uid() or public.is_trip_owner(je.trip_id))
    )
  );
