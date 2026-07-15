# MVP Scope Matrix

## Purpose

This document defines the binding feature boundary for the Crown Checkers MVP.

The MVP is an authenticated product validation build for iOS and Android. It must prove that a player can learn the product, play correct Checkers games locally and online, maintain a persistent competitive identity, interact with friends, solve a daily puzzle, and revisit recent games.

When an existing vision, architecture, monetization, mockup, or UX document describes a different launch scope, this document controls MVP inclusion. Those documents may still describe later product direction.

---

# Product Baseline

The MVP includes one game:

- Checkers, using WCDF English draughts under Go As You Please play.

The normative engine rules are defined in `docs/Specs/Checkers Rules.md` under ruleset identifier `checkers-wcdf-gayp-v1.0.0`.

The MVP has no seasons and no rewards. Elo and its derived League label are persistent competitive indicators, not seasonal progression systems.

The MVP does not include a live economy. Players may select only from cosmetic assets bundled with the app. There are no purchases, unlocks, drops, reward grants, rotating offers, or membership entitlements.

---

# Scope Status Definitions

## Included

The capability must be implemented and pass the acceptance criteria in this document and the MVP Verification Plan.

## Deferred

The capability must not be required for MVP completion. Entry points should be absent rather than displayed as enabled, locked, or coming soon unless a UX specification explicitly requires explanatory copy.

## Prohibited in MVP

The capability would contradict the MVP product contract. It must not affect data, eligibility, ranking, or presentation in an MVP build.

---

# Authentication and Account

## Included

- Durable accounts backed by supported authentication providers.
- Email and password sign-up and sign-in.
- Email verification state synchronized from the authentication provider.
- Sign out and normal session restoration.
- A persistent display name and stable player identifier.
- Access to local bot play and the current Daily Puzzle before email verification.
- Access to the player's own settings and locally available replay data before email verification.

## Email Verification Gate

A verified email is required before a player may use an online or social capability.

Gated capabilities are:

- Entering online matchmaking.
- Starting or resuming an online match.
- Searching for another player.
- Sending, accepting, declining, or removing a friend relationship.
- Reading friend activity.
- Sending or responding to a friend match invitation.
- Starting a rated or unrated friend match.

Authentication providers that return a provider-verified email satisfy this gate. An account without a verified email does not satisfy the gate merely because the player is signed in.

When the gate blocks an action, Crown explains that email verification is required and offers a resend or refresh action where supported. It does not silently queue the action.

## Acceptance Criteria

- A signed-in unverified player can start a bot match and open the current Daily Puzzle.
- A signed-in unverified player cannot enter matchmaking or invoke any friend operation through either the client or backend API.
- A verified player can access online and social capabilities without signing out and back in after verification state refreshes.
- Backend authorization rejects a gated mutation when the client's displayed verification state is stale or forged.

---

# Checkers Gameplay

## Included

- Standard initial position and arbitrary valid authored positions.
- Legal move generation and validation under `checkers-wcdf-gayp-v1.0.0`.
- Mandatory captures and complete multi-capture turns.
- Men, kings, crowning, wins, losses, and automatic draws.
- Resignation for active matches.
- Server-authoritative moves and results for online matches.
- Ruleset identifier persisted with every match and replay.
- Accessible legal-move, turn, king, and result presentation.

## Deferred

- Alternative Checkers variants.
- Three-move restriction openings.
- Opening ballots.
- Player-selected house rules.
- Spectating.
- Chat.
- Takebacks in online play.
- Analysis engines and post-match coaching.

## Acceptance Criteria

- Every engine conformance example in `docs/Specs/Checkers Rules.md` passes against the same production rules module used by bot, online play, puzzles, and replays.
- An online client cannot commit a move the authoritative server rejects.
- A match and its replay identify the exact ruleset used to validate it.
- Cosmetic appearance never changes logical side, legal moves, result, or notation.

---

# Bot Play

## Included

