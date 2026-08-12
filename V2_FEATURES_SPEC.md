# V2_FEATURES_SPEC.md

# Trip App — V2 Feature Implementation Specification

> **Purpose:** Extend the existing V1 Flutter + Supabase application with 5 new features.
>
> **IMPORTANT:** V1 is already implemented and working. Do NOT rebuild V1. Do NOT replace the existing architecture unless absolutely necessary.

---

# 1. Core Instruction to Cursor

You are working on an existing Flutter application.

V1 has already been implemented.

Your job is to:

1. Inspect the existing project first.
2. Understand the current architecture.
3. Reuse existing models, repositories, services, providers, widgets, routes and Supabase setup.
4. Add only the V2 functionality described in this document.
5. Keep all existing V1 behavior working.
6. Avoid unnecessary refactoring.
7. Avoid introducing a new backend.
8. Prefer Supabase Database, Storage and RPC.
9. Keep Supabase Free-plan usage as low as practical.
10. Follow the existing coding conventions of the project.

Before changing code, inspect:

```text
lib/
pubspec.yaml
supabase/
supabase/migrations/
README.md
existing database schema
existing Riverpod providers
existing routing
existing design system
existing authentication
existing storage implementation
```

Do not assume names of existing classes or tables.

Use the actual project implementation.

---

# 2. V2 Features

Implement these 5 features:

```text
1. Smart Settlement
2. Trip Budget
3. Smart Trip Map
4. Auto Trip Recap
5. Digital Trip Book
```

Recommended implementation order:

```text
Smart Settlement
      ↓
Trip Budget
      ↓
Smart Trip Map
      ↓
Auto Trip Recap
      ↓
Digital Trip Book
```

Each feature must be independently usable.

---

# 3. Non-Regression Requirement

Do NOT break:

```text
Authentication
Trip creation
Trip joining
Trip members
Expense creation
Expense editing
Expense deletion
Expense splitting
Journal creation
Photo upload
Existing navigation
Existing Supabase RLS
Existing UI
Existing settings
```

Before finishing:

```text
flutter analyze
flutter test
```

must pass.

Fix regressions rather than disabling tests or lint rules.

---

# 4. Architecture Rules

Follow the architecture already present in the project.

If the project uses:

```text
features/
data/
domain/
presentation/
```

continue using it.

If the project uses another structure, follow that structure.

Do NOT migrate the entire project to another architecture for V2.

For each new feature, prefer:

```text
UI
 ↓
Riverpod / existing state management
 ↓
Repository
 ↓
Supabase
```

Business logic should not live inside widgets.

---

# 5. Supabase Rules

The app already uses Supabase.

Continue using the existing Supabase client.

Do NOT:

```text
create another backend
create another database
create another authentication system
duplicate user data
duplicate trip data
```

Prefer:

```text
PostgreSQL
RPC
RLS
Storage
```

over unnecessary application-side downloads.

---

# 6. Supabase Free-Plan Optimization

This is important.

Avoid:

```text
continuous polling
background GPS tracking
global Realtime subscriptions
duplicate image uploads
unnecessary database writes
large repeated queries
loading all trip photos at once
```

Use:

```text
pagination
selective columns
RPC aggregation
lazy loading
image compression
thumbnail loading
cached local state
```

Only use Realtime where the existing V1 implementation already requires it or where it provides clear value.

---

# 7. Feature 1 — Smart Settlement

## 7.1 Goal

Improve the existing balance screen so the app tells users exactly:

```text
Who should pay whom
How much
How many payments are required
```

The objective is to minimize practical transfers.

Example:

```text
Nguyen +900,000

Minh -300,000
An   -300,000
Tuan -300,000
```

Display:

```text
Minh → Nguyen
300,000 ₫

An → Nguyen
300,000 ₫

Tuan → Nguyen
300,000 ₫
```

---

## 7.2 Inspect Existing V1

Before implementation find:

```text
existing balance calculation
existing expense split logic
existing member model
existing expense repository
existing trip detail screen
```

Reuse these.

Do NOT implement a second balance calculation if V1 already has one.

---

## 7.3 Settlement Algorithm

Implement a deterministic settlement algorithm.

Input:

```dart
List<Balance>
```

Each balance should contain:

```text
memberId
amount
```

Convention:

```text
amount > 0
→ member should receive money

amount < 0
→ member owes money
```

Algorithm:

```text
1. Separate creditors and debtors.
2. Sort by absolute amount descending.
3. Match largest debtor with largest creditor.
4. Transfer min(debt, credit).
5. Reduce both balances.
6. Continue until all balances are zero.
```

Use integer money values.

Never use floating point for currency.

---

## 7.4 Example

Input:

```text
A +500
B +200
C -400
D -300
```

Valid result:

```text
C → A 400
D → A 100
D → B 200
```

---

## 7.5 Settlement UI

Add or improve the existing Settlement section.

Example:

```text
Settlement

3 payments needed

┌────────────────────────────┐
│ Minh pays Nguyen           │
│                            │
│ 300,000 ₫                  │
│                            │
│ [ Mark as Paid ]           │
└────────────────────────────┘
```

Use existing design system.

Do not introduce an unrelated visual style.

---

## 7.6 Mark as Paid

Confirmation:

```text
Mark payment as completed?

Minh → Nguyen

300,000 ₫

[ Cancel ] [ Confirm ]
```

Only create a payment/settlement history record after explicit confirmation.

Generated settlement suggestions must not automatically become database records.

---

## 7.7 Settlement History

If V1 already has a settlement/payment table, reuse it.

If not, add a minimal table only when required.

Recommended fields:

```text
id
trip_id
from_user_id
to_user_id
amount
paid_at
created_at
```

Add RLS:

```text
Only trip members can view/create settlement records.
```

---

## 7.8 Smart Settlement Tests

Test:

```text
1 creditor / 1 debtor
1 creditor / many debtors
many creditors / 1 debtor
many creditors / many debtors
already balanced
zero balances
uneven amounts
large amounts
```

Invariant:

```text
sum(all balances) == 0
```

---

# 8. Feature 2 — Trip Budget

## 8.1 Goal

Allow a trip to have an optional total budget.

Example:

```text
Budget
5,000,000 ₫

Spent
3,850,000 ₫

Remaining
1,150,000 ₫

77%
```

---

## 8.2 Database

Inspect the existing `trips` table.

If no budget field exists, add:

```sql
budget_amount bigint
```

Constraint:

```sql
check (
  budget_amount is null
  or budget_amount > 0
)
```

Do NOT create a separate budget table for a simple total trip budget.

---

## 8.3 Trip Creation/Edit

Add:

```text
Trip Budget

[ 5,000,000 ₫ ]

Optional
```

Allow editing later.

---

## 8.4 Budget Card

Add to Trip Overview:

```text
Trip Budget

5,000,000 ₫

Spent
3,850,000 ₫

Remaining
1,150,000 ₫

██████████████░░░░
77%
```

Over budget:

```text
Budget exceeded

6,200,000 ₫

+1,200,000 ₫ over
```

---

## 8.5 Calculation

Use:

```text
spent = sum(expenses.amount)
remaining = budget - spent
percentage = spent / budget
```

Important:

Settlement transfers are NOT expenses.

Never subtract settlement payments from total trip spending.

---

## 8.6 Category Breakdown

Reuse the existing expense category implementation.

Display:

```text
Food        1,200,000 ₫
Hotel       2,000,000 ₫
Transport     350,000 ₫
Activities    300,000 ₫
```

If V1 does not have categories, do not force a large category refactor. Use only the existing data.

---

## 8.7 Daily Budget

If trip start/end dates exist:

```text
dailyBudget = budget / tripDays
```

Example:

```text
Budget
5,000,000 ₫

4 days

Daily target
1,250,000 ₫
```

Show:

```text
Average daily spend
1,050,000 ₫

You're on track 👍
```

Avoid misleading calculations when the trip duration is zero or dates are missing.

---

## 8.8 Budget Insights

Use deterministic rules.

Examples:

```text
👍 You're below your daily spending target.

⚠️ 82% of the budget has been used.

⚠️ At the current pace, you may exceed the budget.
```

No AI is required.

---

## 8.9 Budget UI

Add budget summary to:

```text
Trip Overview
```

Optionally provide:

```text
Trip → Budget
```

Do not create another bottom-navigation item.

---

## 8.10 Budget Tests

Test:

```text
no budget
budget = spent
under budget
over budget
zero expenses
one expense
many expenses
one-day trip
multi-day trip
missing trip dates
```

---

# 9. Feature 3 — Smart Trip Map

## 9.1 Goal

Visualize locations from the existing Trip Journal.

Example:

```text
📍 Cafe

       │

📍 Hotel ───── 📍 Datanla

       │

📍 Night Market
```

The map should connect:

```text
Photos
Journal entries
Locations
Timeline
```

---

## 9.2 Existing Data

Inspect the existing journal schema.

Reuse fields such as:

```text
latitude
longitude
location_name
visited_at
journal_entry_id
```

Use actual existing column names.

Do not create duplicate location records if V1 already stores coordinates.

---

## 9.3 Map Route

Add:

```text
/trips/:tripId/map
```

or follow the existing routing convention.

---

## 9.4 Map UI

Example:

```text
┌──────────────────────────────┐
│ ← Trip Map                   │
│                              │
│          📍                  │
│   📍              📍         │
│                              │
│             📍               │
│                    📍        │
│                              │
├──────────────────────────────┤
│ 8 places · 37 memories      │
└──────────────────────────────┘
```

Use the project's existing theme.

---

## 9.5 Marker

When selected:

```text
┌──────────────────────────────┐
│ [Photo]                      │
│                              │
│ Datanla Waterfall            │
│ Aug 20 · 10:30 AM            │
│ 4 memories                   │
│                              │
│ [ View Memory ]              │
└──────────────────────────────┘
```

Load only the information required for the selected marker.

---

## 9.6 Marker Clustering

If many markers are near each other:

```text
      12
      📍
```

Tap:

```text
12 memories
```

to zoom in.

Do not render hundreds of individual markers unnecessarily.

---

## 9.7 Journey Path

If coordinates and timestamps are valid:

```text
A → B → C → D
```

Draw an approximate path based on journal order.

Important:

> This is a journal journey visualization, NOT background GPS tracking.

Do NOT implement:

```text
background location
continuous GPS
location tracking service
```

---

## 9.8 Map Provider Isolation

If the project already has a map provider, keep it.

If adding a provider, isolate it behind:

```dart
abstract class TripMapService {
  // provider-independent API
}
```

Do not make the domain layer depend directly on a map SDK.

---

## 9.9 Map Cost Optimization

Do not:

```text
reverse geocode every image
poll the map
track GPS
download all photos for all markers
```

Only load map-related data when the Map screen is opened.

---

## 9.10 Empty State

```text
🗺️

Your journey map is empty

Add locations to your memories
to see your trip here.

[ Add Memory ]
```

---

# 10. Feature 4 — Auto Trip Recap

## 10.1 Goal

Turn the trip into a beautiful visual story after the trip is completed.

Example:

```text
Trip Complete 🎉

Da Lat 2026

4 days
4 friends
12 places
37 memories
8,450,000 ₫ spent

[ Create Trip Recap ]
```

---

## 10.2 Important

Do NOT introduce an AI dependency.

Do NOT create expensive server-side media generation.

Generate the recap from existing data.

---

## 10.3 Recap Data

Use:

```text
Trip metadata
Journal entries
Journal photos
Locations
Expense statistics
Trip members
```

---

## 10.4 Recap Structure

Recommended:

```text
COVER

DA LAT
2026

Aug 20 – Aug 23

[Hero Photo]


DAY 1

[Photo]
[Photo]

Datanla Waterfall

Caption


DAY 2

[Photo]
[Photo]

Night Market

Caption


TRIP STATS

📸 37 memories
📍 8 places
💰 8.45M spent
👥 4 friends


FINAL PAGE

Until next adventure ❤️
```

---

## 10.5 Photo Selection

Do not display every image.

Select approximately:

```text
1–5 photos per journal entry
```

Prefer:

```text
cover image
user-selected image
first image
high-quality image
```

Avoid duplicate-looking images when practical.

---

## 10.6 Story UI

Full-screen story.

Interactions:

```text
Tap right → next
Tap left → previous
Swipe up → next
Long press → pause
```

Progress:

```text
━━━ ━━ ━━ ━━
```

Use subtle animation:

```text
Fade
Scale
Parallax
Slow zoom
```

Animation duration:

```text
300–500ms
```

Do not animate everything simultaneously.

---

## 10.7 Trip Insights

Calculate:

```text
Total days
Total memories
Total photos
Total locations
Total expenses
Average daily spend
Most expensive day
Largest category
Most photographed place
```

Only show useful insights.

---

## 10.8 Generate on Demand

Do not generate recaps automatically after every expense/photo change.

Use:

```text
[ Create Trip Recap ]
```

This reduces:

```text
database reads
storage operations
CPU
unnecessary processing
```

---

## 10.9 Recap Sharing

V2:

```text
Share
```

Future:

```text
Instagram Story
TikTok
Video
PDF
```

Do not implement server-side video rendering now.

---

# 11. Feature 5 — Digital Trip Book

## 11.1 Goal

Turn the Trip Journal into a permanent digital travel book.

Concept:

```text
Trip Journal
     ↓
Trip Complete
     ↓
Create Trip Book
     ↓
Beautiful pages
     ↓
Share
```

---

## 11.2 Book Cover

```text
┌─────────────────────────────┐
│                             │
│          DA LAT             │
│           2026              │
│                             │
│       [ HERO PHOTO ]        │
│                             │
│      Aug 20 – Aug 23        │
│                             │
│          4 friends          │
│                             │
└─────────────────────────────┘
```

---

## 11.3 Pages

Recommended:

```text
Cover
Introduction
Day 1
Day 2
Day 3
Day 4
Trip Statistics
Final Memory
```

Number of day pages must be dynamic.

Do not assume 4 days.

---

## 11.4 Page Templates

Create reusable layouts:

```text
Full Image
Image + Text
Two Images
Three Images
Quote
Statistics
Map
```

Select templates based on available content.

Avoid making every page identical.

---

## 11.5 Visual Style

The book should feel like:

```text
Travel magazine
+
Photo album
```

Use:

```text
large photos
editorial typography
generous whitespace
short captions
subtle transitions
```

Avoid:

```text
dense cards
tables
dashboard appearance
```

---

## 11.6 Book Content

Use:

```text
Trip name
Destination
Dates
Members
Journal titles
Journal descriptions
Locations
Photos
Trip statistics
```

Spending summary is optional.

Individual debt information must NOT be shown by default.

---

## 11.7 Privacy

Before sharing:

```text
Share Trip Book

Include spending summary?

○ Yes
● No

Include member names?

● Yes
○ No

[ Create Share Link ]
```

Never expose:

```text
individual balances
individual debts
settlement history
private expense details
```

unless explicitly enabled.

---

## 11.8 Book Preview

Use page-based UI:

```text
← Page 3 / 12 →

┌───────────────────────────┐
│                           │
│         [PHOTO]           │
│                           │
│ Datanla Waterfall         │
│                           │
│ Beautiful morning...      │
│                           │
└───────────────────────────┘
```

Support:

```text
Swipe
Next
Previous
Page indicator
```

---

## 11.9 Book Generation

V2:

```text
Generate pages dynamically
```

Do NOT create a giant server-side PDF.

Future:

```text
Export PDF
Print Book
Public Share Link
```

---

# 12. Trip Detail Navigation

Do not create a new bottom navigation architecture.

Extend the existing Trip Detail screen.

Recommended:

```text
Overview
Expenses
Journal
Map
Settlement
Budget
```

Secondary actions:

```text
Trip Recap
Trip Book
Statistics
Members
Settings
```

Use the existing navigation pattern wherever possible.

---

# 13. Trip Overview Upgrade

Add compact cards to the existing overview.

Recommended:

```text
┌──────────────────────────────┐
│ HERO PHOTO                   │
│                              │
│ Da Lat 2026                  │
│ Aug 20 – Aug 23              │
└──────────────────────────────┘

💰 8.45M spent
📸 37 memories
📍 8 places
👥 4 friends

Budget
██████████████░░
77%

[ Add Expense ] [ Add Memory ]

Recent Memories
[Photo] [Photo] [Photo]

Recent Expenses
Hotel       4,000,000 ₫
Dinner        850,000 ₫

Explore

🗺️ Trip Map
💸 Settlement
📖 Trip Book
🎞️ Trip Recap
```

Use the existing V1 components when possible.

---

# 14. Database Changes

Before creating migrations:

```text
Inspect current schema.
```

Only add missing columns/tables.

Possible migration:

```sql
alter table trips
add column if not exists budget_amount bigint
check (
  budget_amount is null
  or budget_amount > 0
);
```

If V1 already has a suitable budget field, do not add another.

---

# 15. RPC Recommendations

Prefer RPC for aggregate operations.

Possible functions:

```text
get_trip_balances
get_trip_statistics
get_trip_budget_summary
get_trip_map_points
get_trip_book_data
```

Only create RPCs that are actually needed after inspecting the current repository/query implementation.

