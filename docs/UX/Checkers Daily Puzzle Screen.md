**Screen:** Checkers Daily Puzzle  
**Platforms:** iOS (Primary), Android  
**Purpose:** Present one focused Checkers problem each day, teach tactical pattern recognition, and recognize consistent completion without affecting competitive progression.
**Mockup:** [[CheckersDailyPuzzle.png]]

---

Canonical behavior: [[Specs/Checkers Rules]] and [[Specs/Daily Puzzle]].

---

# Design Principles

The Checkers Daily Puzzle screen should feel:

- Focused
- Thoughtful
- Encouraging
- Premium
- Fair

The player should always understand the objective, whose move it is, and whether a move advances the solution.

Puzzles teach through clear feedback rather than penalties.

---

# Screen Layout

From top to bottom:

1. Crown header and puzzle controls
2. Puzzle status card
3. Checkers board
4. Objective card
5. Turn status and puzzle controls

Bottom navigation is not displayed while solving a puzzle.

The screen does not normally scroll. On compact displays, spacing and card height compress while preserving a comfortably playable board.

Safe area padding should always be respected.

---

# Background

Shared throughout Crown.

- Warm ivory
- Subtle marble texture
- Soft lighting gradients
- Gentle vignette

No distracting background animation.

---

# Header

Centered identity.

Contains:

- Gold Crown logo
- CROWN wordmark
- CHECKERS game indicator
- Back button
- Report Puzzle button

---

## Back Button

Returns to the previous screen.

An incomplete attempt is preserved on the current device for the rest of the day.

No confirmation is required because leaving does not consume the puzzle or end completion eligibility.

---

## Report Puzzle Button

Uses the flag icon shown in the mockup.

Selecting opens a short report sheet.

Reasons include:

- Incorrect objective
- Invalid position
- Incorrect solution
- Display issue
- Other

Submitting a report does not change the player's attempt.

---

# Puzzle Status Card

Appears above the board.

Displays:

- Calendar icon
- Puzzle date
- Completion recognition
- Hint state after the feature launches

Example date:

June 9, 2025

The date shown in the mockup is sample content. The live screen displays the player's local calendar date from the server assignment in [[Specs/Daily Puzzle]].

---

## Completion Recognition

During Alpha, supporting copy displays:

Complete today's puzzle to continue your streak.

Daily Puzzle completion does not award currency, Elo, or League progress.

**Note:** The mockup's shield icon and "50" reward are out of date and are not displayed in the MVP.

---

## Hint

Hints are unavailable during Alpha, so the Hint control is hidden rather than shown as locked.

**Note:** The locked Hint button in the mockup represents a future Crown Membership feature.

After Membership launches, Knight and King members may receive one hint generated during puzzle authoring and stored with the published puzzle.

The future hint:

- Nudges toward the tactical idea
- Does not identify the complete move sequence
- Records that the hint was used
- Does not affect Elo or League

---

# Puzzle Objective

The Objective card appears beneath the board.

Contains:

- Target icon
- Objective heading
- Side to move
- Desired outcome

Example:

Find the best move for White.

White to move and win.

Objective language uses the visible cosmetic side when needed for clarity. Accessibility labels also identify the logical side.

---

# Checkers Board

Uses the same interaction and accessibility foundation as Checkers Gameplay.

The board displays the puzzle's authored `initialBoardState`, not a standard starting position.

**Note:** The mockup is internally out of date: it shows a normal starting formation while asking for a forced win. Production puzzles must display the supplied tactical position.

The solving side is oriented at the bottom.

Coordinates may be displayed around the edge and can be hidden from Settings.

---

## Logical Sides and Cosmetics

Puzzle state uses logical Black and White sides under the same WCDF English draughts rules as gameplay. Black is the first-moving side in a standard position, although an authored puzzle may assign either side to move.

Cosmetic appearance may use white, gold, marble, or collection-specific pieces.

The objective and turn card make the solving side explicit so color is never the only indicator.

---

## Starting Position

When the puzzle opens:

- Every authored piece appears in its exact square
- Kings use an unambiguous king treatment
- The first required side is identified
- No move is made automatically

The position remains stable until the player selects a piece.

---

# Puzzle Interaction

Puzzle moves use select, preview, and submit behavior.

---

## Selecting a Piece

Selecting a movable piece:

- Adds a clear selection ring
- Raises the piece slightly
- Highlights legal destinations

If a capture is mandatory, only pieces with legal captures are selectable.

---

## Correct Move

When the player submits the next move in the authored solution:

1. Animate the move.
2. Remove captured pieces if applicable.
3. Play the authored response move when the sequence requires one.
4. Present the next decision position.

Turn status updates throughout the sequence.

The puzzle completes only after the full solution is entered.

---

## Incorrect Move

When a legal Checkers move does not match the authored solution:

- Briefly show Not quite
- Explain that another move creates a stronger continuation
- Restore the position before that move
- Increment the attempt's incorrect-move count
- Keep the puzzle available

Incorrect moves do not end the daily attempt or break the Daily Puzzle streak.

No Elo, League, or currency penalty applies.

---

## Invalid Move

Moves that are not legal under American checkers are not accepted.

Legal destination markers remain visible.

Optional haptic feedback may reinforce the invalid selection without shaking the board.

---

## Multi-Move Sequence

Some puzzles require more than one player decision.

Authored opponent responses animate automatically between decisions.

If a mandatory multi-capture continues with the same piece, only legal continuation squares remain available.

---

## Reset Puzzle

The Settings sheet includes Reset Puzzle.

