# Matchmaking Queue

## Scope

This specification defines the server-authoritative queue for automatic rated matchmaking. The initial implementation is Checkers, but all keys include the game so another game can use the same lifecycle without sharing queue eligibility.

Automatic matchmaking is always rated. Direct friend and AI matches do not enter this queue.

## Invariants

- A user has at most one live queue entry per game.
- A user with an awaiting or active match for the game cannot join the queue.
- Only the server reads authoritative Elo and derives League and Tier.
- Players from different broad Leagues are never paired.
- Same Tier is preferred, not mandatory after search expansion.
- Pairing, both queue state changes, and match creation are atomic.
- Cancellation cannot delete or invalidate a match that won the pairing race.
- An expired lease is never eligible for a new pairing.

## Queue Record

Use a stable key such as:

```txt
matchmaking/{game}/queue/{userId}
```

The record contains:

```txt
userId
game
generation: UUID
status: waiting | matched | cancelled | expired
ratingSnapshot
leagueSnapshot
tierSnapshot
region
latencyByRegion
joinedAt
updatedAt
leaseUntil
matchedAt
matchId
opponentId
terminalReason
```

`generation` identifies one join lifecycle. Every join creates a new generation. Heartbeat, cancel, and status requests must include it so a delayed request from an old screen cannot affect a newer queue session.

Rating, League, and Tier snapshots are server-produced. They support candidate lookup but are revalidated from authoritative user records during pairing. Client-provided values must be ignored.

## Lifecycle

### Join

`join(game, generation, connectionMeasurements)` runs transactionally:

1. Authenticate the user and validate game availability.
2. Reject if the user has an awaiting or active match for that game.
3. Read the authoritative per-game rating and derive broad League and Tier.
4. If an unexpired `waiting` entry exists, return it; do not reset `joinedAt` or create another generation.
5. If the caller reused the existing generation, return the existing terminal state rather than silently requeueing.
6. Otherwise create `waiting` with server `joinedAt`, `leaseUntil = serverNow + 30 seconds`, and sanitized region/latency data.

Joining is idempotent for a `(userId, game, generation)` tuple. A user must explicitly issue a new generation after a terminal queue state.

### Heartbeat and Lease

The client sends a heartbeat every 10 seconds while it wants matchmaking to continue. A valid heartbeat requires the authenticated owner, matching generation, and `waiting` state.

- Set `leaseUntil = serverNow + 30 seconds` and update `updatedAt`.
- Never change `joinedAt`, rating snapshot, League, or Tier on heartbeat.
- A heartbeat received at or after `leaseUntil` fails with `queue-lease-expired`; it does not revive the entry.
- Duplicate heartbeat command IDs are idempotent.
- App backgrounding may continue the queue only while the platform can maintain the lease. Push notification delivery does not extend it.

Workers treat `leaseUntil <= serverNow` as ineligible. Cleanup transactionally changes an unmatched expired entry from `waiting` to `expired` with terminal reason `lease_expired`. Correctness does not depend on immediate cleanup because candidate selection checks the lease.

### Waiting

Only a `waiting` entry with `leaseUntil > serverNow` is eligible. Search age is `serverNow - joinedAt`; client elapsed timers are display-only.

Candidate policy:

| Search age | Eligible candidates |
| --- | --- |
| 0-10 seconds | Same Tier, close Elo, preferred region |
| 10-20 seconds | Same Tier, expanded Elo range |
| 20-30 seconds | Same Tier, expanded regions and Elo range |
| 30 seconds or more | Any Tier in the same broad League |

The implementation may tune numeric Elo and latency weights without changing eligibility. Within the eligible set, rank candidates in this order:

1. Same Tier before a different Tier.
2. Smallest absolute Elo difference.
3. Best predicted mutual connection quality.
4. Earliest `joinedAt`.
5. Lexicographically smallest user ID as a deterministic tie-breaker.

Search expansion never crosses a broad League boundary, regardless of wait time. Diamond is one broad League and one Tier. Preferred color is a soft preference and never makes a candidate ineligible.

### Matched

`matched` means a match was durably created. Both queue entries store the same `matchId`, each other's user ID, and `matchedAt`. It is terminal for that generation. Clients must navigate to the referenced match rather than issue another join.

### Cancelled

`cancelled` means cancellation committed before pairing. It is terminal for that generation and has no match ID. The user may join again with a new generation.

### Expired

`expired` means the lease elapsed before pairing. It is terminal for that generation. The user may join again with a new generation.

## League and Tier Eligibility

The server derives League and Tier from current authoritative Elo using the ranges in `docs/Architecture.md`.

Before pairing, the transaction re-reads both users' ratings and derives both values again. If either differs from the queue snapshot, update that entry's snapshots and abort this pair attempt. The worker may reconsider the refreshed entries in a later attempt.

The broad League check is mandatory after refresh:

```txt
league(candidateA.authoritativeRating) == league(candidateB.authoritativeRating)
```

Same Tier candidates are preferred according to ranking. After 30 seconds, other Tiers in the same broad League are eligible. Neither client consent, low population, long wait, close Elo, nor good latency permits cross-League automatic pairing.

## Atomic Pairing

A worker proposes unordered users A and B and runs one serializable transaction:

1. Read both queue entries.
2. Verify distinct users, expected generations, `waiting` status, and `leaseUntil > serverNow` for both.
3. Verify neither user has an awaiting or active match for the game.
4. Read both authoritative ratings and derive League and Tier.
5. Abort and refresh snapshots if either queue snapshot is stale.
6. Verify the same broad League and current search-window eligibility.
7. Choose sides by balancing each player's recent assignments, using a server-random tie break recorded in the match. Clients do not choose a side in automatic matchmaking.
8. Create one match in `awaiting_players` with immutable game, mode `matchmaking`, rated status, players, rating snapshots for audit, time control, initial board, and ready deadline.
9. Change both queue entries to `matched` with the same match ID and reciprocal opponent IDs.
10. Write deterministic match-found outbox events for both users.

All writes commit together. The transaction must fail if the match ID already exists with different participants. Use a deterministic proposal ID or a transaction-generated unique ID so retries return the same pair result rather than creating duplicate matches.

No intermediate `claimed` state is externally visible. Database transaction conflicts are the lock: once one pairing commits an entry as `matched`, every competing pairing transaction involving that entry fails its `waiting` guard.

## Cancellation Race

`cancel(game, generation, commandId)` is a transaction over the user's queue record.

- If the matching generation is `waiting`, set it to `cancelled` and return `cancelled`.
- If it is already `cancelled`, return `cancelled` idempotently.
- If it is `expired`, return `expired`.
- If it is `matched`, return `matched` with `matchId`; do not alter either queue entry or the match.
- If the generation differs, return `stale-queue-generation` and do not affect the current entry.

Pairing and cancellation therefore have a single deterministic race outcome:

- Cancellation commits first: the pairing transaction fails because the entry is no longer `waiting`; no match is created.
- Pairing commits first: cancellation observes `matched` and returns the match; the client proceeds to it.

The UI may show a confirmation when it receives `matched`, but there is no server state in which cancellation succeeds while a match from the same generation also exists.

## Failure and Recovery

- Worker crashes before commit create no match and leave both entries waiting.
- Worker crashes after commit are recovered by reading `matched` queue entries and outbox events.
- Outbox delivery retries deduplicate on `(matchId, userId, match_found)`.
- If notification delivery fails, the match and ready deadline remain authoritative.
- A client reconnecting with its generation reads the current queue state and either resumes waiting, opens the match, or shows the terminal cancellation/expiry state.
- Orphan detection may alert on inconsistent historical data, but cleanup must never cancel a valid awaiting or active match.
- Administrative repair must preserve the match if either matched entry references a valid match with those participants.

## Security and Validation

- Clients may create requests through authenticated server APIs only; they cannot directly write queue or match records.
- The authenticated user must equal the queue owner.
- Region and latency samples are bounded and sanitized; they affect ranking only, never League eligibility.
- Rate-limit join, heartbeat, and cancel commands per user and device without shortening a valid lease due solely to throttling.
- Prevent self-pairing and pairing blocked or otherwise ineligible accounts.
- Log proposal ID, both generations, derived League/Tier, transaction outcome, and rejection reason without logging secrets.

## Acceptance Criteria

- Joining creates one `waiting` entry with server-derived rating, League, Tier, server `joinedAt`, and a 30-second lease.
- Repeating the same join generation is idempotent and does not reset queue age.
- Heartbeats extend only a matching, unexpired waiting generation; an expired generation cannot be revived.
- Entries at `leaseUntil` are ineligible and transition to `expired` without creating a match.
- Different broad Leagues are never paired, including after 30 seconds.
- Same Tier is ranked before another Tier in the same broad League; other Tiers become eligible after 30 seconds.
- Authoritative rating changes refresh stale snapshots and cannot produce a cross-League pair.
- One transaction creates the match, marks both entries matched, and writes both outbox events, or writes none of them.
- Two workers racing for one player can create at most one match involving that queue generation.
- A cancellation that commits first prevents pairing; a pairing that commits first causes cancel to return the match ID.
- A stale cancel generation cannot cancel a newer queue session.
- Side assignment never changes eligibility and is recorded immutably in the created match.
- Recovery after a worker or client restart reaches the committed state without duplicate matches or notifications.

## Verification

Automated verification must include:

1. **Lifecycle tests:** join replay, new generation, heartbeat extension, exact lease-boundary expiry, cleanup, reconnect, and terminal-state reads.
2. **Eligibility tests:** every League boundary, same-Tier preference, 10/20/30-second expansion boundaries, Diamond behavior, stale snapshot refresh, and permanent cross-League rejection.
3. **Concurrency tests:** two workers pairing the same entry, reciprocal proposals for the same pair, cancel versus pair in both commit orders, heartbeat versus expiry, and join versus an existing active match.
4. **Atomicity tests:** inject failure at every pairing write and assert there is no partial match, one-sided matched entry, or one-sided outbox event.
5. **Recovery tests:** restart workers and clients after commit but before response delivery, then assert the same match ID is returned and notifications remain deduplicated.

Tests must use an injectable server clock and a transactional datastore or emulator with real conflict behavior. Assertions must inspect both queue entries, the match, active-match guards, and outbox records.