Every RPC must:

1. Verify authenticated user.
2. Verify trip membership.
3. Return only necessary fields.
4. Avoid unnecessary joins.
5. Respect privacy.
6. Use indexes where appropriate.

---

# 16. Suggested Indexes

Only add indexes after checking existing indexes.

Potential indexes:

```sql
trip_id
trip_id + created_at
trip_id + visited_at
trip_id + latitude/longitude
```

Do not create duplicate indexes.

---

# 17. RLS Requirements

All new database objects must have proper RLS.

Rules:

```text
Trip members can read trip-specific V2 data.
Trip members can create allowed trip-specific records.
Only authorized users can modify their own records.
Private financial data must not become public accidentally.
```

Never disable RLS to make a feature work.

---

# 18. Image Performance

The V1 journal already supports image upload.

Reuse it.

For V2:

```text
Do not duplicate original photos.
Do not upload the same photo again for recap.
Do not create a second storage bucket unless necessary.
```

Use thumbnails/resized images where the existing implementation supports them.

For recap/book:

```text
lazy load images
cache images
avoid loading all full-resolution photos simultaneously
```

---

# 19. Animation Guidelines

V2 should feel polished but not overloaded.

Use:

```text
Fade
Scale
Slide
Hero transition
Page transition
Parallax
```

Typical duration:

```text
200–400ms
```

Story/photo transitions:

```text
300–500ms
```

Avoid:

```text
continuous animations
bouncing everything
large delays
animation on every list item
```

Animations must not reduce usability.

---

# 20. Haptic Feedback

Use light haptics for meaningful actions:

```text
Mark as Paid
Create Recap
Create Trip Book
Add Budget
Save Budget
```

Do not vibrate for every interaction.

---

# 21. Loading States

Every new feature must have:

```text
Loading
Success
Empty
Error
```

Use skeletons where appropriate.

Avoid showing a blank screen.

---

# 22. Error Handling

Examples:

```text
Unable to load trip map.
[ Retry ]

Unable to calculate settlement.
[ Retry ]

Unable to create trip recap.
[ Retry ]

Unable to load trip book.
[ Retry ]
```

Never expose raw Supabase/PostgreSQL errors directly to users.

Log technical details through the existing logging mechanism.

---

# 23. Offline / Poor Network Behavior

Do not build a complete offline-first system for V2.

However:

```text
Do not crash when network is unavailable.
```

Show:

```text
No connection

Please reconnect and try again.
```

Existing cached V1 data should continue working according to the existing architecture.

---

# 24. Accessibility

Ensure:

```text
Readable text
Sufficient contrast
Touch targets ≥ 44x44 where practical
Semantic labels
Screen reader-friendly buttons
```

Do not encode important information only through color.

Example:

Bad:

```text
Green = paid
Red = unpaid
```

Better:

```text
✓ Paid
⚠ Unpaid
```

---

# 25. Performance Requirements

V2 must remain smooth on normal mid-range phones.

Target:

```text
60 FPS for normal navigation
```

Avoid:

```text
large synchronous computations on UI thread
loading hundreds of images at once
large unpaginated Supabase queries
unnecessary rebuilds
```

Settlement calculation is small and can be local.

Map and book data should be loaded incrementally.

---

# 26. State Management

Use the existing state-management solution.

If V1 uses Riverpod:

```text
Provider
Notifier
AsyncNotifier
Repository
```

follow the existing conventions.

Do not introduce:

```text
Bloc
GetX
Provider
MobX
```

just for V2 if the project already uses Riverpod.

---

# 27. Models

Create V2 models only when required.

Suggested concepts:

```text
SettlementSuggestion
TripBudgetSummary
TripMapPoint
TripRecap
TripBookPage
```

Keep domain models independent of Supabase response formats where the existing architecture follows that pattern.

---

# 28. Repository Layer

Possible additions:

```text
SettlementRepository
BudgetRepository
TripMapRepository
TripRecapRepository
TripBookRepository
```

But first inspect existing repositories.

If V1 already has:

```text
TripRepository
ExpenseRepository
JournalRepository
```

it may be better to extend those instead of creating unnecessary repositories.

Follow existing project conventions.

---

# 29. Testing Requirements

Add unit tests for:

```text
Settlement algorithm
Budget calculations
Daily budget calculation
Trip statistics
Photo selection
Recap ordering
Map point ordering
Trip book page generation
Privacy filtering
```

