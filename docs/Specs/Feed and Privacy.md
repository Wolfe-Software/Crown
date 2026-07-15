# Feed and Privacy Specification

## Purpose

This document defines the authoritative activity Feed contract, including event creation, per-viewer visibility, replay authorization, ordering, pagination, filtering, deduplication, retention, and local-cache handling.

The Feed is a projection of durable domain events. It is not an authorization boundary, a source of competitive statistics, or a permanent copy of private profile data.

## Scope

The MVP Feed contains activity from completed matches, Daily Puzzle completions, current league movement, friendship lifecycle events, and operational announcements. It is a single reverse-chronological stream.

The following are explicitly deferred and MUST NOT produce MVP Feed events or filters:

- Seasons or seasonal events, including season start/end and seasonal rewards
- Challenges, goals, challenge progress, and challenge rewards
- Achievements or achievement milestones
- Cosmetic unlocks, purchases, collections, and equipment changes

Adding a deferred category requires a versioned taxonomy change, privacy review, projection rules, and acceptance tests. Unknown event types MUST be ignored safely by older clients.

## Principles

- A signed-in viewer receives only events they are authorized to see now.
- New accounts default to friends-only activity visibility.
- Privacy changes apply retroactively to all retained events.
- Replay authorization is stricter than Feed visibility: only match participants may retrieve replay data.
- Every completed non-void supported match creates one canonical match event.
- Event facts are immutable; mutable names, avatars, privacy, friendship, blocks, and replay availability are resolved for the viewer at read time.
- Ordering and pagination are deterministic under concurrent inserts.
- Retried producers and projection fan-out never create duplicate rows.
- No signed-out user data remains readable from a local cache.

## Actors and Relationships

- **Actor:** account whose action produced an event.
- **Viewer:** signed-in account requesting a Feed projection.
- **Subject:** optional second account affected by the event, such as a match opponent or friendship requester.
- **Participant:** account listed in the authoritative match participant set.
- **Friend:** account in an accepted, active friendship with the viewer at read time.
- **Blocked account:** account blocked by either side. A block overrides friendship and all ordinary activity visibility.

## Privacy Model

### Defaults

On account creation, activity categories default to `friends`. The allowed visibility values are:

- `private`: actor only
- `friends`: actor and current accepted friends

Public-by-default activity is out of scope. A future `public` value requires a separate product and safety review.

System announcements are service-authored, not user activity, and may be visible to every eligible signed-in account regardless of user privacy settings.

Conceptual preference schema:

```json
{
  "userId": "userA",
  "revision": 7,
  "categories": {
    "matches": "friends",
    "puzzles": "friends",
    "league": "friends",
    "friendships": "friends"
  },
  "updatedAt": "server timestamp"
}
```

Missing or invalid category values MUST fail closed to `private`. Creation code MUST nevertheless write the friends-only defaults so behavior is explicit and auditable.

### Per-viewer projection

The Feed query MUST be authenticated and server-authorized. For each candidate event, projection evaluates current state rather than trusting visibility copied into the event:

1. Confirm the event type is supported and the event is not retracted.
2. Exclude the event if the viewer and any displayed user have blocked one another.
3. Include the actor's own event.
4. Otherwise evaluate the actor's current category preference.
5. For `friends`, require an accepted friendship between actor and viewer at projection time.
6. Apply event-specific audience constraints, which may only narrow access.
7. Return only viewer-safe fields and actions.

An event involving multiple users MUST NOT leak a hidden subject. If the row cannot be rendered without identifying a user who is not visible to the viewer, omit the row rather than partially redacting it. The viewer's own match row may display the opponent identity required by their match history, subject to account-safety redaction policy.

Clients MUST NOT download a global event collection and filter it locally. Cached projection rows remain non-authoritative and MUST be revalidated on refresh.

### Retroactive privacy

Changing a category to `private`, removing a friendship, or blocking an account MUST hide all retained affected events on the viewer's next server response, including old pages and direct Feed-item deep links. Changing back to `friends` may make retained events visible again if the friendship currently qualifies.

