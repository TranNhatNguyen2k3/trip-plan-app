# TripMate — Flutter Travel Expense & Journal App

## 1. Product Overview

Build a beautiful, modern, mobile-first Flutter application for groups of friends traveling together.

The application combines two core experiences:

1. **Travel Expense Manager**
   - Create trips
   - Invite friends
   - Add expenses
   - Split expenses
   - Calculate balances
   - Suggest settlements
   - Mark settlements as paid
   - View statistics

2. **Trip Journal**
   - Add memories
   - Upload photos
   - Record places
   - Add descriptions
   - Build a chronological travel diary
   - Use a photo as the trip cover
   - Revisit the trip after it ends

Product positioning:

> **Track the money during the trip, keep the memories after the trip.**

The application should feel like:

```text
Modern travel app
+
Photo diary
+
Simple expense manager
```

It must NOT feel like a boring accounting application.

---

# 2. Main Goals

The final app must be:

- Beautiful
- Modern
- Premium
- Friendly
- Extremely easy to use
- Mobile-first
- Fast
- Secure
- Cost-efficient
- Optimized for Supabase Free Plan
- Suitable for real-world production

Primary UX:

```text
Create Trip
    ↓
Invite Friends
    ↓
Add Expenses
    ↓
Automatically Calculate
    ↓
Add Photos & Memories
    ↓
See Who Owes Whom
    ↓
Settle Up
    ↓
Keep the Trip Journal
```

---

# 3. Technology Stack

## Mobile

```text
Flutter
Dart
```

## State Management

```text
Riverpod
```

## Navigation

```text
GoRouter
```

## Backend

```text
Supabase
```

Use:

```text
Supabase Auth
Supabase PostgreSQL
Supabase RLS
Supabase RPC
Supabase Storage
Limited Supabase Realtime
```

Do NOT create a custom backend.

Do NOT create:

```text
Go backend
Node.js backend
REST API server
```

unless explicitly required later.

---

# 4. Supabase Free-First Architecture

Architecture:

```text
Flutter
   │
   └── Supabase Flutter SDK
          │
          ├── Auth
          ├── PostgreSQL
          ├── RLS
          ├── RPC
          ├── Storage
          └── Realtime
```

The application must maximize useful functionality while minimizing Supabase Free Plan consumption.

---

# 5. Supabase Usage Rules

## 5.1 No Custom Backend

Do not deploy a separate backend for MVP.

## 5.2 No Edge Functions

Do not use Edge Functions in MVP unless there is a feature that genuinely cannot be implemented with PostgreSQL/RLS/Flutter.

## 5.3 No Polling

Never implement:

```dart
Timer.periodic(...)
```

to repeatedly query Supabase.

Use:

- normal queries
- mutation-triggered refresh
- pull-to-refresh
- limited Realtime

## 5.4 Limited Realtime

Realtime should only be active while the user is inside an active trip.

Subscribe only to the current trip's relevant data.

Do not subscribe globally.

## 5.5 Pagination

Never download unlimited records.

Recommended:

```text
20 records/page
```

Maximum:

```text
50 records/page
```

## 5.6 Server-Side Aggregation

Do not download thousands of expenses to Flutter to calculate:

- total spending
- spending by category
- spending by member
- daily spending
- balances

Use PostgreSQL queries/RPC.

## 5.7 No Redundant Data

Do not store calculated balances if they can be calculated from expenses and settlements.

## 5.8 No Activity Log in MVP

Do not create a separate activity/event table.

## 5.9 No Push Notifications in MVP

Do not implement Firebase Cloud Messaging.

## 5.10 No Email Infrastructure

Do not use:

- SendGrid
- SMTP
- Resend
- Edge Functions for email

Use shareable invitation links.

---

# 6. Supabase Storage

Storage is required only for Trip Journal photos.

Create one private bucket:

```text
trip-journal
```

Do NOT make it public.

Storage structure:

```text
trip-journal/
└── {trip_id}/
    └── {journal_entry_id}/
        ├── {photo_id}.jpg
        ├── {photo_id}.jpg
        └── {photo_id}.jpg
```

Store only the `storage_path` in PostgreSQL.

Never permanently store signed URLs in the database.

---

# 7. Photo Storage Optimization

Photos must be compressed on-device before upload.

Recommended:

```text
Maximum dimension: 1600px
JPEG quality: 80
Recommended size: < 1.5 MB
Hard maximum after compression: 3 MB
```

Do NOT upload original 10–20 MB camera images.

Upload flow:

```text
Camera / Gallery
      ↓
Resize
      ↓
Compress
      ↓
Validate
      ↓
Upload
```

Maximum photos per journal entry:

```text
10
```

Do not upload 10 photos simultaneously.

Use 1–2 concurrent uploads maximum.

---

# 8. Flutter Dependencies

Use only necessary dependencies.

Recommended:

```yaml
dependencies:
  flutter:
    sdk: flutter

  supabase_flutter:
  flutter_riverpod:
  go_router:
  freezed_annotation:
  json_annotation:
  intl:
  fl_chart:
  image_picker:
  flutter_image_compress:
  cached_network_image:
  share_plus:
  uuid:
```

