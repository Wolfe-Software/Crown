# Analytics Event Catalog

## Purpose

This document is the exact GA4 event contract for Crown. `docs/Specs/Analytics Measurement Plan.md` governs consent, identity, environments, collection products, privacy, and registration. No event or parameter outside this catalog may ship.

All events require the device optional-data toggle to be granted at the instant of the trigger. There is no pre-consent buffering or later backfill. Analytics never gates the product action.

## Contract Conventions

### Primitive types

| Type | GA value | Contract |
| --- | --- | --- |
| `string` | String | Exact lowercase ASCII enum unless a constant below says otherwise |
| `int` | Integer | Signed whole number; durations are non-negative milliseconds |
| `bool` | Integer | `1` for true and `0` for false; never send native boolean or string values |

Every listed parameter is required and non-null for the event row that lists it. A parameter not listed for that event is forbidden. Unknown, null, empty, mistyped, out-of-range, or non-enum values cause the event to be dropped, not coerced. GA automatically supplied parameters are outside Crown's event payload and are not repeated here.

Every event row includes `analytics_schema_version=1`. Parameter sets below name only Crown-supplied event parameters.

### Authority

- `Client`: the committed action and event trigger are local to the current client.
- `Server-confirmed`: the backend owns the state transition. The client emits only after receiving or observing the authoritative transition while consent is currently granted.
- `Hybrid-confirmed`: online and synchronized bot state are server-confirmed; a fully offline bot transition is owned by the UID-scoped local rules engine and later synchronization must not emit it again.

No backend service sends GA events directly. Server records may hold product idempotency facts but do not buffer analytics for a device.

### Once and idempotency

- `Per action`: once after one committed user action. Disabled controls, validation failures, repeated taps while pending, and failed requests emit nothing.
- `Per transition`: once when an entity crosses the named state boundary. Repeated responses or snapshots of the same state emit nothing.
- `Per account`: once for the authoritative account milestone. A server marker owns uniqueness; a device may emit only when it observes the marker's creation while granted.
- Local deduplication keys are UID-scoped and contain domain IDs only inside protected product storage. They are never event parameters, user properties, Crashlytics values, or Performance attributes.
- Withdrawal and sign-out clear local analytics delivery state. Clearing that state does not authorize replay: an old transition does not become a new trigger when consent is restored or the account signs in again.

## Parameter Dictionary

### Context parameters

| Parameter | Type | Allowed values / range | Meaning |
| --- | --- | --- | --- |
| `analytics_schema_version` | int | `1` | Event contract version |
| `game_id` | string | `checkers` | Product-defined game enum, not a record ID |
| `mode` | string | `matchmaking`, `friend`, `bot` | Match mode |
| `rated` | bool | `0`, `1` | Whether the match is rated |
| `ruleset_id` | string | `checkers-wcdf-gayp-v1.0.0` | Product-defined immutable rules enum |
| `source_screen` | string | `authentication`, `home`, `matchmaking`, `match`, `friends`, `profile`, `league`, `daily_puzzle`, `replay`, `appearance`, `settings` | Screen on which the triggering user action occurred or confirmed transition was presented |

`mode`, `rated`, and `ruleset_id` use immutable values snapshotted by the match. Matchmaking is always rated, bot is always unrated, and friend may be rated or unrated.

### Authentication and content parameters

| Parameter | Type | Allowed values | Meaning |
| --- | --- | --- | --- |
| `method` | string | `apple`, `google`, `password` | GA recommended authentication method parameter |
| `auth_method` | string | `apple`, `google`, `password` | Method on the custom `email_verified` event |
| `level_name` | string | `daily_puzzle` | GA recommended level name constant |
| `success` | bool | `1` | GA recommended level success; Daily Puzzle completion emits only on success |
| `content_type` | string | `play_mode`, `social`, `progression` | Closed content grouping |
| `item_id` | string | `matchmaking`, `friend_match`, `bot_match`, `daily_puzzle`, `friends`, `league` | GA recommended selected-item parameter; closed navigation target, not a domain-record ID |
| `appearance_type` | string | `board`, `piece_set` | Changed appearance category; selected item ID is prohibited |
| `reset_reason` | string | `player_day_changed`, `timezone_effective`, `publication_replaced` | Authoritative reason the displayed Daily Puzzle assignment reset |

Allowed `select_content` pairs are exact:

| `content_type` | Allowed `item_id` |
| --- | --- |
| `play_mode` | `matchmaking`, `friend_match`, `bot_match`, `daily_puzzle` |
| `social` | `friends` |
| `progression` | `league` |

### Matchmaking and result parameters

| Parameter | Type | Allowed values / range | Meaning |
| --- | --- | --- | --- |
| `cancel_reason` | string | `player_cancelled`, `screen_closed`, `app_backgrounded` | Client intent that produced a confirmed queue cancellation |
| `matchmaking_duration_ms` | int | `0..3600000` | Server-time difference from confirmed `waiting.joinedAt` to confirmed terminal state |
| `result` | string | `win`, `loss`, `draw`, `void` | Result from the current player's perspective |
| `result_reason` | string | `no_pieces`, `no_legal_move`, `resignation`, `timeout`, `disconnect`, `no_show`, `both_no_show`, `draw_repetition`, `draw_quiet_kings`, `administrative_void` | Authoritative terminal reason |
| `match_duration_ms` | int | `0..86400000` | `endedAt-startedAt`; for local bot, elapsed active play time, excluding restored idle time |
| `elo_before` | int | `0..100000` | Current player's authoritative pre-match Elo |
| `elo_after` | int | `0..100000` | Current player's authoritative post-match Elo |
| `elo_delta` | int | `-100000..100000` | `elo_after-elo_before` |
| `league_before` | string | `bronze`, `silver`, `gold`, `platinum`, `diamond` | Server-derived League before completion |
| `league_after` | string | `bronze`, `silver`, `gold`, `platinum`, `diamond` | Server-derived League after completion |
| `tier_before` | string | `iii`, `ii`, `i`, `diamond` | Server-derived Tier before completion |
| `tier_after` | string | `iii`, `ii`, `i`, `diamond` | Server-derived Tier after completion |
| `reconnect_count` | int | `0..100` | Number of confirmed disconnected-to-connected transitions during this match on this client |
| `reconnect_duration_ms` | int | `0..900000` | Server-time difference from confirmed disconnect start to confirmed reconnection |

For `match_complete`, `result` is derived from the current player and never from opponent identity. `elo_before`, `elo_after`, `elo_delta`, League, and Tier fields are present for every mode: unrated and void matches repeat the current authoritative pre-value as the post-value and use `elo_delta=0`. A no-show before activation uses `match_duration_ms=0`. Cancelled matches emit no `match_complete`.

## Recommended Events

The following rows use Google's recommended event names and parameter names exactly.

| Event | Exact trigger | Owner | Once / idempotency | Exact parameters |
| --- | --- | --- | --- | --- |
| `sign_up` | `completeProfileSetup` atomically creates the public profile and one-time profile-completed marker; emit only from the response or live state transition that confirms first completion | Server-confirmed | Per account; server profile-completed marker; retries and another device cannot create another marker | `analytics_schema_version`, `method` |
| `login` | A provider authentication succeeds for an account whose profile was already completed and `ensureAccount` confirms the account is usable | Server-confirmed | Per successful authentication session; repeated auth callbacks and `ensureAccount` retries share one in-memory auth-attempt key | `analytics_schema_version`, `method` |
| `level_start` | The server creates or returns the current Daily Puzzle attempt with `startedAt` changing from null to server time after the player's first accepted puzzle interaction | Server-confirmed | Per assignment start transition; duplicate commands and snapshots do not emit | `analytics_schema_version`, `game_id`, `ruleset_id`, `source_screen`, `level_name` |
| `level_end` | The server accepts the Daily Puzzle solution and changes the attempt from `in_progress` to `completed` | Server-confirmed | Per assignment completion transition; completion retries and Feed/outbox retries do not emit | `analytics_schema_version`, `game_id`, `ruleset_id`, `source_screen`, `level_name`, `success` |
| `select_content` | The player activates an enabled allowlisted Home or Profile destination and navigation commits to that destination | Client | Per action; one event after committed navigation, no event for screen restoration, deep-link restoration, or failed navigation | `analytics_schema_version`, `source_screen`, `content_type`, `item_id` |

For `sign_up` and `login`, `method` is the credential used for that authentication operation. Linking or unlinking a provider emits neither event.

For `level_start` and `level_end`, `level_name` is always `daily_puzzle`; `level_end.success` is always `1`. Failed moves, abandoned attempts, withdrawn invalid attempts, and reset attempts do not emit `level_end`.

