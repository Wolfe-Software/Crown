# Backend Contracts

## 1. Status and Scope

This document is the implementation contract for Crown's Firebase Authentication, Cloud Firestore, Cloud Functions, Cloud Tasks, Firebase Cloud Messaging, and server-confirmed telemetry boundaries. It supersedes conflicting backend examples elsewhere in the documentation.

The launch contract is intentionally limited to:

- Checkers under WCDF English draughts rules.
- Persistent, nonseasonal Elo and Elo-derived League/Tier placement.
- Rated automatic matchmaking, rated or unrated friend matches, and unrated bot matches.
- Friends, invitations, a privacy-aware activity feed, player-local daily puzzles, bundled appearance options, and ads.
- No purchases, subscriptions, store products, currencies, paid entitlements, seasonal ladders, seasonal resets, or seasonal rewards.
- Replay access for exactly each player's latest 50 completed non-void matches.

The schema targets Firestore Standard edition in Native mode. Development uses Firebase project `crown-chess-and-checkers-dev`; production uses `crown-chess-and-checkers`. Both use the `(default)` database in `nam5`, with Cloud Functions and Cloud Tasks in `us-central1`, as defined in [[Firebase Environments and Services]].

## 2. Contract Conventions

### 2.1 Primitive types

| Notation | Firestore type | Contract |
| --- | --- | --- |
| `string` | string | UTF-8; field-specific maximums apply |
| `int` | integer | Signed 64-bit; never use doubles for counters, ratings, revisions, or durations |
| `bool` | boolean | `true` or `false` |
| `timestamp` | timestamp | UTC Firestore `Timestamp`; authoritative timestamps use server time |
| `map<T>` | map | Keys and values are constrained by the declared schema |
| `list<T>` | array | Ordered; maximum length is declared where relevant |
| `null` | null | Allowed only when explicitly marked nullable |

Unknown fields are rejected by callable validation and by rules on client-writable documents. Enum values are lowercase ASCII strings. IDs are opaque Firestore document IDs unless a deterministic format is specified. No client may use an email address, display name, device identifier, or FCM token as a document ID.

### 2.2 Common enums

```text
Game = checkers
Ruleset = checkers-wcdf-gayp-v1.0.0
Side = black | white
PieceKind = man | king
MatchMode = matchmaking | friend | bot
MatchStatus = awaiting_players | active | completed | cancelled
MatchResult = black_win | white_win | draw | void | none
ResultReason = no_pieces | no_legal_move | resignation | timeout | disconnect | no_show | both_no_show | draw_repetition | draw_quiet_kings | administrative_void | none
FriendshipStatus = pending | accepted
InvitationStatus = pending | accepted | declined | cancelled | expired
FeedType = match.completed | puzzle.completed | league.changed | friend.requested | friend.accepted | system.announcement
FeedAudience = private | friends
Visibility = private | friends
QueueStatus = waiting | matched | cancelled | expired
DevicePlatform = ios | android
```

`none` is used for non-nullable state-machine enum fields. Nullable references and timestamps use Firestore `null`.

### 2.3 IDs and pair keys

- `uid`: Firebase Auth UID, 1-128 characters.
- `pairId`: `base64url(utf8(min(uidA,uidB))) + "." + base64url(utf8(max(uidA,uidB)))`, with padding omitted. A user cannot pair with themselves.
- `requestId`: client-generated UUIDv4, unique per authenticated user and logical mutation.
- `matchId`, `invitationId`, `eventId`: server-generated random Firestore IDs.
- `moveId`: zero-padded six-digit jump/event index, for example `000012`.
- `localDate`: Gregorian date `YYYY-MM-DD` in the player's effective IANA time zone.
- `puzzleId`: opaque stable authored-family ID; publication and assignment records carry dates separately.

### 2.4 Authority, nullability, and deletion

- Firebase Auth is authoritative for identity. Firestore never stores passwords or provider credentials.
- Cloud Functions using the Admin SDK own all competitive, social-state, feed, puzzle-completion, replay-retention, and ad-counter writes.
- Clients may directly update only the narrowly listed private preference fields and device-token documents, if rules implement the validation in this specification. Using callables for those writes is preferred.
- Required fields must exist even when their value is `null`. Omission is permitted only for fields explicitly described as optional.
- The schema reserves `deletion_pending` and cleanup interfaces, but final account-deletion, anonymization, retention, and legal behavior is a launch-readiness contract governed by [[Specs/Auth Account and Offline]]. The development MVP must not claim a deletion SLA that has not received legal and product approval.
- Firestore TTL is cleanup, not authorization. Rules and callables must treat expired records as expired before TTL removes them.

### 2.5 Telemetry ownership and redaction

[[Analytics Measurement Plan]] and [[Analytics Event Catalog]] govern consent, identity, event names, and parameters. The backend owns authoritative product transitions and idempotency facts, but it does not send GA4 events and does not store a queue of GA payloads.

- A server-confirmed response or readable state may tell a consented client that a catalog transition occurred now. The client emits only after observing that transition while optional-data consent is granted.
- Product outbox records support Feed, notification, replay, and cleanup side effects only. They never replay Analytics for a period when a device was denied or offline.
- Server responses return only fields required by the callable contract. They do not add Analytics-specific IDs, opponent attributes, or free-form diagnostic text.
- Logs, Error Reporting, task payloads, and support diagnostics must redact tokens, credentials, emails, handles, Firebase UIDs where not operationally necessary, notification contents, board histories, and raw request/response bodies.
- Stable Crown error enums may be used in allowlisted diagnostics. Dynamic provider text, Firestore paths, domain-record IDs, and player-entered text must not enter Crashlytics or Performance Monitoring.
- Telemetry failure is non-transactional and cannot fail, delay, retry, or roll back a match, rating, friendship, puzzle, replay, account, or ad operation.

## 3. WCDF Game Contract

`checkers-wcdf-gayp-v1.0.0` is the only accepted MVP ruleset. The server and client engines must share immutable conformance vectors for this version.

- Board: 8 by 8 with 32 playable dark squares, numbered 1 through 32.
- Initial material: 12 black men and 12 white men.
- Black moves first.
- Men move diagonally forward; kings move diagonally forward or backward.
- Captures are compulsory. When more than one capture is legal, the player may select any legal WCDF sequence; the backend must not invent a maximum-capture rule.
- A capturing piece must continue for the complete legal sequence. Online clients submit one jump at a time; the server preserves the same side and piece until the complete turn ends.
- A man reaching the king row is crowned and its turn ends, as required by English draughts.
- Win, draw, repetition, move-count, clock, and adjudication behavior must be produced by the versioned WCDF rules engine, not duplicated in callable handlers.

Canonical board state:

```ts
type BoardState = {
  blackMen: number[];   // unique playable squares, ascending
  blackKings: number[];
  whiteMen: number[];
  whiteKings: number[];
  sideToMove: "black" | "white";
  forcedFrom: number | null; // null at persisted turn boundaries
};
```

All square lists are disjoint, contain integers from 1 through 32, and contain no more than 12 entries per side. The server canonicalizes ordering before hashing. `positionHash` is the lowercase hex SHA-256 of the canonical ruleset ID plus canonical board encoding and repetition-relevant state.

## 4. Public and Private Resource Boundary

Public-safe and private data are stored in different documents because Firestore rules cannot hide individual fields in an otherwise readable document.