Optional if implementing current location:

```yaml
  geolocator:
```

Do not add packages without a concrete reason.

---

# 9. Project Structure

Use feature-based architecture:

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│       ├── app_theme.dart
│       ├── app_colors.dart
│       ├── app_spacing.dart
│       └── app_typography.dart
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── utils/
│   └── widgets/
│       ├── app_button.dart
│       ├── app_card.dart
│       ├── app_text_field.dart
│       ├── app_bottom_sheet.dart
│       ├── app_empty_state.dart
│       ├── app_loading.dart
│       ├── app_error_state.dart
│       ├── app_image.dart
│       └── app_currency_text.dart
│
├── features/
│   ├── auth/
│   ├── trips/
│   ├── expenses/
│   ├── settlements/
│   ├── statistics/
│   └── journal/
│
└── main.dart
```

Feature structure:

```text
feature/
├── data/
├── domain/
└── presentation/
```

---

# 10. Architecture Rules

UI must never directly query Supabase.

Bad:

```dart
final response = await Supabase.instance.client
    .from('expenses')
    .select();
```

inside a widget.

Good:

```text
Widget
  ↓
Riverpod Provider
  ↓
Repository
  ↓
Supabase
```

Business logic must be independent from UI.

Financial calculations must be pure Dart functions where possible.

---

# 11. Authentication

Use Supabase Auth.

Support:

- Email/password
- Google Sign In
- Logout
- Session persistence

Flow:

```text
Splash
  ↓
Check Supabase session
  ↓
Authenticated?
 ├── Yes → Home
 └── No  → Login
```

Never store:

```text
SUPABASE_SERVICE_ROLE_KEY
```

inside Flutter.

Only use:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

---

# 12. User Profile

Table:

```text
profiles
```

Fields:

```text
id
display_name
avatar_url
created_at
updated_at
```

`id` references:

```text
auth.users.id
```

Do not use Supabase Storage for avatars in MVP.

If Google provides an avatar URL, store the external URL.

---

# 13. Trips

A trip is the root entity for both expenses and memories.

Fields:

```text
id
name
description
destination
start_date
end_date
currency
cover_photo_path
created_by
created_at
updated_at
```

Default currency:

```text
VND
```

Amounts must be integer values.

Example:

```text
500000
```

means:

```text
500,000 VND
```

Never use floating point for money.

---

# 14. Trip Members

Table:

```text
trip_members
```

Fields:

```text
id
trip_id
user_id
role
joined_at
```

Roles:

```text
owner
member
```

Constraint:

```sql
unique(trip_id, user_id)
```

---

# 15. Trip Invitations

Use shareable invitation links.

Do NOT build an email invitation system.

Table:

```text
trip_invitations
```

Fields:

```text
id
trip_id
token
invited_by
expires_at
accepted_at
created_at
```

Share:

```text
https://your-domain.com/join/{token}
```

Use Flutter `share_plus`.

---

# 16. Expense Model

Table:

```text
expenses
```

Fields:

```text
id
trip_id
description
amount
category
paid_by
expense_date
note
created_by
created_at
updated_at
```

Categories:

```text
food
hotel
transport
activity
shopping
tickets
fuel
other
```

Do not create a category table in MVP.

---

# 17. Expense Participants

Table:

```text
expense_participants
```

Fields:

```text
id
expense_id
user_id
share_amount
```

Constraint:

```text
unique(expense_id, user_id)
```

Example:

```text
Expense = 1,000,000

Nguyen = 250,000
Minh   = 250,000
An     = 250,000
Tuan   = 250,000
```

---

# 18. Equal Split

Implement pure Dart:

```dart
List<ExpenseShare> splitEqually(
  int amount,
  List<String> userIds,
)
```

Example:

```text
100 / 3
```

must become:

```text
34
33
33
```

The total must always equal the original amount.

Never lose the remainder.

---

# 19. Custom Split

Allow users to specify exact shares.

Example:

```text
Nguyen: 500,000
Minh:   300,000
An:     200,000
```

Validation:

```text
500,000 + 300,000 + 200,000
=
1,000,000
```

Save is disabled if:

```text
sum(shares) != expense.amount
```

---

# 20. Quick Add Expense

The most important expense UX.

Trip:

```text
+
```

opens:

```text
Add Expense
Add Memory
```

Expense screen:

```text
Add Expense

500,000 ₫

Dinner

Paid by
You

Split between
Everyone

Split method
Equal

Category
Food

[ Save Expense ]
```

Defaults:

```text
payer = current user
participants = all trip members
split = equal
category = other
date = current date/time
```

---

# 21. Balance Calculation

For each expense:

```text
payer += expense.amount
participant -= participant.share_amount
```

Balance:

```text
balance = amount_paid - amount_owed
```

Example:

```text
Expense:
1,000,000

Paid by Nguyen

