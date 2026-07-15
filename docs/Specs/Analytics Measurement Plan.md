# Analytics Measurement Plan

## Purpose

This document defines Crown's launch contract for Google Analytics for Firebase (GA4), Firebase Crashlytics, and Firebase Performance Monitoring. The event-level contract is in `docs/Specs/Analytics Event Catalog.md`.

The measurement system exists to answer product and reliability questions without collecting player identity, social-graph identity, private content, or game-record identifiers.

## Fixed Decisions

- Consent defaults to denied on every new installation and remains denied until the player explicitly enables optional data collection.
- One optional-data toggle controls GA collection, `analytics_storage`, `ad_storage`, `ad_user_data`, `ad_personalization`, Crashlytics collection, and Performance Monitoring collection as one unit. There are no independent sub-toggles.
- The granted or denied choice is device-scoped. It does not synchronize through the Crown account and does not change another installation.
- No analytics, crash, or performance payload is buffered while consent is denied. An event that occurs while denied is dropped and is not reconstructed or sent after later consent.
- Declining Analytics never restricts gameplay, authentication, social features, matchmaking, Daily Puzzle, replay, appearance, support, or any other product capability.
- Withdrawing consent disables every controlled service, clears the GA User-ID and all GA user properties, resets local analytics state, and discards pending analytics work. Collection resumes only for new activity after a later grant.
- After both consent and authentication are established, GA User-ID is the opaque Firebase Auth UID. It is cleared before sign-out completes and before an account switch can expose the next account. The next UID is set only after the new authenticated account is established.
- Crashlytics User-ID is never set, including to a Firebase UID, hash, handle, email address, installation ID, or placeholder.
- Development and production send to separate Firebase projects and separate GA4 properties. Data must never be intentionally forwarded or merged between them.
- Both GA4 properties use reporting timezone `America/New_York` and currency `USD`.
- BigQuery export is not enabled.
- No GA4 event is marked as a key event.

## Measurement Questions

The catalog is limited to answering:

- Which supported authentication methods reach account creation, login, and email verification?
- Where do players enter core content and which allowlisted content category did they select?
- How often does matchmaking begin, cancel, produce a match, and how long does matching take?
- How often do matches start, complete, and reconnect, split by game, mode, rated state, ruleset, result, League, and Tier?
- How many consenting players reach their first completed match?
- How often do friend requests and match invitations advance from sent to accepted?
- How often are replays opened, appearance categories changed, and Daily Puzzle player days reset?
- Are crashes, non-fatal failures, and critical app operations healthy without attaching player or domain-record identity?

The plan does not measure individual move paths, board positions, messages, search text, handles, display names, friend graphs, opponent identity, puzzle identity, replay identity, or match identity.

## Consent State Machine

```txt
denied (default) --player enables toggle--> granted
granted --player disables toggle--> denied_and_reset
denied_and_reset --reset completes--> denied
```

### Startup

Before configuring or starting any controlled SDK collection:

1. Read the device-scoped optional-data toggle. A missing, unreadable, or migrated value is `denied`.
2. Apply denied consent for `analytics_storage`, `ad_storage`, `ad_user_data`, and `ad_personalization` before any analytics event can be produced.
3. Set GA collection, Crashlytics collection, and Performance Monitoring collection to disabled.
4. If the stored choice is granted, grant all four consent types and enable all three collection products as one operation before accepting new telemetry.
5. If an authenticated Firebase user exists after grant, set GA User-ID and current allowlisted user properties.

No event queue owned by Crown may survive a denied startup. SDK settings in platform manifests, property lists, or generated configuration must also default collection to disabled so application initialization cannot race the consent decision.

### Grant

On explicit opt-in, apply all consent grants and enable GA, Crashlytics, and Performance Monitoring. The grant itself is not an analytics event. Do not backfill session starts, prior screens, authentication, matches, errors, traces, or any catalog event that occurred before the grant.