Widget tests for:

```text
Budget card
Settlement card
Map empty state
Recap loading state
Trip book page
```

Do not over-test implementation details.

Test behavior.

---

# 30. Smart Settlement Unit Test Example

Given:

```text
A +900
B -300
C -300
D -300
```

Expect:

```text
B → A 300
C → A 300
D → A 300
```

Given:

```text
A +500
B +200
C -400
D -300
```

Expect a valid settlement where:

```text
total paid by debtors == 700
total received by creditors == 700
```

and all balances become zero.

---

# 31. Budget Calculation Rules

Use integer currency.

Example:

```dart
final spent = 3_850_000;
final budget = 5_000_000;

final remaining = budget - spent;
```

Percentage:

```text
spent * 100 / budget
```

Handle:

```text
budget == 0
```

safely even if the database constraint should prevent it.

Clamp progress UI:

```text
0.0 → 1.0
```

but preserve the real over-budget amount separately.

---

# 32. Map Data Rules

Only accept valid coordinates:

```text
latitude: -90..90
longitude: -180..180
```

Ignore invalid/null coordinates from map rendering.

Sort journey points by:

```text
visited_at
```

with a deterministic fallback:

```text
created_at
```

---

# 33. Recap Ordering Rules

Order:

```text
journal entries by visited_at
```

Fallback:

```text
created_at
```

Within each entry:

```text
photos by existing display/order field
```

Do not randomly reorder user content.

---

# 34. Digital Book Privacy Rules

A generated shareable book must create a sanitized view model.

Never directly expose the complete Trip object to public rendering.

Public/shareable model should contain only:

```text
trip title
destination
dates
selected members
journal content
selected photos
optional statistics
```

Exclude:

```text
auth IDs
private email
individual balances
private expenses
settlement records
private metadata
```

---

# 35. Shareable Content

V2 can implement local/native sharing first.

Example:

```text
Share Trip Recap
Share Trip Book
```

Use the existing Flutter sharing mechanism if already installed.

Do not add a public web application unless explicitly required.

Future:

```text
Public share URL
```

---

# 36. Feature Flags

Do not introduce a remote feature flag system.

If the project already has feature flags, use them.

Otherwise a simple local mechanism is sufficient during development:

```dart
class FeatureFlags {
  static const smartSettlement = true;
  static const tripBudget = true;
  static const smartTripMap = true;
  static const autoTripRecap = true;
  static const digitalTripBook = true;
}
```

Remove unnecessary flags before production if they are no longer useful.

---

# 37. Empty States

## Settlement

```text
🎉

Everyone is settled up.
```

## Budget

```text
💰

No trip budget yet.

[ Set Budget ]
```

## Map

```text
🗺️

Your journey map is empty.

Add locations to your memories.
```

## Recap

```text
🎞️

Your story is still being written.

Add some memories first.
```

## Trip Book

```text
📖

Your trip book is waiting.

Add memories to start creating it.
```

---

# 38. Definition of Done — Smart Settlement

- [ ] Existing balance logic inspected
- [ ] Settlement algorithm implemented/reused
- [ ] Exact integer arithmetic
- [ ] Optimized payment suggestions
- [ ] Settlement UI
- [ ] Confirm before marking paid
- [ ] Settlement history if required
- [ ] RLS
- [ ] Unit tests
- [ ] Existing V1 balance behavior preserved

---

# 39. Definition of Done — Trip Budget

- [ ] Existing trip schema inspected
- [ ] Budget field added only if missing
- [ ] RLS/migration updated
- [ ] Set budget
- [ ] Edit budget
- [ ] Budget card
- [ ] Remaining amount
- [ ] Progress
- [ ] Over-budget state
- [ ] Daily budget
- [ ] Category breakdown if supported by V1
- [ ] Unit tests
- [ ] Existing trip behavior preserved

---

# 40. Definition of Done — Smart Trip Map

- [ ] Existing journal location fields inspected
- [ ] Map screen
- [ ] Markers
- [ ] Marker selection
- [ ] Open journal memory
- [ ] Clustering if required
- [ ] Journey path
- [ ] Invalid coordinate handling
- [ ] Empty state
- [ ] Loading state
- [ ] Error state
- [ ] No background GPS
- [ ] Existing journal behavior preserved

---

# 41. Definition of Done — Auto Trip Recap

