**Screen:** Checkers Gameplay  
**Platforms:** iOS (Primary), Android  
**Purpose:** Provide a clear, elegant Checkers board for bot, matchmade, and direct friend matches while making legal actions, rated status, turn state, time pressure, and match results immediately understandable.
**Mockup:** [[CheckersGameplayScreen.png]]

---

Canonical rules and lifecycle: [[Specs/Checkers Rules]] and [[Specs/Match and Rating State Machine]].

---

# Design Principles

The Checkers Gameplay screen should feel:

- Focused
- Fair
- Tactile
- Calm under pressure
- Premium

The board is always the primary focus.

Decoration, controls, and status information must never obscure the position or make legal moves difficult to understand.

---

# Screen Layout

From top to bottom:

1. Crown header and match controls
2. Opponent panel
3. Checkers board
4. Player panel
5. Turn status and game controls

The screen does not display bottom navigation during a match.

The standard layout does not scroll. On compact displays, spacing and panel height compress before the board is reduced below a comfortably playable size.

Safe area padding should always be respected.

---

# Background

Shared throughout Crown.

- Warm ivory
- Subtle marble texture
- Soft lighting gradients
- Gentle vignette

The background remains visually quiet during play.

---

# Header

Centered identity.

Contains:

- Gold Crown logo
- CROWN wordmark
- CHECKERS game indicator
- Back button
- Resign button

The game indicator uses small gold typography with decorative separators.

---

## Back Button

Located on the leading side.

In a bot match, selecting Back opens:

Leave Game?

Options:

- Continue Playing
- Save and Leave
- Resign

In any online human-vs-human match, the clock and match continue while the confirmation is visible.

Options:

- Continue Playing
- Resign and Leave

An online human-vs-human match cannot be paused or saved locally.

---

## Resign Button

Located on the trailing side.

Uses the flag icon shown in the mockup.

Selecting opens a confirmation sheet.

Title:

Resign Match?

Supporting text:

Resigning ends the match and counts as a loss.

Actions:

- Keep Playing
- Resign

---

# Player Panels

Two panels frame the board.

The opponent appears above the board. The local player appears below it.

Each panel displays:

- Display name or role
- League badge for rated matches
- Specific League Tier for rated matches
- Remaining time when the mode uses a clock
- Connection state when relevant

Examples:

- Gold III
- Silver I
- Diamond

**Note:** The mockup is out of date and displays "Gold League." Gameplay uses the specific League Tier, consistent with the League screen.

---

## Bot Match Labels

Opponent name:

Crown Bot

The MVP uses one adaptive bot and does not display a difficulty selector or multiple bot identities. Adaptation remains internal and never changes game rules.

The player's first bot game assigns Black. Each subsequent new bot game alternates the player's logical side between Black and White for that account.

League badges and Elo are not displayed for bots.

Unrated friend matches display Unrated instead of competitive rating information.

---

# Friend Match Status

Friend invitations default to Unrated.

Before a rated friend match begins, both players must explicitly accept:

- The selected opponent
- Rated status
- The possibility of Elo and League Tier changes

Rated friend matches may occur across broad League boundaries. The same-League restriction applies only to automatic matchmaking.

The accepted rated or unrated status appears during match introduction and remains immutable after the server creates the match.

---

## Active Player

The panel for the side whose turn it is receives:

- Slightly brighter border
- Warm gold status accent
- Accessible active-turn announcement

The inactive panel remains stable and readable.

---

# Match Clock

Every online human-vs-human Checkers match, including unrated friend play, gives each player 15 minutes with no increment.

Each clock displays remaining time in MM:SS.

Example:

14:56

The active player's clock counts down. The other clock remains still.

The server is authoritative for remaining time.

When less than one minute remains:

- Seconds remain visible
- The clock receives a restrained warning color
- No continuous pulsing is used

When time reaches zero, the server ends the match by timeout.

Bot matches do not use a clock in the MVP.

---

# Checkers Board

Uses an 8×8 board for American checkers.

The local player's side is oriented at the bottom.

Coordinates may be displayed around the board edge, as shown in the mockup. They can be hidden from Settings without changing orientation.

Only playable dark squares accept pieces or interaction.

