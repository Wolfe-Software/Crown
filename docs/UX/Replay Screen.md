**Screen:** Replay  
**Platforms:** iOS (Primary), Android  
**Purpose:** Let players review their latest completed matches with clear playback controls, accurate match context, and resilient handling for offline, unavailable, or incompatible replay data.
**Mockup:** Not yet available

---

Canonical retention, authorization, and data behavior: [[Specs/Backend Contracts]] and [[Specs/Feed and Privacy]].

---

# Design Principles

The Replay screen should feel:

- Focused
- Trustworthy
- Educational
- Calm
- Easy to control

The board remains the primary focus.

Replay is a read-only reconstruction of a completed match. It never changes the match result, rating, League Tier, statistics, Feed, or advertisement frequency, regardless of how many times it is viewed.

---

# Replay Library

The player can access replays for their latest 50 completed non-void matches across all supported modes.

Includes:

- Bot matches
- Rated matchmaking
- Rated friend matches
- Unrated friend matches

Void, cancelled, abandoned, and nonterminal matches are excluded.

The library is ordered by completion time, newest first. The 50-match limit applies across modes rather than separately to each mode.

There is no limit on how many times an available replay may be viewed.

---

## Replay Row

Each row displays:

- Opponent
- Result
- Game
- Mode
- Rated or Unrated status
- Rating-limit status when relevant
- Completion time
- Replay button

Examples of Mode:

- Bot
- Matchmaking
- Friend Match

Examples of Result:

- Victory
- Defeat
- Draw

Selecting a row opens the replay at the initial position.

---

# Screen Layout

From top to bottom:

1. Replay header
2. Match summary
3. Player panels
4. Game board
5. Move progress
6. Playback controls

The screen does not display bottom navigation while a replay is open.

The standard layout does not scroll. On compact displays, supporting metadata collapses before the board is reduced below a comfortably readable size.

Safe area padding should always be respected.

---

# Background

Shared throughout Crown.

- Warm ivory
- Subtle marble texture
- Soft lighting gradients
- Gentle vignette

The background remains visually quiet during playback.

---

# Header

Contains:

- Back button
- Replay title
- Game indicator
- More information button

Selecting Back returns to the source that opened the replay.

The information button opens complete match details without changing the current move.

---

# Match Summary

Displays:

- Final result
- Result reason
- Opponent
- Game
- Mode
- Rated or Unrated status
- Match completion time
- Match duration

Result reasons may include:

- No legal moves
- No remaining pieces
- Resignation
- Timeout
- Draw

The summary describes the committed result and does not recalculate it during playback.

---

## Rating Information

For rated matchmaking and rated friend matches, display:

- Rating change
- Rating before the match
- Rating after the match
- League Tier change when applicable
- Rating-limit status when applicable

If a rated friend result was beyond either player's first three Elo-applying pair results for that player's local date, display:

Daily opponent rating limit reached

Supporting text explains that the match remains Rated in history, but no additional rating change was applied under the rating-limit rule.

If the rating change was applied normally, do not add a warning or limit label.

Bot and unrated friend matches display:

Unrated

They never display Elo or League Tier changes.

---

# Player Panels

The opponent appears above the board. The local player appears below it.

Each panel displays:

- Display name or bot identity
- Logical side
- League Tier captured at match completion when relevant
- Final clock time when the mode uses a clock

Historical display names, piece sets, ratings, and League Tiers use match snapshots and remain fixed. The board theme is viewer-local and uses the viewer's currently selected bundled board; changing it does not alter replay state or historical piece-set snapshots.

---

# Board Reconstruction

Replay reconstructs the match from:

- Initial board state
- Ordered move list
- Final result

Replay data is read-only and immutable after match completion.

At move zero, the board displays the initial position. At the final move, it displays the committed final position.

No board interaction can submit or alter a move.

---

## Orientation

Default orientation matches the local player's original perspective, with their side at the bottom.

The orientation control rotates the board 180 degrees.

Rotating the board:

- Does not change the current move
- Does not change playback state
- Updates coordinates and accessibility descriptions
- Remains active for the current replay session

The control has a visible text label or accessible name. Orientation must not be communicated by piece color alone.

---

# Playback Controls

Controls appear beneath the board.

Includes:

- First move
- Previous move
- Play or Pause
- Next move
- Final move
- Playback speed
- Board orientation