Participants:
Nguyen
Minh
An
Tuan
```

Balances:

```text
Nguyen +750,000
Minh   -250,000
An     -250,000
Tuan   -250,000
```

Invariant:

```text
sum(all balances) == 0
```

---

# 22. Settlement Algorithm

Implement pure Dart:

```dart
List<SettlementSuggestion> calculateSettlements(
  List<Balance> balances,
)
```

Requirements:

- deterministic
- no self-payment
- no money created
- no money destroyed
- minimize transaction count where practical

Example:

```text
Nguyen +900
Minh   -300
An     -300
Tuan   -300
```

Result:

```text
Minh → Nguyen 300
An   → Nguyen 300
Tuan → Nguyen 300
```

---

# 23. Settlements

Table:

```text
settlements
```

Fields:

```text
id
trip_id
from_user_id
to_user_id
amount
note
status
settled_at
created_by
created_at
```

Constraint:

```text
from_user_id != to_user_id
```

Only create a settlement record when the user explicitly taps:

```text
Mark as Paid
```

Do not store generated suggestions automatically.

---

# 24. Trip Journal

The journal is the emotional part of the application.

Each trip can contain multiple journal entries.

Example:

```text
Da Lat 2026

📍 Datanla Waterfall
Aug 20

[Photo]
[Photo]

"Beautiful waterfall and super cold water."

---

📍 Da Lat Night Market
Aug 20

[Photo]
[Photo]
[Photo]

"Amazing food tonight."
```

---

# 25. Journal Entry

Table:

```text
journal_entries
```

Fields:

```text
id
trip_id
title
location_name
latitude
longitude
description
visited_at
created_by
created_at
updated_at
```

All location coordinates are optional.

Users must be able to create a memory without GPS.

---

# 26. Journal Photos

Table:

```text
journal_photos
```

Fields:

```text
id
journal_entry_id
storage_path
display_order
caption
created_at
```

Storage path:

```text
trip/{trip_id}/journal/{entry_id}/{photo_id}.jpg
```

Do not duplicate photos.

---

# 27. Add Memory UX

Screen:

```text
Create Memory

Photos

┌───────┐ ┌───────┐ ┌───────┐
│ Photo │ │ Photo │ │   +   │
└───────┘ └───────┘ └───────┘

Location

[ 📍 Add location ]

Title

[ Datanla Waterfall ]

Description

[ Beautiful place... ]

Date & Time

[ Aug 20, 2026 10:30 ]

[ Save Memory ]
```

Photos are optional.

---

# 28. Photo Selection

Support:

```text
Camera
Gallery
```

Use `image_picker`.

Allow multiple gallery selection.

Before upload:

```text
Resize
Compress
Validate
Upload
```

---

# 29. Photo Upload Progress

Show:

```text
Uploading memories...

3 / 5

████████████░░░░
```

Per-photo state:

```text
Photo 1 ✓
Photo 2 ✓
Photo 3 Uploading...
Photo 4 Waiting...
Photo 5 Waiting...
```

If some fail:

```text
3 photos uploaded
2 photos failed

[ Retry ]
[ Finish ]
```

Never silently fail.

---

# 30. Journal Timeline

Main journal screen:

```text
Da Lat 2026

Aug 20

●
│
│  📍 Datanla Waterfall
│
│  [ Large Photo ]
│
│  Beautiful waterfall.
│
│  10:30 AM
│
●
│
│  📍 Da Lat Night Market
│
│  [Photo] [Photo]
│
│  Amazing food tonight.
│
│  7:45 PM
```

The photo should be the strongest visual element.

---

# 31. Journal Detail

Display:

```text
Datanla Waterfall

📍 Datanla Waterfall

Aug 20, 2026 · 10:30 AM

[ Large Photo ]

[ Photo ]

Beautiful waterfall.

Added by Nguyen
```

Actions:

```text
Edit
Delete
```

---

# 32. Photo Viewer

Full-screen viewer:

- Swipe between photos
- Pinch to zoom
- Close
- Photo counter

Example:

```text
2 / 5
```

Use Hero animation from thumbnail to full-screen image.

---

# 33. Trip Cover Photo

Allow users to choose a journal photo as trip cover.

Add:

```text
cover_photo_path
```

to `trips`.

Do NOT duplicate the file.

Home trip card uses this image.

If no cover photo exists, show a beautiful generated background/illustration.

---

# 34. Journal Summary

At the top of Journal:

```text
Da Lat 2026

