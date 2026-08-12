# TripMate

Travel expense manager and trip journal for friends.

> Track the money during the trip, keep the memories after the trip.

## Stack

- Flutter + Riverpod + GoRouter
- Supabase (Auth, Postgres, RLS, RPC, Storage, limited Realtime)

## Setup

1. Create a Supabase project.
2. Apply migrations in `supabase/migrations/` (001–014) in order.
3. Optionally run `supabase/seed.sql` (replace placeholder user UUIDs first).
4. Enable Email and Google auth providers in Supabase.
5. Create env file:

```bash
cp .env.example .env
# Edit .env with Project URL + anon/publishable key
```

6. Run the app:

```bash
make setup   # once: creates .env from .env.example
make run
```

Or manually:

```bash
flutter pub get
flutter run
```

See `make help` for migrate, seed, test, and other targets.

`--dart-define` still works and overrides `.env` when set.

Never put the service-role key in the Flutter app.

## Tests

```bash
flutter test
flutter analyze
```

## Structure

See `PROJECT_SPEC.md` for product and architecture details.