Controls use a minimum 44×44pt touch target.

Unavailable controls remain visible but disabled. Previous and First are disabled at move zero. Next, Final, and Play are disabled at the final move.

---

## Play and Pause

Selecting Play advances through the ordered move list automatically.

Selecting Pause preserves the current position.

Playback also pauses when:

- The player manually changes moves
- The application enters the background
- An error prevents the next move from loading
- The final position is reached

Returning from the background preserves the current move and does not resume automatically.

---

## Playback Speed

Available speeds:

- 0.5×
- 1×
- 1.5×
- 2×

Default:

1×

Changing speed takes effect before the next move and does not restart playback.

Reduced Motion uses immediate board-state changes with restrained opacity transitions at every speed.

---

## Move Navigation

The move progress displays:

Move 12 of 38

Selecting Previous or Next moves by one complete recorded action.

Selecting First returns to the initial position.

Selecting Final advances directly to the committed final position.

Rapid repeated input is processed in order without displaying an intermediate position from the wrong move.

---

# Multiple Jumps

A mandatory multiple-jump turn is presented as one complete turn with visible jump steps.

During automatic playback:

1. The piece moves to each landing square in order.
2. Each captured piece is removed after its recorded jump.
3. Kinging occurs only at the recorded end of the turn.
4. The next player's turn begins after the full sequence completes.

Previous and Next navigate by complete turn by default so the replay cannot stop in a position that was never a legal turn boundary.

While a multiple jump animates, the move progress identifies the current jump, such as:

Move 12, jump 2 of 3

Reduced Motion shows each recorded jump without travel animation while preserving the sequence and captured-piece order.

---

# Final Position

At the final move:

- Playback stops
- The final board remains visible
- Result and result reason receive emphasis
- Rating information remains available
- Restart Replay becomes available

Restart Replay returns to move zero. It does not increment any gameplay statistic or create another Feed item.

---

# Offline Behavior

Previously downloaded replays remain available offline.

The Replay Library displays cached entries and clearly marks replays that require a download.

If an available replay has not been downloaded:

Display:

Replay requires an internet connection.

Primary button:

Retry

Secondary button:

Return to Replays

Opening or repeatedly viewing a downloaded replay never requires connectivity.

---

# Expired Replay

When a match falls outside the latest 50 completed non-void matches, its replay may no longer be available.

If an expired deep link or stale Feed item is opened:

Display:

Replay expired.

Supporting text:

Only your latest 50 completed non-void matches are available to replay.

Primary button:

View Recent Replays

The historical match result may remain visible where permitted, but playback controls are unavailable.

---

# Corrupt Replay

If replay data is incomplete, inconsistent, or fails validation, do not guess or silently skip moves.

Display:

Replay could not be loaded.

Supporting text:

The saved match data is incomplete or damaged.

Actions:

- Retry Download
- Return to Replays

Preserve the committed result and match metadata when they can be verified independently.

The corrupt replay must not alter match history, rating, or statistics.

---

# Version Compatibility

Every replay records the game rules and replay format version used when the match was completed.

The client uses that version to reconstruct historical behavior rather than applying current rules to an older move list.

If the application can support the recorded version, playback proceeds normally.

If the application is outdated:

Display:

Update Crown to view this replay.

Primary button:

Update Crown

If the recorded version is no longer supported:

Display:

Replay version unavailable.

The final result and match metadata remain visible when available, but controls stay disabled.

---

# Loading States

While replay data loads:

- Preserve the board frame
- Show player panel placeholders
- Display Loading replay...
- Keep playback controls disabled

Do not display the initial position until its version and move data have been validated.

---

# Motion

Motion should clarify the recorded sequence.

Examples:

Piece movement:

Smooth travel between squares.

Capture:

Captured piece fades after the moving piece lands.

Kinging:

Brief crown treatment.

Move navigation:

Restrained crossfade when skipping directly between distant positions.

Reduced Motion removes travel and decorative effects without changing timing information or move order.

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
- Current move
- Captured state
- Board orientation

Playback controls expose their action, selected speed, and disabled state.

Move changes announce concise descriptions without interrupting manual board exploration.

Example:

"Move 12 of 38. Your king moved from C3 to E5 and captured one checker."

Multiple jumps announce the complete sequence and each jump's progress.

Result, mode, Rated or Unrated status, rating change, and rating-limit status are available as text and are never conveyed by color alone.