- [ ] Generate on demand
- [ ] Cover
- [ ] Timeline
- [ ] Photo selection
- [ ] Trip statistics
- [ ] Highlights
- [ ] Full-screen story
- [ ] Progress indicator
- [ ] Pause interaction
- [ ] Smooth animation
- [ ] Share
- [ ] Loading/error/empty states
- [ ] No server-side video generation

---

# 42. Definition of Done — Digital Trip Book

- [ ] Generate book
- [ ] Cover
- [ ] Dynamic day pages
- [ ] Multiple page templates
- [ ] Journal content
- [ ] Photos
- [ ] Statistics
- [ ] Page navigation
- [ ] Privacy options
- [ ] Share
- [ ] Loading/error/empty states
- [ ] No duplicate image uploads
- [ ] No private financial data leak

---

# 43. Implementation Order

Implement exactly in this sequence unless project dependencies require otherwise:

```text
PHASE 1
Smart Settlement

↓

PHASE 2
Trip Budget

↓

PHASE 3
Smart Trip Map

↓

PHASE 4
Auto Trip Recap

↓

PHASE 5
Digital Trip Book

↓

PHASE 6
Integration Testing
```

After each phase:

```text
flutter analyze
flutter test
```

and manually verify the affected V1 screens.

---

# 44. Cursor Workflow

For every phase:

## Step 1 — Inspect

Find:

```text
models
repositories
providers
screens
routes
database tables
RLS policies
storage
theme
shared widgets
```

## Step 2 — Plan

Before editing, identify:

```text
files to modify
files to create
database migration required
existing code to reuse
```

Avoid broad refactoring.

## Step 3 — Implement

Implement the smallest complete version.

## Step 4 — Test

Run:

```bash
flutter analyze
flutter test
```

## Step 5 — Review

Check:

```text
Does V1 still work?
Are there unnecessary Supabase reads?
Are there duplicate models?
Are there security issues?
Are animations smooth?
```

---

# 45. Important "DO NOT" Rules

DO NOT:

```text
rewrite V1
replace the architecture
replace Riverpod if already used
replace Supabase
create a second backend
create duplicate tables
duplicate uploaded images
implement background GPS
implement unnecessary Realtime
add AI dependencies
create server-side video processing
disable RLS
ignore existing tests
rewrite unrelated screens
change existing APIs unnecessarily
```

DO:

```text
inspect first
reuse existing code
extend existing models
extend existing repositories
reuse existing UI components
reuse existing storage
reuse existing Supabase client
add small migrations
add focused tests
keep V1 stable
```

---

# 46. Final Product Experience

After V2, a user should be able to:

```text
Create trip
    ↓
Invite friends
    ↓
Record expenses
    ↓
Split expenses
    ↓
Track budget
    ↓
See who owes whom
    ↓
Settle payments
    ↓
Add memories
    ↓
Upload photos
    ↓
Attach locations
    ↓
View trip map
    ↓
Finish trip
    ↓
Generate Trip Recap
    ↓
Generate Digital Trip Book
    ↓
Share memories
```

The product should feel like:

```text
Expense Splitter
        +
Travel Journal
        +
Trip Map
        +
Memory Book
```

Core positioning:

> **Split the trip. Keep the memories.**

---

# 47. Final Verification Checklist

Before declaring V2 complete:

## V1 Regression

- [ ] Login works
- [ ] Register works
- [ ] Trip creation works
- [ ] Trip joining works
- [ ] Members work
- [ ] Expense creation works
- [ ] Expense editing works
- [ ] Expense deletion works
- [ ] Expense splitting works
- [ ] Journal works
- [ ] Photo upload works

## V2

- [ ] Smart Settlement
- [ ] Trip Budget
- [ ] Smart Trip Map
- [ ] Auto Trip Recap
- [ ] Digital Trip Book

## Security

- [ ] RLS enabled
- [ ] Trip membership verified
- [ ] No private financial data exposed
- [ ] Storage policies remain secure
- [ ] Public sharing does not expose private data

## Performance

- [ ] No unnecessary polling
- [ ] No background GPS
- [ ] No duplicate image uploads
- [ ] Large photo lists lazy-loaded
- [ ] Map markers optimized
- [ ] Supabase queries select only required fields

## Quality

- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] No obvious UI overflow
- [ ] Loading states implemented
- [ ] Empty states implemented
- [ ] Error states implemented
- [ ] Animations feel intentional
- [ ] Existing V1 UI remains consistent
