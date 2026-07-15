# MVP Verification Plan

## Purpose

This plan defines how Crown demonstrates that the Checkers MVP satisfies the binding scope in `docs/Specs/MVP Scope Matrix.md`, the game contract in `docs/Specs/Checkers Rules.md`, the environment contract in `docs/Specs/Firebase Environments and Services.md`, and the telemetry contracts in `docs/Specs/Analytics Measurement Plan.md` and `docs/Specs/Analytics Event Catalog.md`.

Verification must produce evidence, not only a verbal sign-off. A feature is not complete because its happy path works on one client.

---

# Verification Principles

- Test the smallest deterministic layer first.
- Reuse the production rules engine in bot, puzzle, replay, client preview, and server validation tests.
- Treat the server as authoritative for identity gates, social privacy, online moves, clocks, ratings, pair limits, and puzzle dates.
- Test denied behavior as thoroughly as allowed behavior.
- Test local-date and concurrency boundaries with controlled clocks and time zones.
- Test the shipped iOS and Android builds, not only debug widgets or backend functions.
- Preserve evidence for every MVP exit criterion.
- Prove optional collection is absent before consent rather than assuming SDK configuration is sufficient.
- Do not accept deferred launch operations or legal work as completed by implication.

---

# Test Environments

## Local Deterministic Environment

Use for:

- Checkers rules unit tests.
- Bot legality and adaptation tests.
- Replay reconstruction tests.
- Puzzle solution tests.
- Rating calculation tests.
- Date and time-zone pure-function tests.

The environment must support a fake trusted clock and seeded randomness.

## Backend Emulator or Development Project

Use for:

- Authentication claims and verification gates.
- Security rules.
- Friends-only access.
- Match creation and move submission.
- Rated friend result-ledger finalization.
- Elo transaction idempotency.
- Replay retention queries.
- Puzzle-day selection.

Emulator data must be disposable. Non-emulated integration tests use only `crown-chess-and-checkers-dev`, with uniquely prefixed synthetic data and automatic cleanup; production is never a general test target.

## Device Test Environment

Use at least:

- One supported iPhone size.
- One compact iPhone size.
- One supported Android phone size.
- One compact or large-text configuration.
- A device or simulator with network conditioning.

Run accessibility checks with screen reader labels, increased text size, reduced motion, and high contrast where supported.

Both Flutter flavors must be built on iOS and Android. Development artifacts must resolve only to `crown-chess-and-checkers-dev`; production artifacts must resolve only to `crown-chess-and-checkers`. A mismatched Firebase project, app ID, bundle ID, or application ID must fail before authentication or telemetry begins.

---

# Test Accounts and Fixtures

Prepare deterministic accounts:

- `unverified-a`: signed in with an unverified email.
- `verified-a`: verified, time zone `America/Los_Angeles`.
- `verified-b`: verified, time zone `America/New_York`.
- `verified-c`: verified, time zone `Pacific/Kiritimati`.
- `verified-d`: verified, time zone `Pacific/Honolulu`.
- `stranger`: verified and not a friend of `verified-a`.
- `friend`: verified with an accepted friendship with `verified-a`.

Prepare deterministic content:

- The standard Checkers position.
- Every conformance position listed in `Checkers Rules.md`.
- A forced two-jump position.
- A branching capture position with unequal capture counts.
- A crown-row capture position with a possible backward king continuation.
- A no-pieces terminal position.
- A blocked no-legal-move terminal position.
- A threefold repetition sequence.
- A quiet-king sequence of at least 80 plies.
- Daily Puzzles on three consecutive date keys.
- Match histories containing 49, 50, and 51 completed matches.
- Bundled cosmetic identifiers and one unsupported identifier.

---

# Automated Test Layers

## Unit Tests

Unit tests must cover:

- Rules state validation.
- Complete legal-turn generation.
- Turn application and immutability on rejection.
- Terminal results and draw precedence.
- Elo calculation and League-label derivation.
- Bot legal-turn selection at strength bounds.
- Player-local-date calculation.
- Pair date-key calculation.
- Replay ordering and retention selection.
- Cosmetic identifier validation and fallback.

## Property and Fuzz Tests

Generate valid positions and legal games to establish invariants:

