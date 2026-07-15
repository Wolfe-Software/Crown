**Screen:** Checkers Matchmaking  
**Platforms:** iOS (Primary), Android  
**Purpose:** Match the player with an opponent for a rated online Checkers game while reassuring them that progress is being made, reinforcing their competitive identity, and providing useful information during the wait.
**Mockup:** [[CheckersMatchmakingScreen.png]]

---

Canonical queue behavior: [[Specs/Matchmaking Queue]] and [[Specs/Match and Rating State Machine]].

---

# Design Principles

The Matchmaking screen should feel:

- Calm
- Premium
- Anticipatory
- Trustworthy

Rather than feeling like a loading screen, matchmaking should feel like an active part of the competitive experience.

The player should always understand:

- What is happening
- Why it may take time
- What kind of opponent is being searched for
- How long they have likely been waiting

The screen should avoid unnecessary interaction, allowing the player to relax while matchmaking proceeds automatically.

---

# Screen Layout

From top to bottom:

1. Crown header
2. Matchmaking status card
3. Player summary card
4. Strategy tip card
5. Cancel Matchmaking button
6. Bottom navigation

The screen does not normally scroll.

Safe area padding should always be respected.

---

# Background

Shared throughout Crown.

- Warm ivory
- Subtle marble texture
- Soft lighting gradients
- Gentle vignette

No distracting animation.

---

# Header

Centered.

Contains:

- Gold Crown logo
- CROWN wordmark
- Current game indicator

Example:

**CHECKERS**

The game indicator appears beneath the logo using small gold typography with decorative separators.

---

# Matchmaking Status Card

The primary focus of the screen.

Purpose:

Communicate matchmaking progress while reassuring the player that matchmaking is active.

---

## Title

Large centered heading.

Example:

Finding Opponent

Updates dynamically if matchmaking enters another state.

Possible titles include:

- Finding Opponent
- Connecting
- Match Found
- Preparing Match

---

## Status Text

Appears beneath the title.

Examples:

Searching for a player in your range...

Expanding search...

Connecting to opponent...

Preparing board...

The status message updates automatically throughout matchmaking.

---

## Animated Piece

Centered.

Displays the currently selected checker cosmetic.

The piece slowly rotates and subtly floats.

Behind the piece:

Animated concentric rings.

Purpose:

Communicate active searching.

Animation characteristics:

- Very slow
- Smooth
- Continuous
- Never distracting

---

## Match Timer

Large centered timer.

Displays:

Elapsed matchmaking duration.

Format:

MM:SS

Example:

00:08

The timer begins after the server confirms queue entry.

---

## Estimated Wait

Displayed beneath the timer.

Example:

Estimated wait: ~15s

This estimate is continuously updated based on:

- Current player population
- Rating
- League
- League Tier
- Region
- Time of day

If no reliable estimate exists:

Displays:

Estimating...

---

## Matchmaking Status Banner

Appears beneath the primary section.

Contains:

Leading icon

Status message

Examples:

Looking for players in your league.

Searching nearby regions.

Expanding rating range.

High player activity detected.

Finding best connection.

This banner updates as matchmaking progresses.

---

# Matchmaking Behavior

The matchmaking system prioritizes:

1. Same broad League, mandatory
2. Same League Tier, preferred
3. Similar Elo
4. Low latency

League and League Tier are derived directly from authoritative Checkers Elo.

Players outside the same broad League are never eligible for automatic matchmaking.

Search expansion occurs gradually.

Example timeline:

0–10 seconds:

Same League Tier and close Elo range.

10–20 seconds:

Slight Elo expansion within the same League Tier.

20–30 seconds:

Regional expansion while preserving the same broad League.

30+ seconds:

Search other League Tiers within the same broad League while preferring the closest Elo and connection quality.

Search expansion never crosses a broad League boundary.

Players should never see technical details.

Only friendly status messages.

---

# Player Summary Card

Provides reassurance regarding the account currently entering matchmaking.

Displays:

- League badge
- Display name
- Current League Tier
- Active board artwork

---

## Statistics

Displays Checkers statistics only.

Uses the same rated-only aggregates as Home and Profile.

Includes:

### Rating

Current Elo.

Example:

1242

Secondary label:

Current League