If the player is already authenticated, set GA User-ID to the current opaque Firebase UID only after collection is enabled. Set user properties from current authoritative account state. Activity after these steps may be measured normally.

### Decline

An explicit decline preserves the denied state. It does not sign the player out, alter account state, show degraded gameplay, repeatedly prompt during normal play, or create a telemetry record describing the decline.

### Withdraw

Withdrawal ordering is mandatory:

1. Stop Crown telemetry producers and reject new event or trace submissions.
2. Disable GA collection, Crashlytics collection, and Performance Monitoring collection and deny all four consent types.
3. Set GA User-ID to `null` and clear `account_status`, `checkers_league`, and `checkers_tier`.
4. Delete Crown-owned pending telemetry, once markers that exist only for analytics delivery, trace attributes, breadcrumbs, and cached analytics payloads.
5. Invoke the supported GA local analytics reset API so the app-instance analytics state is reset.
6. Clear allowlisted Crashlytics custom keys from process state and remove any Crown-owned persisted diagnostic context.
7. Persist the device-scoped denied choice.

The app does not attempt to delete already transmitted aggregate data through this toggle. Any separate legal deletion right must use the approved account/privacy process and is outside this collection-control operation.

### Sign-Out and Account Switch

Before clearing Firebase Auth credentials or opening another UID namespace:

- Stop event production.
- Set GA User-ID to `null`.
- Clear all three GA user properties.
- Clear UID-scoped local analytics once state.

If consent remains granted, anonymous post-sign-out activity may be collected without User-ID or user properties. On account switch, do not reuse event payloads, once markers, properties, or diagnostic context from the prior UID. Set the new opaque UID and current properties only after authentication and account initialization complete.

## Data Ownership and Delivery

- A client-owned event describes a local UI action and is emitted immediately after the committed local action.
- A server-confirmed event describes authoritative backend state. The backend owns the transition and idempotency fact; the client emits only after observing its confirmed response or state while consent is granted.
- Backend outbox records may identify a pending product side effect, but they are not GA payload queues. They must not send GA events directly or cause an event that occurred while this device was denied to be replayed after consent.
- Offline events may be emitted only when their catalog trigger itself occurs while granted. Crown does not create a separate durable analytics buffer. Normal SDK delivery after an event was validly emitted while granted is allowed; withdrawal disables collection and resets that local state.
- Every producer validates the exact schema before calling the SDK. Unknown parameters, null parameters, disallowed enum values, and identifier-shaped values cause the event to be dropped in development and omitted in production, with no raw value copied into diagnostics.

## Identity and Data Minimization

### Allowed identity

GA User-ID may contain only the current opaque Firebase Auth UID. It must not be placed in an event parameter or user property. The value must not be transformed into a custom identifier for Crashlytics or event payloads.

### Prohibited data

GA events, GA user properties, Crashlytics messages and keys, Performance traces and attributes, and analytics-facing logs must not contain:

- Email addresses, phone numbers, names, display names, handles, free text, search queries, notification contents, auth tokens, IP addresses supplied by Crown, or other PII.
- Firebase UIDs, opponent UIDs, provider subject IDs, device identifiers, advertising identifiers, installation identifiers, FCM tokens, or hashes of any prohibited value.
- Domain-record IDs, including match, queue generation, friendship, friend request, invitation, replay, puzzle, publication, assignment, attempt, command, operation, feed event, or Firestore document IDs.
- Board positions, move notation, chat or support content, filenames containing player data, URLs with query values, or raw backend request/response bodies.
- Dynamic strings derived from exceptions, network responses, Firestore paths, route parameters, or player content.

`game_id`, `ruleset_id`, catalog `item_id`, screen names, and appearance categories are closed, product-defined enums, not domain-record IDs.

## GA4 Configuration

### Properties and streams

| Environment | Firebase project | GA4 property | Permitted data |
| --- | --- | --- | --- |
| Development, test, and internal builds | `crown-chess-and-checkers-dev` | Crown Development | Synthetic or tester activity only |
| App Store and Play production builds | `crown-chess-and-checkers` | Crown Production | Production consenting activity only |