- Applying a generated legal turn always produces a valid state or final state.
- A rejected turn never changes state.
- Piece counts never increase except that rank may change from man to king.
- Captures reduce the opponent's piece count by the number of captured squares.
- A complete legal capture turn never ends while the same piece has a required continuation, except on crowning.
- Serialization followed by deserialization preserves state identity.
- Replay from initial state and ordered turns reaches the recorded final state.
- The bot never chooses a turn outside the generated legal set.

Use fixed seeds in continuous integration and retain failing seeds.

## Backend Integration Tests

Run against security rules and callable or HTTP boundaries, not by invoking internal helpers alone.

Cover:

- Verified and unverified authorization.
- Friend and stranger reads.
- Forged identity and verification claims.
- Match move validation.
- Clock and result commitment.
- Rating transaction idempotency.
- Rated friend finalization concurrency.
- Replay authorization and retention.
- Puzzle date selection from stored time zone and trusted time.
- Match ready, presence heartbeat, reconnect, and deadline reconciliation operations.
- Bot state retrieval and idempotent completed-bot synchronization.
- Friends/request/invitation list reads and presence privacy.
- Feed, leaderboard, replay-list, replay-payload, profile-search, and match-state read authorization.
- Profile, privacy, notification, bundled board, and bundled piece-set updates.
- Block and unblock behavior, including the fact that unblock does not restore friendship.

## Client Integration Tests

Cover:

- Authentication gate presentation and refresh.
- Board selection, legal destinations, and mandatory continuation.
- Bot save and restore.
- Match reconnection.
- Friend request and invitation flows.
- Rated consent and exhausted-limit presentation.
- Puzzle midnight refresh.
- Replay navigation.
- Cosmetic selection and fallback.
- First-launch optional-data grant and decline before Authentication.
- Consent withdrawal, sign-out identity clearing, and rapid account switching.
- Exact Analytics event validation and Crashlytics/Performance allowlists.

## API Contract Cases

- `readyMatch`: first ready remains awaiting, second activates once, duplicate returns the same state, stale revision cannot activate twice.
- `heartbeatMatch` and `reconcileMatchState`: connected heartbeat refreshes match state; missing-heartbeat and deadline boundaries finalize once under deterministic command IDs.
- `heartbeatPresence`: visible friends receive a leased status; strangers, blocked users, and privacy-hidden friends receive no status; expiry never fabricates hidden presence.
- `listFriendsState`: each section paginates independently with stable cursors; stale relationship generations cannot mutate current rows.
- `updateProfile`, `updatePrivacy`, and `updateNotifications`: exact schemas accept owner changes, reject unknown fields, enforce verification where required, and immediately affect subsequent authorized reads.
- `getLeaderboard`: exact game/League/Tier ordering and cursor ties are stable; response exposes only allowlisted limited fields.
- `listFeed`: privacy tightening, friend removal, and block state are rechecked on every page; merged match rows occur once per viewer.
- `listReplays` and `getReplay`: latest-50 order is stable; participant grants succeed; friends and strangers fail; evicted grants fail immediately.
- `getMatchState`: read does not finalize; `reconcileMatchState` performs any due terminal mutation idempotently.

## End-to-End Tests

Run the highest-risk flows across two clients and the backend:

- Verified matchmaking game through rating update and replay.
- Rated friend games one through four.
- Friendship creation, friends-only reads, and removal revocation.
- A game interrupted by disconnect and app backgrounding.
- Daily Puzzle use across a local midnight.
- Match 51 causing deterministic replay eviction.

---

# Ruleset Verification

## Objective

Prove one implementation of `checkers-wcdf-gayp-v1.0.0` is used consistently and conforms to the complete rules contract.

## Automated Tests

Run every required rules test in `docs/Specs/Checkers Rules.md`.

Add cross-surface equivalence tests:

1. Load the same fixture into the client preview engine and server validator.
2. Compare the canonical complete legal-turn sets.
3. Load the fixture as a puzzle position and compare legal turns again.
4. Ask the bot for a turn and assert it belongs to that same set.
5. Serialize a selected turn into a replay and reconstruct the resulting state.
6. Assert every resulting state hash is identical.

## Acceptance Evidence

- Passing unit-test report for all conformance cases.
- Passing property-test report with seed count and retained failing-seed mechanism.
- A serialized sample match containing `rulesetId: checkers-wcdf-gayp-v1.0.0`.
- A replay reconstruction assertion matching authoritative final state and result.

---

