# V3_FEATURES_SPEC.md

# Trip App — V3 Community Trip Plans & Discovery

> **Purpose:** Extend the existing Flutter + Supabase application with a community layer where users can publish travel plans and other users can discover, save, and clone those plans.
>
> **IMPORTANT:** V1 and V2 are already implemented. Do NOT rebuild them. V3 must extend the existing application and preserve all existing functionality.

---

# 1. Core Instruction to Cursor

You are working on an existing Flutter application with:

```text
V1
- Trip management
- Members
- Expenses
- Expense splitting
- Journal
- Photos

V2
- Smart Settlement
- Trip Budget
- Smart Trip Map
- Auto Trip Recap
- Digital Trip Book
```

Your task is to implement V3:

```text
Community Trip Plans
Trip Discovery
Save Plan
Clone Plan
Likes
Plan Views
Creator Profile
```

Before changing code:

1. Inspect the entire existing architecture.
2. Inspect existing Trip, Journal, Expense and User models.
3. Inspect existing repositories.
4. Inspect existing Supabase schema.
5. Inspect existing RLS policies.
6. Inspect existing Storage policies.
7. Inspect routing/navigation.
8. Inspect existing design system.
9. Reuse existing components.
10. Add only the minimum new architecture required.

Do NOT rewrite V1/V2.

---

# 2. V3 Product Goal

Transform the app from:

```text
Trip Expense Manager
+
Travel Journal
```

into:

```text
Trip Expense Manager
+
Travel Journal
+
Travel Discovery Platform
```

Core loop:

```text
User creates trip
       ↓
Records itinerary + places + photos
       ↓
Publishes Trip Plan
       ↓
Other users discover the plan
       ↓
Like / Save
       ↓
Clone Plan
       ↓
Customize
       ↓
Create their own Trip
       ↓
Eventually publish their own plan
```

Core positioning:

> **Discover trips. Plan together. Keep the memories.**

---

# 3. V3 MVP Scope

Implement these features:

```text
1. Public Trip Plans
2. Destination Discovery
3. Search Trip Plans
4. Trip Plan Detail
5. Like Plan
6. Save Plan
7. Clone / Use This Plan
8. Plan View Counter
9. Creator Profile
10. Basic Trending / Popular Ranking
```

Do NOT implement a complete social network in V3.

Out of scope:

```text
Direct messaging
Comments
Following
Followers
Stories
Short videos
Public chat
AI itinerary generation
Full recommendation ML
Creator monetization
```

These can be future versions.

---

# 4. Existing Trip vs Public Trip Plan

This distinction is critical.

A normal Trip:

```text
Private
Used by a group
Contains real expenses
Contains private members
Contains settlement data
```

A Public Trip Plan:

```text
Public
Designed for discovery
Contains itinerary
Contains selected places
Contains selected photos
Contains estimated/summary budget
Contains useful notes
```

Never expose the complete private Trip directly.

Public content must use a sanitized representation.

---

# 5. Publish Trip Plan

Add an action to the existing Trip screen:

```text
[ Publish Trip Plan ]
```

Before publishing, show a preview.

Example:

```text
Publish Trip Plan

┌─────────────────────────────┐
│ [ Cover Photo ]             │
│                             │
│ Da Lat 3N2Đ                 │
│                             │
│ 📍 12 places                │
│ 📸 24 memories              │
│ 💰 ~2,050,000 ₫ / person   │
└─────────────────────────────┘

What will be public?

✓ Trip title
✓ Destination
✓ Itinerary
✓ Selected places
✓ Selected photos
✓ Budget estimate
✓ Tips and descriptions

Private information will NOT be shared.

[ Cancel ] [ Publish ]
```

---

# 6. Publish Requirements

A Trip can be published only when it contains enough useful content.

Minimum recommended:

```text
Trip title
Destination
At least 1 itinerary/place
```

Photos are optional.

Do not force users to have expenses before publishing.

---

# 7. Public / Private Visibility

