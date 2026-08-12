-- TripMate V3: community trip plans schema

-- ---------------------------------------------------------------------------
-- Extend trips
-- ---------------------------------------------------------------------------

alter table public.trips
  add column if not exists visibility text not null default 'private';

alter table public.trips
  drop constraint if exists trips_visibility_check;

alter table public.trips
  add constraint trips_visibility_check
  check (visibility in ('private', 'public'));

alter table public.trips
  add column if not exists trip_type text;

alter table public.trips
  drop constraint if exists trips_trip_type_check;

alter table public.trips
  add constraint trips_trip_type_check
  check (
    trip_type is null
    or trip_type in (
      'weekend', 'budget', 'friends', 'family', 'couple', 'adventure', 'relax'
    )
  );

alter table public.trips
  add column if not exists estimated_budget bigint;

alter table public.trips
  drop constraint if exists trips_estimated_budget_check;

alter table public.trips
  add constraint trips_estimated_budget_check
  check (estimated_budget is null or estimated_budget > 0);

alter table public.trips
  add column if not exists published_at timestamptz;

alter table public.trips
  add column if not exists like_count bigint not null default 0;

alter table public.trips
  add column if not exists save_count bigint not null default 0;

alter table public.trips
  add column if not exists view_count bigint not null default 0;

alter table public.trips
  add column if not exists clone_count bigint not null default 0;

alter table public.trips
  add column if not exists cloned_from_trip_id uuid references public.trips (id) on delete set null;

create index if not exists idx_trips_visibility_published
  on public.trips (visibility, published_at desc)
  where visibility = 'public';

create index if not exists idx_trips_destination_public
  on public.trips (destination)
  where visibility = 'public';

-- ---------------------------------------------------------------------------
-- Engagement + selected public photos
-- ---------------------------------------------------------------------------

create table if not exists public.trip_plan_photos (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  storage_path text not null,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (trip_id, storage_path)
);

create index if not exists idx_trip_plan_photos_trip_id
  on public.trip_plan_photos (trip_id);

create table if not exists public.trip_plan_likes (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (trip_id, user_id)
);

create index if not exists idx_trip_plan_likes_trip_id
  on public.trip_plan_likes (trip_id);

create table if not exists public.trip_plan_saves (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (trip_id, user_id)
);

create index if not exists idx_trip_plan_saves_user_id
  on public.trip_plan_saves (user_id);

create table if not exists public.trip_plan_views (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  viewer_key text not null,
  created_at timestamptz not null default now(),
  unique (trip_id, viewer_key)
);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.trip_plan_photos enable row level security;
alter table public.trip_plan_likes enable row level security;
alter table public.trip_plan_saves enable row level security;
alter table public.trip_plan_views enable row level security;

-- Owners manage selected publish photos; anyone can read photos of public plans
drop policy if exists "trip_plan_photos_select_public_or_member" on public.trip_plan_photos;
create policy "trip_plan_photos_select_public_or_member"
  on public.trip_plan_photos for select to authenticated
  using (
    exists (
      select 1 from public.trips t
      where t.id = trip_plan_photos.trip_id
        and (t.visibility = 'public' or public.is_trip_member(t.id))
    )
  );

drop policy if exists "trip_plan_photos_manage_owner" on public.trip_plan_photos;
create policy "trip_plan_photos_manage_owner"
  on public.trip_plan_photos for all to authenticated
  using (public.is_trip_owner(trip_id))
  with check (public.is_trip_owner(trip_id));

drop policy if exists "trip_plan_likes_select" on public.trip_plan_likes;
create policy "trip_plan_likes_select"
  on public.trip_plan_likes for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.trips t
      where t.id = trip_plan_likes.trip_id and t.visibility = 'public'
    )
  );

drop policy if exists "trip_plan_likes_insert_own" on public.trip_plan_likes;
create policy "trip_plan_likes_insert_own"
  on public.trip_plan_likes for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.trips t
      where t.id = trip_id and t.visibility = 'public'
    )
  );

drop policy if exists "trip_plan_likes_delete_own" on public.trip_plan_likes;
create policy "trip_plan_likes_delete_own"
  on public.trip_plan_likes for delete to authenticated
  using (user_id = auth.uid());

drop policy if exists "trip_plan_saves_select_own" on public.trip_plan_saves;
create policy "trip_plan_saves_select_own"
  on public.trip_plan_saves for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "trip_plan_saves_insert_own" on public.trip_plan_saves;
create policy "trip_plan_saves_insert_own"
  on public.trip_plan_saves for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.trips t
      where t.id = trip_id and t.visibility = 'public'
    )
  );

drop policy if exists "trip_plan_saves_delete_own" on public.trip_plan_saves;
create policy "trip_plan_saves_delete_own"
  on public.trip_plan_saves for delete to authenticated
  using (user_id = auth.uid());

drop policy if exists "trip_plan_views_insert_own" on public.trip_plan_views;
create policy "trip_plan_views_insert_own"
  on public.trip_plan_views for insert to authenticated
  with check (user_id = auth.uid() or user_id is null);

-- Allow authenticated users to read basic profile of public plan creators
drop policy if exists "profiles_select_public_creators" on public.profiles;
create policy "profiles_select_public_creators"
  on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from public.trips t
      where t.created_by = profiles.id and t.visibility = 'public'
    )
    or exists (
      select 1
      from public.trip_members tm_self
      join public.trip_members tm_other on tm_other.trip_id = tm_self.trip_id
      where tm_self.user_id = auth.uid() and tm_other.user_id = profiles.id
    )
  );