| Path | Client read | Client write | Owner / purpose |
| --- | --- | --- | --- |
| `/publicProfiles/{uid}` | Subject to profile visibility | Never | Server-built public identity and leaderboard projection |
| `/users/{uid}` | Owner only | Limited preferences or callable only | Private account, stats, privacy, local-day settings |
| `/appearanceBoards/{boardId}` and `/appearancePieceSets/{pieceSetId}` | Any authenticated user | Never | Bundled MVP appearance catalogs |
| `/puzzleFamilies/{puzzleId}/versions/{version}` and `/puzzlePublications/{publicationId}` | Authenticated assigned user through API | Never | Immutable puzzle prompt/version and publication metadata |
| `/puzzleSolutions/{puzzleId}/versions/{version}` | Never | Never | Server-only authored solution tree |
| `/matches/{matchId}` | Active participants; completed replay grantees | Never | Authoritative match state |
| Other paths in this specification | Explicit participants/owner only | Never unless stated | Server-controlled workflow state |

An authenticated user is not automatically permitted to list all profiles. Profile search and discovery use callable APIs that apply privacy and blocking checks. Rules may allow `get` of an eligible profile but should deny unrestricted collection `list` unless the query constraints are provably safe.

## 5. Resource Contracts

### 5.1 Public profiles

Path: `/publicProfiles/{uid}`

```ts
{
  uid: string;
  displayName: string;                 // 1-30 trimmed grapheme clusters
  normalizedDisplayName: string;       // server-generated search key
  handle: string;                      // globally unique, player-facing identifier
  normalizedHandle: string;            // lowercase uniqueness key
  createdAt: timestamp;
  checkersRating: int;                 // >= 0, starts at 800
  checkersGamesPlayed: int;            // completed rated matches only
  checkersLeague: "bronze" | "silver" | "gold" | "platinum" | "diamond";
  checkersTier: "iii" | "ii" | "i" | "diamond";
  pieceSetId: string;
  profileVisibility: Visibility;
  leagueVisibility: Visibility;
  appearanceVisibility: Visibility;
  updatedAt: timestamp;
}
```

The server derives League and Tier directly from current Elo. `normalizedHandle` is reserved transactionally and is the exact lookup key for friend search; duplicate display names are allowed. `private` and `friends` are the only player-controlled visibility values accepted in the MVP. The authenticated same-Tier leaderboard is a limited-disclosure query that returns only rank, handle, display name, rating, Tier, and appearance marker; it does not grant full profile access. There is no season ID, League XP, weekly placement, reset, or independently mutable League rank. Public profile documents contain no email, provider data, birth date, time zone, notification setting, token, exact activity timestamp, friend list, or puzzle attempt.

### 5.2 Private users

Path: `/users/{uid}`

```ts
{
  schemaVersion: 1;
  createdAt: timestamp;
  updatedAt: timestamp;
  lastActiveAt: timestamp;
  accountStatus: "active" | "deletion_pending" | "disabled";
  timeZone: string;                    // canonical IANA zone
  timeZoneEffectiveAt: timestamp;
  pendingTimeZone: string | null;
  pendingTimeZoneEffectiveAt: timestamp | null;
  stats: {
    checkers: {
      rating: int;
      peakRating: int;
      ratedGames: int;
      wins: int;
      losses: int;
      draws: int;
      currentWinStreak: int;
      bestWinStreak: int;
    };
  };
  puzzleStats: {
    completed: int;
    currentStreak: int;
    bestStreak: int;
    lastCompletedLocalDate: string | null;
    totalSolveSeconds: int;
  };
  botState: {
    checkers: {
      nextPlayerSide: Side;             // Black for first game, then alternates
      adaptiveStrength: int;
      revision: int;
    };
  };
  privacy: {
    profile: Visibility;
    onlineStatus: Visibility;
    currentGame: Visibility;
    matchHistory: Visibility;
    puzzleActivity: Visibility;
    friendshipActivity: Visibility;
    friendsList: Visibility;
    league: Visibility;
    appearance: Visibility;
    allowFriendRequests: "nobody" | "friends_of_friends" | "everyone";
  };
  notifications: {
    friendRequests: bool;
    invitations: bool;
    dailyPuzzle: bool;
    matchReady: bool;
  };
  boardId: string;
  pieceSetId: string;
}
```

Ownership is the path `uid`. Stats, status, effective time-zone fields, and timestamps are server-only. A requested time-zone change becomes effective at the later of the next midnight in the old zone and the next midnight in the new zone. This prevents obtaining two daily puzzles or duplicate daily credit by changing zones.

Feed visibility maps `matches -> matchHistory`, `puzzles -> puzzleActivity`, `league -> league`, and `friendships -> friendshipActivity`.

Private user data is retained until account deletion. `lastActiveAt` updates are server-throttled to at most once per 15 minutes.

### 5.3 Bundled appearance

Paths:

```text
/appearanceBoards/{boardId}
/appearancePieceSets/{pieceSetId}
```

Board record:

```ts
{
  boardId: string;
  name: string;
  status: "active" | "retired";
  sortOrder: int;
  boardAssetKey: string;
  createdAt: timestamp;
  updatedAt: timestamp;
}
```

Piece-set record:

```ts
{
  pieceSetId: string;
  name: string;
  status: "active" | "retired";
  sortOrder: int;
  blackManAssetKey: string;
  blackKingAssetKey: string;
  whiteManAssetKey: string;
  whiteKingAssetKey: string;
  createdAt: timestamp;
  updatedAt: timestamp;
}
```

Every active board and piece set is independently selectable by every authenticated user. There are no frames, selectable effects, selectable sounds, prices, products, receipts, purchases, ownership documents, paid entitlements, rarity-driven availability, or subscription gates.

Matches snapshot each player's piece-set ID at creation. Board presentation is viewer-local and uses that viewer's selected bundled board; it does not alter authoritative state or replay data. Retired piece sets remain replay-readable but cannot be newly selected.

### 5.4 Matches

Path: `/matches/{matchId}`

```ts
{
  schemaVersion: 1;
  game: Game;
  ruleset: Ruleset;
  mode: MatchMode;
  rated: bool;
  status: MatchStatus;
  participants: {
    blackUid: string | null;             // null only for bot side
    whiteUid: string | null;
  };
  participantUids: string[];             // unique human UIDs, sorted, length 1 or 2
  participantSnapshots: map<map>;        // keyed by UID: displayName, handle, rating, League, Tier, pieceSetId at creation
  participantTimeZones: map<string>;     // keyed by UID; IANA zones snapshotted at match creation
  bot: {
    side: Side;
    adaptiveStrength: int;
    engineVersion: string;
  } | null;
  appearance: {
    blackPieceSetId: string;
    whitePieceSetId: string;
  };
  initialBoard: BoardState;
  board: BoardState;
  positionHash: string;
  revision: int;                         // increments once per accepted command or jump
  turnIndex: int;                        // complete-turn index
  jumpIndex: int;                        // immutable event sequence
  forcedContinuationFrom: int | null;
  ready: {
    black: bool;
    white: bool;
  } | null;
  readyDeadlineAt: timestamp | null;
  clock: {
    initialMilliseconds: int;            // 900000 for every online human-vs-human MVP match
    incrementMilliseconds: int;          // 0 for MVP
    blackRemainingMs: int;
    whiteRemainingMs: int;
    runningSide: Side | null;
    turnDeadlineAt: timestamp | null;
  } | null;                              // null for untimed bot matches
  disconnectDeadlineAt: {
    black: timestamp | null;
    white: timestamp | null;
  } | null;
  connection: {
    black: { status: "connected" | "disconnected"; lastHeartbeatAt: timestamp | null };
    white: { status: "connected" | "disconnected"; lastHeartbeatAt: timestamp | null };
  } | null;
  ratingsBefore: map<int> | null;        // string UID keys, integer values; null when unrated
  ratingsAfter: map<int> | null;         // string UID keys; null until rated completion or always when unrated
  ratingAudit: map<map> | null;          // per UID: expected, score, K, raw/applied delta, pre/post, game count
  eloApplied: bool | null;
  friendDailyLimitApplied: bool | null;
  friendRatingLedgerKeys: string[];
  result: MatchResult;
  resultReason: ResultReason;
  winnerUid: string | null;
  createdAt: timestamp;
  startedAt: timestamp | null;            // null while awaiting players
  lastMoveAt: timestamp | null;
  endedAt: timestamp | null;
  invitationId: string | null;
  completionVersion: int | null;
  rulesState: {
    positionOccurrences: map<int>;
    quietKingPlyCount: int;              // resets on capture or any man turn; increments only for noncapturing king turns
  };
}
```

