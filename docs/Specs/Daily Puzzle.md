# Daily Puzzle Specification

## Purpose

This document defines the authoritative Daily Puzzle lifecycle and player-attempt contract: local-day assignment, timezone handling, puzzle identity and publication, corrections and withdrawal, solution validation, timers and resets, streaks, offline and multi-device synchronization, Feed integration, and player reports.

Daily Puzzle completion is recognition only in the MVP. It does not award currency, Elo, League progress, or rated-match statistics.

## Principles

- A player's daily puzzle is selected by that player's local civil date in a server-stored IANA timezone.
- The server owns day assignment; device clocks and offsets are hints, never authority.
- Timezone changes cannot grant two completion-bearing puzzles for one player day or duplicate completion credit.
- Published content is immutable by version. Corrections create a new version; withdrawal is explicit.
- Solutions are branching trees validated under a pinned rules-engine version.
- One logical attempt converges across retries, offline devices, and multiple signed-in devices.
- Only the first accepted completion can affect streak and Feed state.
- Reports never reveal solutions or mutate attempt state.

## Terms

- **Local date:** Gregorian calendar date `YYYY-MM-DD` calculated in the player's effective IANA timezone.
- **Effective timezone:** server-stored IANA timezone used for Daily Puzzle assignment.
- **Player day:** server-issued assignment interval associated with one local date and one puzzle family.
- **Puzzle family:** stable authored puzzle identity across versions.
- **Puzzle version:** immutable content revision within a family.
- **Publication:** assignment of one puzzle version to a game and publication date.
- **Attempt:** the player's one official progress record for a server-issued assignment.
- **Completion:** server-accepted traversal to a terminal success node of the published solution tree.

## Local Date and Timezone

### Stored timezone

Each user profile stores an IANA timezone name, for example `America/Los_Angeles`, plus update metadata:

```json
{
  "userId": "userA",
  "timeZone": "America/Los_Angeles",
  "timeZoneUpdatedAt": "server timestamp",
  "timeZoneSource": "device_confirmed",
  "timeZoneRevision": 4
}
```

Fixed UTC offsets such as `-07:00` are invalid because they do not encode daylight-saving transitions. The server MUST validate timezone names against its supported IANA tzdb. An unknown or missing timezone prevents a new assignment until the client submits a valid value; it MUST NOT silently use the server's timezone.

The client SHOULD offer the current device timezone when it differs, but the server persists the accepted change. A timezone is not inferred anew on every request.

### Assignment

The server calculates `localDate` from trusted current server time and the stored timezone, then resolves or creates a player-day assignment. The returned assignment is authoritative for loading, completion, streak, and Feed behavior.

Conceptual assignment schema:

```json
{
  "assignmentId": "opaque stable ID",
  "userId": "userA",
  "gameId": "checkers",
  "localDate": "2026-07-14",
  "timeZone": "America/Los_Angeles",
  "timeZoneRevision": 4,
  "startsAt": "server timestamp",
  "endsAt": "server timestamp",
  "puzzleId": "checkers-0042",
  "puzzleVersion": 3,
  "publicationId": "checkers:2026-07-14",
  "createdAt": "server timestamp"
}
```

`startsAt` and `endsAt` correspond to local midnight boundaries in the assigned timezone and therefore may span 23, 24, or 25 hours. Calendar arithmetic MUST use timezone-aware date libraries, not add 86,400 seconds.

### Timezone changes and anti-duplication

Timezone changes take effect for Daily Puzzle assignment at the next player-day boundary, not immediately. If the player has an active assignment, changing the profile timezone MUST preserve that assignment until its `endsAt`. The next assignment uses the new stored timezone and starts no earlier than the prior assignment's end.

The server enforces:

- At most one active assignment per user and game.
- Assignment intervals for a user and game never overlap.
- An assignment maps to exactly one publication and immutable puzzle version.
- Completion uniqueness is by `assignmentId`, with a secondary uniqueness guard on `(userId, gameId, publicationId)`.
- Reverting or repeatedly changing timezone cannot recreate an assignment or another completion for a publication already assigned to that user.
- A backward date jump does not grant a second official puzzle for an already assigned local date.
- A forward date jump may skip local dates; skipped puzzles are not backfilled in MVP.

Rate limits and anomaly telemetry MAY discourage timezone hopping, but correctness MUST come from assignment uniqueness, not fraud heuristics. Travel must remain supported.

## Puzzle Identity and Versioning

### Puzzle family

`puzzleId` is a stable opaque identifier for authored intent. It MUST NOT be a date because the same family may be corrected, rescheduled, or used in a future archive.

```json
{
  "puzzleId": "checkers-0042",
  "gameId": "checkers",
  "createdAt": "server timestamp",
  "createdBy": "staff ID",
  "latestVersion": 3
}
```

### Immutable puzzle version

```json
{
  "puzzleId": "checkers-0042",
  "version": 3,
  "status": "validated",
  "rules": {
    "ruleset": "checkers-wcdf-gayp-v1.0.0",
    "wcdfVersion": "pinned supported identifier",
    "engineVersion": "crown-checkers-1.2.0"
  },
  "initialBoardState": {},
  "sideToMove": "black",
  "objective": {"type": "force_win"},
  "solutionTree": {},
  "difficulty": "medium",
  "contentHash": "sha256 of canonical validation content",
  "createdAt": "server timestamp",
  "validatedAt": "server timestamp",
  "supersedesVersion": 2
}
```

The World Checkers/Draughts Federation rules reference MUST use a supported, pinned WCDF rules version or rules publication identifier. A generic `latest` value is forbidden. The same pinned rules interpretation is used by authoring validation, server completion validation, and compatible clients. Changing rules interpretation requires a new puzzle version even if board and moves are unchanged.

Published version content MUST never be edited in place. Administrative notes may live outside the immutable content hash.

## Publication Lifecycle

Conceptual publication schema:

```json
{
  "publicationId": "checkers:2026-07-14",
  "gameId": "checkers",
  "publicationDate": "2026-07-14",
  "puzzleId": "checkers-0042",
  "puzzleVersion": 3,
  "state": "published",
  "publishAt": "server timestamp",
  "withdrawnAt": null,
  "replacement": null,
  "createdAt": "server timestamp",
  "publishedAt": "server timestamp"
}
```

There is at most one effective publication per `(gameId, publicationDate)`. Lifecycle states are:

- `draft`: editable scheduling metadata; not player-readable.
- `scheduled`: references a validated immutable version and has a future `publishAt`.
- `published`: available for assignment when the player's local date matches.
- `withdrawn`: no new assignment or solving; includes a player-safe reason code.

Publishing is an audited server operation. It verifies legal initial state, objective consistency, solution-tree validity, pinned rules versions, content hash, and unique publication date.

### Corrections

A correction creates a new immutable puzzle version and an audited publication revision. It never mutates content already cached under an old version.

- Players without an assignment receive the corrected version.
- Existing incomplete assignments remain on their immutable assigned version in the MVP; correction never migrates an in-progress assignment.
- Existing completed attempts remain credited and retain the version solved.
- A correction MUST NOT revoke a completion, reduce a streak, replace official metrics, or emit a second completion Feed event.

### Withdrawal

Withdrawal stops new assignments immediately. The privileged withdrawal operation records either `preserve_existing` or `reject_incomplete_invalid_solution`.

- Completed attempts remain completed and keep streak credit.
- Existing completion Feed events may remain unless the withdrawal reason requires privacy or integrity retraction.
- Incomplete attempts do not count as failures and do not break a streak by themselves.
- A replacement serves players without an existing assignment; it does not migrate an in-progress MVP assignment or provide a second completion for the same player day.
- Under `preserve_existing`, assigned attempts remain usable and may late-sync for seven days after `endsAt`.
- Under `reject_incomplete_invalid_solution`, incomplete attempts and not-yet-accepted offline completions are rejected, and the assignment is neutral for streak continuity.