📸 37 memories
📍 8 places
📅 4 days
```

Use lightweight aggregate queries.

---

# 35. Location

MVP supports:

```text
Location name
```

Optional:

```text
latitude
longitude
```

If GPS is implemented, only access it after explicit user action:

```text
Use my location
```

Do NOT implement background location tracking.

Do NOT store continuous location history.

---

# 36. Map

A map is NOT required for MVP.

The app must work without:

- Google Maps
- Mapbox
- paid map APIs

Design the schema so a Trip Map can be added later using journal coordinates.

---

# 37. Journal Privacy

Journal is private to trip members.

Do NOT create public journal URLs in MVP.

Do NOT use a public Storage bucket.

Only members of the trip can access journal entries and photos.

---

# 38. Storage Security

Storage policies must verify that the authenticated user belongs to the trip represented by the storage path.

Database RLS alone is not sufficient.

Storage must also be protected.

---

# 39. Photo Deletion

When deleting a journal entry:

```text
1. Load photo paths
2. Delete Storage objects
3. Delete journal entry
4. journal_photos cascade
5. Refresh UI
```

Do not leave orphaned Storage objects.

If Storage deletion fails, do not silently delete the database record.

---

# 40. Expense Statistics

Statistics:

- Total spending
- Spending by category
- Spending by member
- Daily spending

Use:

```text
fl_chart
```

Do not download all raw expenses just to render charts.

Use SQL/RPC aggregation.

---

# 41. Trip Overview

Recommended order:

```text
Hero Cover
    ↓
Trip Name / Dates
    ↓
Money Summary
    ↓
Recent Memories
    ↓
Recent Expenses
```

Example:

```text
Da Lat 2026

8,450,000 ₫
Total spent

You owe
350,000 ₫

You receive
900,000 ₫

Recent Memories
[Photos]

Recent Expenses
Hotel
4,000,000 ₫
```

---

# 42. Home Screen

Example:

```text
Good morning 👋

You owe
350,000 ₫

You receive
900,000 ₫

Recent Trips

[Da Lat 2026]
[Cover Photo]
8.45M ₫
📸 37 memories

[Vung Tau Weekend]
[Cover Photo]
3.20M ₫
```

---

# 43. Trip Navigation

Inside a trip:

```text
Overview
Expenses
Journal
Settlements
Statistics
More
```

Primary action:

```text
+
```

Menu:

```text
💰 Add Expense
📸 Add Memory
```

---

# 44. Main Navigation

Bottom navigation:

```text
Home
Trips
Profile
```

Use modern icons and labels.

Active item uses primary color.

Inactive items use muted color.

---

# 45. Routes

Use GoRouter.

Routes:

```text
/login
/register
/
/trips
/trips/create
/trips/:tripId
/trips/:tripId/expenses
/trips/:tripId/expenses/create
/trips/:tripId/expenses/:expenseId
/trips/:tripId/journal
/trips/:tripId/journal/create
/trips/:tripId/journal/:entryId
/trips/:tripId/journal/:entryId/edit
/trips/:tripId/members
/trips/:tripId/settlements
/trips/:tripId/statistics
/profile
/settings
/join/:token
```

---

# 46. UI/UX Design Direction

The UI must be:

- Modern
- Premium
- Friendly
- Minimal
- Warm
- Travel-oriented
- Photo-focused
- Easy to understand

Avoid:

- corporate dashboard appearance
- dense tables
- excessive borders
- excessive gradients
- too many colors
- excessive animations
- tiny touch targets

The app should look like a polished consumer mobile app.

---

# 47. Design Language

Visual inspiration:

```text
Modern travel app
+
Photo diary
+
Finance app simplicity
```

The app should balance:

```text
Emotion
+
Function
```

The Journal should feel emotional and visual.

Expenses should feel fast and practical.

---

# 48. Color System

Use a centralized theme.

Suggested direction:

```text
Primary:
Emerald / Green

Background:
Warm White / Very Light Gray

Surface:
White

Text:
Dark Charcoal

Secondary Text:
Muted Gray

Success:
Green

Warning:
Orange

Error:
Red

Travel Accent:
Warm natural accent
```

Do not use overly saturated colors.

Use gradients only for:

- hero sections
- trip cover overlays
- empty states
- special highlights

---

# 49. Flutter Theme

Create:

```dart
class AppColors {}
class AppSpacing {}
class AppTypography {}
class AppTheme {}
```

Do not hardcode colors throughout widgets.

Use:

```dart
Theme.of(context).colorScheme
```

where appropriate.

---

# 50. Typography

Use a clean modern sans-serif font.

Recommended:

```text
Inter
```

Typography:

```text
Display: 32–36
Large Heading: 24–28
Heading: 20–22
Body: 16
Secondary: 14
Caption: 12
```

Money values should be visually dominant.

Example:

```text
8,450,000 ₫
```

---

# 51. Spacing

Use a 4/8-based spacing system:

```dart
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}
```

Default horizontal screen padding:

```text
16px
```

Use 20–24px for large visual sections.

---

# 52. Border Radius

Use consistent rounded corners:

```text
Small: 10px
Medium: 14px
Large: 20px
Bottom Sheet: 24px
```

Avoid arbitrary radius values.

---

# 53. Reusable UI Components

Create:

```text
AppButton
AppTextField
AppCard
AppBottomSheet
AppAvatar
AppChip
AppEmptyState
AppLoading
AppErrorState
AppImage
AppCurrencyText
```

Do not duplicate components across screens.

---

# 54. Trip Cards

Use large cover photos.

Example:

```text
┌──────────────────────────────┐
│                              │
│         COVER PHOTO          │
│                              │
│                              │
│  ┌────────────────────────┐  │
│  │ Da Lat 2026            │  │
│  │ Aug 20 – Aug 23        │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

