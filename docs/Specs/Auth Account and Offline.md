# Auth, Account, and Offline

## Purpose

This specification defines app boot, authentication, account initialization, verification gates, cached authenticated offline access, sign-out and account switching, and offline bot progress. Crown has no anonymous guest account in the Alpha. A durable authenticated account is required before any user-owned progress is created.

## Core Invariants

- Firebase Auth `uid` is the permanent Crown account identifier.
- Authentication and Crown profile initialization are separate, retryable steps.
- Account setup is idempotent and never overwrites an existing profile with provider defaults.
- New authentication and provider linking require a network connection.
- Email/password users may enter the authenticated shell before verification, but cannot use online or social features until verified.
- An unverified email/password user may play the offline bot and retain local progress for later synchronization.
- The backend verification predicate is `request.auth.token.email_verified == true` for every provider. Google and Apple normally satisfy it through their verified provider email, including Apple private relay; if the claim is absent or false, online and social access remains gated.
- Offline access is available only for the last locally cached authenticated account on that installation and is not equivalent to a fresh sign-in.
- Cached identity never authorizes server work. The backend validates the current token and permissions when connectivity returns.
- Account-scoped local data is namespaced by UID and never shown under another account.
- The device-scoped optional-data choice is resolved before Authentication and before Analytics, Crashlytics, Performance Monitoring, or advertising consent can collect. It is not stored in or synchronized through the Crown account.

## Boot State Machine

Boot must expose explicit states rather than briefly rendering Authentication, Home, or stale data while identity is unresolved:

```txt
launching
privacyChoiceRequired
restoringSession
offlineSessionAvailable
authenticationRequired
authenticating
initializingAccount
verificationRequired
readyOnline
readyOffline
fatalRecovery
```

### State Meaning

| State | Meaning | Allowed destination |
| --- | --- | --- |
| `launching` | Local services and secure storage are opening | Crown launch surface only |
| `privacyChoiceRequired` | No readable device-scoped optional-data choice exists | Privacy Consent screen only |
| `restoringSession` | Firebase session and connectivity are being resolved | Crown launch surface only |
| `offlineSessionAvailable` | A cached authenticated account can be opened offline | Explicit offline continuation or retry |
| `authenticationRequired` | No usable current or cached session exists | Authentication screen |
| `authenticating` | Exactly one provider flow is active | Authentication loading state |
| `initializingAccount` | Auth succeeded; profile setup or repair is running | Preparing account state |
| `verificationRequired` | Email/password account is authenticated but unverified | Verification guidance plus bot play, own settings, and current Daily Puzzle |
| `readyOnline` | Session and essential account data are usable online | Normal app shell |
| `readyOffline` | Cached authenticated account is open without server authority | Offline-capable app shell |
| `fatalRecovery` | Local account state cannot be opened safely | Retry, clear local data, or sign out |

### Boot Decision Order

1. Read the device-scoped optional-data choice and apply denied SDK defaults before any optional collection can begin. If the choice is missing or unreadable, enter `privacyChoiceRequired` before Authentication.
2. Open secure account metadata and the UID-scoped local database.
3. Ask Firebase Auth for the current persisted user without waiting indefinitely for network refresh.
4. Determine connectivity, but do not treat connectivity detection alone as proof that Firebase is reachable.
5. If a persisted user exists and token refresh succeeds, initialize or load the account and enter the appropriate verified or verification-required online state.
6. If refresh is temporarily unavailable and a matching cached account is eligible, offer or enter `readyOffline` according to the returning-user UX.
7. If there is no persisted user but an eligible cached authenticated account was deliberately retained, offer `offlineSessionAvailable`; otherwise require authentication.
8. If Firebase definitively reports disabled user, revoked refresh token, deleted account, or invalid credential, do not offer cached authenticated access for that UID. Revoke local eligibility and require sign-in.

Transient timeouts, DNS failures, and airplane mode are offline conditions, not proof of revocation. Definitive Firebase responses are authoritative.

## Authentication Methods

Supported Alpha methods are:

```txt
Sign in with Apple
Sign in with Google
Email and password
```

Only one authentication request may run at a time. Cancellation returns to Authentication without an error. Provider tokens, raw Firebase codes, and email-existence details must not appear in user-visible copy or logs.