Invariants:

- Matchmaking is always rated; bot is always unrated; friend matches use the immutable invitation value.
- Two-human matches contain two distinct non-null participant UIDs. Bot matches contain exactly one human UID and one null side.
- Awaiting and active matches have `result = none`, `resultReason = none`, `winnerUid = null`, `endedAt = null`, and `ratingsAfter = null`.
- Completed matches have a terminal result/reason and non-null `endedAt`. Draws and void results have `winnerUid = null`.
- Cancelled matches have no competitive result and no rating, statistics, Feed-result, ad, or replay side effects.
- `ratingsBefore`, `ratingsAfter`, and `ratingAudit` contain exactly both human UIDs for a completed non-void rated match. They are null for void and unrated matches.
- Board, clocks, turn, ratings, result, appearance, participants, and status are server-only.
- Match completion and its competitive effects happen once under `completionVersion = 1`.

Active match documents are retained until completion or abort. Completed summaries are retained for 400 days for support and abuse investigation, then may be anonymized or deleted. Replay payload retention is governed separately by the latest-50 contract.

### 5.5 Moves

Path: `/matches/{matchId}/moves/{moveId}`

```ts
{
  jumpIndex: int;                        // equals document ID numerically
  turnIndex: int;
  segmentIndex: int;
  actorUid: string | null;               // null for bot
  side: Side;
  from: int;
  to: int;
  capturedSquare: int | null;
  crowned: bool;
  boardBeforeHash: string;
  boardAfterHash: string;
  clientActionId: string | null;          // request ID for a human move
  serverReceivedAt: timestamp;
  clockAfter: {
    blackRemainingMs: int;
    whiteRemainingMs: int;
  } | null;
}
```

A move document is immutable and represents one step or one jump. Its creation and the parent match update occur in the same transaction. The transaction rejects a `jumpIndex` other than the parent's next event index, a stale revision/hash, the wrong actor, an illegal segment, or a move by a different piece while `forcedContinuationFrom` is set. Events sharing a `turnIndex` form one complete multi-capture turn. Side and clock transfer occur only after the final required jump.

### 5.6 Per-player match indexes and latest-50 replay grants

Paths:

```text
/users/{uid}/matchIndex/{matchId}
/matches/{matchId}/replayGrants/{uid}
```

Match index document:

```ts
{
  matchId: string;
  opponentUid: string | null;
  opponentDisplayName: string;
  game: Game;
  mode: MatchMode;
  rated: bool;
  playerSide: Side;
  playerResult: "win" | "loss" | "draw";
  ratingBefore: int | null;
  ratingAfter: int | null;
  eloApplied: bool | null;
  friendDailyLimitApplied: bool | null;
  playerLeagueBefore: string | null;
  playerTierBefore: string | null;
  playerLeagueAfter: string | null;
  playerTierAfter: string | null;
  durationMilliseconds: int;
  completedAt: timestamp;
  replayAvailable: bool;                 // true while matching grant exists
}
```

Replay grant document:

```ts
{
  uid: string;
  completedAt: timestamp;
  rankBasis: "latest_50";
  createdAt: timestamp;
}
```

For every completed non-void match, the server writes one match-index document and one replay grant for each human participant. Void and cancelled matches remain server-retained for diagnostics but create no player history, replay, Feed, statistics, rating, ledger-slot, or ad side effects. The index is owned/readable only by that player. A completed match and its moves are readable only when the caller has its replay grant.

In the critical completion transaction, the server queries each player's current granted indexes, adds the new match, orders the set by `(completedAt desc, matchId desc)`, retains the first 50 with `replayAvailable = true`, and removes the grant and sets `replayAvailable = false` for the displaced entry, if any. The transaction reads no more than 50 existing granted indexes per participant and conflicts with another completion affecting the same player. A player therefore has no more than 50 grants at any committed state. The index summary may remain with `replayAvailable = false` until its 400-day TTL, but UI replay queries always use `replayAvailable == true` and `limit(50)`.

A match's moves are retained while at least one human participant has a grant. When the last grant is removed, a server cleanup job deletes all moves after a 24-hour grace period. Thus both players independently retain their own latest 50, even if the match has fallen out of the opponent's latest 50. Direct document IDs cannot bypass this authorization.

### 5.7 Player local-day ledgers

Paths:

```text
/users/{uid}/localDays/{localDate}
/users/{uid}/localDays/{localDate}/matches/{matchId}
```

Ledger document:

```ts
{
  localDate: string;
  timeZone: string;
  openedAt: timestamp;
  updatedAt: timestamp;
  completedMatches: int;
  ratedMatches: int;
  eligibleAdMatches: int;
  puzzleId: string | null;
  puzzleCompleted: bool;
}
```

Match ledger entry:

```ts
{
  matchId: string;
  completedAt: timestamp;
  localDate: string;
  timeZone: string;
  mode: MatchMode;
  rated: bool;
  playerResult: "win" | "loss" | "draw" | "aborted";
  adEligible: bool;
}
```

At match completion, the server computes `localDate` separately for each human participant using that player's effective time zone snapshot. It writes a deterministic ledger entry and increments the matching aggregate for both players in the same critical completion transaction. The two players may therefore receive different local dates. A bot match writes only the human player's ledger.

The deterministic `{matchId}` entry is the idempotency guard for aggregate increments. Local-day ledgers and entries are private and retained for 400 days.

Rated friend Elo uses an additional per-opponent ledger:

```text
/users/{uid}/friendRatingDays/{localDate}/opponents/{opponentUid}
```

```ts
{
  uid: string;
  opponentUid: string;
  localDate: string;
  timeZoneSnapshot: string;
  appliedCount: int;                    // 0-3
  appliedMatchIds: string[];            // at most 3, finalization order
  updatedAt: timestamp;
}
```

The rated-friend finalization transaction reads both players' ledgers for their independently computed local dates. Elo applies only when both `appliedCount` values are below three. An eligible result increments both and appends the same match ID atomically. If either ledger is full, neither changes, the rated result still updates rated aggregate statistics, and both Elo deltas are zero.

### 5.8 Matchmaking queue

Path: `/matchmaking/{game}/queue/{uid}`

```ts
{
  userId: string;
  game: Game;
  generation: string;                    // client UUID for one queue lifecycle
  status: QueueStatus;
  ratingSnapshot: int;
  leagueSnapshot: "bronze" | "silver" | "gold" | "platinum" | "diamond";
  tierSnapshot: "iii" | "ii" | "i" | "diamond";
  region: string;
  latencyByRegion: map<int>;
  joinedAt: timestamp;
  updatedAt: timestamp;
  leaseUntil: timestamp;
  matchedAt: timestamp | null;
  matchId: string | null;
  opponentId: string | null;
  terminalReason: string | null;
  appVersion: string;
}
```