## Solution Tree

Daily Puzzle solutions are trees, not a single flat move list. This supports equivalent player moves and authored opponent responses.

Conceptual node schema:

```json
{
  "rootNodeId": "n0",
  "nodes": {
    "n0": {
      "positionHash": "canonical position hash",
      "turn": "black",
      "kind": "player_choice",
      "edges": [
        {"move": {"from": 21, "to": 14, "captures": [17]}, "to": "n1"}
      ]
    },
    "n1": {
      "positionHash": "canonical position hash",
      "turn": "white",
      "kind": "authored_response",
      "edges": [
        {"move": {"from": 10, "to": 17}, "to": "n2"}
      ]
    },
    "n2": {
      "positionHash": "canonical position hash",
      "kind": "success",
      "edges": []
    }
  }
}
```

Validation requirements:

- Every position and edge is legal under the pinned WCDF/rules-engine version.
- Mandatory captures, multi-jump continuation, crowning, side to move, and terminal conditions are enforced.
- Every reachable nonterminal node has at least one edge and every edge reaches a declared node.
- The tree is acyclic for MVP puzzle traversal.
- Every authored-response branch eventually reaches another player choice, success, or explicit failure node.
- Every accepted player edge satisfies the objective under authoring analysis; alternatives may be represented as separate equivalent edges.
- Position hashes are recomputed, not trusted from author input.
- The server validates submitted move paths against the assigned immutable tree and version.

The client receives only the initial state and enough current-node data to validate interaction without revealing future player moves. Full solution content MUST not be exposed before completion through ordinary client APIs. Automatic opponent responses are returned only when reached.

## Attempt and Completion Model

Conceptual attempt schema:

```json
{
  "attemptId": "same stable ID as assignment or derived from it",
  "assignmentId": "assignment01",
  "userId": "userA",
  "gameId": "checkers",
  "puzzleId": "checkers-0042",
  "puzzleVersion": 3,
  "publicationId": "checkers:2026-07-14",
  "status": "in_progress",
  "currentNodeId": "n2",
  "acceptedPath": ["edge IDs"],
  "startedAt": "server timestamp or null",
  "completedAt": null,
  "activeElapsedMs": 46000,
  "incorrectMoves": 1,
  "resetCount": 0,
  "usedHint": false,
  "revision": 9,
  "processedOperationIds": [],
  "updatedAt": "server timestamp"
}
```

The server is authoritative. Clients submit idempotent operations containing `operationId`, `attemptId`, expected revision, device ID, operation kind, and relevant move or timing evidence. Accepted operations advance revision exactly once. A repeated operation ID returns the original result.

Supported operation kinds and payloads are:

- `begin`: no domain payload; starts the official timer once.
- `move`: `from`, `to`, and optional ordered continuation landings for one complete player decision; server resolves the matching solution-tree edge and authored response.
- `incorrect_move`: not submitted directly; it is the server result of a legal `move` that is not an accepted authored edge and increments the count once.
- `reset`: no domain payload; restores the root node while retaining official counters and elapsed time.
- `timing_segment`: monotonic segment ID, duration milliseconds, lifecycle start/end reason, and local sequence number.
- `sync_batch`: ordered offline operations, each with its own operation ID and expected predecessor revision.

Completion is never a client-selected operation kind. It is the server result of an accepted `move` reaching a success node.

Move operations MUST be sequential and validated from the authoritative current node. Conflicting operations from two devices cannot both advance the same revision. The losing device refreshes and reconciles to server state.

## Timer and Reset

### Official timer

The official solve timer starts on the first piece selection that begins interaction, matching the UX contract. It stops on first accepted completion. It measures active foreground time while the puzzle screen is visible.