### Email and Password

Account creation sends a verification email and enters `verificationRequired`. The user can resend subject to rate limits, change a mistyped email through a reauthentication-safe flow, refresh verification status, sign out, play the adaptive bot, or open their current Daily Puzzle.

Until `emailVerified` is true, the account cannot:

- Enter automatic matchmaking
- Start or accept friend matches
- Search for users, send requests, or manage invitations
- Write Feed, League, rating, friend, match, or other online/social progress except the minimum account and verification operations explicitly allowed

The unverified user may use local settings, fetch and submit their own Daily Puzzle assignment, and play bot matches offline or online using the offline-capable path. Bot play remains unrated. When verification succeeds, refresh the Firebase ID token before enabling gated features.

Password reset uses neutral responses that do not reveal whether an address exists.

### Google

Use the native Google flow and Firebase credential exchange. Google satisfies Crown's online and social gate only when the resulting Firebase token has `email_verified == true`. Crown does not send a separate verification email for a qualifying provider email.

### Apple

Use a nonce-protected native Apple flow and Firebase credential exchange. Apple satisfies Crown's online and social gate only when the resulting Firebase token has `email_verified == true`. Apple's verified private relay email qualifies and must not be replaced with a guessed or subsequently observed personal address. Apple may provide name and email only on first authorization; capture available display-name input during idempotent initial setup without overwriting later user edits.

Provider verification establishes control of that provider identity, not ownership of matching profile data from another Crown account.

## Idempotent Account Setup

After every successful online authentication, call an authenticated `ensureAccount` server operation before entering `readyOnline`. The operation is keyed by Firebase UID and safe to retry after timeout, app termination, or multi-device sign-in.

In a transaction, `ensureAccount`:

1. Reads `/users/{uid}` and a private account metadata record.
2. If both exist, returns the existing account without resetting display name, Crown handle, rating, League, settings, bundled appearance, or timestamps intended to remain original.
3. If the private account is absent, creates it with server defaults, server `createdAt`, and the authenticated provider set. If no public profile exists, returns `profileSetupRequired` rather than publishing an incomplete identity.
4. If one required record exists and another is missing, repairs only the missing or schema-required fields using deterministic defaults or migrations.
5. Updates `lastAuthenticatedAt` and provider metadata separately from user-editable profile fields.

Initial rating and progression grants must be transactionally guarded so retries cannot duplicate them. Clients cannot choose UID, initial rating, membership, entitlements, or verification status.

`completeProfileSetup` accepts a 1-30 grapheme display name, an available normalized Crown handle, and a validated IANA time zone. It reserves the handle, creates the public profile, and creates the one-time profile-completed milestone atomically. Retrying the same request returns the existing profile; a conflicting handle returns a stable availability error without partial publication. While optional-data consent is granted, the client emits `sign_up` only when it observes creation of that milestone.

## Provider Collisions and Linking

Authentication must not automatically merge accounts solely because providers return the same email. Firebase's trusted collision response starts a recovery flow:

1. Preserve the pending provider credential only in memory for the shortest practical duration.
2. Prompt the user to authenticate with an already-linked method, using non-enumerating copy where appropriate.
3. After successful authentication to the existing UID, require recent authentication and explicitly confirm linking.
4. Link the pending credential to that same Firebase user.
5. Run `ensureAccount` and remain on the original Crown UID.

If the credential is already linked to a different Firebase UID, linking fails; do not move progress, purchases, friends, or ratings automatically. Account merging is not an Alpha capability and requires a separately designed, auditable support process.

Provider management occurs in authenticated Settings. At least one usable sign-in method must remain linked. Unlinking requires recent authentication and is blocked if it would strand the account. Linking and unlinking require network access and cannot be queued offline.

## Cached Authenticated Offline Access

Offline mode is for a previously authenticated account, not a guest identity. Eligibility requires:

- A Firebase user was successfully authenticated on this installation.
- Essential account data and a UID-scoped local database were committed atomically.
- The user has not signed out, switched away, requested account deletion, or received a definitive revocation response.
- Local cache integrity and schema checks pass.

