-- TripMate: Storage policies
-- Private bucket trip-journal
-- Object path: {trip_id}/{entry_id}/{photo_id}.jpg

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'trip-journal',
  'trip-journal',
  false,
  3145728, -- 3 MB hard max after compression
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Helper: trip_id is the first folder segment of the object name
create or replace function public.storage_trip_id(object_name text)
returns uuid
language sql
immutable
as $$
  select nullif((storage.foldername(object_name))[1], '')::uuid;
$$;

-- SELECT: trip members can read photos
create policy "trip_journal_select_members"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'trip-journal'
    and public.is_trip_member(public.storage_trip_id(name))
  );

-- INSERT: trip members can upload
create policy "trip_journal_insert_members"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'trip-journal'
    and public.is_trip_member(public.storage_trip_id(name))
  );

-- UPDATE: trip members can update (e.g. replace)
create policy "trip_journal_update_members"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'trip-journal'
    and public.is_trip_member(public.storage_trip_id(name))
  )
  with check (
    bucket_id = 'trip-journal'
    and public.is_trip_member(public.storage_trip_id(name))
  );

-- DELETE: trip members can delete
create policy "trip_journal_delete_members"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'trip-journal'
    and public.is_trip_member(public.storage_trip_id(name))
  );