- One bot identity presented as Crown Bot.
- One adaptive difficulty system rather than player-selectable difficulty levels.
- Automatic side assignment: the player's first bot game uses Black, then new bot games alternate Black and White per account.
- Offline bot play.
- Local save and resume from the latest completed turn.
- Unrated results that never affect Elo, League, or rated statistics.
- Bot match replays eligible for the same latest-50 retention policy as other completed matches.

The adaptive bot may use recent bot results, move quality, and game progress to tune future search strength or mistake frequency. Adaptation must remain within configured minimum and maximum strength bounds. The selected strength is internal and is not presented as multiple bots or difficulty choices.

## Deferred

- Multiple named bots.
- Manual difficulty selection.
- Bot ratings or League badges.
- Cloud competition against bot results.
- AI explanations, hints, or coaching.

## Acceptance Criteria

- The player sees one bot entry point and no difficulty selector.
- The bot always returns a legal turn when at least one legal turn exists.
- A bot game can begin, save, restore, and complete without network access.
- Side assignment is deterministic across account devices after synchronization and never requires a setup screen.
- Distinct bot games completed concurrently offline may share a snapshotted side; both remain valid, and server commit order restores one canonical alternating next-side state after synchronization.
- Bot adaptation changes only bot behavior and cannot modify game rules or rated account fields.
- Reinstalling or clearing local data may reset adaptation without affecting account rating.

---

# Online Matchmaking

## Included

- Verified players may join a Checkers matchmaking queue.
- Matchmaking games are rated.
- The server creates the match, assigns sides, owns clocks, validates moves, and commits the result.
- Each player receives 15 minutes with no increment.
- Elo updates exactly once after a committed rated result.
- League and League Tier labels are derived from authoritative Elo.
- Reconnection restores the authoritative position, active turn, and clocks.

## Acceptance Criteria

- An unverified account cannot join the queue even through a direct backend request.
- Two eligible queued players can receive one match with opposite sides and Black to move.
- Duplicate completion delivery does not apply Elo twice.
- A disconnected or backgrounded client cannot pause the server clock.
- Timeout, resignation, no-piece, no-legal-move, and draw results are persisted with distinct result reasons.

---

# Ratings and League Labels

## Included

- A persistent Checkers Elo rating.
- Elo changes from completed rated matchmaking games.
- Elo changes from eligible completed rated friend games.
- Broad League and League Tier labels derived directly from current Elo.
- Rated-only aggregate statistics.

## No Seasons or Rewards

The MVP has:

- No season identifier in active product behavior.
- No season start or end.
- No seasonal reset.
- No weekly promotion or demotion process.
- No placement rewards.
- No participation rewards.
- No challenge rewards.
- No puzzle rewards.
- No currency, points, chests, unlock tracks, or claim actions.

League labels change only when Elo crosses a configured threshold. They do not grant an item or entitlement.

## Acceptance Criteria

- Completing a bot game, unrated friend game, or Daily Puzzle leaves Elo and rated aggregate statistics unchanged.
- Completing an eligible rated game updates Elo once and refreshes the derived League label.
- No MVP screen or result payload offers, grants, or claims a season or reward.
- Advancing a League label does not create an inventory record.

---

# Friends and Social Privacy

## Included

- Friends as a persistent, reciprocal relationship.
- Exact-identity player lookup suitable for sending a request.
- Send, receive, accept, decline, and cancel friend requests.
- Remove a friend.
- Block and unblock an account.
- Presence or last-active information when enabled.
- Direct friend match invitations.
- Unrated friend matches by default.
- Rated friend matches only after explicit consent from both players.
- Rated and unrated friend matches both use the standard 15-minute, no-increment online clock.
- Friends-only visibility for profiles and activity.

## Friends-Only Privacy

Full player profiles, statistics, match activity, puzzle activity, presence, and replay links are visible only to the player and accepted friends.

Limited identity disclosure is permitted only where needed to complete a product action:

- An exact-identity lookup may return stable player identifier and display name.
- A pending friend request may show sender or recipient display name.
- A matchmaking opponent may see display name, rating, League label, side, clock, and match result.
- A player viewing their League Tier leaderboard may see rank, Crown handle, display name, rating, and bundled appearance marker for leaderboard rows.