Store only the minimum session marker in platform secure storage. Store profile and game data in an encrypted or platform-protected UID-scoped database where supported. Never store passwords, provider credentials, raw OAuth tokens, or ID tokens in application data. Firebase SDK token persistence remains under its supported secure mechanism.

`readyOffline` must visibly indicate offline state. Server-backed values may be displayed as last synchronized with appropriate stale treatment. Online actions are disabled rather than simulated, except operations explicitly listed as queueable.

Possession of a locally cached account does not allow switching into it after another user has authenticated. Offline account selection is not a credential mechanism.

## Revoked, Disabled, or Deleted Sessions

Revocation cannot always be detected while fully offline. Offline access may continue from a previously valid cache until the app can contact Firebase, but no queued work is considered accepted by the server.

When Firebase definitively reports a revoked token, disabled user, deleted user, or invalidated session:

- Stop synchronization and online subscriptions immediately.
- Mark that UID ineligible for offline authenticated access.
- Quarantine unsynchronized local bot records pending the retention decision; do not upload them under another account.
- Clear Firebase credentials and sensitive account cache.
- Return to Authentication with neutral session-expired copy.

If revocation is learned during an active online match, preserve the match identifier for support diagnostics, stop accepting local moves, and let the server's normal disconnect or abandonment policy resolve the match. The client must not fabricate a result.

## Sign-Out

Sign-out is an online-independent local security action and must always be possible. Before completing it, inspect active and queued work.

### Active Online Match

If an online match is active, warn that signing out does not pause the match and may cause a timeout or loss under match rules. On confirmation, attempt best-effort presence cleanup without blocking sign-out. Do not mark the match complete from the client.

### Queued Local Work

Show whether unsynchronized bot progress exists. The user may cancel sign-out or sign out and discard that UID's pending queue. Alpha must not retain an uploadable queue after sign-out because a later user must not be able to submit or inspect it. Already synchronized records remain on the server.

### Cache Handling

On confirmed sign-out:

- Stop Analytics event production, clear GA4 User-ID and user properties, and clear UID-scoped analytics once-state before clearing Firebase Auth. The device-scoped optional-data choice remains unchanged.
- Cancel listeners, background synchronization, matchmaking, and pending invitation UI.
- Delete pending local operation queues and sensitive cached account data for the UID.
- Clear Firebase Auth credentials.
- Clear notification deep links and in-memory models.
- Return to Authentication only after the account-scoped UI state is gone.

Non-sensitive downloaded assets shared by all users may remain. UID-scoped data must not remain available through normal app UI.

## Account Switching

Account switching is implemented as sign-out followed by fresh online authentication. Crown does not provide a local offline account picker and does not infer an account from a typed email.

The switch flow applies the same active-match warning and queued-work decision as sign-out. After authentication:

- Open only the new UID's namespace.
- Run `ensureAccount` for the new UID.
- Re-register push tokens and notification preferences for the new UID.
- Recreate subscriptions and synchronize from the new account's cursors.
- Never upload the previous UID's bot saves, operations, analytics identity, or drafts.
- Set the next GA4 User-ID and allowlisted properties only after the new account is authenticated and initialized, and only while optional-data consent remains granted.

Switching back later requires authentication again unless Firebase's supported provider flow restores it. Tests must prove that rapid switching cannot flash or leak the previous account's profile, friends, purchases, or game data.

## Adaptive Bot Save

Bot matches are local-first, unrated, and available in verified online, unverified, and eligible offline sessions. Maintain one resumable in-progress bot match per UID and game unless the game mode later specifies multiple slots.

An adaptive save records after every completed turn and on lifecycle pause:

```json
{
  "localMatchId": "uuid",
  "ownerUid": "userA",
  "game": "checkers",
  "rulesetId": "checkers-wcdf-gayp-v1.0.0",
  "engineVersion": "semantic version",
  "playerSide": "black",
  "botSide": "white",
  "adaptiveRevision": 7,
  "adaptiveStateBefore": {},
  "adaptiveStateAfter": {},
  "initialState": {},
  "orderedEvents": [{"turnIndex": 0, "segmentIndex": 0}],
  "currentState": {},
  "status": "active",
  "startedAtClient": "timestamp",
  "updatedAtClient": "timestamp",
  "completedAtClient": null,
  "completionOperationId": null,
  "syncState": "localOnly",
  "checksum": "sha256"
}
```