# Authentication and Email Verification

## Test Cases

### AUTH-001 Unverified Local Access

1. Sign in as `unverified-a`.
2. Start and complete a bot game.
3. Open the current Daily Puzzle.
4. Open own settings and retained local replay.

Expected:

- Every listed action is available.
- No online or social authorization is implicitly granted.

### AUTH-002 Unverified Online Gate

1. Attempt to join matchmaking from the client.
2. Attempt the equivalent backend request directly.
3. Attempt to start or resume an online match.

Expected:

- Client explains verification is required.
- Backend rejects each operation.
- No queue or match record is created.

### AUTH-003 Unverified Social Gate

1. Search for a player.
2. Send and accept a friend request.
3. Read friend activity.
4. Send and accept a friend invitation.

Expected:

- Client blocks each action with verification guidance.
- Direct backend attempts are rejected.
- No social record changes.

### AUTH-004 Verification Refresh

1. Sign in unverified.
2. Complete provider email verification.
3. Refresh verification state without signing out.
4. Enter matchmaking and open Friends.

Expected:

- Gated capabilities become available after authoritative refresh.
- A stale client flag alone cannot enable them.

### AUTH-005 Provider-Verified Email

1. Sign in using a supported provider that supplies a verified email.
2. Read the authoritative account claim.
3. Enter an online capability.

Expected:

- The account satisfies the gate.
- Provider identity without a verified email does not satisfy it.

---

# Bot Verification

## Test Cases

### BOT-001 Single Adaptive Bot Presentation

1. Open bot play.
2. Inspect all bot configuration and profile surfaces.

Expected:

- One Crown Bot is available.
- No named alternatives or manual difficulty selector appears.

### BOT-002 Legal Move Reliability

1. Run the bot against generated valid positions at minimum and maximum adaptive strength.
2. Include mandatory captures, branches, multi-captures, and crowning.

Expected:

- Every returned turn is in the canonical complete legal-turn set.
- The bot reports no turn only in a terminal no-legal-move state.

### BOT-003 Adaptation Boundary

1. Seed repeated player losses, then repeated player wins.
2. Record selected internal strength parameters.

Expected:

- Parameters react in the intended direction within configured bounds.
- Rules, clocks, Elo, League, and rated statistics do not change.

### BOT-004 Offline Save and Resume

1. Disable network access.
2. Start a bot match and complete several turns.
3. Background and terminate the app.
4. Relaunch and resume.

Expected:

- The latest completed turn is restored exactly.
- The game can complete offline.
- Its result remains unrated.

### BOT-005 Side Alternation and Synchronization

1. Start the first bot game and confirm the player is Black.
2. Complete and synchronize it, then start another game on a second device.
3. Complete a bot match offline and upload the same legal lineage twice.

Expected:

- New bot games alternate the player's side per account.
- The second device receives the synchronized next-side and adaptive revision.
- Duplicate upload creates one match index, replay grant, Feed event, and eligible ad-counter increment.
- Bot synchronization never changes Elo or rated statistics.

4. Start different offline bot games on two devices from the same adaptive revision and synchronize both.

Expected:

- Both distinct legal completions are retained once even if they share a snapshotted side.
- Adaptive updates serialize in server commit order.
- Both devices converge on one canonical next side and adaptive revision.

---

# Online Match Verification

## Test Cases

### ONLINE-001 Match Creation

1. Queue two verified eligible players.
2. Wait for one match creation transaction.

Expected:

- One match is created.
- Players receive opposite logical sides.
- Match remains awaiting players with no running clock.
- Ruleset identifier is persisted.

3. Submit authenticated ready commands for both players.

Expected after both ready:

- Match becomes active.
- Black is active.
- Both clocks begin at 15:00 with no increment.

### ONLINE-002 Authoritative Validation

1. Submit a legal turn.
2. Submit an illegal step during mandatory capture.
3. Submit for the inactive side.
4. Replay a previously accepted move request.

Expected:

- Legal state advances once.
- Every invalid or duplicate request leaves state unchanged.
- Client display reconciles to authoritative state.

### ONLINE-003 Clock and Reconnection

1. Begin a player's turn.
2. Disconnect and background that player's client.
3. Advance trusted server time.
4. Reconnect.

Expected:

- The clock did not pause.
- Position, active side, and remaining time synchronize.
- If time reached zero, the persisted result is timeout.

