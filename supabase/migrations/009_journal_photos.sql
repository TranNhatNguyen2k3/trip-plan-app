-- TripMate: journal_photos
-- Photos attached to journal entries; storage_path only (no signed URLs)

create table public.journal_photos (
  id uuid primary key default gen_random_uuid(),
  journal_entry_id uuid not null references public.journal_entries (id) on delete cascade,
  storage_path text not null,
  display_order integer not null default 0,
  caption text,
  created_at timestamptz not null default now()
);

comment on table public.journal_photos is 'Journal photo metadata; files live in trip-journal storage bucket';