The persisted adaptive state must contain the inputs needed to reproduce difficulty selection; it must not depend on mutable global state from another account. Writes use atomic replacement or a database transaction so interruption leaves the previous valid checkpoint. On startup, validate owner UID, schema, exact ruleset ID, side assignment, adaptive revision, event sequence, and checksum before resuming. An incompatible or corrupt save is quarantined with a recoverable message rather than partially loaded.

Completed bot matches may synchronize for feed/history and ad-frequency accounting only after the server validates ownership, idempotency key, supported rules version, plausible move sequence, and completion. They never affect Elo, League, rated statistics, or rated streaks. Adaptive skill estimates are account-scoped and synchronize through a versioned server record; they are not a competitive rating.

## Offline Capability Matrix

| Capability | Verified online | Unverified online | Cached offline | Queue while offline |
| --- | --- | --- | --- | --- |
| View cached Home/Profile/history | Yes | Limited | Yes, stale | No write needed |
| Play or resume bot match | Yes | Yes | Yes | Save locally |
| Complete bot match | Yes | Yes | Yes | Yes, UID-scoped |
| Automatic matchmaking | Yes | No | No | No |
| Active online match moves | Yes | No | No new moves; reconnect UX applies | No, unless match protocol separately defines bounded reconnect submission |
| Friends and user lookup | Yes | No | Cached read only | No |
| Friend requests and invitations | Yes | No | No | No |
| Daily Puzzle assignment and actions | Yes | Yes, for own assignment | Cached puzzle only if already assigned | Completion may queue only if puzzle policy validates assignment and version |
| Ratings, League, feed, cosmetics | Read/write per feature | Cached read only | Cached read only | Server-owned writes are not queued |
| Edit local preferences | Yes | Yes | Yes | Yes, last-write policy required |
| Edit public profile | Yes | No | No | No |
| Purchases, restore, membership | Yes | No | No | No |
| Link/unlink provider | Yes | Verification flow only | No | No |
| Sign out | Yes | Yes | Yes | Immediate local action |
| Delete account | Yes, recent auth required | Yes, recent auth required | No | No |

Features not explicitly marked queueable must fail closed while offline. A disabled action should explain that connection is required and preserve non-sensitive form input where safe.

## Synchronization

Every queueable record contains:

```txt
operationId
ownerUid
entityId
baseVersion or sync cursor when relevant
createdAtClient
payload schema version
attempt count
```

Synchronization begins only when all are true:

- Connectivity is usable.
- Firebase has refreshed a valid token for the same `ownerUid`.
- Account setup is complete.
- Verification requirements for that operation are met.

Process records in dependency order, with bounded exponential backoff and jitter. The server deduplicates by `(ownerUid, operationId)`. Server timestamps are authoritative for shared chronology; client timestamps are retained only as metadata. Never rewrite another UID into a queued record.

Conflict policy:

- Bot match events are append-once and idempotent by local match ID and completion operation ID.
- Local preferences use field-specific server versioning or an explicit last-write policy.
- Server-owned progression, ratings, entitlements, friendships, invitations, and online match state always win and are never reconstructed from cache.
- Permanently rejected operations move to a visible or diagnosable failed state; they are not retried forever.

App termination, duplicate delivery, and switching between online and offline must not duplicate feed entries, ad counters, or bot completion records.

## Errors and Recovery

Required user-facing categories include:

| Category | Behavior |
| --- | --- |
| Temporary network failure | Offer retry or eligible cached offline access |
| Invalid or expired session | Require sign-in; do not claim the account is deleted |
| Verification required | Show verification actions and allow bot play and the player's own Daily Puzzle |
| Provider collision | Authenticate existing method, then explicitly link |
| Account initialization failure | Retry idempotently without creating duplicate defaults |
| Cache corruption or incompatible schema | Quarantine affected local data and offer safe recovery |
| Sync rejection | Keep server truth, explain only actionable user steps, retain diagnostic code privately |
| Rate limit | Respect retry time and disable repeated submission |

Error copy must not enumerate accounts, expose raw provider errors, or suggest that offline data has synchronized before server acknowledgement.

## Security and Privacy

