**Screen:** Friends  
**Platforms:** iOS (Primary), Android  
**Purpose:** Help players find and manage persistent friendships, respond to requests, and invite friends into clearly understood rated or unrated matches.
**Mockup:** Not yet available

---

Canonical relationship and privacy behavior: [[Specs/Friends and Invitations]] and [[Specs/Feed and Privacy]].

---

# Design Principles

The Friends screen should feel:

- Personal
- Safe
- Clear
- Responsive
- Low pressure

Social actions should be easy to understand without making online presence or competitive play feel mandatory.

The screen must always distinguish a friend request from a match invitation and a rated invitation from an unrated invitation.

---

# Screen Layout

From top to bottom:

1. Crown header
2. Player lookup
3. Incoming match invitations
4. Friend requests
5. Friends list
6. Bottom navigation

Sections with no content are hidden except when every section is empty.

The screen scrolls vertically.

Bottom navigation remains fixed.

Safe area padding should always be respected.

---

# Background

Shared throughout Crown.

- Warm ivory
- Soft marble texture
- Gentle directional lighting
- Extremely subtle vignette

No distracting patterns or social-media-style visual noise.

---

# Header

Centered.

Contains:

- Gold Crown logo
- Friends title
- Privacy shortcut

The privacy shortcut opens friend request and online visibility settings.

---

# Player Lookup

Located beneath the header.

Contains:

- Search field
- Clear button
- Exact lookup result

Players search by exact Crown handle. Display names are not unique and are never used to select an account.

Search begins after a syntactically valid handle is entered. It returns zero or one privacy-safe result and does not expose private account details.

---

## Lookup States

Idle:

Display:

Find friends by Crown handle.

Searching:

- Preserve the search field
- Display a compact progress indicator
- Keep existing Friends sections available

No results:

Display:

No players found.

Supporting text:

Check the handle and try again.

Lookup unavailable:

Display a retryable inline message without clearing the query.

---

## Search Result

Each result displays only information permitted by the player's privacy settings:

- Display name
- Crown handle
- Current League Tier when visible
- Friendship or request status
- Available action

Possible actions and states:

- Add Friend
- Request Sent
- Respond to Request
- Friends
- Requests Disabled
- Blocked or unavailable result omitted

The current player never appears in their own results.

Selecting a permitted result opens the player's profile preview.

---

# Friend Requests

Incoming and outgoing requests are visually distinct.

Friend request states:

- None
- Sending
- Pending Incoming
- Pending Outgoing
- Accepted
- Declined
- Cancelled
- Failed

The server is authoritative for every transition.

---

## Sending a Request

Selecting Add Friend changes the action to a progress state while the request is submitted.

On success:

Display:

Request Sent

On failure:

- Restore Add Friend
- Preserve the search result
- Display a retryable message
- Do not create a partial relationship

If both players send requests at the same time, the server resolves them into one accepted friendship rather than duplicate requests or relationships.

---

## Incoming Requests

Each incoming request displays:

- Sender display name
- League Tier when visible
- Sent time
- Accept button
- Decline button

Accepting creates one persistent friendship.

Declining removes the pending request and does not notify the sender beyond the request no longer being pending.

Repeated taps are disabled while the response is submitted.

---

## Outgoing Requests

Each outgoing request displays:

- Recipient display name
- Pending status
- Sent time
- Cancel button

Cancellation is available until the request is accepted.

If the request was accepted before cancellation reached the server, the Friends screen displays the accepted friendship rather than an incorrect cancelled state.

---

# Persistent Friends

Accepted friendships persist across sessions and devices until either player removes the relationship.

Friendships are not tied to:

- A League
- A League Tier
- A game
- A season
- Online status

Promotion, demotion, inactivity, and application updates do not remove a friendship.

The server prevents duplicate friend rows.

---

# Friends List

Friends are ordered by normalized display name and stable UID tie-break. Presence is displayed but does not control server pagination order.

Each row displays:

- Display name
- Current League Tier when visible
- Presence state when visible
- Current game when permitted
- Invite to Match button
- More actions button

Selecting the row opens the friend's profile preview.

---

## Presence States

Available:

The friend is online and may receive a match invitation.

Busy:

The friend is already playing, entering matchmaking, or responding to another accepted invitation.

Offline:

The server can authoritatively determine that the friend's visible presence lease expired.

Unknown:

Used when presence cannot be loaded.

Presence is advisory and may change before an action reaches the server.

Hidden online status is never inferred from activity or presented as Offline with certainty. Use no presence label or a privacy-safe status.

---

# Remove Friend

Available from the More actions button.

Selecting opens a confirmation sheet.

Title:

Remove Friend?

Supporting text:

This removes the friendship for both players.

Actions:

- Keep Friend
- Remove Friend

Removing a friend does not change completed matches, ratings, or participant replay grants. Former-friend Feed projections become unauthorized and disappear on the next server refresh, including historical rows.

Pending match invitations between the players are cancelled when the friendship is removed.

---

# Friend Match Invitation

Selecting Invite to Match opens a setup sheet.

Contains:

- Friend
- Game
- Rated or Unrated selection
- Rating impact explanation when Rated is selected
- Send Invitation button

Default:

Unrated

The default resets to Unrated for every new invitation. A previous Rated selection is never remembered as the next invitation's default.

---

## Unrated Invitation

Unrated is selected by default.

Displays:

This match will not change Elo, League Tier, or rated statistics.

The sender can send the invitation without a separate competitive consent step.

The recipient still chooses Accept or Decline.

---

## Rated Invitation

When Rated is selected, display:

- Current ratings when visible
- Current League Tiers when visible
- Elo and League Tier may change
- Explicit sender confirmation

The sender must actively confirm rated play before the invitation is sent.

The recipient must separately and explicitly accept rated play before a match is created.

Accepting an unrated invitation never grants rated consent.

Consent applies only to the selected friend, game, and invitation. It cannot be reused for a rematch or future invitation.

Rated or Unrated status becomes immutable after the server creates the match.

The daily opponent Elo limit is evaluated atomically when a rated result is finalized, not when the invitation is sent. A fourth or later result may remain Rated while applying zero Elo.

---

# Cross-League Matches

Friend matches may occur across broad League boundaries.

The same-League restriction applies only to automatic matchmaking.

For a cross-League rated invitation, both players see:

- Each player's League Tier
- Each player's rating when permitted
- A clear statement that Elo and League Tier may change

No extra warning is required for an unrated cross-League invitation beyond the standard Unrated explanation.

---

# Invitation States

Match invitation states:

- Preparing
- Sending
- Pending Incoming
- Pending Outgoing
- Accepting
- Accepted
- Declined
- Cancelled
- Expired
- Friend Busy
- Sender Busy
- Failed

The current state appears as text and is never communicated by color alone.

---

## Incoming Invitations

Each incoming invitation displays:

- Inviting friend
- Game
- Rated or Unrated status
- League and rating context when Rated
- Expiration time
- Accept button
- Decline button

For a rated invitation, Accept includes explicit rated consent and cannot be triggered by a generic notification action that omits the rating information.

---

## Outgoing Invitations

Each outgoing invitation displays:

- Invited friend
- Game
- Rated or Unrated status
- Sent time
- Expiration time
- Cancel button

The sender may cancel until the invitation is accepted.

Only one pending match invitation to the same friend for the same game is displayed. Repeated submission does not create duplicate matches.

---

# Busy Handling

If the recipient is busy before an invitation is sent, disable Invite to Match and display:

Busy

If presence was stale and the server reports the recipient is busy after submission:

Display:

Friend is busy.

Supporting text:

Try again after their current activity ends.

If either player becomes busy before acceptance completes, no match is created and the invitation remains Pending until accepted later, declined, cancelled, or expired. The attempted acceptance displays Friend is busy.

An accepted invitation and server-created match take priority over later presence updates.

---

# Offline Behavior

Cached friends remain visible offline.