Use a subtle bottom gradient overlay for text readability.

---

# 55. Journal Cards

Prioritize photos.

Example:

```text
┌──────────────────────────────┐
│                              │
│            PHOTO             │
│                              │
├──────────────────────────────┤
│ 📍 Datanla Waterfall         │
│                              │
│ Beautiful waterfall...       │
│                              │
│ Aug 20 · 10:30 AM            │
└──────────────────────────────┘
```

For multiple photos:

```text
┌─────────────┬─────────────┐
│             │             │
│    PHOTO    │    PHOTO    │
│             │             │
└─────────────┴─────────────┘
```

Show at most 3 photos in the card.

If more:

```text
+5
```

---

# 56. Full-Bleed Photography

Trip covers and journal hero photos can be edge-to-edge.

Normal content should return to 16px padding.

---

# 57. Bottom Sheets

Use bottom sheets for:

- payer selection
- participant selection
- category selection
- add expense/memory
- sorting
- filtering
- short actions

Bottom sheet:

- rounded top corners
- drag indicator
- clear title
- large touch targets

---

# 58. Buttons

Primary:

```text
Filled
Rounded
Large
```

Secondary:

```text
Outlined
```

Tertiary:

```text
Text
```

Avoid multiple competing primary buttons on one screen.

---

# 59. Accessibility

Minimum touch target:

```text
44 x 44
```

Support:

- dynamic text size
- semantic labels
- screen readers
- sufficient contrast
- focus states

Never rely on color alone.

Use:

```text
+900,000 ₫
-350,000 ₫
```

rather than color only.

---

# 60. Animations

Animations should be:

- short
- subtle
- purposeful
- smooth
- non-blocking

Recommended durations:

```text
Micro interaction: 100–180ms
Button: 150–220ms
Bottom sheet: 200–300ms
Page transition: 200–300ms
Hero: 300–450ms
Success: 300–500ms
```

Preferred curves:

```dart
Curves.easeOut
Curves.easeInOut
Curves.fastOutSlowIn
```

Use spring animations mainly for:

- FAB
- photo interactions
- selection states

Do not use excessive bouncing.

---

# 61. Page Transitions

Use:

```text
Fade
Fade + slight slide
Shared-axis style
```

Avoid dramatic transitions.

---

# 62. Hero Animations

Use Hero for:

```text
Trip card → Trip detail
Journal thumbnail → Full-screen photo
```

Example:

```dart
Hero(
  tag: 'trip-cover-${trip.id}',
  child: ...
)
```

Tags must be unique.

---

# 63. Scroll Animations

Trip detail can use a collapsing app bar:

```text
Large Hero
   ↓
Scroll
   ↓
Compact Header
```

Keep it smooth.

Journal cards can use subtle:

```text
opacity: 0 → 1
translateY: 8 → 0
```

Only animate newly visible items.

Do not animate hundreds of items at once.

---

# 64. FAB Animation

Trip FAB:

```text
+
```

Tap:

```text
Add

💰 Expense
📸 Memory
```

Use short:

```text
scale
+
fade
```

animation.

---

# 65. Micro Interactions

Use subtle feedback for:

- expense saved
- memory saved
- settlement completed
- selection
- toggles

Success animation:

```text
scale 0.9
  ↓
scale 1.05
  ↓
scale 1.0
```

Duration:

```text
300–400ms
```

Do not use confetti for every action.

---

# 66. Haptic Feedback

Use light haptic feedback for important interactions:

- expense saved
- memory saved
- settlement completed
- selection

Do not use haptic feedback for every tap.

---

# 67. Loading States

Every async screen must handle:

```text
loading
success
empty
error
```

Prefer skeleton loading for pages.

Use small progress indicators for:

- button actions
- uploads
- refresh

Do not show full-screen spinners for every operation.

---

# 68. Image Loading

Never show a blank white image box.

Use:

- cached image
- skeleton
- blurred placeholder

Use:

```text
CachedNetworkImage
```

For thumbnails, configure appropriate memory dimensions.

Example:

```dart
CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: 600,
)
```

Adjust to actual display size.

---

# 69. Image Error State

Show a friendly fallback:

```text
🖼

Unable to load
```

with retry where appropriate.

---

# 70. Reduced Motion

Respect reduced-motion settings where practical.

If reduced motion is enabled:

- reduce page animations
- reduce Hero animation
- reduce shimmer
- reduce scale effects

Keep important state feedback.

---

# 71. Dark Mode

Architecture must support dark mode.

MVP may default to light mode.

Do not hardcode:

```dart
Colors.white
Colors.black
```

throughout the application.

Use theme colors.

---

# 72. Login UI

Login should be premium and simple.

Example:

```text
        ✈️

     TripMate

Track expenses.
Save memories.

[ Email ]

[ Password ]

[ Continue ]

────────────

Continue with Google

────────────

Don't have an account?
Sign up
```

Use subtle entrance animation.