Add a visibility concept to the existing Trip.

Possible values:

```text
private
public
```

If V1 already has visibility:

```text
Reuse it.
```

Do not create a second visibility field.

---

# 8. Unpublish

Users must be able to unpublish.

Example:

```text
Trip Settings

Visibility

● Public
○ Private
```

When changed to private:

```text
The trip will no longer appear
in community discovery.

Existing saved copies remain
unchanged.
```

Important:

> Unpublishing a plan must not delete other users' cloned trips.

---

# 9. Public Plan Data Model

Do NOT expose the complete `trips` row through public queries.

Create a sanitized query/RPC or public view.

Recommended public fields:

```text
trip_id
title
destination
description
cover_image
start_date
end_date
duration_days
created_at
updated_at

creator_id
creator_display_name
creator_avatar

place_count
memory_count

estimated_budget
budget_per_person

like_count
save_count
view_count
clone_count
```

Never expose:

```text
private member IDs
emails
phone numbers
individual balances
settlement history
private expenses
private notes
auth metadata
```

---

# 10. Public Plan Itinerary

A public plan should display a structured itinerary.

Example:

```text
Da Lat 3N2Đ

DAY 1

09:00
☕ Coffee

11:30
🏨 Check-in

14:00
🌲 Datanla Waterfall

19:00
🍜 Dinner


DAY 2

08:00
🌄 Langbiang

12:00
🍴 Lunch

15:00
📸 City Center
```

Reuse existing journal/itinerary information when possible.

Do not force users to recreate the same data in a second system.

---

# 11. Community Home

Add a discovery entry point to the existing app.

Possible:

```text
Home
Trips
Profile
```

or follow the current V1 navigation architecture.

Do NOT create a new navigation system if one already exists.

---

# 12. Discovery Screen

Initial screen:

```text
┌─────────────────────────────┐
│ Explore                     │
│                             │
│ Bạn muốn đi đâu? 🌎         │
│                             │
│ [ 🔍 Đà Lạt, Phú Quốc... ] │
│                             │
│ Popular Destinations        │
│                             │
│ Đà Lạt                      │
│ Phú Quốc                    │
│ Đà Nẵng                     │
│ Hội An                      │
│ Sapa                        │
└─────────────────────────────┘
```

The primary CTA should be:

```text
Bạn muốn đi đâu?
```

This should feel like travel discovery rather than an expense app.

---

# 13. Destination Search

User enters:

```text
Đà Lạt
```

Show:

```text
Đà Lạt

🔥 Popular
💰 Budget
📸 Photo-rich
👥 Group
🗓️ Weekend
```

Search should initially be simple:

```text
case-insensitive
partial matching
destination/title
```

Do not build Elasticsearch or another search engine.

---

# 14. Search Results

Example:

```text
Đà Lạt

24 plans

┌─────────────────────────────┐
│ [PHOTO]                     │
│                             │
│ Đà Lạt 3N2Đ chill           │
│                             │
│ 👤 Nguyen                   │
│ 📍 12 places                │
│ 💰 ~2.5M/person             │
│                             │
│ ❤️ 128   🔖 64   👁 2.4K   │
└─────────────────────────────┘
```

Cards should prioritize:

```text
cover
title
creator
destination
duration
budget
engagement
```

---

# 15. Discovery Filters

MVP filters:

```text
Destination
Duration
Budget
Trip type
```

Trip type can be:

```text
Weekend
Budget
Family
Friends
Couple
Adventure
Relax
```

Only implement trip types if the existing data model can support them cleanly.

Do not create an overcomplicated tagging system in V3.

---

# 16. Sort Options

Provide:

```text
Recommended
Popular
Most Saved
Most Liked
Newest
Budget Friendly
```

Recommended can initially be deterministic.

Example score:

```text
score =
    saves * 5
  + likes * 2
  + views * 0.1
  + freshness_score
```

Do not use AI.

---

# 17. Trending Plans

Add:

```text
🔥 Trending Plans
```

Use recent engagement.

Example:

```text
🔥 Da Lat 3N2Đ
🔥 Phu Quoc 4N3Đ
🔥 Da Nang – Hoi An
```

Trending should favor:

```text
recent
+
high saves
+
high likes
+
high views
```

Do not let old plans dominate forever.

---

# 18. Trip Plan Detail

When a user opens a plan:

```text
┌─────────────────────────────┐
│ [ HERO IMAGE ]              │
│                             │
│ Đà Lạt 3N2Đ                 │
│                             │
│ by Nguyen                   │
│                             │
│ ❤️ 128   🔖 64   👁 2.4K   │
└─────────────────────────────┘
```

Then:

```text
Overview
Itinerary
Places
Photos
Budget
Tips
```

Bottom CTA:

```text
[ Save Plan ]   [ Use This Plan ]
```

---

# 19. Creator Section

Show:

```text
Created by

[Avatar]

Nguyen

23 public trips
1.2K saves
```

Tap creator:

```text
Creator Profile
```

---

# 20. Creator Profile

MVP profile:

```text
┌─────────────────────────────┐
│          [Avatar]           │
│                             │
│ Nguyen                      │
│                             │
│ 23 trips                    │
│ 1.2K saves                  │
└─────────────────────────────┘

Published Trips

[Card]
[Card]
[Card]
```

Do NOT implement followers/following in V3.

---

# 21. Like Plan

User can:

```text
❤️ Like
```

Toggle:

```text
❤️ → 🤍
```

Requirements:

```text
one like per user per plan
```

Database should enforce uniqueness:

```text
unique(user_id, trip_id)
```

Do not trust the client.

---

# 22. Save Plan

User can:

```text
🔖 Save
```

Saved plans appear in:

```text
Profile
   ↓
Saved Plans
```

Uniqueness:

```text
unique(user_id, trip_id)
```

Do not duplicate the plan data when saving.

Only store the relationship.

---

# 23. Saved Plans

Example:

```text
My Saved Plans

❤️ Weekend
🌲 Nature
💰 Budget
```

Card:

```text
[Photo]

Da Lat 3N2Đ

by Nguyen

🔖 Saved
```

Allow:

```text
Open
Remove from Saved
Use This Plan
```

---

# 24. Clone / Use This Plan

This is one of the most important V3 features.

CTA:

```text
[ Use This Plan ]
```

Flow:

```text
Public Plan
      ↓
Use This Plan
      ↓
Preview
      ↓
Customize
      ↓
Create My Trip
```

---

# 25. Clone Confirmation

Show:

```text
Use this plan?

We'll create a new trip
based on:

Da Lat 3N2Đ

12 places
3 days
~2.5M/person

You can customize everything
after creating it.

[ Cancel ] [ Create My Trip ]
```

---

# 26. Clone Rules

When cloning:

COPY:

```text
title
destination
description
dates/duration
itinerary
places
selected public photos
tips
budget estimate
trip type
```

DO NOT COPY:

```text
original trip members
original expenses
original settlements
private notes
original creator's private data
```

The cloned trip belongs entirely to the new user.

---

# 27. Clone Ownership

After clone:

```text
owner = current authenticated user
```

Example:

```text
Original

Da Lat 3N2Đ
by Nguyen


Clone

My Da Lat Trip
based on Nguyen's plan
```

The clone must become a normal V1/V2 Trip.

This means the user can:

```text
add friends
add expenses
edit itinerary
add memories
set budget
use settlement
use map
create recap
create trip book
```

---

# 28. Clone Attribution

Show optional attribution:

```text
Based on
"Da Lat 3N2Đ"
by Nguyen
```

This should be informational.

Do not create a hard dependency between the two trips.

If the original is deleted or unpublished:

```text
Clone remains valid.
```

---

# 29. View Counter

When a user opens a public plan:

```text
view_count += 1
```

Do not increment repeatedly during the same screen session.