### ONLINE-004 Idempotent Completion

1. Complete a rated game.
2. Deliver the completion event concurrently and repeatedly.

Expected:

- One final result exists.
- Each rating changes exactly once.
- Rated aggregates change exactly once.
- One replay record per participant is available.

---

# Friends and Privacy Verification

## Test Cases

### SOCIAL-001 Friendship Lifecycle

1. Send a request between two verified players.
2. Confirm no friends-only access while pending.
3. Accept the request.
4. Confirm reciprocal friendship.
5. Remove the friendship from one account.

Expected:

- State transitions are consistent for both players.
- Friends-only access starts only after acceptance.
- Removal revokes access for both players.

### SOCIAL-002 Stranger Access Denial

1. As `stranger`, guess or obtain `verified-a`'s identifier.
2. Request profile, statistics, activity, presence, friend list, and replay endpoints.

Expected:

- Every protected read is denied or returns no protected data.
- Exact-identity lookup returns only the permitted minimal identity fields.

### SOCIAL-003 Friend Access

1. As `friend`, request the allowed profile and activity for `verified-a`.
2. Request fields outside the MVP friend view.

Expected:

- Allowed friends-only data is returned.
- Private account or authentication fields remain absent.

### SOCIAL-004 Matchmaking Disclosure

1. Match two verified non-friends.
2. Inspect both match payloads.
3. Attempt to follow the opponent identity to full profile or activity.

Expected:

- Match identity, rating, League, side, clock, and result are available.
- Full profile, activity, friend list, and replay history remain inaccessible.

### SOCIAL-005 Revocation During Session

1. Open a friend's profile and feed on one device.
2. Remove the friendship on another device.
3. Refresh and invoke direct APIs from the first device.

Expected:

- Subsequent reads are denied without requiring sign-out.
- Cached UI is removed or marked unavailable.

---

# Rated Friend Pair Limit Verification

## Test Cases

### FRIEND-RATED-001 First Three Games

1. Set both players to the same stable local date.
2. Create and complete three mutually consented rated friend games.

Expected:

- Each match stores both players' time zones and date keys.
- Each match is rated.
- Each committed result updates Elo once.
- Pair usage is three for both applicable date keys.

### FRIEND-RATED-002 Fourth Game

1. After the first three, request another rated friend game in either invitation direction.
2. Accept rated consent from both players.

Expected:

- Match creation and play remain rated.
- Finalization records that the pair's daily Elo limit is reached.
- Rated aggregate statistics update.
- Elo remains unchanged for both players and neither ledger consumes a fourth slot.

### FRIEND-RATED-003 Concurrent Finalization

1. Preload pair usage to two.
2. Finalize two rated friend results concurrently.

Expected:

- Exactly one finalization consumes the third slot and applies Elo.
- The other result remains rated, updates rated aggregate statistics, and records zero Elo change.
- Pair usage never exceeds three for either date key.

### FRIEND-RATED-004 Different Local Dates

1. Use `Pacific/Kiritimati` and `Pacific/Honolulu` around the International Date Line.
2. Set trusted time so the players have different local dates.
3. Preload one player's pair count to three for that player's date and the other's to zero.
4. Finalize a rated match.

Expected:

- Elo is not applied because both local-date checks must pass.
- Stored or diagnostic date calculations use each account's IANA time zone.

### FRIEND-RATED-005 Date Rollover

1. Exhaust the limit for one player's current local date.
2. Advance trusted time past that player's midnight but not the other player's midnight.
3. Keep the other player's applicable count below three.
4. Finalize a rated match.

Expected:

- The rolled-over player uses a fresh date key.
- Elo applies only if the other player's current date key also has capacity.

### FRIEND-RATED-006 Clock and Time-Zone Tampering

1. Exhaust a pair limit.
2. Change device clock and device time zone.
3. Finalize another rated result without changing the account time zone through the authorized setting path.

Expected:

- Eligibility does not change.
- Trusted server time and stored account time zone control the result.

### FRIEND-RATED-007 Result Lifecycle

1. Create and decline an invitation.
2. Create an accepted match that starts and ends by resignation.
3. Create an accepted match that is server-voided before start.

Expected:

- Declined invitation consumes no slot.
- The finalized resignation result consumes one slot.
- The never-started server-voided match consumes no slot.

---

# Daily Puzzle Verification