Limited identity disclosure does not grant full profile, activity, friend-list, or replay access. There is no broadly public profile or global social feed in the MVP.

Email verification is required for every friend and social read or mutation other than viewing the player's own data.

## Acceptance Criteria

- A non-friend cannot read another player's profile, activity, friend list, presence, or replay by guessing an identifier.
- An accepted friend can read the profile and activity allowed by the MVP client.
- Removing a friend revokes friends-only reads for both players without waiting for a new login.
- A friend request alone does not grant friends-only access.
- Blocking immediately removes friendship access and prevents new requests or invitations; unblocking does not restore the friendship.
- Friend match invitations default to unrated and cannot become rated without both players' recorded consent.

---

# Rated Friend Pair Limit

## Included Rule

Only the first three finalized rated friend results between the same pair of players on each player's local calendar date are eligible to alter Elo.

Each player's local date is calculated by the server at finalization using the IANA time zone snapshotted when the match was created. A later time-zone or device-clock change does not alter the match's ledger dates.

The finalization transaction applies Elo only when both players have fewer than three Elo-applying results against that opponent on their respective local dates. One eligible result atomically consumes one slot for both players. If either player has no slot, the result remains rated, updates rated aggregate statistics, records zero Elo change, and consumes no slot for either player.

Commit order determines which three concurrently finalized results receive the slots. Pending, declined, cancelled, unrated, and void matches consume no slot.

## Acceptance Criteria

- The first, second, and third eligible rated friend matches for a pair can be created and update rating after committed results.
- A fourth rated match may be created and completed after normal rated consent, but finalization records zero Elo when either player's applicable local-date count is already three.
- The capped result still updates rated aggregate statistics and clearly explains the zero Elo change.
- Reversing inviter and recipient does not create additional rated slots.
- Concurrent rated finalizations cannot apply Elo to a fourth result.
- Players in different time zones can have different date keys, and both date-key limits must pass.
- Changing a device clock does not change eligibility.

---

# Daily Puzzle

## Included

- One published Checkers puzzle for each player-local calendar date.
- Authored position, side to move, objective, forced solution, and authored opponent responses.
- Legal move validation under the canonical Checkers ruleset.
- Incorrect-move feedback, reset, completion, elapsed time, and local-date streak recognition.
- Replay of the current completed puzzle without changing official completion data.
- No hint.
- No competitive or economic reward.

## Player-Local Puzzle Day

The current puzzle day is the player's local date, calculated from the IANA time zone stored on the account and a trusted current timestamp. The client device clock is not authoritative.

The puzzle catalog is keyed by date. At a local midnight boundary, the current puzzle changes to the new date's published puzzle. A puzzle already open may be finished and recorded against the date key with which it was opened, but opening the Daily Puzzle again loads the current local-date puzzle.

One official completion exists per player and puzzle date. Replays and repeated solution submissions do not create additional completions or modify the official solve time.

## Acceptance Criteria

- Two players at the same instant but on different local dates receive puzzles for their respective date keys.
- Advancing the device clock alone does not reveal another date's puzzle.
- Reopening before local midnight returns the same date-keyed puzzle and attempt.
- Reopening after local midnight loads the new local-date puzzle.
- Completing or replaying a puzzle changes no Elo, League, inventory, currency, or reward field.

---

# Replays and Recent Match History

## Included

- Basic deterministic replay from immutable initial state, ordered turns, result, and ruleset identifier.
- The latest 50 completed non-void matches available to each participating player.
- Bot, matchmaking, rated friend, and unrated friend matches included in recency ordering.
- Unlimited views of every retained replay.
- Forward, backward, start, end, and step controls.

The retained set is ordered by authoritative completion timestamp, newest first, with match identifier as a deterministic tie-breaker. Void and cancelled matches do not enter recent history. When a 51st completed non-void match becomes available to a player, the oldest retained replay leaves that player's accessible recent set. Viewing a replay never changes ordering or retention.

The 50-match limit is per player, not global and not per mode. A replay may remain available to one participant after it has left the other's latest-50 set because their subsequent match histories differ.

## Deferred