The client records monotonic active-time segments and submits them with unique operation IDs. The server validates ordering and applies reasonable integrity bounds. Wall-clock changes, timezone changes, app restarts, and network latency MUST NOT directly add or remove elapsed time.

If precise timing evidence cannot be reconciled, completion remains valid but timing may be marked `unverified`; streak credit does not depend on solve speed. The completion UI distinguishes pending synchronization from an accepted official time.

### Pause behavior

Timing pauses when the app backgrounds, the puzzle route is no longer visible, the user signs out, or the assignment is withdrawn. Process death closes the last locally persisted segment at the most recent lifecycle checkpoint; the server MAY cap an unclosed segment rather than count indefinite time.

### Reset behavior

Reset returns visible progress to the assigned version's initial board and root solution node. It:

- Does not change assignment, puzzle version, `startedAt`, accumulated active elapsed time, incorrect-move count, hint usage, or completion eligibility.
- Increments `resetCount` once per idempotent reset operation.
- Clears only the current accepted path used for board presentation.
- Has no effect after official completion except to begin an unofficial replay view.

Incorrect legal moves increment `incorrectMoves` once per idempotent submission and restore the prior authoritative node. Invalid gestures or moves rejected before submission do not increment the count.

## Completion and Streaks

Completion occurs only when the authoritative path reaches a success node. A transaction or equivalent atomic server operation MUST:

1. Change the attempt from incomplete to completed once.
2. Set immutable official completion metrics and server `completedAt`.
3. Apply at most one streak credit for the assignment.
4. Create or claim the one puzzle completion event/outbox record.
5. Return the same result to duplicate completion requests.

### Streak model

Streaks use consecutive credited player-day assignments, not UTC dates or upload dates. Conceptual state:

```json
{
  "userId": "userA",
  "gameId": "checkers",
  "current": 7,
  "best": 12,
  "lastCreditedAssignmentId": "assignment01",
  "lastCreditedLocalDate": "2026-07-14",
  "revision": 31
}
```

- The first accepted completion for an assignment provides one credit.
- Replay, reset, correction, duplicate sync, and second-device completion provide no additional credit.
- Consecutiveness follows the user's server-issued assignment sequence, allowing legitimate timezone changes and daylight-saving boundaries without requiring exactly 24 hours.
- A skipped eligible player day breaks the streak when the next eligible assignment is evaluated.
- A date skipped solely because a timezone transition moved forward and no assignment existed is not treated as an eligible missed day.
- A withdrawn day with no replacement is neutral and does not break or increment the streak.
- Late upload may repair streak state if the offline completion was valid for its assignment; the server recomputes from immutable credits rather than applying arrival order blindly.

## Offline and Multiple Devices

### Offline availability

After an assignment and its exact immutable puzzle version are fetched, the client may cache and solve it offline until it learns that the assignment is replaced or withdrawn. Offline storage includes assignment identity, content hash, accepted local path, active-time segments, incorrect-move operations, resets, and completion operation.

It MUST NOT manufacture an assignment for a device-local date. If no server-issued assignment is cached, the player must connect before starting that day's official puzzle.

### Late synchronization

Offline operations retain original monotonic ordering and unique IDs. On reconnect, the client sends the operation log for the assigned puzzle version. The server verifies:

- Assignment belongs to the authenticated user.
- Puzzle ID, version, and content hash match.
- Operation sequence forms a legal solution-tree traversal.
- Completion was produced from a server-issued assignment.
- The assignment has not already received completion credit.
- Withdrawal or replacement policy permits acceptance.

Upload after `endsAt` is allowed for seven days because assignment validity was established before offline play. Upload time does not become the completion's local date. Outside that window, the server returns `expired_sync` and does not partially apply metrics.

For a normal correction, the previously assigned immutable version remains accepted for that assignment and can synchronize within the same seven-day window. For withdrawal caused by an invalid or unsound solution, incomplete attempts and offline completions not already accepted by the server are rejected with `puzzle_withdrawn`; the assignment is neutral for streak continuity and grants no Feed event. Other withdrawal reasons preserve existing assignments through their normal late-sync window. The privileged withdrawal operation must select one of these two policies explicitly; clients never infer it.