---

## Logical Sides and Cosmetics

Game state uses logical Black and White sides.

Black moves first.

Cosmetic piece appearance is independent from logical side. White, gold, marble, or bundled appearance pieces may represent logical Black or White.

The player panel and turn status communicate ownership; visual color alone must not be the only indication.

**Note:** The mockup's white pieces moving first are out of date. Production gameplay follows the logical Black-first rule in [[Specs/Checkers Rules]].

---

## Regular Pieces

Regular pieces move diagonally forward by one playable square.

They capture by jumping diagonally over an adjacent opponent piece into an empty square beyond it.

---

## Kings

A piece becomes a king when it reaches the far row.

Kings move and capture diagonally forward or backward.

Kinging is shown with a clear piece treatment that remains distinguishable in High Contrast mode.

The move ends when a regular piece reaches the king row.

---

# Move Interaction

Moves use select, preview, and commit behavior.

---

## Selecting a Piece

Selecting a movable piece:

- Raises it slightly
- Adds a clear selection ring
- Highlights every legal destination

Selecting another movable piece transfers selection when no capture sequence is active.

Selecting the selected piece again clears selection.

---

## Available Moves

Legal destinations use a gold marker with sufficient contrast against every board cosmetic.

If a capture is required, only pieces that can capture are selectable.

Noncapturing moves are not offered while any capture is available.

---

## Completing a Move

Selecting a legal destination previews the piece on that square.

By default, the move is submitted immediately.

If Move Confirmation is enabled in Settings, the player must select Confirm before submission and may select Cancel to restore the original position.

After server confirmation:

- The move becomes final
- Captured pieces are removed
- Turn state updates
- The opponent's clock begins only when the complete turn, including any mandatory capture sequence, ends

---

## Invalid Moves

Invalid destinations do not accept the piece.

Use restrained feedback:

- Brief selection response
- Clear legal destination markers remain visible
- Optional haptic feedback

Do not shake the entire board or use punitive error sounds.

---

# Capture Rules

Captures are mandatory.

When one or more captures exist:

- Capturing pieces receive a distinct highlight
- Turn status displays Capture required
- Other pieces cannot be selected

---

## Multiple Captures

If the moved piece can capture again:

- The same piece remains selected
- Only its legal continuation squares are highlighted
- No other piece can be selected
- The turn does not change

Captured pieces disappear as each server-confirmed jump completes.

---

# Game Status

The status card beneath the player panel communicates the immediate action.

Examples:

Your Turn

Move a piece

Opponent's Turn

Waiting for opponent

Capture Required

Continue the capture

Reconnecting

Synchronizing match

Status text updates without moving the surrounding controls.

---

# Game Controls

The status card contains two secondary controls.

---

## Move History

The leading control opens a compact list of completed moves.

The list is read-only during live play.

**Note:** The mockup uses a speech-bubble icon for this control. Chat is not included in the MVP. The final control uses a move-history icon and accessible label rather than a chat symbol.

---

## Settings

The trailing gear opens in-match settings.

Contains:

- Sound
- Haptics
- Move Confirmation
- Board Coordinates
- Reduced Motion

Settings never pause an online human-vs-human match.

Resign remains in the header and is not duplicated as an unlabelled settings action.

---

# Online Move Validation

The client may preview legal moves, but the server confirms every online matchmaking and friend-match move.

While confirmation is pending:

- The moved piece remains in its preview position
- A subtle progress state appears in the turn card
- Additional moves are disabled

If the server rejects a move because the match state changed:

1. Restore the authoritative position.
2. Update clocks and turn state.
3. Display Match updated. Choose another move.

---

# Network Handling

If connectivity is interrupted during an online match:

- Keep the board visible
- Disable move submission
- Display Reconnecting
- Continue showing the latest server-authoritative clock estimate

The server clock continues while the player is disconnected.

After reconnection:

1. Fetch the authoritative match state.
2. Reconcile board and clocks.
3. Resume interaction if the match remains active.

If the match ended while disconnected, open the appropriate result state.

---

# App Backgrounding

Online human-vs-human matches continue when the app is backgrounded.

The player's clock continues on their turn.

Returning to the app reconnects and synchronizes before accepting input.