- Replay purchases or view limits.
- AI match review.
- Branch analysis.
- Public replay links.
- Spectator annotations.
- Permanent replay archive.
- User pinning that bypasses the 50-match limit.

## Acceptance Criteria

- A player with 50 completed matches can open any of the 50 repeatedly without a counter, charge, or lockout.
- Completing match 51 makes exactly the latest 50 available under the defined ordering.
- Opening an old replay does not move it ahead of a newer replay.
- Replaying every retained match reaches the persisted final position and result.
- Every non-participant, including an accepted friend, cannot fetch the replay.

---

# Bundled Cosmetic Selection

## Included

- A small set of boards and piece sets shipped in the application bundle.
- Selection and persistence of one active bundled board and one active bundled piece set.
- Preview of bundled choices.
- Clear king treatment and accessible contrast for every valid board and piece combination.
- Cosmetic presentation independent from logical Black and White sides.

Every bundled cosmetic is available to every MVP player. Cosmetic identifiers may be persisted to the account, but no ownership or entitlement check beyond inclusion in the supported bundle is needed.

## Deferred or Prohibited in MVP

- Cosmetic purchases.
- Collections shop.
- Individual item shop.
- Membership cosmetic access.
- Seasonal cosmetics.
- Earned cosmetics.
- Random drops.
- Limited-time availability.
- Avatars, frames, badges, victory animations, move effects, and cosmetic sound packs unless required as a fixed part of the base interface.

## Acceptance Criteria

- A player can select any bundled board and piece set without purchase, reward, membership, or inventory state.
- Unsupported or forged cosmetic identifiers fall back to the default bundled cosmetic.
- Both players retain unambiguous ownership and king recognition under every bundled combination.
- Selecting a cosmetic cannot affect legal moves, bot strength, matchmaking, clocks, rating, or puzzle behavior.

---

# Feed and Activity

## Included

- The player's own recent match, League-label change, and puzzle-completion activity.
- Accepted friends' activity subject to friends-only authorization.
- Reverse-chronological ordering.
- Replay entry points only when the viewer is authorized and the replay remains in the owner's retained latest 50.

## Deferred

- Public activity.
- Comments and reactions.
- Challenge cards.
- Reward activity.
- Cosmetic unlock activity.
- Featured or promoted content.

## Acceptance Criteria

- An activity read returns only the player's own items and accepted-friend items.
- Removing a friend removes authorization for subsequent activity reads.
- A stale feed item does not bypass replay retention or replay authorization.

---

# Notifications and Settings

## Included

- Transactional friend request and friend match invitation notifications for verified players.
- Match state notifications where supported.
- Daily Puzzle reminder preference.
- Sound, haptics, board coordinates, reduced motion, privacy, and notification settings needed by included features.

## Deferred

- Marketing campaigns.
- Seasonal reminders.
- Reward reminders.
- Shop or membership notifications.

## Acceptance Criteria

- Disabling a notification category suppresses that category without disabling unrelated transactional state in the app.
- Notification deep links recheck authentication, email verification, friendship, invitation, and match authorization before displaying protected content.

---

# Advertising

## Included

- AdMob interstitial integration.
- One interstitial after every third eligible completed Checkers match when an ad is available.
- Eligible completions are bot, rated matchmaking, and Elo-applying rated friend results.
- Unrated friend matches, capped rated friend results, cancelled or void matches, and sessions without a committed result do not count.
- Ads are requested only after result persistence and never interrupt active play or reconnection.
- An unavailable ad is cleared rather than deferred.
- Personalized advertising, advertising storage, and advertising user-data signals remain denied unless the player has granted the device-scoped optional-data choice. Ad eligibility never implies consent.

## Acceptance Criteria

- Eligible result finalization increments the account-scoped counter exactly once.
- The third eligible completion makes one ad due.
- Ineligible results do not increment the counter.
- Duplicate completion processing cannot make multiple ads due.
- Ad failure never blocks result display, replay access, or navigation.
- Declining optional data never blocks play or changes match eligibility, result persistence, or ad-frequency accounting.

---

# Firebase Environments and Optional Data

## Included

