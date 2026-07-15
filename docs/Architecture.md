# Architecture

## Status

This document is the architectural overview for the Crown Checkers MVP.

Implementable behavior is defined by the canonical specifications under `docs/Specs/`. If an example or summary elsewhere conflicts with a canonical specification, the specification controls.

Canonical documents:

- [[Specs/MVP Scope Matrix]]
- [[Specs/Checkers Rules]]
- [[Specs/Match and Rating State Machine]]
- [[Specs/Matchmaking Queue]]
- [[Specs/Backend Contracts]]
- [[Specs/Firebase Environments and Services]]
- [[Specs/Analytics Measurement Plan]]
- [[Specs/Analytics Event Catalog]]
- [[Specs/Friends and Invitations]]
- [[Specs/Auth Account and Offline]]
- [[Specs/Feed and Privacy]]
- [[Specs/Daily Puzzle]]
- [[Specs/MVP Verification Plan]]

---

# Product Boundary

The MVP includes:

- WCDF English draughts under Go As You Please play
- One adaptive offline bot
- Rated automatic matchmaking
- Persistent Friends
- Rated and unrated friend matches
- Persistent per-game Elo
- Nonseasonal Elo-derived League and League Tier labels
- Player-local Daily Puzzle
- Friends-only activity Feed
- Latest 50 completed-match replays per account
- Bundled board and piece selection
- Interstitial advertising

The MVP excludes:

- Seasons and seasonal rewards
- Currency and progression rewards
- Cosmetic ownership, purchases, shops, and collections
- Memberships and AI coaching
- Achievements and challenge goals
- Chess, tournaments, chat, spectating, and clubs
- Web and desktop clients, Firebase Hosting, Vercel, and other web deployment infrastructure

---

# Platform

Crown is built in Flutter for:

- iOS
- Android

The local rules engine is separated from Flutter presentation and reused by:

- Bot play
- Client move previews
- Server validation
- Daily Puzzle validation
- Replay reconstruction

The MVP ruleset identifier is:

```txt
checkers-wcdf-gayp-v1.0.0
```

Every match, puzzle, saved bot game, and replay stores the ruleset identifier that created it.

---

# Suggested Project Structure

```txt
lib/
  app/
  features/
    auth/
    home/
    matchmaking/
    match/
    bot/
    replay/
    puzzles/
    league/
    feed/
    friends/
    profile/
    appearance/
    settings/
    privacy_consent/
  game_engine/
    core/
    checkers/
  services/
  models/
  shared/

functions/
  src/
    auth/
    matchmaking/
    matches/
    ratings/
    friends/
    feed/
    puzzles/
    notifications/
    ads/

firestore/
  rules/
  indexes/
  fixtures/
```

Package and file names may differ, but domain ownership and trust boundaries must match the canonical contracts.

---

# Backend

Recommended services:

```txt
Firebase Authentication
Cloud Firestore
Cloud Functions
Cloud Tasks
Firebase Cloud Messaging
Firebase Remote Config
Firebase Analytics
Firebase Crashlytics
Firebase Performance Monitoring
Firebase App Check
AdMob
```

RevenueCat and paid-entitlement infrastructure are not MVP dependencies.

All competitive and social mutations use authenticated server APIs. Firestore clients do not directly write matches, moves, ratings, League projections, friend relationships, invitations, Feed events, replay grants, or puzzle completions.

The complete resource, API, query, index, retention, and authorization contracts are defined in [[Specs/Backend Contracts]].

Environment and deployment configuration are defined in [[Specs/Firebase Environments and Services]]. Crown uses separate development and production Firebase projects, iOS/Android app registrations, and GA4 properties. Both Firestore databases use Standard edition, Native mode in `nam5`; Functions and Cloud Tasks use `us-central1`. No web application, web Analytics stream, Firebase Hosting target, or Vercel project is part of the MVP.

---

# Optional Data and Diagnostics

Google Analytics, advertising storage and personalization signals, Crashlytics, and Performance Monitoring are integrated but default to disabled. Before Authentication on first launch, one device-scoped choice grants or denies all optional collection categories together. Declining never restricts gameplay and no denied-period payload is buffered for later submission.

After consent and authentication, GA4's dedicated User-ID field may use the opaque Firebase UID. Event parameters, user properties, Crashlytics, Performance attributes, and logs never receive the UID, PII, player handles, domain-record IDs, board states, or free text. Sign-out, account switching, and consent withdrawal clear the Analytics identity before the previous account context is released. Crashlytics User-ID is never set.

The collection lifecycle and privacy contract are defined in [[Specs/Analytics Measurement Plan]]. Exact GA4 events and parameters are defined in [[Specs/Analytics Event Catalog]]. First-launch presentation and Settings behavior are defined in [[UX/Privacy Consent Screen]].

---

# Identity and Offline Access

Supported providers:

- Sign in with Apple
- Sign in with Google
- Email and password

Every account receives a durable Firebase UID. Anonymous guest mode is excluded.

Provider-verified accounts may use online and social features immediately. Email-password accounts must verify their email before using matchmaking, Friends, social Feed reads, or friend matches.

An unverified or authenticated-offline player may use:

- Adaptive bot play
- The current Daily Puzzle while online, or an already assigned puzzle while offline
- Cached own profile and settings
- Downloaded retained replays

Boot states, provider collisions, cache isolation, sign-out, and offline synchronization are defined in [[Specs/Auth Account and Offline]].

---

# Game and Match Authority

Logical Checkers sides are Black and White. Black moves first. Cosmetic colors never change logical side or legal behavior.

Online matches are server-authoritative. Each command includes:

- Authenticated actor
- Client-generated idempotency key
- Expected match revision
- Command type and validated payload

The server resolves deadline expiration before applying a command. Individual jumps in a mandatory capture sequence are durable, but the moving side and clock remain active until the complete turn ends.

Every online human-vs-human Checkers match uses 15 minutes per player with no increment.

Match states, result precedence, draw rules, disconnection, no-shows, clocks, idempotency, atomic finalization, Elo, statistics, and friend daily limits are defined in [[Specs/Match and Rating State Machine]].

---

# Matchmaking

Automatic matchmaking:

1. Requires a verified account.
2. Requires the same broad League.
3. Prefers the same League Tier.
4. Ranks eligible candidates by Elo proximity and connection quality.
5. Never expands across a broad League boundary.

Queue leases, heartbeats, stale cleanup, atomic pairing, readiness, cancellation races, and background behavior are defined in [[Specs/Matchmaking Queue]].

Direct friend matches do not use the automatic queue and may cross League boundaries.

---

# Ratings and League

Checkers rating starts at 800.

Elo uses the standard base-10, 400-point expected-score formula with the K-factor and rounding rules in [[Specs/Match and Rating State Machine]].

League and League Tier are derived directly from current Elo:

| League Tier | Elo Range |
| --- | --- |
| Bronze III | 0-699 |
| Bronze II | 700-799 |
| Bronze I | 800-899 |
| Silver III | 900-999 |
| Silver II | 1000-1099 |
| Silver I | 1100-1199 |
| Gold III | 1200-1299 |
| Gold II | 1300-1399 |
| Gold I | 1400-1499 |
| Platinum III | 1500-1599 |
| Platinum II | 1600-1699 |
| Platinum I | 1700-1799 |
| Diamond | 1800+ |

There are no seasons, resets, placement matches, League XP, or weekly promotion processes.

Rated matchmaking results alter Elo. Rated friend results alter Elo only for the first three eligible finalized pair results on both players' respective local dates. Later rated friend results remain rated statistics but record zero Elo change.

---

# Friends and Privacy

Friends are persistent reciprocal relationships. Friend requests and match invitations use deterministic uniqueness and transactional state changes.

Friend match invitations:

- Default to unrated
- Require consent from both players for rated play
- Become immutable when the server creates the match
- May create rated matches across League boundaries

Profiles and activity are friends-only by default. Match replays remain participant-only even when a match summary is visible to a friend.

The state machines are defined in [[Specs/Friends and Invitations]]. Privacy and Feed behavior are defined in [[Specs/Feed and Privacy]].

---

# Feed

The Feed is a per-viewer, reverse-chronological activity projection. It is not a public global feed.

Every completed match creates an owner event. Eligible friends receive a projection only when the actor's friends-only privacy setting permits it.

The MVP Feed excludes:

- Challenges
- Achievements
- Seasons and rewards
- Cosmetic unlocks and purchases

Feed ordering, pagination, deduplication, retroactive privacy, and replay authorization are defined in [[Specs/Feed and Privacy]].

---

# Daily Puzzle

The Daily Puzzle uses each player's server-stored IANA time zone and local calendar date.

Puzzle content is immutable and versioned. Solution data is server-private. Offline completions synchronize idempotently and retain their assigned player-day identity.

Publication, correction, withdrawal, solution trees, streaks, timezone changes, and multi-device conflict behavior are defined in [[Specs/Daily Puzzle]].

Daily Puzzles do not affect Elo or League and grant no MVP currency or item reward.

---

# Replays

Each player may view their latest 50 completed non-void matches across bot, matchmaking, rated friend, and unrated friend modes. Viewing is unlimited while a replay remains retained.

Replay access is participant-only. Ruleset version, initial state, immutable move events, result, and mode are retained sufficiently to reconstruct the match.

The screen behavior is defined in [[UX/Replay Screen]]. Storage and authorization are defined in [[Specs/Backend Contracts]].

---

# Bundled Appearance

Every MVP player may select from the boards and piece sets bundled with the application. The selected IDs may sync to the account.

There are no ownership records, entitlements, prices, purchases, shops, collection counts, or locked appearance options in the MVP.

---

# Advertising

Free MVP players are eligible for an interstitial:

- After every third completed Checkers match
- After every second completed Chess match after Chess launches

For Checkers, completed bot, rated matchmaking, and Elo-applying rated friend matches count. Unrated friend matches, friend results capped by the daily Elo limit, cancelled matches, void matches, and abandoned sessions without a committed result do not count.

Ads appear only after result persistence and never interrupt active play or reconnection.

---

# Security Baseline

The backend uses default-deny authorization.

Required guarantees include:

- Private and public profile data are stored separately.
- Clients cannot directly mutate competitive or social workflow state.
- Active matches are readable only by participants.
- Replays are readable only through a current participant grant.
- Puzzle solutions are never client-readable.
- Friend and Feed reads enforce current relationship and privacy state.
- Every mutation validates authentication, email-verification gates, authorization, schema, idempotency, and rate limits.

The required Rules test matrix is defined in [[Specs/MVP Verification Plan]].

---

# Development Gate

MVP development follows [[Specs/MVP Verification Plan]]. Development is considered contract-ready when:

- Every MVP action maps to a documented API.
- Every query maps to a documented index and cursor.
- Every concurrency-sensitive mutation has an atomicity and idempotency rule.
- Engine conformance, transaction races, security Rules, offline synchronization, and primary UX journeys have executable test cases.

Final legal text, store compliance, final budget values, incident response, backups, and support operations remain launch-readiness work. Firebase environment isolation, GitHub deployment identity, consent behavior, and telemetry verification are implementation requirements rather than deferred launch assumptions.