Prefer:

```text
once per user/session
```

Do not write a database row for every screen rebuild.

---

# 30. Engagement Counters

Possible:

```text
like_count
save_count
view_count
clone_count
```

Counters must not be trusted directly from the client.

Use:

```text
database trigger
RPC
transaction
```

according to the existing architecture.

Do not create expensive recalculation queries on every screen load.

---

# 31. Database Design

Inspect existing schema first.

Possible new tables:

```text
trip_plan_likes
trip_plan_saves
```

Example:

```sql
trip_plan_likes
----------------
id
trip_id
user_id
created_at
```

Unique:

```text
trip_id + user_id
```

Example:

```sql
trip_plan_saves
----------------
id
trip_id
user_id
created_at
```

Unique:

```text
trip_id + user_id
```

Only add tables that do not already exist.

---

# 32. Public Plan Metadata

If current `trips` table does not contain suitable fields, add only necessary fields.

Possible:

```text
visibility
destination
description
cover_image
trip_type
estimated_budget
```

Do not duplicate:

```text
title
dates
owner
```

if they already exist.

---

# 33. Trip Type

If useful, support:

```text
weekend
budget
friends
family
couple
adventure
relax
```

Store as a simple value or existing project-compatible structure.

Do NOT implement arbitrary user-generated hashtags in V3.

---

# 34. RLS

All community tables require RLS.

Rules:

## Public Plans

Anonymous/authenticated users may read only:

```text
visibility = public
```

and only sanitized fields.

## Likes

Authenticated users can:

```text
create own like
delete own like
read allowed public like information
```

## Saves

Authenticated users can:

```text
create own save
delete own save
read own saves
```

## Publishing

Only the Trip owner can:

```text
publish
unpublish
edit public metadata
```

---

# 35. Privacy Rules

Never expose:

```text
email
phone
private member list
individual expense amounts
individual balances
settlements
private journal entries
private notes
```

A public plan should be explicitly constructed.

Do not simply make the existing `trips` table publicly readable.

---

# 36. Public Photos

A public plan can display selected photos.

Do not automatically expose every private trip photo.

Allow:

```text
Select photos to publish
```

Example:

```text
Choose Photos

✓ Photo 1
✓ Photo 2
○ Photo 3
○ Photo 4

[ Continue ]
```

If V1 already has a journal photo visibility model, reuse it.

---

# 37. Publish Editor

Create:

```text
Publish Plan Editor
```

Fields:

```text
Title
Destination
Description
Cover photo
Trip type
Estimated budget
Selected itinerary
Selected photos
```

Preview:

```text
[ Preview ]
```

Then:

```text
[ Publish ]
```

---

# 38. Editing Public Plan

Owner can:

```text
Edit
Update
Unpublish
```

Other users should see updated public data.

Saved plans should point to the plan, not duplicate it.

Cloned trips remain independent.

---

# 39. Supabase Free-Plan Optimization

Strict rules:

Do NOT:

```text
create a view row on every rebuild
poll engagement
load all public plans
download all images
duplicate images for saved plans
duplicate plans when saving
run AI ranking
create a search engine
```

Use:

```text
pagination
RPC
indexes
thumbnail URLs
lazy loading
cached results
```

---

# 40. Pagination

Community feeds must be paginated.

Do not load:

```text
1000 plans
```

initially.

Recommended:

```text
20 plans/page
```

Load more when needed.

Use the existing pagination architecture if available.

---

# 41. Search Optimization

If searching PostgreSQL:

Use indexes where appropriate.

For simple MVP:

```text
destination
title
```

can use case-insensitive search.

If scale becomes large later:

```text
PostgreSQL full-text search
```

or another search system can be introduced.

Do not add external search infrastructure in V3.

---

# 42. Image Optimization

Public discovery is image-heavy.

Use:

```text
thumbnail
medium
full
```

where existing Storage supports transformations.

Cards should use:

```text
thumbnail
```

Plan detail can load:

```text
medium
```

Full resolution should only be loaded when viewing a photo.

---

# 43. Community Home Performance

Initial page should not load:

```text
all destinations
all plans
all creators
all photos
```

Load:

```text
Popular destinations
+
first page of trending plans
```

Then lazy load.

---

# 44. Recommendation MVP

Do NOT implement AI.

Initial recommendation:

```text
User searches destination
       ↓
Find public plans
       ↓
Rank by engagement + freshness
```

Later:

```text
User history
Saved plans
Previous trips
Budget
Trip type
      ↓
Personalized recommendation
```

---

# 45. Destination Ranking

Popular destinations can be calculated using:

```text
number of public plans
number of saves
number of likes
number of recent views
```

Do not run expensive aggregation on every home screen.

Use:

```text
RPC
cached aggregate
```

where necessary.

---

# 46. Empty States

## Community

```text
🌎

No trip plans yet.

Be the first to share a trip!

[ Publish My Trip ]
```

## Search

```text
🔍

No plans found for "Tokyo"

Try another destination.
```

## Saved Plans

```text
🔖

You haven't saved any plans yet.

Find a trip that inspires you.
```

## Creator

```text
No public trips yet.
```

---

# 47. Error States

Examples:

```text
Unable to load trip plans.
[ Retry ]

Unable to publish your plan.
[ Retry ]

Unable to save this plan.
[ Retry ]

Unable to create your trip.
[ Retry ]
```

Never expose raw PostgreSQL/Supabase errors.

---

# 48. Loading States

Use:

```text
skeleton cards
image placeholders
shimmer
```

Avoid blank screens.

Do not use long artificial delays.

---

# 49. Animation Guidelines

Community should feel modern.

Use:

```text
card fade-in
subtle slide
hero image transition
like scale
save animation
page transition
```

Typical:

```text
200–400ms
```

Like interaction:

```text
scale 1.0
→ 1.15
→ 1.0
```

Keep animations subtle.

---

# 50. Haptic Feedback

Use light haptics for:

```text
Like
Save
Publish
Clone
```

Do not vibrate on every scroll/tap.

---

# 51. Navigation

Do not automatically add many bottom-nav tabs.

Preferred structure:

```text
Home
Trips
Profile
```

Community can be:

```text
Home
```

or a section of Home depending on existing V1 navigation.

Use the current project structure.

---

# 52. Profile Upgrade

Existing profile can gain:

```text
My Trips
Saved Plans
Published Plans
```

Example:

```text
Profile

Nguyen

My Trips
Saved Plans
Published
```

Do not add followers/following yet.

---

# 53. Creator Metrics

Show only useful public metrics:

```text
Public trips
Total saves
```

Avoid showing:

```text
private financial statistics
private trip count
private member count
```

---

# 54. Plan Detail Budget

Public budget must be clearly labeled.

Use:

```text
Estimated budget
```

NOT:

```text
Actual expense
```

Example:

```text
Estimated

~2,050,000 ₫ / person
```

If calculated from original trip expenses, sanitize it:

```text
total public budget / estimated people
```

Never expose individual payments.

---

# 55. Public Plan Statistics

Display:

```text
📍 12 places
📸 24 memories
🗓️ 3 days
💰 ~2.5M/person
```

Optional:

```text
❤️ 128
🔖 64
```

Do not overwhelm the screen with metrics.

---

# 56. Clone Budget Behavior

When cloning:

```text
estimated_budget
```

becomes the new Trip's optional budget.

The new owner can change it.

Do not copy actual expenses.

Example:

```text
Original Plan

Estimated budget:
2,500,000 ₫ / person

↓

New Trip

Budget:
2,500,000 ₫

Actual expenses:
0 ₫
```

---

# 57. Clone Journal Behavior

Only copy content explicitly marked public.

Copy:

```text
public itinerary descriptions
public tips
public selected locations
public selected photos
```

Do not copy:

```text
private journal notes
private captions
private metadata
```