## Test Cases

### PUZZLE-001 Player-Local Date

1. At one trusted instant, request Daily Puzzle as `verified-c` in `Pacific/Kiritimati` and `verified-d` in `Pacific/Honolulu`.

Expected:

- Each account receives the puzzle matching its own local date.
- Device locale and clock do not select the date.

### PUZZLE-002 Same-Day Resume

1. Open a puzzle and make partial progress.
2. Close and reopen before local midnight.

Expected:

- The same date-keyed puzzle and attempt return.
- Official timing and incorrect-move data remain coherent.

### PUZZLE-003 Midnight Boundary

1. Open a puzzle immediately before local midnight using a fake trusted clock.
2. Advance past midnight.
3. Finish the already open puzzle.
4. Return home and open Daily Puzzle again.

Expected:

- The open attempt records against its original date key.
- The new open loads the new local-date puzzle.
- Date-key completions do not overwrite each other.

### PUZZLE-004 Device Clock Tampering

1. Request today's puzzle.
2. Move the device clock forward and backward by one day.
3. Request again while trusted time remains fixed.

Expected:

- The selected puzzle date does not change.

### PUZZLE-005 No Rewards

1. Snapshot Elo, League, rated statistics, cosmetic settings, inventory-like records, and any currency-like fields.
2. Complete the puzzle, replay it, and complete the solution again.

Expected:

- One official completion exists.
- Official solve data is not replaced by replay data.
- No competitive, inventory, currency, or reward state changes.

### PUZZLE-006 Authored Legality

1. Validate every published puzzle position and solution with the canonical rules engine.
2. Apply every authored opponent response.

Expected:

- Every position is valid.
- Every solution turn and response is legal.
- The complete sequence satisfies the authored objective.

---

# Replay Verification

## Test Cases

### REPLAY-001 Unlimited Views

1. Create a retained replay.
2. Open it repeatedly beyond any previously considered product limit.

Expected:

- Every open succeeds while authorization and retention remain valid.
- No view counter, payment, advertisement gate, cooldown, or lockout appears.
- Viewing does not alter recency.

### REPLAY-002 Latest 50

1. Give a player exactly 50 completed matches with distinct completion timestamps.
2. Assert all 50 are available newest first.
3. Complete a 51st match.

Expected:

- Exactly 50 remain in the accessible recent set.
- The oldest by completion timestamp is no longer available through recent replay access.
- The new match is first.

### REPLAY-003 Deterministic Tie-Breaker

1. Create multiple completed matches with the same authoritative completion timestamp.
2. Query the retained set repeatedly.

Expected:

- Match identifier provides stable tie ordering.
- Retention does not fluctuate between requests.

### REPLAY-004 Per-Player Retention

1. Complete a match between A and B.
2. Give A 50 newer matches and B fewer than 50 newer matches.

Expected:

- The shared match leaves A's retained set.
- It remains in B's retained set.

### REPLAY-005 Reconstruction

1. For every retained fixture, start from stored initial state.
2. Apply ordered turns using the stored ruleset implementation.
3. Exercise step forward, step backward, start, and end controls.

Expected:

- Every state is deterministic.
- End reaches the recorded final position and result.
- Backward navigation displays the exact prior reconstructed state.

### REPLAY-006 Authorization

1. Fetch a replay as its participant.
2. Fetch it as an accepted friend who can see an authorized match summary.
3. Fetch it as a stranger.
4. Remove the friendship and fetch again.

Expected:

- Participant access succeeds.
- Accepted-friend and stranger replay access are denied.
- Removed-friend access is denied immediately.
- A stale feed link cannot bypass the check.

---

# Cosmetics Verification

## Test Cases

### COSMETIC-001 Bundled Availability

1. Sign in with a new account.
2. Open cosmetic selection.

Expected:

- Every supported bundled board and piece set is selectable immediately.
- No ownership, reward, membership, purchase, rarity, season, or price state appears.

### COSMETIC-002 Persistence

1. Select a non-default bundled board and piece set.
2. Restart the app and sign in on another supported device.

Expected:

- The active supported identifiers persist where account sync is available.
- Offline play uses the last locally known supported selection.

### COSMETIC-003 Unsupported Identifier

1. Inject an unknown or removed cosmetic identifier.
2. Open gameplay and selection.

Expected:

- The app uses the default bundled cosmetic.
- Gameplay remains available.
- No entitlement is granted.

### COSMETIC-004 Rules Independence

1. Load the same position under every valid board and piece combination.
2. Compare canonical legal-turn sets and bot behavior seed.

Expected:

- Legal-turn sets are identical.
- Logical sides and kings remain distinguishable.
- Cosmetic choice does not alter strength, clock, rating, or result.

### COSMETIC-005 Accessibility

1. Inspect every valid combination in normal and high-contrast settings.
2. Enable screen reader and inspect piece labels.

Expected:

- Pieces remain distinguishable from squares and each other.
- Kings have a non-color-only distinction.
- Labels identify logical side, rank, and coordinate.

---

# No Seasons or Rewards Verification

## Automated Checks

- Search active route and feature configuration for season, reward claim, currency, chest, unlock track, and shop entry points.
- Assert match, puzzle, League-change, and friend-match completion functions cannot create reward or inventory grant records.
- Assert League labels derive only from current Elo.
- Assert no scheduled season reset or rollover job is enabled in the MVP environment.

## Manual Checks

Inspect:

- Home.
- League.
- Feed.
- Profile.
- Match result.
- Puzzle completion.
- Notifications.
- Settings.

Expected:

- No season countdown, reward amount, claim action, currency balance, earned cosmetic, shop, purchase, or membership is presented.
- League-label changes are informational and do not grant anything.

---

# Advertising Verification

## Automated Checks

- Finalize two eligible Checkers results and assert no ad is due.
- Finalize the third eligible result and assert exactly one ad is due.
- Retry all three finalizations and assert counters do not change twice.
- Finalize bot, rated matchmaking, Elo-applying rated friend, capped rated friend, unrated friend, cancelled, and void cases and assert only the documented eligible cases increment.
- Record both shown and unavailable outcomes and assert the due state clears without deferred accumulation.

## Manual Checks

- Confirm an interstitial is requested only after the committed result is visible.
- Confirm ads never interrupt active play, readiness, matchmaking, or reconnection.
- Confirm an unavailable ad does not delay replay or navigation.

---

# Accessibility and UX Verification

## Board Interaction

- Legal destinations are not communicated by color alone.
- Mandatory capture and continued capture are announced.
- Logical side and king rank remain available to assistive technology independent of cosmetics.
- Touch targets meet platform minimums.
- Board orientation does not change canonical coordinates or move legality.

## Dynamic Content

- Clock changes do not overwhelm screen reader output.
- Turn, reconnecting, result, and verification-gate states are announced once at useful transitions.
- Large text does not hide required controls or force the board below a usable size.
- Reduced motion removes nonessential movement without removing state feedback.

## Error Recovery

- Rejected online moves restore authoritative state and explain that the match changed.
- Offline or backend errors provide retry or safe return actions.
- Verification, friendship, replay-retention, and rated-limit errors state the actual eligibility issue.

---

# Firebase Environment Verification

## ENV-001 Project and Application Isolation

1. Inventory both Firebase projects and all registered applications.
2. Build development and production flavors for iOS and Android.
3. Inspect compiled identifiers and initialized Firebase options.

Expected:

- Development uses `crown-chess-and-checkers-dev` and `dev.wxlfe.crown.dev`.
- Production uses `crown-chess-and-checkers` and `dev.wxlfe.crown`.
- Each project has one iOS app, one Android app, and no web app.
- Crossed flavor/configuration fixtures fail closed before network or telemetry activity.

## ENV-002 Locations and Services

Expected inventory:

- Both `(default)` Firestore databases are Standard edition, Native mode in `nam5`.
- Every Cloud Function and Cloud Tasks queue is explicitly in `us-central1`.
- Development and production Auth, FCM, Remote Config, Analytics, Crashlytics, Performance, App Check, AdMob, secrets, and deployment identities are isolated.
- No Firebase Hosting target, Vercel project, web Analytics stream, or BigQuery link exists.

## ENV-003 Deployment Identity

Attempt GitHub OIDC exchange from the canonical `wxlfe/crown` repository environments, then from a fork, pull request, wrong environment, and wrong repository claim.

Expected:

- Approved development and production environment jobs receive only their project-scoped short-lived credentials.
- Every untrusted or cross-environment exchange fails.
- No long-lived service-account JSON key is used.

---

# Optional Data and Telemetry Verification