Materialized inboxes are permitted only as candidate indexes. Projection MUST still check current preferences, relationships, blocks, account state, and event constraints before returning a row. A privacy change SHOULD invalidate or purge affected cached projections promptly, but correctness MUST not depend on fan-out deletion completing.

Feed snapshots, analytics exports, logs, and notifications MUST minimize user data and follow their own retention controls. A push notification MUST not contain details that the recipient is no longer allowed to open.

### Replay access

Feed-event visibility never grants replay access. The replay endpoint MUST load the authoritative match and authorize `viewerId` against its immutable participant IDs on every request.

- Human-versus-human replay: both participants only.
- Human-versus-bot replay: the human participant only.
- Staff, moderation, and support access requires a separately audited privileged path.
- Friends, profile viewers, notification recipients, and users who once shared a friendship are not participants.
- A client-supplied participant list, event payload, or cached replay URL is never authoritative.

Replay links MUST be short-lived or resolve through an authorized endpoint. Downloaded replay data is user-scoped cache data and is removed on sign-out.

## Event Taxonomy

### Common envelope

```json
{
  "eventId": "stable globally unique ID",
  "schemaVersion": 1,
  "type": "match.completed",
  "actorIds": ["userA", "userB"],
  "subjectIds": [],
  "gameId": "checkers",
  "category": "matches",
  "occurredAt": "authoritative domain timestamp",
  "recordedAt": "server timestamp",
  "source": {
    "kind": "match",
    "id": "match123",
    "version": 1
  },
  "dedupeKey": "match.completed:match123",
  "payload": {},
  "retractedAt": null
}
```

`occurredAt` is the authoritative completion or transition time. `recordedAt` is operational metadata and MUST NOT replace a known domain time. Event payloads contain stable facts and IDs, not mutable authorization decisions. A match source event is actor-neutral and lists both human participants. Projection evaluates each participant as a possible actor context, then merges all contexts authorized for one viewer into one row.

### MVP types

| Type | Category | Actor/audience | Required facts | Dedupe key |
| --- | --- | --- | --- | --- |
| `match.completed` | `matches` | Each participant sees their own projection; friends may see actor activity without replay | Match ID, game, mode, rated flag, participant IDs, result, completion time | `match.completed:{matchId}` |
| `puzzle.completed` | `puzzles` | Actor and eligible current friends | Assignment ID, puzzle ID/version, publication date, official solve metrics, completion time | `puzzle.completed:{userId}:{assignmentId}` |
| `league.changed` | `league` | Actor and eligible current friends | Game, prior tier, new tier, triggering match ID, transition time | `league.changed:{userId}:{gameId}:{triggerId}:{newTier}` |
| `friend.requested` | `friendships` | Request recipient only | Pair ID, relationship generation ID, requester ID | `friend.requested:{pairId}:{generationId}` |
| `friend.accepted` | `friendships` | The two friendship members only | Pair ID, relationship generation ID, member IDs | `friend.accepted:{pairId}:{generationId}` |
| `system.announcement` | `system` | Server-selected eligible signed-in audience | Announcement ID, localized content key, active interval, destination | `system.announcement:{announcementId}` |

League events describe immediate Elo-derived tier changes only. Weekly rank movement, top-ten movement, and season completion are not MVP events.

Friend lifecycle rows have an event-specific participant-only audience and are never exposed merely because another account is a friend of one participant.

### Every completed match mode

Exactly one canonical `match.completed` event MUST be emitted when a match first reaches a terminal completed state for each supported mode:

- `matchmaking` (rated)
- `friend` (rated or unrated)
- `bot` (unrated)

Completion Feed events include non-void wins, draws, resignation, timeout, and disconnect results. Void, cancelled, abandoned, and nonterminal matches MUST NOT emit a completion event. A repaired match completion uses the same dedupe key and MUST NOT create another event.

Feed inclusion does not alter ratings or profile statistics. Mode and rated status MUST be displayed from authoritative match facts.

## Projection Schema

The API returns a viewer-specific display model, not the raw event:

```json
{
  "projectionId": "event01",
  "eventId": "event01",
  "type": "match.completed",
  "category": "matches",
  "occurredAt": "timestamp",
  "sortId": "event01",
  "title": "You defeated Victor",
  "metadata": {
    "gameId": "checkers",
    "mode": "friend",
    "rated": false,
    "result": "win"
  },
  "actors": [],
  "actions": [
    {"type": "replay", "matchId": "match123", "state": "available"}
  ]
}
```

Within a viewer's Feed path, `projectionId` equals `eventId`; the viewer ID is implicit in the parent path. One viewer receives at most one projection per source event. If the viewer is eligible through both match participants, both authorized actor contexts are merged into that row. If only one context is authorized, the other participant is redacted except for facts independently disclosed by the viewer's own participation. `title`, actor summaries, and actions are computed for the viewer.

## Ordering and Pagination

### Total order

Rows are sorted by the immutable tuple `(occurredAt DESC, eventId DESC)`. `eventId` MUST be globally unique and use a stable bytewise comparison.

If an authoritative `occurredAt` is unavailable, event creation fails and retries; clients do not assign it. Corrected events retain identity and follow the correction policy rather than silently changing position.

### Cursor contract

The initial page defaults to 20 rows. The opaque cursor encodes at least:

```json
{
  "occurredAt": "timestamp of last returned row",
  "eventId": "ID of last returned row",
  "filter": "all",
  "viewerId": "userA",
  "projectionRevision": 12
}
```

The next page requests rows strictly after the last tuple in descending order. Offset pagination MUST NOT be used. A cursor is bound to the authenticated viewer and normalized filter and MUST be rejected if either changes.

New events inserted above page one do not shift an existing cursor. Privacy or relationship changes may remove rows between requests, so a page may contain fewer than 20 rows. The server SHOULD scan additional candidates up to a bounded limit to fill the page; it MUST never include unauthorized rows to reach the target size.

The API returns `nextCursor` only when more candidate data may exist. Clients deduplicate by `eventId` when merging refreshes and pages. Pull-to-refresh starts a new first-page traversal.

## Filters

MVP filters are:

- `all`
- `matches`
- `friends`
- `league`
- `puzzles`
- `system`

`friends` selects friendship lifecycle events, not all activity authored by friends. Achievements are absent because that taxonomy is deferred. Filters only narrow an already authorized projection and never broaden visibility. Ordering is identical under every filter.

Unknown filters return a validation error. The client may fall back to `all` only after an explicit error; the server MUST NOT interpret unknown values broadly.

## Deduplication and Delivery

Event producers are at-least-once. Creation MUST atomically claim the unique `dedupeKey` or use it as deterministic event identity. Concurrent retries therefore converge on one canonical event.

Projection fan-out, refresh, pagination overlap, local retries, and notification deep links may deliver the same event repeatedly. Consumers MUST upsert by `eventId`; content changes replace the prior projection rather than append another row.

Notifications use a stable `(recipientId, eventId, notificationKind)` idempotency key. A Feed row and a push notification are separate delivery channels and do not create separate domain events.

## Replay Retention and Expiry

Feed event retention and replay-data retention are independent. A retained match row may outlive its replay.

At projection time, a participant's replay action is one of:

- `available`: replay endpoint currently authorizes and data exists.
- `expired`: retention elapsed or replay data was legitimately removed.
- `processing`: completed match exists but immutable replay material is not ready.
- `unavailable`: data is corrupt, withdrawn, or otherwise cannot be served.

Nonparticipants receive no replay action, not a disabled replay URL. Selecting an expired action displays a clear non-retryable message and leaves the Feed row intact. The API SHOULD provide a machine-readable reason but no storage path.

## Caching, Offline Use, and Sign-out

Cached Feed pages and downloaded replays MUST be encrypted or stored in platform-protected, account-scoped storage. Every cache key includes the authenticated user ID and environment.

Offline mode may display the last authorized projection with an explicit stale/offline state. It MUST NOT infer newly visible events or expose actions requiring server authorization. Cached replay playback is allowed only for replay data previously downloaded by that participant in the same account session.

On sign-out, account switch, token revocation handling, or account deletion, the client MUST:

1. Stop Feed listeners and in-flight requests.
2. Clear memory state.
3. Delete persisted Feed pages, cursors, images containing private activity, and replay data for the departing account.
4. Clear Feed notification previews and deep-link state.
5. Verify the signed-out and next-account UI cannot render the prior account's data.

Cache deletion is part of sign-out completion, not a best-effort background task.

## Failure and Security Behavior

- Unauthenticated Feed and replay requests return an authentication error and no user data.
- Authorization is performed server-side for each request and direct item lookup.
- Event IDs are not secrets and possession of one grants no access.
- Missing relationship or preference state fails closed.
- Projection errors omit the affected row and emit privacy-safe operational telemetry.
- Clients do not render raw event payloads for unknown schema versions.
- Retraction immediately suppresses the event from future projections and deep links.

## Acceptance Criteria

1. A new account has friends-only visibility for matches, puzzles, league activity, and friendship activity.
2. A nonfriend cannot retrieve another user's activity through list, filter, pagination, direct-event, notification, or replay endpoints.
3. An accepted friend sees eligible retained activity; removing the friendship hides it on the next server read without rewriting the original events.
4. Changing puzzle visibility to private removes old and new puzzle rows from friends' projections.
5. A block in either direction suppresses affected rows even if a friendship record remains.
6. Only authoritative match participants can retrieve replay data, including when a visible friend activity row references that match.
7. Exactly one match event is produced for every completed non-void matchmaking, rated friend, unrated friend, and bot match, including retrying completion handlers.
8. Void, cancelled, and nonterminal matches produce no `match.completed` event.
9. No MVP event or filter exists for seasons, challenges, achievements, or cosmetics.
10. Equal-timestamp events paginate in stable `eventId` order with no omissions or duplicates.
11. A cursor cannot be reused by another viewer or another filter.
12. Every filter preserves the same reverse-chronological total order and privacy rules.
13. Duplicate production and delivery attempts result in one displayed row.
14. An expired replay remains represented by the match row but cannot be fetched or presented as retryable.
15. Sign-out removes all persisted Feed and replay content before signed-out UI or another account can access it.
16. Unknown event types and schema versions are ignored without exposing raw payload data or breaking pagination.

## Verification

### Automated

- Unit-test visibility as a decision table over actor/viewer identity, category setting, friendship state, block state, account state, and event-specific audience.
- Unit-test each event-to-projection mapper for allowlisted fields and viewer-relative copy.
- Property-test ordering and cursor traversal with identical timestamps, concurrent inserts, deleted candidates, and randomized page boundaries.
- Integration-test event creation under concurrent and repeated completion deliveries for every match mode and terminal reason.
- Integration-test retroactive privacy across first page, later pages, direct item lookup, notifications, and materialized candidate inboxes.
- Security-test replay endpoints using participant, friend, former friend, unrelated, blocked, signed-out, and privileged identities.
- Test replay state transitions from processing to available to expired without creating a second Feed row.
- Test all filter values and reject deferred or unknown categories.
- Test offline cache isolation and automated deletion on sign-out, account switch, token revocation, and account deletion.
- Run emulator or staging authorization tests against the selected database edition before deployment; this conceptual schema does not substitute for database-specific rules and index verification.

### Manual

- Complete one match in each supported mode and confirm label, rated state, result, ordering, and single-row behavior.
- Change each privacy category from friends to private and back while a friend observes old and new pages.
- Remove and restore a friendship, then block an account, confirming retroactive projection behavior.
- Open a friend's visible match row and confirm no replay action is offered; open the same match as each participant and confirm authorized replay behavior.
- Expire replay fixtures and confirm the row remains with clear expired messaging.
- Populate more than two pages with timestamp collisions, refresh between page loads, and confirm stable merge behavior.
- Cache a Feed and replay, sign out offline, and inspect the signed-out and second-account experiences for leakage.

## Operational Observability

Monitor event creation retries, dedupe conflicts, projection authorization failures, candidate-to-returned row ratios, cursor validation errors, replay authorization denials, replay expiry rates, and cache-clearing failures. Logs MUST use IDs and reason codes rather than titles, display names, replay moves, or other private rendered content.