### Multi-device conflict resolution

- All devices address the same assignment and attempt.
- Server revision and idempotent operation IDs determine accepted order.
- First valid completion wins and freezes official metrics.
- Later completion uploads return `already_completed` with official server state; they do not overwrite time, errors, streak, or Feed data.
- If one device advances a different valid branch, another device refreshes to that branch. Client histories are never merged into an impossible path.
- Pending offline operations based on a stale branch are rejected with a conflict response and retained locally only long enough to explain that progress was superseded.

## Feed Integration

The first accepted official completion claims one `puzzle.completed` event with dedupe key:

```txt
puzzle.completed:{userId}:{assignmentId}
```

The event references user ID, assignment ID, publication ID, puzzle ID/version, official solve metrics, streak milestone if applicable, and authoritative completion time. It follows the Puzzle Activity privacy setting and all per-viewer rules in `Feed and Privacy.md`.

Retries, late sync, multi-device completion, replay, corrections, and streak recomputation MUST NOT create another Feed event. If official metrics are later marked unverified, projection may update the existing event while retaining `eventId` and ordering identity.

## Report Handling

Signed-in players may report the puzzle version assigned to them using an allowlisted reason:

- `incorrect_objective`
- `invalid_position`
- `incorrect_solution`
- `display_issue`
- `other`

Conceptual report schema:

```json
{
  "reportId": "stable ID",
  "reporterId": "userA",
  "assignmentId": "assignment01",
  "puzzleId": "checkers-0042",
  "puzzleVersion": 3,
  "reason": "incorrect_solution",
  "comment": "bounded sanitized text",
  "clientContext": {
    "appVersion": "1.4.0",
    "platform": "ios",
    "currentNodeId": "n2"
  },
  "status": "open",
  "createdAt": "server timestamp",
  "resolution": null
}
```

Submitting a report does not pause, reset, complete, penalize, or otherwise mutate the attempt. Reports are idempotent by a client-generated submission ID and rate-limited. Free text is length-bounded, sanitized for administrative display, access-controlled, and excluded from analytics logs.

Moderators can aggregate reports by exact puzzle version, inspect validation artifacts, and resolve them as `no_issue`, `corrected`, `withdrawn`, or `duplicate`. Reporter identity is not exposed to other players or Feed. Resolution may trigger correction or withdrawal workflows but MUST NOT directly edit published content or player attempts.

The player receives a generic submission confirmation without solution details. If a report leads to a correction or withdrawal, affected players receive player-safe status; staff notes remain private.

## API and Security Expectations

- All assignment, attempt, completion, timezone, and report operations require authentication.
- The server derives user ID from authentication, never request payload.
- Players can read only their own assignments, attempts, official metrics, and reports.
- Published puzzle APIs do not expose unreached solution nodes or staff metadata.
- Authoring, validation, publication, correction, withdrawal, and report moderation require audited privileged roles.
- Device timestamps and timezone values do not determine completion credit without server assignment state.
- Raw operation logs and reports follow bounded retention and data-minimization policies.
- Cache data is account-scoped and removed on sign-out under the Feed/privacy cache contract.

## Acceptance Criteria