Release configuration must fail closed if a build points to the wrong Firebase project. DebugView and developer debug flags are permitted only in non-production builds.

For both properties:

- Reporting timezone: `America/New_York`.
- Currency: `USD`.
- BigQuery linking/export: disabled.
- Key events: none.
- Google Signals, ads personalization, and advertising features remain unavailable until the single toggle grants the applicable consent. No separate product assumption overrides the current consent state.

### Naming and limits

- Event and parameter names use lowercase `snake_case`, begin with a letter, and contain only letters, digits, and underscores.
- User property names use lowercase `snake_case` and begin with a letter.
- Event names are at most 40 characters. Each event has at most 25 event parameters.
- Parameter names are at most 40 characters. User property names are at most 24 characters and user property values are at most 36 characters.
- Names beginning with `firebase_`, `google_`, or `ga_` are forbidden. Reserved event, parameter, and user-property names are forbidden.
- Values obey the current GA4/Firebase SDK limits; the catalog's tighter enums apply first.
- Automatically collected and enhanced-measurement events are not emitted manually. In particular, Crown does not duplicate `screen_view`, `session_start`, `first_open`, `app_update`, `app_remove`, `notification_open`, or other automatic events.
- The recommended events in the catalog use Google's exact event and required parameter names. Crown custom events are used only where no listed recommended event expresses the transition.

Schema review must re-check the official limits and reserved-name lists before each schema version is released.

## User Properties

User properties are set only after consent and authentication and are cleared on sign-out, account switch, and consent withdrawal.

| Property | Type | Allowed values | Source | Update trigger |
| --- | --- | --- | --- | --- |
| `account_status` | string | `unverified`, `verified` | Authoritative Firebase email-verification claim | Auth initialization and confirmed verification change |
| `checkers_league` | string | `bronze`, `silver`, `gold`, `platinum`, `diamond` | Server-derived current Elo band | Auth initialization and confirmed rated finalization |
| `checkers_tier` | string | `iii`, `ii`, `i`, `diamond` | Server-derived current Elo band | Auth initialization and confirmed rated finalization |

No property is set to an unknown, empty, stale-account, or signed-out sentinel. It is cleared instead. No additional user property may ship without updating this specification and the GA4 registration inventory.

## Custom Definitions

GA4 event-scoped custom dimensions to register:

| Parameter | Display name |
| --- | --- |
| `analytics_schema_version` | Analytics Schema Version |
| `game_id` | Game ID |
| `mode` | Match Mode |
| `rated` | Rated |
| `ruleset_id` | Ruleset ID |
| `source_screen` | Source Screen |
| `result` | Match Result |
| `result_reason` | Match Result Reason |
| `league_before` | League Before |
| `league_after` | League After |
| `tier_before` | Tier Before |
| `tier_after` | Tier After |
| `auth_method` | Auth Method |
| `content_type` | Content Type |
| `item_id` | Selected Content ID |
| `appearance_type` | Appearance Type |
| `reset_reason` | Daily Puzzle Reset Reason |
| `cancel_reason` | Matchmaking Cancel Reason |

GA4 event-scoped custom metrics to register:

| Parameter | Display name | Unit |
| --- | --- | --- |
| `matchmaking_duration_ms` | Matchmaking Duration | Milliseconds |
| `match_duration_ms` | Match Duration | Milliseconds |
| `reconnect_duration_ms` | Reconnect Duration | Milliseconds |
| `elo_before` | Elo Before | Standard |
| `elo_after` | Elo After | Standard |
| `elo_delta` | Elo Delta | Standard |
| `reconnect_count` | Reconnect Count | Standard |

`method`, `level_name`, and `success` are recommended-event parameters and need no Crown custom definition unless GA4 reporting proves one necessary. User properties are registered as user-scoped custom dimensions under their exact names. Do not register high-cardinality IDs or create calculated metrics that reconstruct identity.

