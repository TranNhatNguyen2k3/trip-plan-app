-- Fix: allow creators to read their trips (INSERT ... RETURNING after create trip)
-- Without this, PostgREST insert+select fails if membership row is missing or lags.

drop policy if exists "trips_select_members" on public.trips;

create policy "trips_select_members"
  on public.trips
  for select
  to authenticated
  using (
    public.is_trip_member(id)
    or created_by = auth.uid()
  );
