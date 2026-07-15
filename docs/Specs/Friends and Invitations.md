# Friends and Invitations

## Purpose

This specification defines the authoritative behavior for persistent friendships, friend requests, and direct match invitations. It applies to Checkers at launch and must remain game-agnostic so future Crown games can use the same social graph.

## Core Invariants

- A user cannot friend or invite themselves.
- One unordered pair of users has at most one current relationship record.
- A friendship is symmetric. There is no separate source of truth under each user's profile.
- Accepted friendships persist until either participant removes them.
- Only accepted friends can create direct match invitations.
- A pair has at most one actionable invitation for the same game at a time.
- Friend invitations are unrated unless rated play is explicitly selected.
- A rated friend match requires independent consent from both participants.
- Match mode, participants, game, and rated status are immutable when the match is created.
- Direct friend matches may cross League and League Tier boundaries.
- All security-sensitive transitions use authenticated server operations and server timestamps.

## Deterministic Pair Identity

For users `uidA` and `uidB`, sort the complete, case-sensitive Firebase UIDs lexicographically and encode both values unambiguously:

```txt
lowUid = min(uidA, uidB)
highUid = max(uidA, uidB)
pairId = base64url(utf8(lowUid)) + "." + base64url(utf8(highUid))
```

Padding is omitted from each Base64URL component. The separator and component encoding prevent concatenation collisions. Clients may compute `pairId` for routing, but the server must recompute and validate it for every write.

The canonical relationship is stored at:

```txt
/friendships/{pairId}
```

Example accepted relationship:

```json
{
  "pairId": "encoded-userA.encoded-userB",
  "generationId": "server UUID for this request/relationship occurrence",
  "memberIds": ["userA", "userB"],
  "status": "accepted",
  "requesterId": "userA",
  "recipientId": "userB",
  "createdAt": "timestamp",
  "acceptedAt": "timestamp",
  "updatedAt": "timestamp"
}
```

`memberIds` is always stored in sorted UID order. The deterministic document path is the unique point lookup for friendship checks and prevents duplicate or directional relationships. Per-user friend lists, request counts, and notification documents are derived indexes only; they must be repairable from the canonical record and must never authorize access by themselves.

Every newly created pending relationship receives a new `generationId`. It remains stable when accepted. If the relationship is deleted and the pair reconnects later, the new request receives a new generation so request and acceptance events cannot collide with historical events for the same pair.

## Relationship States

Supported canonical states are:

```txt
pending
accepted
```

Declining or removing a relationship deletes the canonical document after any required event or notification is written. Historical analytics and audit records may remain in server-only storage, but a deleted relationship must not appear as actionable to clients.

### Send Request

`sendFriendRequest(recipientId)` runs in a transaction:

1. Authenticate the sender and reject self-targeting.
2. Read the deterministic relationship document.
3. If absent, create `pending` with the caller as `requesterId`.
4. If it is pending in the same direction, return the existing request as an idempotent success.
5. If it is pending in the opposite direction, atomically change it to `accepted`. This is a crossed request and requires no second acceptance action.
6. If already accepted, return `already-friends` without changing timestamps.

The UI should identify users by an exact unique account lookup selected from server results, never by trusting a display name. The launch implementation must provide a unique lookup key, such as a normalized globally unique Crown handle. Email addresses and Apple relay addresses are not public friend-search identifiers. Exact UID lookup may be available only to trusted internal or deep-link flows, not exposed as general user-facing search.

### Accept or Decline

Only the pending recipient may accept or decline. Every response includes the expected `generationId`. Acceptance changes `pending` to `accepted` in a transaction. Decline deletes the pending relationship. A delayed command for a prior generation is rejected as stale and cannot mutate a recreated relationship.

### Remove Friend

Either participant may remove an accepted friendship. `removeFriend(friendId, generationId)` transactionally verifies the current generation, deletes the canonical relationship, and cancels every still-pending invitation for the pair. Active or completed matches are unaffected and remain available according to match and replay policy.

Removal does not notify the removed user by push notification. Their next synchronized friends view simply no longer includes the relationship. A later request creates a new relationship with new timestamps.

### Block and Report

Directional account blocking is included in the MVP. A block is a private record separate from the symmetric friendship and atomically removes the friendship, cancels pending pair workflows, and prevents lookup, requests, invitations, presence, and friend Feed visibility without revealing the block to the other user. Unblocking does not restore the friendship.

User-conduct reporting and moderation operations are deferred pending launch trust-and-safety review. Reporting must eventually use a private, access-controlled moderation path and must not be approximated with friendship deletion or client-only filtering.

## Match Invitations

Invitations are stored at:

```txt
/matchInvitations/{invitationId}
```

`invitationId` is server-generated. The document includes a deterministic `slotKey` used by the server to enforce one actionable invitation per pair and game:

```txt
slotKey = pairId + ":" + game
```

Example:

```json
{
  "pairId": "encoded-userA.encoded-userB",
  "slotKey": "encoded-userA.encoded-userB:checkers",
  "senderId": "userA",
  "recipientId": "userB",
  "game": "checkers",
  "ratedRequested": true,
  "ratedConsent": {
    "userA": true,
    "userB": false
  },
  "status": "pending",
  "createdAt": "timestamp",
  "expiresAt": "timestamp",
  "respondedAt": null,
  "matchId": null
}
```

The unique invitation slot is a deterministic lock document at `/invitationSlots/{slotKey}` that points to the current invitation. Creating, expiring, or resolving an invitation updates the invitation and slot in one transaction. A new invitation is not created while another actionable invitation occupies the slot.

### States

```txt
pending
accepted
declined
cancelled
expired
```

Only `pending` is actionable.

- `accepted` has exactly one `matchId` and means match creation committed.
- `declined` means the recipient rejected it.
- `cancelled` means the sender withdrew it or friendship removal invalidated it.
- `expired` means server time reached `expiresAt` before acceptance committed.

Terminal states never transition again. Cleanup may archive or delete terminal documents after the product's retention period.

### Creation and Expiry

`sendMatchInvitation(friendId, game, ratedRequested)` requires an accepted friendship and a supported game. The server chooses `createdAt` and `expiresAt`; the Alpha default expiry is five minutes and should be remotely configurable within a bounded server policy.

Creating an invitation transactionally checks the unique slot:

- If the same sender has an equivalent pending invitation, return it as an idempotent success.
- If the friend has sent a pending invitation for the same game, do not silently accept or merge it. Return `crossed-invitation` with the existing invitation so the caller can accept it.
- If the slot references an expired invitation, mark it expired and create the new invitation atomically.
- If either user is in an active online match or committed matchmaking flow, return `player-busy`.

The server, not a client timer, determines expiry. A scheduled cleanup may mark stale invitations expired, but every read-sensitive mutation must also compare `expiresAt` with server time so delayed cleanup cannot permit acceptance.

### Busy and Offline Behavior

Presence is advisory; authoritative busy checks occur when creating and accepting an invitation. A user is busy when they are already committed to an active online match, an accepted invitation whose match is being created, or a matchmaking match that has been assigned. Merely viewing offline bot play does not reserve online presence; accepting an online invitation exits or suspends bot play only through the bot mode's explicit UX.

An offline recipient may receive an invitation. The invitation remains pending until expiry, is delivered by push when permitted, and appears after synchronization if still actionable. The sender sees `Sent`, not a claim that the friend is online. If the sender goes offline after creation, the server-side invitation remains valid. Creating, accepting, declining, or cancelling cannot be queued offline because the result depends on current friendship, expiry, and busy state.

### Unrated and Rated Consent

`ratedRequested` defaults to `false` when omitted. For an unrated invitation, both `ratedConsent` values remain `false`; acceptance creates an unrated match.

For a rated invitation:

- The sender's explicit selection of rated play records the sender's consent as `true`.
- The recipient must see that the match affects Elo and explicitly accept rated play. A generic invitation acceptance control must not imply rated consent.
- The server records recipient consent and creates the match in the same transaction or idempotent server workflow.
- Both consent values must be `true` before a rated match can be created.
- Consent is scoped to one invitation and cannot be reused for a rematch or future invitation.

The recipient cannot unilaterally convert a rated invitation to unrated. They may decline and send a new unrated invitation. This keeps the accepted terms identical for both players.

### Match Creation

Accepting an invitation invokes one idempotent server operation. It rechecks authentication, friendship, participants, expiry, busy state, game availability, and rated consent. It then creates exactly one match and marks the invitation `accepted` with that `matchId`.

The created match snapshots:

```txt
mode = friend
game
player UIDs and assigned sides
rated
ratingsBefore when rated
sourceInvitationId
createdAt
```

These values are immutable. Rated friend matches are allowed across all League and League Tier boundaries. League restrictions used by automatic matchmaking do not apply because both players chose the opponent and, for rated play, separately consented.

If match creation fails before commit, the invitation remains pending unless it expired or became invalid. If the client loses the response after commit, retry returns the same accepted invitation and `matchId`.

## Rematch

A rematch is a new invitation linked with `rematchOfMatchId`. It may be sent only by a participant after the referenced match reaches a terminal state. It uses the same friendship, busy, expiry, and unique-slot checks as any other invitation.

The previous match's rated status is a suggested default only. The UI must still default a new invitation to unrated unless the sender explicitly chooses rated, and a rated rematch requires fresh consent from both players. A rematch creates a new match document and never resets or mutates the completed match.

## Notifications

Create in-app notifications for:

- Friend request received
- Friend request accepted, including crossed-request acceptance
- Match invitation received
- Invitation accepted and match ready
- Invitation declined or cancelled when the sender is actively awaiting a response
- Invitation expired while the relevant invitation UI is open

Push notifications are best-effort enhancements, not state. Use stable event IDs for deduplication, respect notification preferences, omit sensitive rating or account details from lock-screen text, and deep-link by record ID. Opening a stale notification must resolve current server state and show an appropriate terminal message instead of recreating the action.