---

# 73. Onboarding

Optional lightweight onboarding.

Maximum:

```text
3 screens
```

Example:

```text
Track expenses
      ↓
Save memories
      ↓
Enjoy the trip
```

Always provide:

```text
Skip
```

Do not force long onboarding.

---

# 74. Empty States

Example:

```text
🏔️

No memories yet

Start capturing your trip.
Add your first memory.

[ Add Memory ]
```

Avoid:

```text
No data found
```

---

# 75. Error UX

Always provide recovery.

Example:

```text
Unable to load memories.

[ Try Again ]
```

Do not expose raw Supabase/PostgreSQL errors.

Convert:

```text
PostgrestException(...)
```

to user-friendly messages.

---

# 76. Delete Confirmation

For expenses, memories, and trips:

```text
Delete this memory?

This will permanently delete
the photos and memory.

[ Cancel ]    [ Delete ]
```

Use the error color for destructive action.

---

# 77. Performance

Target:

```text
60 FPS
```

Avoid:

- unnecessary rebuilds
- huge lists
- nested FutureBuilders
- expensive calculations in build()
- decoding original-size photos for thumbnails

Use:

```text
const widgets
ListView.builder
CachedNetworkImage
RepaintBoundary
```

where appropriate.

---

# 78. Network Optimization

Avoid sequential unnecessary requests.

Do not do:

```text
get trip
get owner
get profile
get members
get summary
```

if a focused relational query can safely retrieve the required data.

However, do not create huge nested queries unnecessarily.

---

# 79. Caching

Use Riverpod provider caching during the current session.

After mutation:

```text
create expense
    ↓
invalidate expenses
invalidate balances
invalidate statistics
```

Do not refetch unrelated trips.

Use image caching for journal photos.

---

# 80. App Lifecycle

When returning from background:

Do not refresh the entire application.

Refresh only the currently relevant screen if needed.

Example:

```text
Trip screen
   ↓
App background
   ↓
App resumed
   ↓
Refresh current trip
```

---

# 81. Realtime

Realtime is a UX enhancement, not a dependency.

When entering an active trip:

```text
subscribe:
expenses for current trip
settlements for current trip
```

Optionally subscribe to journal changes if necessary.

When leaving:

```text
unsubscribe
```

Never keep global subscriptions alive.

If Realtime fails, the app remains fully functional through normal queries and pull-to-refresh.

---

# 82. Pagination

Expenses:

```text
20/page
```

Journal entries:

```text
20/page
```

Use server-side pagination.

Do not load the entire trip history.

---

# 83. Database Schema

## profiles