- Use Firebase security rules and trusted server functions to enforce UID ownership and verification gates; client UI gates are not sufficient.
- Require `request.auth.token.email_verified == true` in server authorization for online/social operations, regardless of provider.
- Use recent authentication for linking, unlinking, sensitive email/password changes, and deletion.
- Redact passwords, OAuth credentials, Firebase tokens, private relay addresses, and full emails from logs and analytics.
- Bind push tokens to the current UID and remove or rotate bindings during sign-out and switching.
- Encrypt or platform-protect UID-scoped local data and wipe key material when cache removal is required.
- Never let cached data grant entitlements, ratings, membership, or social authorization.

## Account Deletion and Legal Requirements

Detailed account-deletion implementation, retention schedules, legal text, regional consent, data export, purchase handling, and support workflows are deferred pending product and legal review. This deferral is not permission to launch without them.

Public launch is gated on approved and tested behavior for:

- In-app account deletion and any platform-required web path
- Recent-authentication and compromised-account safeguards
- Immediate access revocation and treatment of active matches
- Deletion or legally justified retention of profile, auth, social, match, purchase, analytics, moderation, backup, and support data
- User-facing retention timelines and confirmation states
- Apple, Google Play, Firebase, privacy-policy, Terms of Service, and applicable regional requirements
- Restoration, cooling-off, or irreversibility policy
- Handling of queued offline data and every cached installation after deletion

Until that design is approved, Alpha access must be limited according to the project's test distribution policy, and no implementation should promise deletion semantics that the backend cannot fulfill.

## Required Tests

### Unit Tests

- Every boot input maps to one explicit state without Authentication/Home flicker.
- Verification gates permit bot play and the player's own Daily Puzzle assignment/actions while rejecting every verification-gated match or social operation.
- Provider metadata never overwrites edited profile fields.
- Bot checkpoints are atomic, UID-bound, versioned, and checksum-validated.
- Sync eligibility rejects mismatched UID, invalid token, unverified disallowed operation, and non-queueable type.

### Firebase Emulator and Integration Tests

- Concurrent and repeated `ensureAccount` calls create one profile and one initial progression grant.
- Interrupted setup repairs missing records without resetting existing account data.
- Email verification claims are enforced by backend rules/functions, not client fields.
- Google and Apple users pass the provider-verification path; untrusted or absent provider claims fail closed.
- Collision recovery links only after authentication to the existing UID and never creates a second profile automatically.
- Linking a credential owned by another UID fails without moving data.
- Revoked, disabled, and deleted sessions lose offline eligibility after definitive detection.
- Duplicate bot completion uploads create one server record, one feed event, and one ad-frequency increment when eligible.
- Server rejects bot records for another UID, invalid move history, unsupported rules, or rated-stat mutations.

### Offline and End-to-End Tests

- First launch offline cannot create or enter an account.
- Returning authenticated user can open eligible cached data and play/resume a bot match in airplane mode.
- Unverified email user can play a bot but cannot use matchmaking, friends, invitations, public profile writes, or purchases.
- Verification completed on another device becomes available after token reload.
- App termination after every move restores the last complete bot checkpoint.
- Offline bot completion synchronizes once after reconnect, including lost-response retry.
- Temporary refresh failure offers offline access; definitive revocation does not.
- Sign-out with active match warning, pending bot queue discard, listener cancellation, and cache wipe behaves as specified.
- Account A to B switching never displays or uploads A's profile, queue, bot save, notifications, or entitlements under B.
- Corrupt cache enters safe recovery without exposing another account or crashing.
- Every offline-matrix action is enabled, disabled, or queued exactly as documented.

## Acceptance Criteria

- Boot always resolves identity, verification, connectivity, setup, and cache eligibility before rendering account content.
- Account initialization and synchronization are idempotent under retries, concurrent devices, and lost responses.
- Unverified email accounts are blocked from match/social features by the backend while retaining bot and own Daily Puzzle access.
- Cached offline access cannot become a fresh sign-in, cross account boundaries, or grant server authority.
- Sign-out and switching clear account-scoped active state and queues according to this specification.
- Adaptive bot saves survive interruption and synchronize without affecting competitive progression.
- Account deletion and legal requirements are approved, implemented, and tested before public launch.