---

### Win Streak

Current streak.

Includes completed rated matchmaking and rated friend matches only.

Example:

7

Displays:

Best: 12

---

### Games Played

Completed rated matchmaking and rated friend matches.

---

### Win Rate

Win percentage across completed rated matches.

---

## Interaction

Selecting the player card opens:

Profile screen.

This should not interrupt matchmaking.

---

# Tip Card

Appears beneath the player summary.

Purpose:

Provide useful educational content during the wait.

---

## Layout

Leading icon.

Title:

Tip

Supporting text.

Example:

Control the center early to create more options.

Background artwork:

Current equipped board and checker pieces.

---

## Tip Rotation

Tips rotate every:

8–10 seconds.

Categories include:

### Beginner

Simple strategic advice.

### Intermediate

Pattern recognition.

### Advanced

Positional concepts.

### Rules

Game mechanics.

### Crown Features

Replay system.

League progression.

Puzzles.

Membership (after launch).

Tips never repeat during a single matchmaking session.

---

# Cancel Matchmaking

Large glass button.

Centered.

Displays:

Red X icon.

Label:

Cancel Matchmaking

---

## Interaction

Selecting immediately:

Stops matchmaking.

Returns the player to the previous screen.

No confirmation dialog is shown while the queue entry is still waiting. If pairing committed first, cancellation returns the assigned match and the client enters the ready flow rather than orphaning the opponent.

---

# Match Found

When an opponent is located:

The screen transitions into the match introduction.

Animation sequence:

1. Rings brighten.
2. Timer freezes.
3. Piece emits a subtle glow.
4. "Opponent Found!" appears.
5. Gentle transition into versus screen.

Duration:

Approximately one second.

---

# Network Handling

If connectivity is interrupted:

Status updates.

Example:

Connection interrupted.

Attempting to reconnect...

If matchmaking fails:

Display:

Unable to find a match.

Buttons:

Retry

Return Home

---

# Long Wait Handling

After approximately thirty seconds:

Status updates become more descriptive.

Examples:

Searching other Tiers within your League.

Expanding Elo range within your League.

Still looking for the best match.

The estimated wait updates accordingly.

The player should never feel abandoned.

---

# Background Matchmaking

If the player briefly opens:

- Profile
- League
- Feed

Matchmaking continues in the background.

A compact matchmaking banner appears at the top of supported screens.

Selecting the banner returns to the matchmaking screen.

---

# Push Notifications

If the application is backgrounded:

A remote push notification may appear when a match is found. Push delivery is not authoritative; returning to the app always asks the server for the current queue or match state.

Example:

Your opponent is ready.

Returning to the app opens the assigned match readiness state. Both players must acknowledge readiness before the server activates clocks and board input.

---

# Motion

Animations should feel elegant.

Examples:

Searching rings:

Continuous radial expansion.

Checker piece:

Slow hover.

Status transitions:

Fade.

Tip transitions:

Crossfade.

Card appearance:

Soft upward motion.

No harsh movement.

---

# Cards

Shared Crown design language.

Characteristics:

- Frosted glass
- Rounded corners
- Soft shadows
- Thin highlights
- Warm lighting

Cards subtly elevate while pressed.

---

# Accessibility

Supports:

- VoiceOver
- Dynamic Type where practical
- Reduced Motion
- High Contrast

Example accessibility label:

"Finding opponent. Elapsed time: eight seconds. Estimated wait: fifteen seconds."

Animations reduce automatically when Reduced Motion is enabled.

---

# Offline Behavior

If matchmaking cannot begin:

Display:

You're offline.

Connect to the internet to play online.

Primary button:

Retry

Secondary button:

Return Home

---

# Empty States

Not applicable.

The screen is only presented while matchmaking is active.

---

# Future Expansion

The matchmaking screen is designed to support additional matchmaking modes without requiring structural redesign.

Potential future additions include:

- Casual matchmaking
- Tournament matchmaking
- Regional matchmaking preferences
- Estimated opponent skill indicator
- Daily challenge matchmaking
- Live player count
- Queue priority for Crown Membership
- Featured strategy articles
- Daily puzzle preview
- Matchmaking music selection
- Seasonal matchmaking themes
- Cross-game support for Chess and future board games