- Separate development and production Firebase projects and GA4 properties.
- Development and production iOS/Android application identifiers under `dev.wxlfe.crown`.
- Firestore Standard edition, Native mode in `nam5` and Cloud Functions/Tasks in `us-central1`.
- Firebase Authentication, Firestore, Functions, Tasks, FCM, Remote Config, App Check, Analytics, Crashlytics, Performance Monitoring, and AdMob as defined in `docs/Specs/Firebase Environments and Services.md`.
- One device-scoped, default-denied optional-data choice before Authentication.
- Google Analytics, advertising storage and personalization consent, Crashlytics, and Performance Monitoring controlled together.
- No pre-consent buffering or later reconstruction.
- Opaque Firebase UID used only in GA4's dedicated User-ID field after consent and authentication.
- Exact allowlisted Analytics events and parameters from `docs/Specs/Analytics Event Catalog.md`.

## Deferred or Excluded

- BigQuery export.
- GA4 key events.
- Web Analytics streams, Firebase Hosting, Vercel, and all web-hosting workflows.
- Analytics events, properties, traces, or crash context outside the canonical allowlists.

## Acceptance Criteria

- A clean installation sends no Analytics, Crashlytics, Performance, or optional advertising-storage data before the player grants the choice.
- Declining leaves every product capability available and does not replay denied-period activity after a later grant.
- Withdrawal disables controlled collection, clears GA User-ID and user properties, and resets local analytics state.
- Rapid sign-out or account switching cannot associate one UID's Analytics identity or properties with another account.
- Development and production builds fail closed on a Firebase project or application identifier mismatch.
- No event payload, user property, crash report, trace attribute, or log contains PII, a Firebase UID, Crown handle, or domain-record ID.

---

# Launch Operations and Legal

## Deferred

Launch operations and legal completion are outside the MVP engineering acceptance boundary.

Deferred work includes:

- App Store and Play Store production submissions.
- Production release orchestration and rollout policy.
- Customer support operations and service-level commitments.
- Moderation operations beyond basic technical report capture.
- Final legal review and production legal copy.
- Jurisdiction-specific age gating or additional consent requirements beyond the included optional-data choice.
- Production privacy policy and terms publication.
- Data export and account deletion operations beyond any development-only mechanism.
- Paid acquisition, press, and launch analytics operations.

Deferral does not authorize insecure handling of personal data or secrets. MVP builds must still use least-privilege access, protect credentials, and avoid collecting data that included features do not need.

## Acceptance Criteria

- MVP completion is not blocked on store submission, marketing, production support staffing, or final legal publication.
- Production launch is explicitly blocked until the deferred legal, privacy, account lifecycle, moderation, and store obligations are separately accepted.

---

# Explicitly Deferred Product Features

- Chess and other games.
- Memberships and subscriptions.
- In-app purchases.
- Seasons and every form of reward.
- Currency and progression tracks.
- Tournaments.
- Clubs and teams.
- Unauthenticated or global public leaderboards and broadly public profiles. The authenticated same-Tier limited-disclosure leaderboard remains included.
- Chat, comments, and reactions.
- Spectating.
- Puzzle archive.
- Puzzle hints.
- AI coaching and match review.
- Advanced replay analysis.
- User-generated content.
- Custom avatars or profile pictures.
- Web and desktop release targets.
- Vercel, Firebase Hosting, web Analytics streams, and other web deployment infrastructure.

---

# MVP Exit Standard

The MVP is scope-complete only when:

- Every included capability has implementation evidence.
- Every acceptance criterion has a passing automated or documented manual test.
- All Checkers conformance tests pass for `checkers-wcdf-gayp-v1.0.0`.
- Authorization tests prove email-verification gates and friends-only privacy at the backend boundary.
- Rated friend pair limits pass concurrency and time-zone tests.
- Daily Puzzle behavior passes player-local-date boundary tests.
- Replay retention proves latest 50 with unlimited views.
- Firebase environment isolation and optional-data consent pass the canonical verification cases.
- No prohibited season, reward, shop, purchase, membership, or multiple-bot behavior is exposed.
- Deferred launch operations and legal work remain clearly marked as production launch blockers rather than silently treated as complete.