## Crashlytics Contract

Crashlytics collection follows the single consent toggle and is disabled by default. Crashlytics User-ID is never set.

Only these custom keys are allowed; all values are closed enums or bounded numbers:

| Key | Type | Allowed value |
| --- | --- | --- |
| `app_flow` | string | `boot`, `auth`, `home`, `matchmaking`, `match`, `friends`, `daily_puzzle`, `replay`, `appearance`, `settings` |
| `game_id` | string | `checkers` |
| `mode` | string | `matchmaking`, `friend`, `bot`, or key absent |
| `rated` | bool | `true`, `false`, or key absent |
| `match_state` | string | `awaiting_players`, `active`, `completed`, `cancelled`, or key absent |
| `network_state` | string | `online`, `offline`, `constrained`, `unknown` |
| `ruleset_id` | string | `checkers-wcdf-gayp-v1.0.0` or key absent |
| `error_code` | string | Stable reviewed application error enum; never provider text or backend payload |
| `schema_version` | int | Positive shipped diagnostic schema version |

Non-fatal reports use reviewed exception classes and static messages. Before recording, redaction removes email-like text, URLs and query strings, UUIDs, Firebase/Firestore paths, bearer tokens, long digit sequences, and values associated with keys such as `email`, `name`, `handle`, `uid`, `user`, `token`, `authorization`, `match`, `invitation`, `request`, `puzzle`, and `replay`. If redaction cannot prove a value safe, omit the value or the report. Breadcrumbs use static allowlisted action names only. Custom logs must not include dynamic exception text, objects, payloads, identifiers, or player input.

## Performance Monitoring Contract

Performance Monitoring follows the single consent toggle and is disabled by default. Automatic HTTP URL collection must not expose path or query components containing IDs or player data; instrument server operations with the static traces below rather than dynamic URLs.

Allowed custom traces:

| Trace | Start | Stop | Allowed custom attributes |
| --- | --- | --- | --- |
| `app_ready` | Process enters Crown boot state machine | First stable authentication-required, verification-required, ready-online, or ready-offline state | `outcome`: `auth_required`, `verification_required`, `ready_online`, `ready_offline`, `recovery` |
| `auth_initialize` | Provider credential exchange succeeds | `ensureAccount` and required profile load succeed or fail | `method`: `apple`, `google`, `password`; `outcome`: `success`, `failure` |
| `matchmaking_wait` | Confirmed queue join enters `waiting` | Confirmed matched, cancelled, expired, or error terminal state | `outcome`: `matched`, `cancelled`, `expired`, `error`; `game_id`: `checkers` |
| `match_state_load` | Static match-state operation begins | Usable state or terminal failure is returned | `mode`: `matchmaking`, `friend`; `outcome`: `success`, `failure` |
| `daily_puzzle_load` | Assignment load begins | Usable assigned puzzle or terminal failure is returned | `outcome`: `success`, `unavailable`, `failure`; `game_id`: `checkers` |
| `replay_load` | Replay payload load begins | Replay is renderable or terminal failure is returned | `outcome`: `success`, `unauthorized`, `not_found`, `failure`; `game_id`: `checkers` |

Trace names and attributes are static. Do not append IDs, screen instances, status text, dates, routes, or error messages. Do not add metrics carrying identifiers. SDK-provided duration and network metrics are sufficient; custom duration values belong in GA only where listed in the event catalog.

## Quality Controls

- `analytics_schema_version` starts at integer `1`. Increment it only for a breaking event or parameter semantic change; do not reinterpret an existing enum under the same version.
- A shared schema validator enforces exact event names, exact parameter sets, types, nullability, enum values, ranges, name limits, and the 25-parameter event limit.
- Production drops invalid events rather than coercing values. Development fails the relevant automated assertion and emits only a static local diagnostic.
- Analytics failures never fail or delay product operations.
- Dashboard queries filter by `analytics_schema_version` and environment property.
- A quarterly review removes unused events and custom definitions and re-checks consent, automatic collection, SDK changes, naming reservations, and data minimization.