## Errors

Server operations return stable machine-readable codes with safe UI copy. Required cases include:

| Code | Meaning | Expected client behavior |
| --- | --- | --- |
| `not-authenticated` | No valid account session | Route to authentication when online |
| `invalid-target` | Self, malformed, or unavailable target | Stop and show a generic unavailable message |
| `user-not-found` | Unique lookup found no visible account | Preserve query and allow retry |
| `already-friends` | Relationship is already accepted | Refresh friends and treat as success |
| `request-not-actionable` | Request is absent or no longer pending | Refresh relationship state |
| `not-friends` | Invitation pair is not accepted | Refresh friends and close composer |
| `crossed-invitation` | Recipient already invited the caller | Open the existing invitation |
| `invitation-expired` | Server expiry passed | Mark expired and offer a new invitation |
| `invitation-not-actionable` | Invitation is terminal or unauthorized | Refresh and display current state |
| `player-busy` | Either participant cannot start | Keep friendship intact and allow later retry |
| `rated-consent-required` | Both rated consents are not present | Return to explicit consent UI |
| `offline` | Current operation requires the server | Preserve intent but do not queue submission |
| `rate-limited` | Abuse or duplicate threshold reached | Disable retry until the supplied retry time |

Authorization failures and nonexistent private records should use indistinguishable external responses where needed to avoid account or relationship enumeration. Technical provider and Firestore errors are not shown directly.

## Transactions and Server Authority

The following operations must be transactional or use an idempotent server workflow with equivalent guarantees:

- Create, accept, decline, and cross a friend request
- Remove a friendship and cancel its pending invitations
- Acquire or release a unique invitation slot
- Accept an invitation and create exactly one match
- Record both rated consents before rated match creation
- Recheck and reserve player availability
- Snapshot pre-match ratings for rated play

Clients cannot directly write canonical friendship state, invitation terminal state, rated consent for another user, match rated status, or `matchId`. Use operation IDs or deterministic result keys to make callable retries safe. Transactions must read authorization and invariant documents before writes and must tolerate concurrent retries from both devices.

## Security and Indexing

- Only relationship participants may read the canonical friendship.
- Only invitation participants may read an invitation.
- Public user lookup returns the minimum profile fields needed to identify a player.
- Display names are not unique and never authorize an action.
- Rate-limit lookup, friend requests, invitations, declines, and notification fan-out.
- Derived per-user indexes must be written by trusted code and reconciled after partial asynchronous failures.
- Server logs may use restricted internal correlation IDs under the logging policy. Analytics must not contain internal IDs, UIDs, relationship IDs, email addresses, provider tokens, handles, or private notification content; it uses only the closed low-cardinality schema in [[Analytics Event Catalog]].

## Required Tests

### Unit Tests

- Pair identity is identical in both UID orders and collision-safe for delimiter-like UID content.
- Invitation slot identity is stable per pair and game.
- Every state transition accepts allowed origins and rejects terminal-state mutation.
- Expiry uses server time boundaries, including equality at `expiresAt`.
- Rated consent cannot be inferred, copied from another invitation, or altered after match creation.

### Emulator and Integration Tests

- Simultaneous opposite friend requests produce one accepted friendship.
- Duplicate same-direction requests are idempotent.
- Delayed accept, decline, cancel, and remove commands for an old generation cannot mutate a recreated relationship.
- Accept versus decline races produce one valid terminal outcome.
- Removal races with invitation creation leave no actionable invitation for non-friends.
- Simultaneous invitations for one slot leave one actionable invitation.
- Two devices accepting one invitation create exactly one match and return the same `matchId`.
- Acceptance racing expiry cannot create a match after expiry.
- Acceptance racing matchmaking or another invitation cannot place a player in two active online matches.
- Rated creation fails with zero or one consent and succeeds with two explicit consents.
- Cross-League rated and unrated friend matches succeed; automatic matchmaking restrictions remain unchanged.
- Offline recipients see only still-pending invitations after reconnect.
- Security rules prevent unrelated users and direct client writes from reading or mutating private state.
- Notification retries deduplicate and stale deep links resolve current state.
- Rematches store and validate `rematchOfMatchId`, create new invitations and matches, and require fresh rated consent.

### End-to-End Tests

- Search by unique lookup, request, crossed request, removal, and re-request.
- Online, backgrounded, and offline invitation delivery.
- Unrated invitation, rated two-consent invitation, decline, cancellation, expiry, busy response, and rematch.
- Lost-response retries after request acceptance and match creation.

## Acceptance Criteria

- No concurrency path creates duplicate friendships, duplicate actionable invitation slots, or multiple matches from one invitation.
- No rated friend match exists without immutable evidence of two invitation-scoped consents.
- Offline and stale clients cannot bypass current friendship, expiry, availability, or consent checks.
- Direct friend play works across League boundaries and remains unrated by default.
- All required transaction, emulator, security-rule, and end-to-end tests pass before the feature is enabled for Alpha users.