1. The server selects a puzzle using server time and the user's stored valid IANA timezone, including correct 23-hour and 25-hour days.
2. Device clock or UTC-offset manipulation cannot select another official puzzle.
3. Changing timezone during an active player day preserves the current assignment; repeated backward and forward changes cannot create overlapping assignments or duplicate credit.
4. Puzzle family identity is independent from date, and every published version is immutable and content-hashed.
5. Every publication references a validated puzzle version and a pinned supported WCDF/rules-engine version.
6. Publishing two effective puzzles for the same game and publication date is rejected.
7. A correction creates a new version, preserves completed attempts, and cannot create another streak or Feed credit.
8. Withdrawal blocks new solving, preserves prior completions, and handles incomplete/offline attempts with an explicit deterministic result.
9. The solution tree accepts all authored equivalent branches, rejects nonauthored legal moves, and enforces mandatory captures, multi-jumps, and crowning under the pinned rules.
10. The official timer begins on first piece selection, excludes background time, stops once, and is not reset by Reset Puzzle.
11. Reset restores the root position while retaining timer, errors, hint state, and completion eligibility.
12. Exactly one completion and streak credit can be committed per assignment across concurrent devices and retries.
13. Streaks follow consecutive server-issued player days and are correctly repaired when valid offline completions arrive out of order.
14. A client without a cached server assignment cannot create an official offline attempt from its local date.
15. Valid late sync within retention preserves the original assignment; duplicate or stale-device sync returns canonical official state without overwriting it.
16. Exactly one privacy-controlled Feed event is created for first completion, regardless of retries, replay, corrections, or devices.
17. Reports reference the exact assigned version, are idempotent and rate-limited, do not change attempt state, and reveal no solution or reporter information publicly.
18. Replaying a completed puzzle cannot alter official time, errors, streak, completion, or Feed state.

## Verification

### Automated

- Unit-test local-date and midnight-boundary calculation across representative IANA zones, DST gaps/overlaps, half-hour and quarter-hour offsets, and tzdb updates.
- Property-test assignment intervals across randomized timezone changes, proving no overlap and no duplicate publication credit.
- Concurrency-test first assignment and first completion from multiple devices and repeated requests.
- Validate every publication in CI with the pinned WCDF/rules-engine version, including mandatory captures, multi-jumps, crowning, cycles, unreachable nodes, bad hashes, and objective failures.
- Snapshot-test immutable version canonicalization and content hashes.
- Integration-test draft, schedule, publish, correct, migrate, withdraw, replace, and completed-attempt preservation.
- Test timer segment reconciliation through foreground/background transitions, process death, wall-clock changes, reset, conflict, and unverified timing fallback.
- Test idempotency for every move, incorrect move, reset, completion, Feed outbox, and report operation.
- Test offline completion before and after assignment end, inside and outside late-sync retention, before and after withdrawal knowledge, and against a replacement version.
- Test out-of-order completion uploads and streak recomputation across timezone changes and withdrawn neutral days.
- Security-test ownership boundaries, privileged publication operations, unreached solution-node access, report access, and client attempts to spoof user, date, timezone revision, version, metrics, or completion time.
- Run emulator or staging authorization, transaction, query, and index tests against the selected database edition before deployment; physical Firestore structure remains an implementation decision.

### Manual

- Travel between timezones before and during a player day and confirm the active puzzle does not change until the assignment boundary.
- Solve across a daylight-saving transition and confirm timer and streak behavior.
- Start offline, reset, make mistakes, complete, reconnect after midnight, and confirm one official result and Feed row.
- Solve different branches on two devices, synchronize in both orders, and confirm first valid server completion remains authoritative.
- Publish a correction while one account is incomplete and another is complete; confirm deterministic migration and preserved credit.
- Withdraw a puzzle while online and offline clients have it open; confirm safe messaging and no accidental streak penalty or duplicate replacement credit.
- Submit each report reason, retry submission, and confirm attempt state is unchanged and moderation sees the exact version.

## Operational Observability

Monitor assignment creation conflicts, timezone revision frequency, skipped and overlapping interval attempts, publication validation failures, correction migrations, withdrawals, operation dedupe hits, revision conflicts, late-sync outcomes, timer verification failures, duplicate completion prevention, streak repairs, Feed outbox retries, and reports per puzzle version.

Operational logs MUST avoid board solutions, unreached moves, report free text, display names, and other unnecessary player data. Alerts should identify puzzle/version and reason codes so staff can act without exposing sensitive content.