Clearly mark presence as unavailable rather than showing stale online states.

While offline, the player cannot:

- Search for players
- Send or respond to friend requests
- Remove friends
- Send or respond to match invitations

Disabled actions display:

You're offline.

Connect to the internet to manage friends or invitations.

Actions are not silently queued for later submission because relationship and invitation state may change before reconnection.

---

# Invitation Expiry

Every match invitation displays its server-defined expiration time.

Examples:

- Expires in 4m
- Expires in 30s
- Expired

The countdown uses server time and updates while the screen is visible.

When an invitation expires:

- Accept and Cancel become unavailable
- Status changes to Expired
- No match is created
- Both players converge on the same state after synchronization

Opening an expired notification displays the invitation's Expired state rather than an empty destination.

---

# Errors

Errors preserve the current screen, query, and unaffected sections.

Possible messages include:

- Friend request could not be sent.
- Friend request could not be updated.
- Invitation could not be sent.
- Invitation is no longer available.
- Friend is busy.
- Match could not be created.
- Friends could not be refreshed.

Retry is offered only when repeating the action is safe.

The server prevents duplicate friendships, duplicate invitations, partial consent, and duplicate matches when a retry follows an uncertain response.

If acceptance succeeds but navigation fails, refresh authoritative state and open the created match rather than accepting again.

---

# Notifications

Friend requests, request acceptance, match invitations, and invitation responses use in-app and push notifications.

Notifications respect the player's notification settings.

Selecting a friend request notification opens the relevant request on the Friends screen.

Selecting a match invitation notification opens the full invitation on the Friends screen with:

- Inviting friend
- Game
- Rated or Unrated status
- Rating impact when Rated
- Expiration state

Notifications never create a match by themselves.

Rated invitations require explicit in-app consent after the complete rating context is visible.

Friend match invitations are not Feed challenge cards.

---

# Loading States

On initial load:

- Preserve the header and lookup field
- Show section-shaped skeleton placeholders
- Load requests and invitations before the full friends list
- Avoid layout shifts

Refreshing one section does not block interaction with another section unless an authoritative relationship change is pending.

---

# Empty States

If the player has no friends, requests, or invitations:

Display:

Find your friends on Crown.

Supporting text:

Search by name to connect and play together.

The lookup field remains the primary action.

If there are friends but no pending requests or invitations, hide the empty pending sections.

---

# Block Account

Block Account is available from a friend or lookup-result overflow menu.

Selecting it opens a confirmation explaining that blocking:

- Removes an existing friendship
- Cancels pending requests and invitations
- Prevents future lookup, requests, invitations, presence, and friend activity visibility
- Does not notify the blocked player

Unblock is available from Privacy Settings. Unblocking does not restore the friendship.

---

# Privacy

Players control:

- Who may send friend requests
- Online status visibility
- Current game visibility
- Friends list visibility
- Match history visibility
- League and rating visibility where supported
- Friend notification preferences

Player lookup exposes only the minimum information required to identify the intended person.

Disabling friend requests removes Add Friend from lookup results and displays Requests Disabled when appropriate.

Blocking and safety controls take precedence over friendship, lookup, presence, requests, invitations, and notifications.

Private presence is not revealed through sorting, timestamps, notifications, or busy-state wording.

---

# Accessibility

Supports:

- VoiceOver
- TalkBack
- Dynamic Type where practical
- Reduced Motion
- High Contrast

Touch targets meet the 44×44pt minimum.

Every request and invitation exposes:

- Player name
- Relationship or invitation state
- Game
- Rated or Unrated status
- Expiration time when relevant
- Available actions

Example:

"Match invitation from Aria. Checkers. Rated. Expires in four minutes. Accepting may change your Elo and League Tier."

Presence, pending state, rating consent, errors, and expiry are available as text and are never conveyed by color, icon, motion, or position alone.

Dynamic Type may stack row actions vertically rather than truncating names or Rated status.

Status changes and errors are announced once without moving focus away from the affected row.
