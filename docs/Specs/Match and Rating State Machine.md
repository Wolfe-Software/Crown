# Match and Rating State Machine

## Scope

This specification is authoritative for server-managed Checkers matches, results, competitive statistics, and Elo updates. Clients may predict board changes and clocks for presentation, but they never decide legality, timeouts, results, ratings, or statistics.

The Checkers rules baseline is the **WCDF Rules of Checkers (2012)**: [official WCDF PDF](https://wcdf.net/rules/rules_of_checkers_english.pdf). Crown uses the American/English 8x8 game described there. Product-specific clock, connectivity, automatic draw, and rating rules are defined below and take precedence where the WCDF rules do not define online service behavior.

## Terms

- **Jump:** one capture from one playable square to another, removing one opposing piece.
- **Complete turn:** one non-capturing move or the entire mandatory sequence of one or more jumps by the same piece.
- **Revision:** the monotonically increasing version of the authoritative match document.
- **Competitive result:** a non-void terminal result of a rated match.
- **Server time:** time from the server environment processing the transaction. Client timestamps are never used for ordering or deadlines.
- **Local date:** an ISO `YYYY-MM-DD` date calculated by the server in a player's snapshotted IANA time zone.

## Authoritative Match Record

The logical record must contain at least:

```txt
matchId
game: checkers
mode: matchmaking | friend | bot
rated: boolean
status: awaiting_players | active | completed | cancelled
revision: integer >= 0
players.black, players.white
ready.black, ready.white
readyDeadlineAt
boardState
sideToMove: black | white | null
forcedContinuationFrom: square | null
turnIndex: integer >= 0
jumpIndex: integer >= 0
quietKingPlyCount: integer >= 0
positionOccurrences: map<positionHash, integer>
remainingMilliseconds.black, remainingMilliseconds.white
turnDeadlineAt
connection.black, connection.white
disconnectDeadlineAt.black, disconnectDeadlineAt.white
result
rating
createdAt, startedAt, endedAt
```

`result` is null until completion. A completed result is immutable and contains:

```txt
outcome: black_win | white_win | draw | void
winnerSide: black | white | null
winnerId: userId | null
loserId: userId | null
reason: no_pieces | no_legal_move | resignation | timeout | disconnect |
        no_show | draw_repetition | draw_quiet_kings |
        both_no_show | administrative_void
finalizedRevision
finalizedAt
```

`rating` is null for unrated and void matches. For rated matches it records, for each player, the pre-rating, expected score, actual score, K-factor, unrounded delta, applied delta, post-rating, and pre-finalization rated game count. It also records `eloApplied`, `friendDailyLimitApplied`, and the ledger keys used.

## Match States

### `awaiting_players`

The server has created the match and assigned both sides, but both clients have not yet acknowledged readiness. The board cannot accept moves. `readyDeadlineAt` is set from server time when the match is created.

Allowed transitions:

| Trigger | Guard | Transition |
| --- | --- | --- |
| Player ready | Before deadline and player belongs to match | Remain `awaiting_players`; set that side ready |
| Second player ready | Before deadline | `active` |
| Ready deadline | Exactly one player ready; matchmaking mode | `completed` with `no_show`; ready player wins |
| Ready deadline | Exactly one player ready; friend mode | `completed` as `void` with `no_show`; no winner |
| Ready deadline | Neither player ready | `completed` with `both_no_show` and `void` |
| Administrative cancellation | No player has made a move | `cancelled` |

The ready window is 60 seconds. A player is ready only after an authenticated ready command is committed. Opening a screen or receiving a push notification is not readiness. Matchmade no-show wins are competitive results. Friend-match no-shows are `void` and create no rating, statistics, Feed, replay, match-index, or ad side effects.

### `active`

Both players are ready and the server has initialized the position, Black to move, clocks, `startedAt`, and `turnDeadlineAt`. Only this state accepts move, resign, connection, and timeout commands.

Allowed transitions:

| Trigger | Transition/result |
| --- | --- |
| Legal jump that has a mandatory continuation | Remain `active`; same side moves |
| Legal move or final jump completing a turn | Remain `active`; side changes |
| Opponent has no pieces after a jump | `completed`, `no_pieces` |
| Opponent has no legal turn after a complete turn | `completed`, `no_legal_move` |
| Resignation | `completed`, `resignation` |
| Active clock reaches zero | `completed`, `timeout` |
| Disconnect grace expires first | `completed`, `disconnect` |
| Third occurrence of the same position | `completed`, `draw_repetition` |
| Quiet-king limit reached | `completed`, `draw_quiet_kings` |
| Administrative void | `completed`, `administrative_void` and `void` |

### `completed`

The result, rating decision, ratings, statistics, and required ledgers have committed. No gameplay or result command can mutate the match. Duplicate commands return the existing terminal result.

### `cancelled`

The match was withdrawn before play and has no result. It updates neither ratings nor statistics. This state is terminal.

## Move and Turn Processing

Every online action is validated by the server against the authoritative position and WCDF move rules:

1. Verify authenticated player, `active` status, side to move, expected revision, and clock deadline.
2. If `forcedContinuationFrom` is non-null, accept only a jump by that piece.
3. Otherwise, if any capture exists for the side, reject every non-capture and every piece without a legal capture.
4. Apply exactly one submitted move segment. A submitted capture command represents one jump, not an entire multi-jump path.
5. Remove the captured piece and crown a man that reaches the king row.
6. If a man was crowned, the complete turn ends immediately under the WCDF rule, even if the new king could capture.
7. Otherwise, if the same piece can jump again, set `forcedContinuationFrom`, retain `sideToMove`, and retain the current clock deadline.
8. If no continuation exists, clear `forcedContinuationFrom`, increment `turnIndex`, change `sideToMove`, and start the opponent's deadline.
9. After each accepted segment, evaluate terminal board conditions before accepting another command.

Each accepted jump is independently durable and increments `jumpIndex` and `revision`. It creates a move event with `turnIndex`, zero-based `segmentIndex`, source, destination, captured square, crown flag, resulting position hash, actor, server timestamp, and idempotency key. A non-capturing move also creates one event. Replay and notation may group events sharing a `turnIndex`, but storage and conflict control operate per segment.

The moving player's clock runs through every jump in a multi-jump turn. It does not stop or reset between jumps.

## Revision and Idempotency

Every mutating command supplies:

```txt
commandId: client-generated UUID
expectedRevision: last revision observed by the client
commandType
payload
```

The server stores a command receipt keyed by `(matchId, actorId, commandId)` in the same transaction as the mutation. The receipt stores a canonical payload hash and the complete response.

- If the receipt exists and its payload hash matches, return the stored response without another mutation, even if `expectedRevision` is now stale.
- If the receipt exists with a different payload hash, reject with `idempotency-key-reused`.
- If no receipt exists and `expectedRevision != match.revision`, reject with `revision-conflict` and return the current revision and authoritative state.
- Every committed mutation, including ready, connection-state, jump, resignation, and finalization, increments revision once.
- Rejected commands do not increment revision or consume their command ID.

Receipts must be retained at least as long as the match record. Server-generated timeout and cleanup commands use deterministic IDs such as `timeout:{matchId}:{turnDeadlineAt}`.

## Server Clock and Deadlines

Every online human-vs-human Checkers match, including unrated friend play, uses 900,000 milliseconds per player and no increment.

At activation:

```txt
remainingMilliseconds.black = 900000
remainingMilliseconds.white = 900000
sideToMove = black
turnDeadlineAt = serverNow + 900000ms
```

For any command while active, the transaction compares `serverNow` to `turnDeadlineAt` before processing the requested action. If `serverNow >= turnDeadlineAt`, the side to move loses by timeout and the requested action is not applied.

When a complete turn ends at `serverNow`:

```txt
remainingMilliseconds[movingSide] = max(0, turnDeadlineAt - serverNow)
sideToMove = otherSide
turnDeadlineAt = serverNow + remainingMilliseconds[otherSide]
```

An individual jump that requires continuation does not change `turnDeadlineAt`. Displayed time is derived as `max(0, turnDeadlineAt - estimatedServerNow)` for the active side; persisted remaining time is only a checkpoint. Scheduled workers may finalize expired clocks, but correctness must not depend on prompt delivery: every later transaction performs the same deadline check.

AI matches do not use this server clock. Any future time control must be snapshotted into the match and use the same deadline semantics.

## Disconnects and No-Shows

Authenticated presence changes are advisory; missing heartbeats alone do not alter the board or pause a clock.

- Clients heartbeat every 10 seconds while connected.
- After 30 seconds without a heartbeat, the server marks the side disconnected and sets a one-time `disconnectDeadlineAt = serverNow + 90 seconds`.
- Reconnection before that deadline clears it. Repeated connection events are idempotent.
- The game clock continues while disconnected.
- If the active clock expires first, the result is `timeout`.
- If the disconnect deadline expires first, the disconnected player loses with reason `disconnect`.
- If both players are disconnected, each deadline remains independent. The first terminal deadline observed wins; if equal to the millisecond, the match is a `void` administrative result requiring no rating or statistics update.
- A disconnect after a terminal result has no effect.

No-show handling applies only before activation and uses `readyDeadlineAt` as described above. No disconnect grace is added to the ready window.

## Draws

Crown supports the automatic draw paths in [[Checkers Rules]]:

- `draw_repetition`: the same canonical position occurs for the third time. The hash includes every piece square and king/man state, side to move, and `forcedContinuationFrom`. It excludes clocks, revision, and cosmetics. Occurrences are counted after complete turns and at the initial position only, never during an incomplete capture sequence.
- `draw_quiet_kings`: 80 consecutive complete turns are made only by kings without a capture. A capture or any turn by a man resets the counter to zero. The server adjudicates automatically after the complete turn that reaches 80.

Draw offers and draws by agreement are not included in the MVP.

Automatic board win conditions are evaluated before draw conditions. Thus a final capture producing `no_pieces` wins before `draw_quiet_kings` can apply.

## Resignation and Result Precedence

A valid resignation by an active player immediately loses the match. If multiple terminal events race, transaction serialization and this order determine the result at the transaction's server time:

1. Existing terminal result
2. Active clock deadline already reached
3. Disconnect deadline already reached
4. Submitted resignation
5. Board win caused by the submitted move
6. Automatic draw caused by the submitted move

This prevents a move, resignation, or draw acceptance submitted at or after a deadline from replacing a timeout or disconnect result.

## Elo Calculation

Ratings are per game. Checkers starts at 800. For player A against player B, use standard Elo with base 10 and a 400-point scale:

```txt
expectedA = 1 / (1 + 10 ^ ((ratingB - ratingA) / 400))
scoreA = 1 for a win, 0.5 for a draw, 0 for a loss
rawDeltaA = kA * (scoreA - expectedA)
roundedDeltaA = roundHalfAwayFromZero(rawDeltaA)
ratingAfterA = max(0, ratingA + roundedDeltaA)
appliedDeltaA = ratingAfterA - ratingA
```

Calculate each player independently from both pre-match ratings. Do not derive one delta by negating the other; K-factors may differ. Use at least IEEE-754 double precision and do not round the expected score or raw delta before final rounding.

Half away from zero means `1.5 -> 2`, `-1.5 -> -2`, `1.49 -> 1`, and `-1.49 -> -1`. The rating floor is zero. `appliedDelta`, not the pre-floor rounded delta, is displayed and stored as the rating change.

Choose K from the player's pre-finalization completed rated game count:

| Rated games already completed | Rating before match | K |
| --- | --- | --- |
| 0-9 | Any | 64 |
| 10-29 | Any | 40 |
| 30 or more | Below 1800 | 24 |
| 30 or more | 1800 or above | 16 |

This implements K=64 for games 1-10, K=40 for games 11-30, then K=24 below 1800 or K=16 at/above 1800.

## Rated Friend Daily Pair Limit

Rated friend matches remain marked rated and produce competitive statistics, but only the first three eligible pair results per each player's local date may alter Elo.

At match creation, the server snapshots each player's validated IANA time zone from their profile. If absent or invalid, use `UTC`. At finalization, calculate each player's local date from `finalizedAt` in that player's snapshot. Client-supplied dates or offsets are ignored.

For an unordered pair A/B, use two ledger slots:

```txt
friendRatingDaily/{game}/{playerA}/{localDateA}/{playerB}
friendRatingDaily/{game}/{playerB}/{localDateB}/{playerA}
```

Each ledger stores `appliedCount` and the match IDs that consumed slots. A result changes Elo only when both ledgers have `appliedCount < 3` in the finalization transaction.

- If both have a slot, increment both ledgers atomically and apply both players' calculated Elo deltas.
- If either has no slot, increment neither ledger and set both applied Elo deltas to zero.
- A later result can never consume only one player's slot.
- Ledger membership by `matchId` makes retries idempotent.
- Commit order defines which three concurrently finalized pair results receive the slots.
- Draws and decisive competitive results each consume one slot when eligible.
- Void and unrated matches consume no slot.
- Matchmaking is not subject to this friend limit.

A capped rated friend match still updates rated games and result statistics. Its rating before and after are equal, and the result records `eloApplied = false` with `friendDailyLimitApplied = true`.

## Competitive Statistics

Every non-void rated result, including rated friend results with zero Elo delta, atomically updates each player's per-game statistics:

- Increment `gamesPlayed` by one.
- Increment exactly one of `wins`, `losses`, or `draws`.
- On a win, increment `winStreak` and set `bestWinStreak = max(bestWinStreak, winStreak)`.
- On a loss or draw, set `winStreak` to zero.
- Derive rates for display from integer totals; do not maintain independently mutable percentage fields.
- Refresh cached League and Tier from the post-match authoritative rating, even when the delta is zero.

Unrated, bot, cancelled, and void matches do not update competitive statistics. Feed/replay records are separate side effects and do not define whether a result is competitive.

## Atomic Finalization

Finalization is one serializable transaction. It must:

1. Re-read the match and return its stored result if already terminal.
2. Verify the expected active or awaiting state and terminal trigger.
3. Read both authoritative user rating/stat records.
4. For rated friend matches, read and conditionally consume both daily-ledger slots.
5. Calculate both ratings and statistics from values read in this transaction.
6. Write both user records and derived League/Tier caches when the result is competitive.
7. Write any consumed friend ledgers.
8. Write the immutable result and rating audit to the match, set `endedAt`, increment revision, and set `status = completed`.
9. Write deterministic outbox records for feed, notification, and replay-completion side effects. Analytics is client-emitted only after a consented device observes the server-confirmed transition; outbox records never queue GA payloads.

No client may observe a completed match whose required ratings, statistics, or ledgers were not committed. Outbox consumers may run later and must deduplicate by `(matchId, eventType)`. Transaction retries recalculate from newly read values; they must not reuse stale rating snapshots. A failure commits none of these writes.

## Acceptance Criteria

- The official WCDF 2012 rules PDF is linked, and legal-move tests cover mandatory capture, same-piece continuation, and turn-ending crowning.
- A multi-jump sequence stores one event and one revision per jump while changing side and incrementing `turnIndex` only after the final jump.
- Duplicate commands with the same ID and payload return the original response without changing revision; changed payloads with the same ID fail.
- A stale revision is rejected without changing board, clock, result, or statistics.
- A command at exactly `turnDeadlineAt` loses by timeout and cannot apply its requested move, draw, or resignation.
- The clock deadline remains unchanged between jumps of one capture sequence.
- No-show, timeout, disconnect, resignation, no-pieces, no-legal-move, automatic-draw, void, and cancellation paths produce only the states/results specified above.
- Repetition ignores clocks and cosmetics but distinguishes side to move, piece rank, and forced continuation.
- Elo tests use base 10/400, scores 1/0.5/0, the four K cases, half-away-from-zero rounding, and a zero rating floor.
- Players with different K-factors are calculated independently.
- The first three rated friend pair results alter Elo only when both local-date ledgers have capacity; later results have zero delta and do not consume either ledger.
- A capped rated friend result still updates games played, win/loss/draw, and streak statistics.
- Concurrent finalization attempts produce one immutable result and one update per player.
- A completed result, both user updates, both friend ledgers when applicable, and outbox records are all committed or none are committed.

## Verification

Implementations must provide automated tests at three levels:

1. **Pure rule tests:** WCDF move generation, position hashing, draw counters, Elo vectors, K boundaries at games 10/11/30/31, rounding at positive and negative halves, and rating floor behavior.
2. **Transactional tests:** command replay, reused keys, stale revisions, simultaneous terminal commands, friend-ledger limits across different local dates, concurrent match finalization, and rollback on an injected write failure.
3. **Clock integration tests:** use an injectable server clock to test one millisecond before, exactly at, and after ready, turn, and disconnect deadlines; verify multi-jump deadlines and deadline/result precedence.

The verification suite must assert persisted records, not only API responses. It must run with at least two finalizers racing the same match and two rated friend matches racing for the last daily slot.