---

# 58. Clone Photos

Do not create unnecessary duplicate Storage objects if avoidable.

If the existing architecture allows references to public assets, reuse them.

If ownership rules require copying:

```text
copy only selected public assets
```

and document the reason.

Do not copy all original photos.

---

# 59. Creator Attribution

On cloned Trip:

```text
Inspired by
Da Lat 3N2Đ
by Nguyen
```

Optional.

This should not grant the original creator access to the cloned trip.

---

# 60. Security Testing

Test:

```text
Anonymous user can see public plans.
Anonymous user cannot see private trips.

User A cannot edit User B's public plan.

User A cannot delete User B's like.

User A cannot access User B's saves.

Private expenses never appear in public plan.

Private journal entries never appear in public plan.

Cloning does not expose original private members.
```

---

# 61. Unit Tests

Add tests for:

```text
Public plan sanitization
Ranking
Trending score
Search filtering
Clone mapping
Budget sanitization
Like toggle
Save toggle
Pagination
```

---

# 62. Clone Mapping Test

Given:

```text
Original:
Trip A
3 days
10 places
5 public photos
3 private photos
4 members
20 expenses
```

Clone should contain:

```text
3 days
10 places
5 public photos
0 original members
0 original expenses
```

and:

```text
owner = current user
```

---

# 63. Ranking Test

Example:

```text
Plan A
100 saves
50 likes

Plan B
20 saves
100 likes
```

Using:

```text
score = saves * 5 + likes * 2
```

Plan A should rank higher.

Ranking must be deterministic.

---

# 64. Definition of Done — Public Trip Plans

- [ ] Publish editor
- [ ] Preview
- [ ] Public/private visibility
- [ ] Selected public photos
- [ ] Public itinerary
- [ ] Sanitized public data
- [ ] Unpublish
- [ ] Edit public plan
- [ ] RLS
- [ ] Privacy tests

---

# 65. Definition of Done — Discovery

- [ ] Explore screen
- [ ] "Bạn muốn đi đâu?"
- [ ] Destination search
- [ ] Search results
- [ ] Pagination
- [ ] Popular destinations
- [ ] Trending plans
- [ ] Sort
- [ ] Filters
- [ ] Loading state
- [ ] Empty state
- [ ] Error state

---

# 66. Definition of Done — Likes

- [ ] Like
- [ ] Unlike
- [ ] Unique constraint
- [ ] Counter
- [ ] Optimistic UI where safe
- [ ] Error rollback
- [ ] RLS

---

# 67. Definition of Done — Saved Plans

- [ ] Save
- [ ] Unsave
- [ ] Saved Plans screen
- [ ] Unique constraint
- [ ] Pagination
- [ ] RLS
- [ ] No duplicated trip data

---

# 68. Definition of Done — Clone

- [ ] Use This Plan
- [ ] Confirmation
- [ ] Clone itinerary
- [ ] Clone public photos
- [ ] Clone estimated budget
- [ ] No private data copied
- [ ] New owner
- [ ] New independent Trip
- [ ] Attribution
- [ ] Unit tests

---

# 69. Definition of Done — Creator Profile

- [ ] Public creator profile
- [ ] Avatar
- [ ] Display name
- [ ] Public trip count
- [ ] Save count
- [ ] Public trips
- [ ] Pagination
- [ ] Privacy safe

---

# 70. Product UX Flow

The ideal V3 experience:

```text
OPEN APP
    ↓
"Bạn muốn đi đâu?"
    ↓
Đà Lạt
    ↓
Explore Plans
    ↓
[Da Lat 3N2Đ]
    ↓
Plan Detail
    ↓
❤️ Like
🔖 Save
    ↓
Use This Plan
    ↓
Create My Trip
    ↓
Customize
    ↓
Invite Friends
    ↓
Track Expenses
    ↓
Journal
    ↓
Map
    ↓
Recap
    ↓
Trip Book
    ↓
Publish
    ↓
Another user discovers it
```