One queue entry exists per user. Callables snapshot authoritative rating/League/Tier and reject users already queued or in an active online match. Matching requires the same broad League, prefers the same Tier, then minimizes Elo distance and latency. Search expansion never crosses a broad League. Clients cannot choose color; the pairing service balances recent side assignments and uses a cryptographically secure tie break.

Queue leases last 30 seconds and clients heartbeat every 10 seconds while waiting. Heartbeat, cancel, and status requests include `generation`, so a delayed request cannot affect a newer queue session. Expired entries are ineligible even before cleanup. Pairing atomically revalidates two waiting leases, creates exactly one `awaiting_players` match, and changes both entries to `matched` with the same match ID. Terminal entries remain long enough for reconnecting clients to resolve the lifecycle before cleanup. The complete transition and cancellation-race contract is [[Specs/Matchmaking Queue]].

### 5.9 Friendships and requests

Path: `/friendships/{pairId}`

```ts
{
  pairId: string;
  generationId: string;                  // new server UUID each time a deleted pair reconnects
  memberUids: string[];                  // exactly two, sorted
  status: FriendshipStatus;
  requesterUid: string;
  recipientUid: string;
  createdAt: timestamp;
  updatedAt: timestamp;
  acceptedAt: timestamp | null;
}
```

The deterministic friendship document is the canonical request and accepted-relationship state. Only the two members may read it. Decline, sender cancellation, and friend removal delete the canonical document after writing required outbox events.

Sending a crossed request atomically changes `pending` to `accepted`. Accepting changes the same document to `accepted`. Existing friendship, block, privacy, pending request, and self-request checks are server-side. Removing a friendship also cancels pending invitations for the pair but does not delete historical matches or Feed source events.

Accepted Friends pagination uses a server-maintained projection at `/users/{uid}/friendsIndex/{friendUid}` containing `friendUid`, `generationId`, `displayName`, `normalizedDisplayName`, `handle`, and `updatedAt`. Acceptance writes both users' projections transactionally. Display-name changes update affected projections through an idempotent outbox. The projection is a query index only; authorization always rechecks the canonical friendship generation.

### 5.10 Match invitations

Path: `/matchInvitations/{invitationId}`

```ts
{
  senderUid: string;
  recipientUid: string;
  pairId: string;
  slotKey: string;                       // pairId + ":" + game
  game: Game;
  ruleset: Ruleset;
  rated: bool;
  senderRatedConsent: bool;
  recipientRatedConsent: bool;
  status: InvitationStatus;
  createdAt: timestamp;
  updatedAt: timestamp;
  expiresAt: timestamp;
  respondedAt: timestamp | null;
  matchId: string | null;
  rematchOfMatchId: string | null;
}
```

Invitations require an active friendship, expire after five minutes by default, and are visible only to the two players. The bounded server policy may adjust expiry without changing the client contract. A deterministic `/invitationSlots/{slotKey}` lock points to at most one actionable invitation for a pair/game and is updated in the same transaction as invitation state. Unrated is the default. For a rated invitation, `senderRatedConsent` is true at creation and acceptance requires `recipientRatedConsent = true`; otherwise no match is created. Rated status and both consent values become immutable after acceptance. Friend matches may cross League boundaries.

Accepting an invitation transactionally verifies pending/unexpired/friendship/consent state, creates one match, sets `status = accepted`, and stores `matchId`. Repeated acceptance returns the same `matchId`. Terminal invitations are retained for 30 days and then TTL-deleted.

### 5.11 Feed source events and private inboxes

Paths:

```text
/activityEvents/{eventId}
/users/{uid}/feed/{eventId}
```

Server-only source event:

```ts
{
  type: FeedType;
  actorUids: string[];
  audience: FeedAudience;
  subjectUids: string[];
  sourceId: string;
  game: Game | null;
  occurredAt: timestamp;
  recordedAt: timestamp;
  payloadVersion: 1;
  payload: map;
}
```

Private inbox projection:

```ts
{
  eventId: string;
  type: FeedType;
  actorContextUids: string[];
  sourceId: string;
  game: Game | null;
  occurredAt: timestamp;
  recordedAt: timestamp;
  payloadVersion: 1;
  payload: map;                          // display-safe snapshot only
}
```

Every completed non-void match creates one actor-neutral canonical `match.completed` source event keyed by match ID, including bot and unrated friend matches. It lists every human participant in `actorUids`. Projection evaluates each participant's privacy and relationships, then writes at most one merged row per viewer with the authorized actor contexts. A first accepted Daily Puzzle completion creates one event keyed by assignment ID. Invitations are not Feed events.

The source-event ID is deterministic from event type and domain source ID. Within `/users/{uid}/feed/{eventId}`, the viewer projection uses that same event ID and stores at most one merged row. Privacy is checked again when reading/deep-linking. Tightening privacy recomputes or removes actor contexts; owner projections remain. Blocking immediately denies reads and schedules projection reconciliation.

Inbox documents are server-candidate rows, ordered newest first, and retained for 180 days. Clients read them only through `listFeed`. Source events are server-only and retained for 400 days. Feed pagination uses 20 items and an exact `(occurredAt, eventId)` cursor; delayed fanout never changes domain ordering.

### 5.12 Privacy and blocks

Privacy preferences live only in `/users/{uid}` and their safe projection fields in `/publicProfiles/{uid}`. All preference updates are atomic across those two documents.

Path: `/users/{blockerUid}/blocks/{blockedUid}`

```ts
{
  blockerUid: string;
  blockedUid: string;
  createdAt: timestamp;
}
```

The path IDs must equal the matching fields. Only the blocker may read the block document. Independent directional documents allow both users to block each other. A block in either direction prevents profile discovery, requests, invitations, friend feed fanout, online-status disclosure, and automatic matchmaking between the pair. Blocking removes an existing friendship and cancels pending pair workflows. It does not alter completed matches or ratings.

Privacy checks are deny-by-default. A missing preference, profile, friendship lookup, or malformed audience is treated as private. Backend list APIs filter before returning data; clients must never fetch broad collections and filter private records locally.

### 5.13 Device tokens

Paths:

```text
/users/{uid}/deviceTokens/{tokenHash}
/deviceTokenOwners/{tokenHash}
```

`tokenHash = sha256(fcmToken)`. The owner-private token document is:

```ts
{
  token: string;
  platform: DevicePlatform;
  deviceInstallationId: string;          // random app-install ID, not hardware ID
  appVersion: string;
  locale: string;
  createdAt: timestamp;
  updatedAt: timestamp;
  lastUsedAt: timestamp;
  disabledAt: timestamp | null;
}
```

The server-only ownership registry is:

```ts
{
  uid: string;
  deviceInstallationId: string;
  updatedAt: timestamp;
}
```

Tokens are owner-private and must never appear in logs, analytics payloads, profiles, or callable responses. Registration atomically writes the private token and ownership registry. It rejects a token bound to another UID unless a reauthenticated server operation atomically moves both records. Invalid/unregistered FCM responses set `disabledAt`; disabled or unused-for-90-days tokens and registries are deleted together. Sign-out deletes that installation's token and registry; account deletion deletes all tokens and registries.

### 5.14 Presence

Path: `/presence/{uid}`

```ts
{
  uid: string;
  status: "online" | "in_match";
  activeMatchId: string | null;
  leaseUntil: timestamp;
  updatedAt: timestamp;
}
```

Presence is advisory, owner-written only through `heartbeatPresence`, and considered offline when its 60-second lease expires. It is readable only through privacy-filtered Friends APIs. Hidden presence returns no status rather than a false Offline label. Presence never authorizes invitations, pairing, or match access; those operations recheck authoritative queue and match state.