## CONSENT-001 Clean Install and Decline

1. Install with clean app storage and capture device traffic.
2. Leave the Privacy Consent screen open, open and return from the Privacy Policy, then choose Continue without optional data.
3. Authenticate and exercise each core feature.

Expected:

- No GA4, Crashlytics, Performance, or optional advertising-storage payload is sent before the choice or after denial.
- Authentication is not reachable before an explicit choice.
- Every gameplay and account feature remains available after denial.
- No denied-period activity appears after a later grant.

## CONSENT-002 Grant and Withdrawal

1. Grant optional data on first launch and authenticate.
2. Verify future allowlisted events, traces, and diagnostics only.
3. Withdraw from Settings during normal use and during an active trace.
4. Restart the app.

Expected:

- GA4 User-ID is the current opaque Firebase UID only in the dedicated User-ID field.
- Withdrawal stops producers, denies all controlled consent categories, clears User-ID and properties, resets local Analytics state, and persists denied state.
- Active trace context and Crown-owned pending telemetry are discarded.
- Already transmitted data is not represented as deleted by this control.

## CONSENT-003 Device Scope and Account Switching

Expected:

- The choice does not synchronize to a second installation.
- Sign-out clears User-ID and properties before Firebase credentials and account UI are released, without changing the device consent choice.
- Account A events, once-state, properties, and diagnostic context never appear under account B during rapid switching.
- Crashlytics User-ID remains unset in all flows.

## ANALYTICS-001 Schema and Routing

Run every fixture in `docs/Specs/Analytics Event Catalog.md` through the production schema validator and inspect Firebase DebugView in the development property.

Expected:

- Exactly the 20 catalog events are accepted with exact parameter sets, types, enums, and ranges.
- Invalid, unknown, null, reserved-prefix, PII-shaped, UID-shaped, domain-ID-shaped, and high-cardinality values are dropped.
- Automatic events are not manually duplicated.
- `select_content` uses prescribed `content_type` and `item_id` parameters.
- Development events appear only in Crown Development; production validation does not pollute that property.
- Neither property has a key event or BigQuery export configured.

## ANALYTICS-002 Trigger Idempotency

Expected:

- `sign_up` occurs once on first successful profile completion, not private account creation or retry.
- `login` occurs once for a successful authentication session of an existing completed profile.
- Listener reattachment, transaction retry, duplicate snapshot, process restart, outbox retry, and second-device observation do not violate catalog once rules.
- Backend outboxes never send GA4 events or backfill activity first observed while denied.

## DIAGNOSTICS-001 Crashlytics and Performance

Expected:

- Consent-denied crashes and traces are not submitted.
- Consented test crashes are symbolicated from the exact development artifact.
- Crash keys, breadcrumbs, nonfatal messages, trace names, and attributes match the allowlists.
- Fuzzed emails, handles, UIDs, UUIDs, Firestore paths, domain IDs, tokens, dynamic URLs, and backend payloads are redacted or rejected.
- Every custom trace closes on success, cancellation, timeout, failure, and consent withdrawal.

---

# Performance and Reliability Verification

Measure on representative supported devices:

- Cold start to usable authentication state.
- Board render and interaction latency.
- Legal-turn generation latency on branching capture positions.
- Bot response latency at configured maximum strength.
- Match update and reconnection latency under normal and degraded networks.
- Replay load and step latency for long games.

Reliability tests must include:

- Duplicate requests.
- Out-of-order realtime events.
- App termination during a bot turn.
- App termination during an online move confirmation.
- Temporary backend unavailability.
- Match completion transaction retry.
- Concurrent friendship removal and protected read.
- Concurrent rated friend acceptances.

Pass thresholds should be recorded in the implementation repository or release test run before MVP sign-off. Any threshold not yet selected is an open release criterion, not an automatic pass.

---

# Security Verification

Test from an untrusted client with modified payloads:

- Forge `emailVerified` in a request body.
- Read another player's private profile and activity.
- Enumerate friend lists.
- Create friendship without acceptance.
- Mark a friend invitation rated after creation.
- Forge ledger capacity or a nonzero Elo delta for a capped fourth rated friend result.
- Change stored local date keys supplied by the client.
- Submit a move for another player.
- Submit an illegal or stale move.
- Modify clocks, result, rating, League label, replay retention, or cosmetic support list.
- Fetch an evicted or unauthorized replay.