## Acceptance and Tests

### Consent

- A clean install with no stored choice sends no GA, Crashlytics, or Performance data before a grant.
- Startup applies denied consent and disabled collection before SDK producers can emit.
- Decline leaves every gameplay and account capability available and produces no decline event.
- Events occurring while denied are absent after later grant; there is no Crown queue or reconstructed backfill.
- Withdrawal stops new traffic, clears User-ID and all user properties, resets GA local state, clears diagnostic context, and leaves the toggle denied after restart.
- The device-scoped choice does not appear on another device signed into the same UID.

### Identity and Privacy

- Consent plus authentication sets GA User-ID to exactly the current Firebase UID; denied consent does not set it.
- Sign-out clears User-ID and properties before account UI teardown. Rapid account switching cannot associate the prior UID or properties with the next account's event.
- Crashlytics User-ID remains unset in every build and flow.
- Schema fuzz tests reject emails, handles, UIDs, UUIDs, Firestore paths, dynamic URLs, domain IDs, free text, unknown parameters, and reserved prefixes.
- Crashlytics redaction tests cover email-like text, tokens, UUIDs, paths, query strings, and nested backend error payloads.

### GA4 Contract

- Every catalog event passes exact-name, exact-parameter, type, enum, nullability, length, and parameter-count tests.
- Recommended events use the documented names and automatic events are never manually duplicated.
- Development and production build artifacts resolve to different Firebase projects and GA4 properties.
- Both properties show `America/New_York`, `USD`, no BigQuery link, and zero key events.
- The custom definition inventory exactly matches this document; no high-cardinality definition exists.

### Ownership and Idempotency

- Client-owned actions emit once per committed UI action while granted.
- Server-confirmed retries, duplicate snapshots, listener reattachment, process restart, and two-device observation cannot emit more than the catalog's stated once key on one device.
- A server transition completed while denied is not emitted when later observed after grant.
- Match completion and first-match completion remain deduplicated under transaction and outbox retries without sending a domain ID to GA.

### Reliability

- Each allowed Performance trace closes on success, cancellation, timeout, and failure and uses only allowlisted attributes.
- Dynamic route segments and query values do not appear in Performance Monitoring.
- Disabling consent during an active trace prevents Crown from submitting further trace data and clears trace context.
- Collection failures do not alter gameplay result, rating, queue state, friendship, puzzle state, replay access, or appearance state.

## Official References

- [Google consent mode overview](https://developers.google.com/tag-platform/security/concepts/consent-mode)
- [Firebase Analytics data collection and usage](https://firebase.google.com/docs/analytics/configure-data-collection)
- [Firebase Analytics events](https://firebase.google.com/docs/analytics/events)
- [GA4 recommended events](https://support.google.com/analytics/answer/9267735)
- [GA4 event naming rules and reserved names](https://support.google.com/analytics/answer/13316687)
- [GA4 collection limits](https://support.google.com/analytics/answer/9267744)
- [GA4 User-ID](https://support.google.com/analytics/answer/9213390)
- [GA4 custom dimensions and metrics](https://support.google.com/analytics/answer/14240153)
- [Google Analytics policy against personally identifiable information](https://support.google.com/analytics/answer/6366371)
- [Firebase Crashlytics customize crash reports](https://firebase.google.com/docs/crashlytics/customize-crash-reports)
- [Firebase Crashlytics data collection controls](https://firebase.google.com/docs/crashlytics/customize-crash-reports#enable_opt-in_reporting)
- [Firebase Performance Monitoring data collection controls](https://firebase.google.com/docs/perf-mon/disable-sdk)
- [Firebase Performance Monitoring custom traces](https://firebase.google.com/docs/perf-mon/custom-code-traces)