This creates the core community loop.

---

# 71. Product Principle

The product should evolve into:

```text
DISCOVER
   ↓
PLAN
   ↓
TRAVEL
   ↓
TRACK
   ↓
REMEMBER
   ↓
SHARE
   ↓
DISCOVER AGAIN
```

This loop is more important than adding many social features.

---

# 72. Future Features — NOT V3

Do NOT implement these now:

```text
AI Trip Planner
AI recommendation
Comments
Followers
Following
Creator subscriptions
Creator payouts
Public messaging
Travel groups
Video feed
Stories
Social notifications
Public web profiles
Affiliate booking
Hotels
Flights
Restaurant booking
```

Keep V3 focused.

---

# 73. Future AI Layer

V4+ can use:

```text
User behavior
Saved plans
Liked plans
Previous trips
Budget preferences
Trip types
Destinations
```

Then:

```text
Personalized Recommendation
```

Example:

```text
Because you saved:

Da Lat 3N2Đ
Phu Quoc 4N3Đ

You may like:

🌊 Nha Trang 3N2Đ
🌲 Sapa 3N2Đ
🏖️ Quy Nhon 3N2Đ
```

But V3 must work completely without AI.

---

# 74. Supabase Cost Rules

V3 should remain compatible with Supabase Free as much as practical.

Avoid:

```text
Realtime on every public plan
heavy analytics tables
event row per impression
background jobs
AI API calls
large image duplication
unbounded feeds
```

Use:

```text
PostgreSQL
RPC
RLS
Storage
pagination
indexes
cached counters
```

---

# 75. Implementation Order

Implement:

```text
PHASE 1
Public Trip Plan
        ↓
PHASE 2
Discovery + Search
        ↓
PHASE 3
Like + Save
        ↓
PHASE 4
Plan Detail
        ↓
PHASE 5
Clone Plan
        ↓
PHASE 6
Creator Profile
        ↓
PHASE 7
Trending + Ranking
        ↓
PHASE 8
Security + Performance
        ↓
PHASE 9
Integration Testing
```

After every phase:

```bash
flutter analyze
flutter test
```

---

# 76. Cursor Implementation Workflow

For each phase:

## Step 1

Inspect existing code.

## Step 2

List:

```text
files to modify
files to create
migrations
RPC
RLS
```

## Step 3

Implement minimal complete feature.

## Step 4

Run:

```bash
flutter analyze
flutter test
```

## Step 5

Manually test V1/V2.

## Step 6

Check Supabase query count and payload size.

---

# 77. Final V3 Verification

## V1 Regression

- [ ] Authentication
- [ ] Trips
- [ ] Members
- [ ] Expenses
- [ ] Splitting
- [ ] Journal
- [ ] Photos

## V2 Regression

- [ ] Settlement
- [ ] Budget
- [ ] Map
- [ ] Recap
- [ ] Trip Book

## V3

- [ ] Publish
- [ ] Unpublish
- [ ] Discovery
- [ ] Search
- [ ] Filters
- [ ] Trending
- [ ] Like
- [ ] Save
- [ ] Saved Plans
- [ ] Plan Detail
- [ ] Clone
- [ ] Creator Profile

## Security

- [ ] RLS
- [ ] Public/private separation
- [ ] Sanitized public data
- [ ] Private expenses hidden
- [ ] Private members hidden
- [ ] Private journal hidden
- [ ] Clone isolation

## Performance

- [ ] Pagination
- [ ] Lazy images
- [ ] Thumbnail usage
- [ ] No unnecessary Realtime
- [ ] No polling
- [ ] No duplicate plan data
- [ ] No duplicate image uploads where avoidable

## Quality

- [ ] flutter analyze passes
- [ ] flutter test passes
- [ ] No UI overflow
- [ ] Loading states
- [ ] Empty states
- [ ] Error states
- [ ] Smooth animations
- [ ] Existing V1/V2 visual consistency