Bot matches save locally after each completed turn and resume from the latest completed turn.

---

# Match Completion

The match ends when:

- A player has no legal move
- A player has no remaining pieces
- A player resigns
- A player loses on time
- The server detects the third occurrence of the same canonical position
- The server detects 80 complete king turns without a capture; a capture or any turn by a man resets the counter

Input is disabled immediately after the final state is confirmed.

The board remains visible behind the result card.

---

## Result Card

Displays:

- Victory, Defeat, or Draw
- Opponent
- Result reason
- Final position
- Match duration
- Rating change for rated matchmaking and rated friend matches
- Updated League Tier when changed
- Daily friend Elo-limit status when a rated friend result receives zero Elo

Examples:

Victory

Opponent resigned

+18 Elo

Promoted to Gold II

Bot and unrated friend matches never display Elo or League changes.

If a rated friend result is beyond either player's first three Elo-applying pair results for that player's local date, display:

Daily opponent rating limit reached

The result remains part of rated statistics, but Elo does not change.

---

## Completion Actions

Primary and secondary actions include:

- View Replay
- Return Home
- Play Again against a bot
- Find Another Match after rated online play
- Invite Friend to Rematch after a friend match

Basic replay reconstructs the completed match from its initial state and ordered move list.

AI Match Review is a separate future coaching feature and is not presented as basic replay.

---

# Advertising

Free players receive an interstitial ad, when one is available, after every third completed Checkers match.

Completed bot, rated matchmaking, and Elo-applying rated friend matches count. Unrated friend matches, capped rated friend results, cancelled or void matches, and sessions without a committed result do not count.

If an ad is unavailable, Crown continues without delaying the player and does not show that missed ad later.

The match result is committed and visible before an ad is requested.

Ads never appear:

- During a match
- Before a result is saved
- During a reconnecting state

After dismissal, return to the result card or the destination selected by the player.

---

# Cards

Shared Crown design language.

Characteristics:

- Frosted glass
- Rounded corners
- Soft shadows
- Thin highlights
- Warm lighting

Gameplay cards remain visually quieter than the board.

---

# Buttons

Circular controls meet the 44×44pt minimum touch target.

Destructive actions use a confirmation and a clear text label in the confirmation sheet.

Board squares are not treated as generic buttons; accessibility labels describe their coordinate, occupant, and legal state.

---

# Motion

Motion should clarify state changes.

Examples:

Piece movement:

Smooth travel between squares.

Capture:

Captured piece fades after the moving piece lands.

Kinging:

Brief gold highlight and crown treatment.

Turn transition:

Status crossfade.

Reduced Motion uses immediate position updates and opacity transitions.

---

# Loading States

When opening an online match:

- Preserve the board frame
- Show player panel placeholders
- Display Preparing match...
- Do not start local interaction before authoritative state arrives

When resuming a bot match, restore the saved position before enabling input.

---

# Empty States

Not applicable during active gameplay.

If an online match identifier is invalid or unavailable:

Display:

Match unavailable.

Primary button:

Return Home

---

# Accessibility

Supports:

- VoiceOver
- TalkBack
- Dynamic Type where practical
- Reduced Motion
- High Contrast

The board exposes:

- Coordinate
- Piece owner
- Piece type
- Selection state
- Legal destination state

Example accessibility label:

"C3. Your regular checker. Selected. Legal moves to B4 and D4."

Turn changes, required captures, reconnecting, clock warnings, and results are announced without repeatedly interrupting board exploration.

Piece ownership and legal moves must not rely on color alone.

---

# Offline Behavior

Bot matches remain available offline.

Offline bot results:

- Remain excluded from competitive statistics
- Save local replay and match history data
- Create a chronological Feed item after synchronization
- Never change Elo or League Tier

Online human-vs-human play cannot begin offline.

If an active online match loses connectivity, use Network Handling rather than converting it into an offline match.

---

# Future Expansion

The gameplay layout can support additional modes without changing the board interaction model.

Potential future additions include:

- Casual online play
- Alternate time controls
- Spectating
- Tournaments
- Match reactions
- AI Match Review
- Chess and future board games

Open chat is not part of the MVP.