### 5.15 Puzzles and private solutions

Paths:

```text
/puzzleFamilies/{puzzleId}
/puzzleFamilies/{puzzleId}/versions/{version}
/puzzlePublications/{publicationId}
/puzzleSolutions/{puzzleId}/versions/{version}
```

Puzzle family:

```ts
{
  puzzleId: string;
  game: Game;
  latestVersion: int;
  createdAt: timestamp;
}
```

Immutable puzzle version:

```ts
{
  puzzleId: string;
  version: int;
  ruleset: Ruleset;
  status: "validated";
  title: string;
  objective: string;
  difficulty: "easy" | "medium" | "hard";
  initialBoard: BoardState;
  solvingSide: Side;
  contentHash: string;
  createdAt: timestamp;
  validatedAt: timestamp;
}
```

Publication:

```ts
{
  publicationId: string;                // game + publication date
  game: Game;
  publicationDate: string;
  puzzleId: string;
  puzzleVersion: int;
  state: "draft" | "scheduled" | "published" | "withdrawn";
  publishAt: timestamp;
  publishedAt: timestamp | null;
  withdrawnAt: timestamp | null;
  withdrawalPolicy: "preserve_existing" | "reject_incomplete_invalid_solution" | null;
  withdrawalReasonCode: string | null;
  replacementPublicationId: string | null;
}
```

Private solution version:

```ts
{
  puzzleId: string;
  version: int;
  rootNodeId: string;
  nodes: map<map>;
  contentHash: string;
  verifiedAt: timestamp;
  verifierVersion: string;
}
```

There is at most one effective publication per game/publication date. Puzzle family IDs are opaque and are never dates. Published versions are immutable. Corrections create a new version and publication revision rather than editing content in place.

Solutions are branching trees and are never client-readable. The server returns only the reached node and authored response needed for the current operation. Publication, correction, withdrawal, and accepted-version behavior is canonical in [[Specs/Daily Puzzle]]. Puzzles award no Elo, League progress, currency, item, purchase credit, or ad-counter progress. The MVP has no hints.

Published prompts are retained indefinitely. Withdrawn prompts and solutions are retained for at least 400 days.

### 5.16 Puzzle attempts

Paths:

```text
/users/{uid}/puzzleAssignments/{assignmentId}
/users/{uid}/puzzleAttempts/{assignmentId}
```

Assignment:

```ts
{
  assignmentId: string;
  userId: string;
  game: Game;
  localDate: string;
  timeZone: string;
  timeZoneRevision: int;
  startsAt: timestamp;
  endsAt: timestamp;
  publicationId: string;
  puzzleId: string;
  puzzleVersion: int;
  createdAt: timestamp;
}
```

Attempt:

```ts
{
  attemptId: string;
  assignmentId: string;
  userId: string;
  game: Game;
  puzzleId: string;
  puzzleVersion: int;
  publicationId: string;
  status: "not_started" | "in_progress" | "completed";
  currentNodeId: string;
  acceptedEdgeIds: string[];
  startedAt: timestamp | null;
  completedAt: timestamp | null;
  activeElapsedMs: int;
  timingStatus: "verified" | "unverified";
  incorrectMoves: int;
  resetCount: int;
  revision: int;
  completionFeedEventId: string | null;
  updatedAt: timestamp;
}
```

There is at most one active assignment per player/game and assignment intervals never overlap. Completion uniqueness is by assignment ID with a secondary guard on player/game/publication. Offline clients persist an idempotent operation log for the exact assignment/version. The server accepts only legal solution-tree edges and reconciles by attempt revision. Incorrect legal moves increment once per unique operation and do not end the attempt. Completion is monotonic and immutable.

The client submits monotonic foreground active-time segments. The server validates ordering and integrity bounds. If timing evidence cannot be reconciled, completion remains valid with `timingStatus = unverified`; streak credit never depends on speed. Attempts are owner-private. Feed dedupe uses `puzzle.completed:{userId}:{assignmentId}`.

### 5.17 Ad counters

Path: `/users/{uid}/adCounters/{game}`

```ts
{
  game: Game;
  threshold: int;                       // 3 for Checkers
  eligibleCompletedSinceLastDue: int;   // 0..threshold-1
  adsDue: int;                          // 0 or 1; no deferred accumulation
  lastEligibleMatchId: string | null;
  lastDueAt: timestamp | null;
  lastImpressionAt: timestamp | null;
  updatedAt: timestamp;
}
```

Eligible Checkers matches are completed bot matches, rated matchmaking matches, and rated friend results for which Elo was applied. Unrated friend, capped rated friend, cancelled, void, uncommitted, and puzzle activity are ineligible. Completion increments each human player's counter exactly once using the local-day match ledger as the idempotency source.

On every third eligible completion, the server sets the counter to zero and `adsDue = 1`. The client attempts an interstitial on the next eligible transition. `recordAdOutcome` clears `adsDue` whether the outcome is `shown` or `unavailable`; unavailable ads are not deferred. While `adsDue = 1`, further eligible completions continue counting toward the next threshold but never increase `adsDue` above 1. Ad counters are private, server-written, and retained for the account lifetime.

## 6. Callable API Contract

### 6.1 Common envelope

All mutations are HTTPS callable functions. Authentication uses a valid Firebase Auth ID token. App Check is required in production. Callable regions are fixed by deployment configuration and clients use the configured region.

Mutation request:

```ts
{
  requestId: string;                    // UUIDv4
  clientVersion: string;
  payload: map;
}
```

Success response:

```ts
{
  ok: true;
  requestId: string;
  serverTime: string;                   // RFC 3339 UTC
  result: map;
}
```

Errors use callable `HttpsError` plus details:

```ts
{
  code: string;                         // stable Crown error enum
  retryable: bool;
  retryAfterMs: int | null;
  requestId: string | null;
}
```

The backend validates exact keys, scalar types, enum membership, lengths, ownership, current state, and authorization before writes. It returns no stack traces, internal IDs unrelated to the caller, token values, puzzle solutions, or another user's private fields.

### 6.2 Idempotency

Every mutation reserves `/users/{uid}/idempotency/{requestId}` with operation name, SHA-256 request hash, state, and serialized terminal response. Records expire after 7 days.

- Same user, request ID, operation, and hash returns the original success or terminal business error.
- Reusing a request ID with different content returns callable status `already-exists` and Crown code `idempotency-key-reused`.
- A recoverable interrupted record is resumed or returns callable status `aborted` and Crown code `operation-in-progress` with retry guidance.
- Domain-level deterministic guards also apply: jump/action ID, pair ID, invitation match ID, local-day match entry, puzzle assignment/operation ID, and Feed projection ID.
- Clients must retry a timed-out mutation with the same request ID and payload.

### 6.3 Operations

Every matchmaking, match, profile-search, friendship, invitation, presence, social Feed, leaderboard, and replay mutation or protected read requires `request.auth.token.email_verified == true`. Daily Puzzle assignment/actions, adaptive-bot synchronization, own settings, and own cached-data synchronization require authentication but do not require email verification.