Expected:

- Server-derived identity, claims, trusted time, stored time zone, rules state, and transactions override or reject client assertions.
- No denied request partially mutates protected state.
- Security-sensitive denials are logged without exposing credentials or unnecessary personal data.

---

# Deferred Scope Verification

The MVP build must not expose active entry points for:

- Seasons.
- Rewards.
- Currency.
- Purchases or subscriptions.
- Cosmetic shops or unlocks.
- Multiple bots or difficulty selection.
- Broadly public profiles or global public activity.
- Chat or spectating.
- Puzzle hints or archive.
- AI coaching or analysis.
- Tournaments, clubs, or teams.

Launch operations and legal are verified only as explicit deferrals:

- MVP evidence states that production store launch is not approved.
- Open production blockers include final legal review, privacy and terms publication, account lifecycle obligations, moderation operations, and store submission requirements.
- No test report describes those obligations as complete unless separately reviewed and accepted.

---

# Continuous Integration Gates

Every change to rules, matches, ratings, friends, puzzles, replays, or cosmetics must run:

- Static analysis and formatting checks.
- Unit tests.
- Checkers conformance tests.
- Relevant backend integration tests.
- Serialization and replay compatibility tests.

Every change to Firebase initialization, authentication lifecycle, consent, Analytics, Crashlytics, Performance Monitoring, AdMob consent, or environment selection must run:

- Clean-install default-denied tests.
- Consent grant, decline, withdrawal, restart, and account-switch tests.
- Analytics schema and prohibited-data tests.
- Development/production build-identity assertions.
- Crashlytics and Performance allowlist tests.

Changes to rules behavior require:

- A new ruleset identifier when persisted game interpretation changes.
- Migration or continued availability of the old replay implementation.
- New conformance fixtures.
- Explicit product approval.

Nightly or pre-release runs should add:

- Property tests with an expanded seed count.
- Two-client end-to-end flows.
- Security-rule denial suite.
- Time-zone and midnight suite.
- Rated friend concurrency suite.
- Device accessibility smoke tests.

---

# Evidence and Traceability

For each acceptance criterion, record:

- Requirement or test identifier.
- Build and backend version.
- Device or emulator configuration.
- Test data and trusted timestamp where relevant.
- Automated report or manual evidence link.
- Pass, fail, or blocked status.
- Defect identifier for failures.
- Reviewer and review date for manual tests.

Required release evidence includes:

- Checkers conformance report.
- Backend authorization and privacy report.
- Rated friend limit concurrency report.
- Daily Puzzle time-zone report.
- Replay latest-50 report.
- iOS and Android end-to-end smoke reports.
- Accessibility checklist.
- Firebase environment inventory and build-identity report.
- Optional-data consent and network-inspection report.
- Analytics event-schema and routing report.
- Crashlytics redaction/symbolication and Performance trace report.
- Deferred-scope inspection checklist.
- Known defects and accepted-risk list.

---

# MVP Exit Checklist

The engineering MVP passes verification only when:

- All required automated suites pass on the release candidate.
- Every included scope acceptance criterion has evidence.
- No open critical or high-severity defect affects game correctness, authorization, privacy, rating integrity, date eligibility, replay integrity, or data loss.
- The single adaptive bot is legal, bounded, offline-capable, and unrated.
- Email verification is enforced at client and backend boundaries for online and social use.
- Friends-only privacy survives direct API and revocation tests.
- The first three Elo-applying rated friend results per pair and each player's local date are enforced atomically.
- Daily Puzzle selection follows trusted time and the player's stored IANA time zone.
- Exactly the latest 50 completed non-void match replays are available per player with unlimited views.
- Cosmetics are bundled selection only and remain rules-neutral.
- Development and production Firebase resources and GA4 properties are isolated and use the canonical identifiers and regions.
- Optional data defaults denied, never gates gameplay, never backfills denied-period activity, and clears identity on withdrawal, sign-out, and account switching.
- Analytics, Crashlytics, and Performance payloads conform to exact allowlists and contain no prohibited identity or domain-record data.
- Seasons, rewards, purchases, memberships, public social access, and other deferred features are absent.
- Production launch remains blocked on separately tracked operations and legal acceptance.

Any failed item keeps the MVP in a not-verified state until fixed and rerun or explicitly removed from MVP scope through a reviewed specification change.