## Custom Events

| Event | Exact trigger | Owner | Once / idempotency | Exact parameters |
| --- | --- | --- | --- | --- |
| `email_verified` | After token refresh, the authoritative Firebase claim changes from `email_verified=false` to `true` and the backend atomically creates the account's verification milestone | Server-confirmed | Per account; server verification milestone; provider accounts already verified at account creation do not emit | `analytics_schema_version`, `auth_method` |
| `matchmaking_join` | `join` commits a new queue generation in `waiting`; returning an existing waiting or terminal generation does not emit | Server-confirmed | Per queue generation waiting transition; join retries do not emit | `analytics_schema_version`, `game_id`, `mode`, `rated`, `ruleset_id`, `source_screen` |
| `matchmaking_cancel` | `cancel` changes the current queue generation from `waiting` to `cancelled`; matched, expired, stale, failed, and already-cancelled responses do not emit | Server-confirmed | Per queue generation cancelled transition; command retries do not emit | `analytics_schema_version`, `game_id`, `mode`, `rated`, `ruleset_id`, `source_screen`, `cancel_reason`, `matchmaking_duration_ms` |
| `matchmaking_matched` | Atomic pairing changes the current queue generation from `waiting` to `matched` and creates its match | Server-confirmed | Per queue generation matched transition; queue snapshots and outbox retries do not emit | `analytics_schema_version`, `game_id`, `mode`, `rated`, `ruleset_id`, `source_screen`, `matchmaking_duration_ms` |
| `match_start` | Online match changes from `awaiting_players` to `active`; bot match commits its initial board and first player/bot turn begins | Hybrid-confirmed | Per match active/start transition; retries, restoration, and second-device observation do not emit again on one device | `analytics_schema_version`, `game_id`, `mode`, `rated`, `ruleset_id`, `source_screen` |
| `match_complete` | Online match first becomes authoritative `completed`; bot rules engine commits a legal terminal non-cancelled result, with later server synchronization treated as the same transition | Hybrid-confirmed | Per match completion transition; finalization, sync, listener, and outbox retries do not emit | `analytics_schema_version`, `game_id`, `mode`, `rated`, `ruleset_id`, `source_screen`, `result`, `result_reason`, `match_duration_ms`, `elo_before`, `elo_after`, `elo_delta`, `league_before`, `league_after`, `tier_before`, `tier_after`, `reconnect_count` |
| `first_match_complete` | The first non-void completed match of any mode causes the backend to create the account's first-match milestone; an offline bot may emit only after synchronization confirms it won that milestone | Server-confirmed | Per account; atomic server milestone; competing completions and devices produce one milestone | `analytics_schema_version`, `game_id`, `mode`, `rated`, `ruleset_id`, `source_screen` |
| `match_reconnect` | An active online match confirms this client changed from disconnected to connected before its disconnect deadline and play remains active | Server-confirmed | Per confirmed reconnect transition; heartbeats while connected and duplicate responses do not emit | `analytics_schema_version`, `game_id`, `mode`, `rated`, `ruleset_id`, `source_screen`, `reconnect_duration_ms`, `reconnect_count` |
| `friend_request_sent` | The server creates a new pending friend request after all verification, privacy, and block checks; existing, reciprocal-auto-accept, rejected, and retried requests do not emit sent | Server-confirmed | Per newly created request transition; request command idempotency prevents duplicate emit | `analytics_schema_version`, `source_screen` |
| `friend_request_accepted` | The server changes a pending request addressed to the current player into an accepted friendship | Server-confirmed | Per friendship acceptance transition; accept retries and duplicate snapshots do not emit | `analytics_schema_version`, `source_screen` |
| `match_invitation_sent` | The server creates a new pending friend-match invitation after eligibility checks | Server-confirmed | Per newly created invitation transition; command retries do not emit | `analytics_schema_version`, `game_id`, `mode`, `rated`, `ruleset_id`, `source_screen` |
| `match_invitation_accepted` | The server changes a pending invitation addressed to the current player to accepted and durably creates or references its friend match | Server-confirmed | Per invitation accepted transition; accept and match-creation retries do not emit | `analytics_schema_version`, `game_id`, `mode`, `rated`, `ruleset_id`, `source_screen` |
| `replay_open` | An authorized replay payload finishes loading and the Replay screen renders its first usable frame | Client | Per successful open action; rebuilds, frame changes, retries before first render, and unauthorized/not-found loads do not emit | `analytics_schema_version`, `game_id`, `mode`, `rated`, `ruleset_id`, `source_screen` |
| `appearance_changed` | A board or piece-set update commits and the selected bundled appearance is applied; selecting the current item or a failed update does not emit | Client | Per committed change action; server retry/acknowledgement of the same local change does not emit again | `analytics_schema_version`, `source_screen`, `appearance_type` |
| `daily_puzzle_reset` | While Daily Puzzle is displayed, the server replaces the prior assignment with a different authoritative current assignment because the player day changed, a pending timezone became effective, or a publication replacement was assigned | Server-confirmed | Per assignment replacement transition; refresh and listener retries do not emit; initial assignment load does not emit | `analytics_schema_version`, `game_id`, `ruleset_id`, `source_screen`, `reset_reason` |