```sql
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

## trips

```sql
create table trips (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  destination text,
  start_date date,
  end_date date,
  currency text not null default 'VND',
  cover_photo_path text,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

## trip_members

```sql
create table trip_members (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references trips(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  unique(trip_id, user_id)
);
```

## trip_invitations

```sql
create table trip_invitations (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references trips(id) on delete cascade,
  token text unique not null,
  invited_by uuid not null references profiles(id),
  expires_at timestamptz,
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);
```

## expenses

```sql
create table expenses (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references trips(id) on delete cascade,
  description text not null,
  amount bigint not null check (amount > 0),
  category text not null default 'other',
  paid_by uuid not null references profiles(id),
  expense_date timestamptz not null default now(),
  note text,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

## expense_participants

```sql
create table expense_participants (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references expenses(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  share_amount bigint not null check (share_amount >= 0),
  unique(expense_id, user_id)
);
```

## settlements

```sql
create table settlements (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references trips(id) on delete cascade,
  from_user_id uuid not null references profiles(id),
  to_user_id uuid not null references profiles(id),
  amount bigint not null check (amount > 0),
  note text,
  status text not null default 'completed',
  settled_at timestamptz not null default now(),
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  check(from_user_id <> to_user_id)
);
```

## journal_entries

```sql
create table journal_entries (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references trips(id) on delete cascade,
  title text,
  location_name text,
  latitude double precision,
  longitude double precision,
  description text,
  visited_at timestamptz not null default now(),
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

## journal_photos

```sql
create table journal_photos (
  id uuid primary key default gen_random_uuid(),
  journal_entry_id uuid not null references journal_entries(id) on delete cascade,
  storage_path text not null,
  display_order integer not null default 0,
  caption text,
  created_at timestamptz not null default now()
);
```

---

# 84. Database Indexes

Create:

```sql
create index idx_expenses_trip_id
on expenses(trip_id);

create index idx_expenses_expense_date
on expenses(expense_date);

create index idx_expenses_paid_by
on expenses(paid_by);

create index idx_expense_participants_expense_id
on expense_participants(expense_id);

create index idx_expense_participants_user_id
on expense_participants(user_id);

create index idx_trip_members_trip_id
on trip_members(trip_id);

create index idx_trip_members_user_id
on trip_members(user_id);

create index idx_settlements_trip_id
on settlements(trip_id);

create index idx_journal_entries_trip_id
on journal_entries(trip_id);

create index idx_journal_entries_visited_at
on journal_entries(visited_at);

create index idx_journal_entries_created_by
on journal_entries(created_by);

create index idx_journal_photos_entry_id
on journal_photos(journal_entry_id);
```

---

# 85. Database Functions / RPC

Implement at minimum:

```text
create_expense
get_trip_balances
get_trip_statistics
accept_trip_invitation
```

Optional later:

```text
get_journal_summary
```

RPC functions must verify:

```text
auth.uid()
```

and trip membership.

Never trust IDs sent by Flutter.

---

# 86. Atomic Expense Creation

Preferred flow:

```text
Flutter
   ↓
supabase.rpc('create_expense')
   ↓
PostgreSQL
   ├── validate membership
   ├── validate payer
   ├── validate participants
   ├── validate shares
   ├── insert expense
   └── insert participants
```

If any operation fails:

```text
ROLLBACK
```

No partial expense should remain.

---

# 87. Balance RPC

Implement:

```text
get_trip_balances(trip_id)
```

Return:

```text
user_id
amount_paid
amount_owed
net_balance
```

This avoids downloading all raw expenses.

---

# 88. Statistics RPC

Implement:

```text
get_trip_statistics(trip_id)
```

Return aggregated:

```text
total_spent
by_category
by_member
by_date
```

Do not return unnecessary raw expense records.

---

# 89. RLS

RLS is mandatory on every table.

A user can access data only if they are a member of the relevant trip.

Concept:

```text
auth.uid()
   ↓
trip_members
   ↓
trip
   ↓
expenses / settlements / journal
```

Never rely on Flutter authorization alone.

---

# 90. Permissions

Trip owner:

- update trip
- delete trip
- manage members
- generate invitations
- manage trip content as appropriate

Trip member:

- view trip
- add expenses
- edit own expenses
- delete own expenses
- add memories
- edit own memories
- delete own memories
- view balances
- create settlements

All authorization must be enforced by RLS.

---

# 91. Storage Policies

Bucket:

```text
trip-journal
```

must be private.

Storage policy must verify trip membership based on the storage path.

Users outside the trip must not be able to:

- read photos
- upload photos
- delete photos

---

# 92. Supabase Migrations

Create migrations:

```text
001_profiles.sql
002_trips.sql
003_trip_members.sql
004_trip_invitations.sql
005_expenses.sql
006_expense_participants.sql
007_settlements.sql
008_journal_entries.sql
009_journal_photos.sql
010_indexes.sql
011_functions.sql
012_rls.sql
013_storage_policies.sql
014_triggers.sql
```

Use migrations for all schema changes.

---

# 93. Development Seed

Create development seed data:

```text
Trip:
Da Lat 2026

Members:
Nguyen
Minh
An
Tuan

Expenses:
Hotel
Dinner
Taxi
Coffee
Tickets

Memories:
Datanla Waterfall
Night Market
Langbiang
Xuan Huong Lake
```

Never use seed data in production.

---

# 94. Testing

Unit test:

## Equal Split

```text
100 / 3
1000 / 3
1000 / 4
```

## Custom Split

```text
valid
invalid
zero
negative
```

## Balance

Test:

- one payer
- multiple payers
- multiple participants
- partial participation
- settlements

## Settlement

Test simple and complex cases.

## Journal

Test:

- create entry
- edit entry
- delete entry
- multiple photos
- photo ordering
- failed upload state

---

# 95. Financial Invariants

Always guarantee:

```text
sum(expense shares) == expense amount
```

and:

```text
sum(all balances) == 0
```

Add assertions in tests.

---

# 96. Offline Strategy

Do not implement full offline synchronization in MVP.

May cache:

- recent trip information
- recent journal images
- recent UI state

Mutations require network.

Do not build conflict-resolution infrastructure.

---

# 97. Environment

Use `--dart-define` or another safe environment approach.

Example:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

Create:

```text
.env.example
```

if appropriate.

Never commit secrets.

---

# 98. App Lifecycle

Startup should be lightweight.

Do not fetch:

```text
all trips
all expenses
all memories
all statistics
```

before showing the Home screen.

Flow:

```text
Splash
 ↓
Auth session
 ↓
Home
 ↓
Load required data
```

---

# 99. Screen List

Implement:

```text
Splash
Login
Register
Home
Trips
Create Trip
Trip Overview
Expenses
Add Expense
Expense Details
Edit Expense
Members
Invite Friends
Journal
Create Memory
Memory Details
Edit Memory
Photo Viewer
Settlements
Statistics
Profile
Settings
Join Trip
```

---

# 100. Definition of Done

Application is complete when:

- register works
- login works
- Google login works
- logout works
- create trip works
- edit trip works
- delete trip works
- invite link works
- join trip works
- add expense works
- equal split works
- custom split works
- edit expense works
- delete expense works
- balances are correct
- settlement suggestions are correct
- mark paid works
- statistics work
- create memory works
- camera works
- gallery works
- image compression works
- image upload works
- journal timeline works
- photo viewer works
- journal editing works
- journal deletion cleans Storage
- trip cover photo works
- pagination works
- RLS is secure
- Storage is private
- no service-role key exists in Flutter
- no background polling exists
- Realtime is limited to active trips
- unit tests pass
- `flutter analyze` passes
- release build succeeds

---

# 101. Development Order

Implement in this order.

## Phase 1 — Foundation

- Flutter setup
- dependencies
- theme
- spacing
- typography
- reusable components
- GoRouter
- Riverpod
- Supabase client

## Phase 2 — Database

- tables
- indexes
- functions
- RLS
- Storage policies
- triggers
- seed

## Phase 3 — Authentication

- login
- register
- Google
- logout
- profile

## Phase 4 — Trips

- trip list
- create trip
- trip detail
- members

## Phase 5 — Invitations

- token
- share
- join

## Phase 6 — Expenses

- add expense
- equal split
- custom split
- list
- detail
- edit
- delete

## Phase 7 — Balances

- balances
- settlement algorithm

## Phase 8 — Settlements

- suggestions
- mark paid
- history

## Phase 9 — Journal

- create memory
- camera/gallery
- image compression
- upload
- timeline
- details
- edit
- delete
- photo viewer
- trip cover

## Phase 10 — Statistics

- total
- categories
- members
- timeline

## Phase 11 — Realtime

- active trip subscription
- invalidation
- reconnect

## Phase 12 — Polish

- animations
- loading
- empty states
- errors
- haptics
- accessibility
- performance

---

# 102. Cursor Instructions

Act as a senior Flutter + Supabase engineer and product UI/UX engineer.

Before writing code:

1. Inspect the repository.
2. Determine whether Flutter is already configured.
3. Inspect existing dependencies.
4. Do not replace working architecture unnecessarily.
5. Create an implementation plan.
6. Identify existing code that can be reused.
7. Implement incrementally.
8. Run `flutter analyze` after major phases.
9. Run tests after financial logic changes.
10. Fix errors before continuing.
11. Never bypass RLS.
12. Never expose service-role credentials.
13. Keep Supabase usage minimal.
14. Keep financial calculations deterministic.
15. Keep Storage private.
16. Compress images before uploading.
17. Never implement unnecessary polling.
18. Use Realtime only when useful.
19. Do not add Edge Functions unless absolutely necessary.
20. Do not add unnecessary dependencies.
21. Build reusable UI components.
22. Keep UI consistent across all screens.
23. Use animations only when they improve UX.
24. Test the app on small mobile screens.
25. Prioritize performance when rendering images.

---

# 103. Cursor UI Quality Rules

Do NOT generate generic Flutter UI.

Do NOT make every screen look like a basic CRUD application.

The UI should feel:

```text
Premium
Modern
Travel-focused
Warm
Clean
Friendly
```

Use:

- strong typography
- beautiful photography
- rounded cards
- clear hierarchy
- subtle shadows
- generous spacing
- polished empty states
- smooth transitions
- meaningful micro-interactions

Do not overuse:

- gradients
- shadows
- borders
- animations
- colors
- icons

---

# 104. Cursor Animation Rules

Every animation must have a purpose.

Use animations for:

- navigation
- photo opening
- card entrance
- bottom sheets
- button state
- selection
- success feedback
- FAB expansion

Avoid animation for:

- every text
- every list item on every rebuild
- every database update
- financial numbers constantly changing

Animation must never block user interaction.

---

# 105. Cursor Performance Rules

Pay special attention to:

```text
Journal photo grids
Journal timeline
Trip cover images
Expense lists
Statistics charts
```

Use:

```text
ListView.builder
GridView.builder
CachedNetworkImage
const widgets
provider select
RepaintBoundary
```

where appropriate.

Never decode full-resolution photos for tiny thumbnails.

---

# 106. Final Product Experience

The finished application should feel like:

```text
TripMate

A trip companion for friends.

Before the trip:
Create the trip
Invite friends

During the trip:
Track expenses
Add memories
Save photos
Record places

After the trip:
Settle expenses
View statistics
Relive the journey
```

Example final trip:

```text
╔════════════════════════════════╗
║                                ║
║          DA LAT 2026           ║
║                                ║
║       [ COVER PHOTO ]          ║
║                                ║
║     Aug 20 – Aug 23            ║
╚════════════════════════════════╝

💰 8,450,000 ₫
Total spent

📸 37 memories
📍 8 places

──────── JOURNAL ────────

📍 Datanla Waterfall

[ Photo ] [ Photo ]

Beautiful waterfall...

────────────

📍 Da Lat Night Market

[ Photo ] [ Photo ] [ Photo ]

Amazing food tonight...

──────── EXPENSES ────────

Hotel          4,000,000 ₫
Food           2,150,000 ₫
Transport        800,000 ₫
Activities     1,500,000 ₫

──────── SETTLEMENT ──────

Minh → Nguyen
300,000 ₫

An → Nguyen
300,000 ₫
```

The app's core differentiator is:

> **It does not only split the cost of a trip. It preserves the story of the trip.**