| Callable | Request payload | Success result | Auth and transaction contract |
| --- | --- | --- | --- |
| `ensureAccount` | no player-selected fields | private account or `profileSetupRequired` | Auth required; creates private defaults once; repeated call returns existing account without resetting progress |
| `completeProfileSetup` | `displayName`, `handle`, `timeZone` | `uid`, profile snapshot, `profileCompletedNow` | Auth required; reserves normalized handle and creates public profile plus one-time profile-completed marker with deterministic default board/piece IDs; repeated request returns existing profile with `profileCompletedNow = false` |
| `updateProfile` | optional `displayName`, `timeZone`, `boardId`, `pieceSetId` | updated safe/private fields | Verified owner for display-name/public projection changes; any authenticated owner for timezone and bundled appearance; atomically updates projections |
| `updatePrivacy` | complete `privacy` map | applied privacy map | Owner only; atomically updates safe projection and emits reconciliation outbox |
| `updateNotifications` | complete `notifications` map | applied notification map | Owner only; validates exact booleans and updates private settings atomically |
| `searchProfiles` | exact normalized Crown handle | zero or one safe profile result | Verified auth; exact match only; server filters privacy, blocks, and self; no display-name prefix discovery |
| `getLeaderboard` | game, broad League, Tier, limit <= 50, optional cursor | limited-disclosure rows, current-player rank, cursor | Verified auth; exact League-Tier query ordered by rating and stable UID tie-break; no full-profile access |
| `enqueueMatchmaking` | `generation`, region, latency samples, `appVersion` | queue entry, lease expiry | Verified auth required; transaction verifies no queue/awaiting/active online match and snapshots authoritative Elo |
| `heartbeatMatchmaking` | `generation` | lease expiry or existing `matchId` | Owner waiting generation only; expected every 10 seconds; same request ID on retry |
| `cancelMatchmaking` | `generation` | terminal queue state, optional `matchId` | If waiting wins, marks cancelled; if pairing committed first, returns matched state and match ID |
| `getMatchState` | `matchId` | authorized match snapshot | Participant only; genuinely read-only; client derives displayed clock from returned deadline |
| `reconcileMatchState` | `matchId`, observed revision | current or terminal match snapshot | Participant or scheduled worker; stateful idempotent mutation using deterministic deadline command ID; finalizes expired ready/turn/disconnect deadlines exactly once |
| `readyMatch` | `matchId`, `expectedRevision` | readiness or active match snapshot | Awaiting participant only; second ready activates match and clocks atomically |
| `heartbeatMatch` | `matchId`, `expectedRevision` | connection/deadline state | Active participant; rate-limited, idempotent, and never pauses the game clock |
| `submitMove` | `matchId`, `expectedRevision`, `expectedBoardHash`, `from`, `to` | new revision, board, clock, forced continuation, optional result | Participant on turn; transaction validates one legal step or jump and clock, creates event, then transfers side only when the complete turn ends |
| `resignMatch` | `matchId`, `expectedRevision` | terminal match summary | Active human participant; completion transaction exactly once |
| `getBotState` | no domain fields | next player side, adaptive-strength state, revision | Auth required; returns account state for online start or reconciliation; cached state supports offline start |
| `syncBotMatch` | client match ID, ruleset, assigned sides, adaptive revision, initial state, ordered jumps, terminal result, idempotency ID | canonical match/index/replay/ad state, next side | Auth required; validates full legal lineage and assignment revision; bot remains unrated; duplicate upload returns canonical result |
| `listFriendsState` | optional independent cursors for friends, incoming/outgoing requests, incoming/outgoing invitations | five sections, each with rows, exhaustion state, and its own next cursor | Verified auth; returns only pair workflows involving caller and privacy-safe presence summaries; sections never share a cursor |
| `heartbeatPresence` | installation ID, current route class, optional active match ID | lease expiry | Verified auth; owner only, rate-limited; current route is coarse and never exposes private screen content |
| `sendFriendRequest` | `recipientUid` | request or existing friendship | Verified auth; pair transaction checks privacy/blocks; crossed request accepts atomically |
| `respondFriendRequest` | `pairId`, `generationId`, `accept` | accepted friendship or deleted pending request | Recipient only; rejects stale generation; accepts or declines transactionally |
| `cancelFriendRequest` | `pairId`, `generationId` | removed pending request | Sender only while the supplied generation is pending |
| `removeFriend` | `friendUid`, `generationId` | `removed: true` | Pair member; rejects stale generation, deletes friendship, and cancels pending invitations transactionally |
| `blockUser` | `blockedUid` | `blocked: true` | Verified auth; creates block and removes pair workflows; cleanup fanout is asynchronous |
| `unblockUser` | `blockedUid` | `blocked: false` | Original blocker only; does not restore friendship |
| `sendMatchInvitation` | `recipientUid`, `rated`, optional `rematchOfMatchId` | invitation | Friendship required; rated sender consent is explicit; rematch source must be terminal and contain both players; creates five-minute invitation and unique pair/game slot |
| `respondMatchInvitation` | `invitationId`, `accept`, `ratedConsent` | terminal invitation, optional `matchId` | Recipient only; acceptance transaction creates exactly one match; rated consent must match contract |
| `cancelMatchInvitation` | `invitationId` | terminal invitation | Sender only while pending |
| `getDailyPuzzle` | optional client local date for diagnostics | assignment, immutable prompt/version, attempt state | Auth required; server derives effective local date and atomically resolves one nonoverlapping assignment; stateful/idempotent |
| `submitPuzzleAction` | `assignmentId`, `puzzleId`, `puzzleVersion`, `operationId`, `expectedRevision`, operation kind/payload, timing segments | correctness, reached-node response, progress, optional completion | Owner only; validates assignment, version, solution-tree edge, and revision; updates attempt/streak/feed outbox once |
| `reportPuzzle` | `assignmentId`, reason enum, optional note <= 500 chars | report ID with authoritative puzzle ID/version | Assigned player only; server resolves exact immutable version; one open report per player/assignment/reason |
| `listFeed` | filter, limit <= 20, optional `(occurredAt,eventId)` cursor | authorized rows, cursor | Verified auth; rechecks privacy/friendship/block state and preserves canonical ordering |
| `listReplays` | limit <= 50, optional cursor | retained replay summaries, cursor | Verified owner; latest-50 grants only |
| `getReplay` | `matchId` | versioned initial state, ordered jump events, result, snapshots | Verified participant with current replay grant only; accepted friendship never grants access |
| `registerDeviceToken` | token, platform, installation ID, app version, locale | token hash | Owner only; transaction binds token hash to one UID; response never includes token |
| `unregisterDeviceToken` | token hash or installation ID | removed count | Owner only |
| `recordAdOutcome` | game, outcome `shown` or `unavailable`, optional mediation receipt ID | cleared due state | Owner only; clears one due ad idempotently; never grants gameplay value |

Match completion's critical transaction includes the terminal match, ratings/stats if rated, both human match indexes/grants, exact latest-50 grant displacement, both human local-day entries and aggregates, both ad counters when eligible, and an outbox marker. Feed fanout, notifications, unreferenced-move cleanup, and bulk privacy cleanup run asynchronously from deterministic outbox records and must not roll back a committed result. GA4 events are not outbox effects; a consented client emits the allowlisted event only when it observes the confirmed transition.

For `syncBotMatch`, a stale adaptive revision does not discard a distinct completed legal game. The server accepts each unique client match ID once, records the supplied snapshotted side, applies the result to adaptive state in server commit order, and advances `nextPlayerSide` once per accepted completion. Concurrent offline games may therefore share a side assignment; after synchronization the canonical next side and adaptation revision converge for all devices. A stale in-progress save never overwrites another device's completed result.

If the critical transaction would exceed Firestore limits, completion must fail before any write; implementation may split only noncritical outbox-driven projections. Competitive state, both-player local ledgers, and idempotency guards must not be split.

### 6.4 Errors and retries