## Event-Specific Rules

### Matchmaking

All matchmaking events use `mode=matchmaking`, `rated=1`, and `ruleset_id=checkers-wcdf-gayp-v1.0.0`. `matchmaking_duration_ms` uses authoritative server timestamps and is clamped only by dropping an event outside the documented range, never by changing the value. Queue expiry emits no catalog event.

`cancel_reason` reflects the action that requested and won cancellation:

- `player_cancelled`: explicit Cancel control.
- `screen_closed`: explicit navigation that invokes cancellation.
- `app_backgrounded`: lifecycle policy invokes cancellation because the lease cannot be maintained.

If pairing wins the race, emit `matchmaking_matched`, not `matchmaking_cancel`, regardless of the player's attempted cancellation.

### Match Results

Map authoritative match state to the current player's `result`:

| Authoritative result | Current player value |
| --- | --- |
| Current player's side won | `win` |
| Other side won | `loss` |
| `draw` | `draw` |
| `void` | `void` |

`result_reason` is copied only from the closed authoritative enum. Bot terminal states can use `no_pieces`, `no_legal_move`, `resignation`, `draw_repetition`, or `draw_quiet_kings`; unsupported bot reasons cause the event to be dropped.

`reconnect_count` is zero for bot matches and matches with no confirmed reconnect on this client. It increments after each emitted `match_reconnect`, is bounded at 100, and is snapshotted into `match_complete`. The count describes reconnect behavior, not a player or match identifier.

### Ratings, League, and Tier

For a rated completion, the server-confirmed rating audit supplies Elo before and after. For an unrated or void completion, the current authoritative Elo and derived League/Tier are used for both before and after, with zero delta. The client never calculates League or Tier from stale cached labels for analytics.

When a rated completion changes current values, set the `checkers_league` and `checkers_tier` user properties after emitting `match_complete` with both before and after fields. This ordering preserves the event's pre/post interpretation.

### Social Events

Social events describe only the current player's action or accepted incoming transition. They carry no friend count, opponent attributes, relationship source, handle, UID, request ID, invitation ID, match ID, or other correlating value.

### Replay and Appearance

`replay_open` uses the replay's immutable match context but never its replay or match ID. `source_screen` is the screen from which replay loading was initiated, and cannot be `replay` for the initial open.

`appearance_changed` identifies only `board` or `piece_set`. Board IDs, piece-set IDs, names, rarity, ownership, and prices are forbidden.

### Daily Puzzle Reset

Exactly one reset reason applies:

- `player_day_changed`: the previous assignment interval ended and the next player-day assignment became current without a timezone-effective boundary.
- `timezone_effective`: a pending timezone became effective at this assignment boundary.
- `publication_replaced`: the server assigned an approved replacement publication under the Daily Puzzle correction/withdrawal policy.

The event carries no date, timezone, puzzle ID, publication ID, assignment ID, attempt ID, streak, or solution data.

## Parameter Count Check