Reset returns to the authored starting position and resets the visible sequence.

It does not erase the first-attempt start time or incorrect-move count.

---

# Timer

Solve time begins when the player makes the first piece selection.

It stops when the full solution completes.

The timer pauses while the app is backgrounded or the puzzle is not visible.

Elapsed time is shown discreetly in the turn status card after solving begins.

Solve time supports personal statistics and completion activity. It does not determine Elo, League, or an MVP reward.

Replaying a completed puzzle records no new official solve time.

---

# Turn Status

The status card beneath the Objective communicates the immediate action.

Examples:

Your Turn

Find the winning move

Correct

Continue the sequence

Not Quite

Try another move

Puzzle Complete

Solved in 00:46

Status changes do not move the surrounding controls.

---

# Puzzle Controls

The status card contains two secondary controls.

---

## Solution Progress

The leading control opens a compact, read-only list of completed puzzle moves.

It does not reveal future solution moves.

**Note:** The mockup uses a speech-bubble icon. Chat is not part of the Daily Puzzle. The final control uses a sequence or progress icon with an accessible label.

---

## Settings

The trailing gear opens puzzle settings.

Contains:

- Sound
- Haptics
- Board Coordinates
- Reduced Motion
- Reset Puzzle

---

# Puzzle Completion

When the full solution is completed:

1. Lock board interaction.
2. Play a restrained completion animation.
3. Stop the timer.
4. Save the completion result.
5. Display the completion card.

---

## Completion Card

Displays:

- Puzzle Complete
- Solve time
- Incorrect moves
- Current Daily Puzzle streak
- Whether a future hint was used

Example:

Puzzle Complete

Solved in 46 seconds

7 day streak

Completion recognition is informational and noncompetitive during Alpha.

---

## Completion Actions

Actions:

- Replay Puzzle
- Return Home

Replay starts from the authored position.

Replay does not:

- Change the official solve time
- Change the Daily Puzzle streak
- Create another completion activity
- Award anything again

---

# Daily Streak

Completing assigned puzzles for consecutive player-local dates increases the Daily Puzzle streak.

Only the first accepted completion for each player-local date counts.

Replays do not affect the streak.

The streak is separate from Checkers match win streaks.

---

# Feed Integration

The first completion may create one Puzzle Completion feed item.

Contains:

- Puzzle date or number
- Solve time
- Streak milestone when relevant

Replays do not generate additional feed items.

Puzzle activity follows the visibility preference managed from Profile Settings.

---

# Notification Integration

Daily Puzzle reminders are managed from Profile Settings.

Selecting a reminder opens today's puzzle.

If today's puzzle is already complete, the notification is not sent.

---

# Network Handling

The current puzzle is loaded from the published puzzle record.

If loading fails:

Display:

Today's puzzle couldn't be loaded.

Actions:

- Retry
- Return Home

Completion sync retries automatically after a temporary interruption.

The completion card distinguishes a solved puzzle from its pending sync state.

Example:

Puzzle complete. Saving progress...

---

# Cards

Shared Crown design language.

Characteristics:

- Frosted glass
- Rounded corners
- Soft shadows
- Thin highlights
- Warm lighting

Cards remain visually quieter than the board.

---

# Buttons

Circular controls meet the 44×44pt minimum touch target.

The entire labelled Hint control becomes interactive only after that feature launches and the player is eligible.

Disabled or unavailable behavior is communicated with text, not opacity alone.

---

# Motion

Motion should teach the sequence without rushing the player.

Examples:

Correct move:

Smooth travel between squares.

Authored response:

Brief pause followed by clear movement.

Incorrect move:

Return to the prior square with a short fade.

Completion:

Subtle gold board highlight.

Reduced Motion uses immediate board updates and opacity transitions.

---

# Loading States

While today's puzzle loads:

- Preserve the board frame
- Show piece placeholders only if position data is unavailable
- Display Loading today's puzzle...
- Disable board interaction

The objective appears only when its matching position is ready.

---

# Empty States

## Puzzle Unavailable

If no puzzle has been published for the current date:

Display:

Today's puzzle is being prepared.

Actions:

- Try Again
- Return Home

---

## Already Completed

Open the completed puzzle at its authored starting position with a completion banner.

Display:

Today's puzzle complete.

The player may replay without changing completion statistics or streaks.

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

"D4. Your king. Selected. Legal captures on B6 and F6."

Objective, correct move, incorrect move, automatic response, and completion states are announced.

Piece ownership and legal moves never rely on color alone.

---

# Offline Behavior

Once today's assigned puzzle version has loaded, it is cached for that player-local date and may be completed offline.

Offline completion stores:

- Puzzle identifier
- Completion state
- Elapsed time
- Incorrect move count
- Completion timestamp

The result synchronizes when connectivity returns.

Late synchronization preserves the original assignment date and version. It cannot create duplicate completion or streak credit. Corrected and withdrawn versions follow [[Specs/Daily Puzzle]].

If no current puzzle has been cached:

Display:

Connect to the internet to load today's puzzle.

---

# Privacy

Puzzle completion is private account data unless surfaced through the activity Feed.

Feed visibility follows the Puzzle Activity setting in Profile Settings.

The puzzle screen does not expose another player's attempt history.

---

# Future Expansion

The Daily Puzzle screen can support deeper learning features without changing its core board interaction.

Potential future additions include:

- Crown Membership hint
- Puzzle archive
- Difficulty filters in the archive
- Solution explanation
- AI coaching
- Shareable completion result
- Streak recovery rules
- Chess Daily Puzzle

Future rewards must remain separate from Elo and League progression.