| Callable status | Crown code examples | Retry contract |
| --- | --- | --- |
| `unauthenticated` | `auth-required`, `token-revoked` | Reauthenticate; do not blind retry |
| `permission-denied` | `not-participant`, `privacy-denied`, `blocked` | Terminal until user state changes |
| `invalid-argument` | `invalid-schema`, `invalid-path`, `invalid-time-zone` | Terminal; correct request and use a new request ID |
| `failed-precondition` | `wrong-turn`, `revision-conflict`, `capture-required`, `invitation-expired`, `not-friends` | Refresh state; retry logical action with a new request ID if still applicable |
| `already-exists` | `already-queued`, `idempotency-key-reused` | Use returned/existing resource; conflict is terminal |
| `not-found` | `match-not-found`, `puzzle-unavailable` | Terminal unless response explicitly supplies `retryAfterMs` |
| `resource-exhausted` | `rate-limited`, `queue-capacity` | Retry same request after `retryAfterMs` plus jitter |
| `aborted` | `transaction-contention`, `operation-in-progress` | Retry same request ID with exponential backoff |
| `unavailable` | `dependency-unavailable` | Retry same request ID with exponential backoff |
| `deadline-exceeded` | `deadline` | Outcome unknown; retry same request ID |
| `internal` | `internal` | Retry same request ID at most three times, then surface support ID |

Default retry delays are 250 ms, 500 ms, 1 s, 2 s, and 4 s with full jitter, capped by `retryAfterMs` when supplied. Clients do not retry validation, authorization, illegal move, stale state, expired resource, or privacy errors without first changing or refreshing state.

## 7. Query and Index Contracts

All list queries use explicit limits and stable cursors. Offset pagination is forbidden. Timestamp-only cursors are forbidden because timestamps can tie; include document ID as the final cursor component.

Required composite indexes:

| Collection / group | Query fields in order | Purpose |
| --- | --- | --- |
| `publicProfiles` | `checkersLeague ASC, checkersTier ASC, checkersRating DESC, __name__ ASC` | Nonseasonal Tier leaderboard |
| `publicProfiles` | `normalizedHandle ASC, __name__ ASC` | Exact handle lookup through server API |
| queue under `/matchmaking/{game}/queue` | `status ASC, leagueSnapshot ASC, tierSnapshot ASC, joinedAt ASC, ratingSnapshot ASC` | Same-Tier candidate scan |
| queue under `/matchmaking/{game}/queue` | `status ASC, leagueSnapshot ASC, joinedAt ASC, ratingSnapshot ASC` | Expanded same-League scan |
| `matchIndex` collection group | `replayAvailable ASC, completedAt DESC, __name__ DESC` | Owner latest-50 replay page; query scoped to owner path when possible |
| `friendships` | `recipientUid ASC, status ASC, createdAt DESC, __name__ DESC` | Incoming pending requests |
| `friendships` | `requesterUid ASC, status ASC, createdAt DESC, __name__ DESC` | Outgoing pending requests |
| `friendsIndex` collection group | `normalizedDisplayName ASC, friendUid ASC` | Per-owner accepted Friends pagination; query scoped to owner path |
| `matchInvitations` | `recipientUid ASC, status ASC, expiresAt ASC, __name__ ASC` | Incoming active invitations |
| `matchInvitations` | `senderUid ASC, status ASC, createdAt DESC, __name__ DESC` | Outgoing invitations |
| `feed` collection group | `type ASC, occurredAt DESC, __name__ DESC` | Owner filtered Feed; unfiltered owner Feed uses single-field ordering |
| `moves` collection group | `jumpIndex ASC, __name__ ASC` | Replay event order; normally scoped below one match |

Query limits:

- Leaderboard: 50.
- Exact Crown-handle lookup: one result.
- Matchmaking candidate scan: 25 per expansion stage, server only.
- Match history/replays: 50 maximum, no pagination beyond eligible replay grants.
- Requests/invitations: 50.
- Feed: 20 per page, maximum 100 per foreground session without a new user action.
- Moves: maximum 300 event documents per replay query; a match exceeding this is loaded in pages of 100.

Single-field indexing must be disabled for large or sensitive fields not queried: FCM `token`, board maps, Feed `payload`, puzzle `objective`, puzzle solution `nodes`, attempt `acceptedEdgeIds`, idempotency serialized responses, and normalized latency maps. Per-jump scalar move fields remain indexed only where the replay query requires them. TTL fields require their Firestore TTL configuration but are never used as an authorization substitute.

## 8. Security Rules Expectations

Rules must be deny-by-default and unit-tested in the Firestore emulator. Admin SDK writes are still validated in application code because Admin bypasses rules.

Required rule behavior:

- Require authentication for every client Firestore access. Public in this document means authenticated and privacy-eligible, not internet-anonymous.
- `/users/{uid}` private account/settings reads require `request.auth.uid == uid`. Protected workflow subcollections use the stricter rules below rather than inheriting blanket owner readability.
- Never allow clients to write ratings, stats, League/Tier, local-day ledgers, ad counters, match indexes, replay grants, attempts, feed projections, friendships, requests, invitations, queue snapshots, matches, moves, puzzles, solutions, source events, blocks, or idempotency records directly.
- Direct public-profile reads are denied except self. Exact handle search, friend profile previews, and the allowlisted same-Tier leaderboard use verified server APIs returning limited fields.
- Awaiting/active match and completed replay reads require `email_verified == true` and an authorized participant/grant. Cancelled matches have no replay grant.
- Replay grants require `email_verified == true`, are readable only by their matching UID, and are never writable by clients.
- Friendship/request/invitation direct reads require `email_verified == true` and exact participation. Server APIs remain preferred for joined privacy/presence responses.
- Queue entries are not client-readable as a collection. A user may read only their own entry. Pairing candidates are server-only.
- Feed candidate inboxes and activity source events are never client-readable. Verified clients use `listFeed`, which rechecks current privacy, friendship, and block state.
- Puzzle prompts require a matching owner local-day assignment or attempt for that puzzle. Puzzle solutions are always denied.
- Block documents are readable only by the blocker; block existence used for broader authorization should be checked by trusted callables to avoid leaking who blocked whom.
- Device tokens are owner-only and cannot be listed by any other user.
- Rules validate `request.time < expiresAt` wherever expired resources might otherwise be readable or acted upon.
- No rule depends on a client-supplied rating, League, local date, time zone, participant list, result, ownership claim, appearance entitlement, or privacy audience.

Rules tests must cover both direct document reads and collection queries because a rule that safely permits `get` may still make an unsafe `list` possible.

## 9. Transactions, Concurrency, and Background Work

- Read every document that controls authorization or state before writing it in the same transaction.
- Use server timestamps for all authoritative event times. Client timestamps are diagnostic only.
- Never send push notifications, call AdMob, or invoke external services inside a Firestore transaction.
- Transaction handlers must be pure and safe for automatic Firestore retries.
- Match revision and board hash provide optimistic concurrency; only one concurrent move can commit.
- Rating calculations use integer Elo inputs and a versioned deterministic rounding rule. Both players' rating/stat changes commit with the match result.
- Local-day calculation uses a pinned time-zone database version. Store the effective IANA zone in every ledger and attempt for auditability.
- Outbox workers lease records, use deterministic target document IDs, and record completion. At-least-once delivery must produce exactly-once visible projections.
- Scheduled workers expire queue entries and invitations; delete unreferenced moves; reconcile privacy Feed projections; disable stale tokens; and apply TTL policies.
- A worker failure may delay a feed row, notification, or unreferenced-move deletion, but cannot change a match result, rating, replay grant, local-day ledger, puzzle completion, or ad eligibility.