| Event | Crown parameters | Count |
| --- | --- | --- |
| `sign_up` | `analytics_schema_version`, `method` | 2 |
| `login` | `analytics_schema_version`, `method` | 2 |
| `level_start` | Listed recommended-event set | 5 |
| `level_end` | Listed recommended-event set | 6 |
| `select_content` | Listed recommended-event set | 4 |
| `email_verified` | Listed custom-event set | 2 |
| `matchmaking_join` | Listed custom-event set | 6 |
| `matchmaking_cancel` | Listed custom-event set | 8 |
| `matchmaking_matched` | Listed custom-event set | 7 |
| `match_start` | Listed custom-event set | 6 |
| `match_complete` | Listed custom-event set | 17 |
| `first_match_complete` | Listed custom-event set | 6 |
| `match_reconnect` | Listed custom-event set | 8 |
| `friend_request_sent` | Listed custom-event set | 2 |
| `friend_request_accepted` | Listed custom-event set | 2 |
| `match_invitation_sent` | Listed custom-event set | 6 |
| `match_invitation_accepted` | Listed custom-event set | 6 |
| `replay_open` | Listed custom-event set | 6 |
| `appearance_changed` | Listed custom-event set | 3 |
| `daily_puzzle_reset` | Listed custom-event set | 5 |

Every event remains below GA4's 25 custom event-parameter limit. Adding an automatically supplied SDK parameter does not permit adding another Crown parameter without schema review.

## Acceptance and Tests

### Schema tests

- The event registry contains exactly the 20 event names in this catalog and no aliases.
- Every valid fixture contains exactly its row's parameters and values with the documented types.
- Removing a required parameter, adding an unknown parameter, sending null, sending a native boolean, or violating an enum/range drops the event.
- Every name starts with a letter, is lowercase ASCII `snake_case`, stays within the official length limit, and avoids `firebase_`, `google_`, `ga_`, and all official reserved names.
- Every row has no more than 25 Crown parameters; `match_complete` has exactly 17.
- `select_content` rejects every unlisted `content_type`/`item_id` pair.

### Consent tests

- Each trigger under denied consent completes its product behavior and emits nothing.
- Granting later does not emit a trigger that occurred or was first observed while denied.
- Withdrawing between backend confirmation and client handling emits nothing and clears pending delivery state.
- Re-granting measures only new triggers.

### Trigger and idempotency tests

- First successful profile completion emits one `sign_up`; later successful authentication of that completed account emits `login`; `ensureAccount` and profile-setup retries do not duplicate either.
- Provider linking emits neither `sign_up` nor `login`.
- Verification false-to-true emits one `email_verified`; an account already verified at creation emits none.
- Daily Puzzle start and successful completion each emit once under command retries, listener reattachment, and app restart; failures emit no `level_end`.
- Queue join, cancel, match, and cancel-versus-pair races emit only the committed transition with authoritative duration.
- Match activation, terminal finalization, offline bot synchronization, duplicate snapshots, and outbox retries emit at most one matching event per device trigger.
- Two completions racing for the first-match milestone create one milestone and at most one `first_match_complete` observation while granted.
- Reconnect heartbeats do not emit; each confirmed disconnected-to-connected transition emits once and increments the completion count.
- Social retries and reciprocal state changes emit only the event whose exact transition occurred.
- Replay load failure and selecting the already-active appearance emit nothing.
- Initial Daily Puzzle load emits no reset; each documented assignment replacement emits one exact reason.

### Privacy tests

- Property-based fixtures inject UID, email, handle, UUID, Firestore path, match ID, invitation ID, puzzle ID, replay ID, query text, and dynamic URL values into every string position; validation rejects them unless the value is an exact closed enum.
- Network inspection confirms no event payload contains domain-record IDs or PII and GA User-ID appears only in the SDK's User-ID field.
- Social events cannot be joined by a Crown-supplied value to another player or relationship.
- Replay, appearance, and Daily Puzzle events expose no selected record or content-record identity.

### Reporting tests

- DebugView in the development property shows exact recommended-event parameters and custom enums for synthetic fixtures.
- Production validation confirms no duplicate automatic event is manually emitted.
- Registered custom dimensions and metrics match `docs/Specs/Analytics Measurement Plan.md` and every registration refers to a parameter in this catalog.
- No catalog event is configured as a GA4 key event.

## Official References

- [Firebase Analytics log events](https://firebase.google.com/docs/analytics/events)
- [GA4 recommended events](https://support.google.com/analytics/answer/9267735)
- [GA4 event naming rules and reserved names](https://support.google.com/analytics/answer/13316687)
- [GA4 collection limits](https://support.google.com/analytics/answer/9267744)
- [Google Analytics policy against personally identifiable information](https://support.google.com/analytics/answer/6366371)