## 10. Retention Summary

These periods are development defaults for bounded test data and storage design. Account-deletion and legally required retention remain provisional until the launch-readiness policy is approved.

| Resource | Retention |
| --- | --- |
| Private user, stats, appearance selection, attempts, ad counters | Account lifetime; deletion timing pending launch-readiness policy |
| Public profile | Account lifetime; deletion behavior pending launch-readiness policy |
| Bundled boards and piece sets | Indefinite while referenced; retired piece sets remain replay-readable |
| Active match | Until terminal state |
| Completed match summary and local-day match entries | 400 days, then delete or anonymize |
| Moves | While at least one latest-50 replay grant exists, plus 24-hour cleanup grace |
| Per-player replay grants | Exactly that player's latest 50 completed non-void matches, enforced in each completion transaction |
| Match index summaries | 400 days; only latest 50 have replay access |
| Queue entry | 30-second lease; retain terminal state briefly for reconnect, then delete |
| Friendship | Until removed or account deletion |
| Pending friendship request state | Until accepted, declined, cancelled, blocked, or account deletion |
| Invitation | Five-minute default pending expiry; terminal history 30 days |
| Feed inbox | 180 days |
| Source events / outbox audit | 400 days |
| Device token | Until sign-out, invalidation, account deletion, or 90 days unused |
| Published puzzle prompt | Indefinite |
| Puzzle solution / withdrawn puzzle | At least 400 days |
| Idempotency record | 7 days |

## 11. Acceptance Criteria

The backend is acceptable only when all of the following are true:

1. A WCDF conformance suite proves black moves first, compulsory capture, legal multi-capture completion, crowning behavior, king movement, terminal states, and draw adjudication for `checkers-wcdf-gayp-v1.0.0`.
2. No deployed schema or callable accepts American/red-first rules, season IDs, League XP, purchase records, product IDs, prices, currencies, paid entitlements, or subscriptions.
3. Matchmaking never pairs different broad Leagues and never trusts client rating, League, Tier, side, board, or clock values.
4. A rated friend match cannot exist without explicit consent from both players; an unrated invitation cannot be upgraded after creation.
5. Concurrent submissions for one turn commit one move and return a stale-state error for the loser without duplicate clocks, stats, or results.
6. Completing a rated match updates the terminal match, both ratings/stats, both match indexes/grants, both independently computed local-day ledgers, and both eligible ad counters exactly once.
7. Players in different time zones receive ledger entries under their respective local dates for the same match.
8. A player receives exactly the puzzle for their effective local date; changing time zones cannot create a second official puzzle or completion for an already assigned day.
9. Puzzle solutions cannot be read through direct paths, collection queries, feed payloads, errors, logs, or callable responses.
10. Every player can replay their newest 50 completed matches and cannot read match or move data after the corresponding grant is pruned, even with a known document ID.
11. One player's replay grant remains valid if the same match has fallen out of the other player's latest 50.
12. Bot and unrated friend matches create private match history/feed entries but do not change Elo, League/Tier, or rated aggregates.
13. Every third eligible Checkers completion makes one ad due; unavailable ads clear the due state and are never deferred; ineligible matches do not increment.
14. Privacy tightening and blocking prevent new discovery/fanout immediately and remove stale friend feed projections asynchronously without exposing private source data.
15. Crossed friend requests create one friendship; repeated invitation acceptance creates one match; retried puzzle completion creates one streak/feed effect.
16. Disabled, stale, signed-out, or invalid FCM tokens are not used, and no token is readable by another user.
17. Leaderboards are persistent and nonseasonal, ordered by authoritative current Elo within derived Tier, with no reset fields.
18. All list endpoints use limits and stable cursors, and all required production indexes are declared before release.
19. Development schemas expose the account-status and cleanup hooks required by the future deletion policy without claiming that launch deletion obligations are complete.
20. Emulator rules tests deny every unspecified read/write path and prove that authorization cannot be bypassed with malformed fields or unconstrained queries.
21. Backend responses expose enough closed-enum transition context for the client event catalog without adding PII, UIDs, handles, or domain-record IDs to Analytics payloads.
22. Outbox retries never send GA4 events, and telemetry failure cannot alter an authoritative product transaction.

## 12. Emulator Verification

Use the Firebase Local Emulator Suite with isolated Auth, Firestore, Functions, and Tasks/worker test doubles. Each test starts from a cleared emulator and uses fixed UIDs, timestamps, time zones, and deterministic engine vectors.

Required suites:

### 12.1 Rules matrix

- Unauthenticated user against every collection: deny.
- Owner, friend, stranger, blocked user, match participant, replay grantee, expired replay grantee, request sender/recipient, invitation sender/recipient, and unrelated user: assert each allowed and denied `get`, `list`, `create`, `update`, and `delete` case.
- Attempt field injection, immutable-field mutation, unknown enum values, null in required fields, oversized strings/arrays, forged UID fields, and unconstrained collection queries: deny.
- Verify active-match participant reads and completed-match replay-grant reads independently for parent and move subcollection.
- Verify puzzle prompt assignment access and unconditional solution denial.

### 12.2 Callable and transaction tests

- Run every callable with missing auth, missing App Check in production-mode tests, malformed envelopes, reused request IDs, and transaction contention.
- Submit the same mutation 20 times concurrently with one request ID; assert one domain effect and identical responses.
- Submit two different move paths at the same revision; assert one commit, contiguous move IDs, one revision increment, and no partial clock update.
- Race resignation, timeout finalization, and a legal winning move; assert one terminal completion and one set of ratings/ledgers/feed outbox records.
- Race crossed friend requests and repeated invitation acceptance; assert one friendship and one match.
- Force an outbox worker crash after each write boundary, rerun it, and assert no duplicate feed projection or notification intent.

### 12.3 Time-zone and puzzle tests

- Complete one match with players in `Pacific/Kiritimati` and `Pacific/Honolulu`; assert two valid different local dates and one ledger entry per player.
- Test daylight-saving gaps/folds using canonical IANA zones and a pinned clock.
- Request a puzzle before and after local midnight, then request a time-zone change; assert one assignment per effective local date and no duplicate streak credit.
- Complete a puzzle offline, replay the same sync request, submit conflicting elapsed time, and assert the original official completion remains unchanged.

### 12.4 Replay retention tests

- Generate 51 completed matches for player A and fewer than 50 for each opponent. Assert every completion transaction leaves A with at most 50 grants, ending with exactly matches 2-51, while the first opponent retains match 1 if it remains in that opponent's latest 50.
- Verify direct reads of pruned match 1 and its moves fail for A.
- Remove the final grant, advance 24 hours, run cleanup, and assert moves are deleted while allowed summary retention remains.
- Generate tied completion timestamps and verify `matchId` tie-breaking produces deterministic membership and cursors.

### 12.5 Query and index tests

- Seed enough profiles, feed rows, requests, invitations, moves, and queue entries to exercise every composite query and cursor.
- Run emulator query tests and a CI check against the deployed index manifest once implementation files exist.
- Assert page boundaries have no duplicates or omissions when timestamps tie.
- Assert replay queries return at most 50 and feed pages return exactly the requested limit or exhaustion.

### 12.6 Release gate

CI must fail on any rules-test denial mismatch, callable contract mismatch, WCDF vector failure, duplicate idempotent effect, missing index, or retention invariant failure. Before production release, run the same integration suite against the isolated development Firebase project using Standard edition, Native mode and verify TTL policies, scheduled workers, FCM invalid-token handling, task OIDC delivery, and App Check enforcement. Crown has no third persistent staging Firebase project.
