**Screen:** Home  
**Platforms:** iOS (primary), Android  
**Purpose:** Provide the primary launch point for the application, allowing the player to quickly begin playing, view their progress, access online play, solve puzzles, and navigate throughout Crown.
**Mockup:** [[HomeScreen.png]]

---

Canonical MVP scope: [[Specs/MVP Scope Matrix]].

---

# Design Principles

The Home screen should communicate:

- Calm
- Prestige
- Simplicity
- Craftsmanship
- Premium quality

Unlike many game UIs, the Home screen intentionally avoids visual noise.

Animations should be subtle.
Typography should be elegant.
Spacing should be generous.

The screen should feel closer to Apple's first-party applications than a traditional mobile game.

---

# Screen Layout

From top to bottom:

1. Crown title
2. Game selector
3. Player summary card
4. Primary action cards
5. Bottom navigation

The screen scrolls vertically if necessary, although on most modern phones the default layout should fit without scrolling.

Safe area padding should always be respected.

---

# Background

The background consists of:

- Warm white
- Very subtle marble texture
- Extremely soft vignette
- Gentle lighting gradients

No visible hard edges or distracting patterns.

---

# Header

Centered at the top.

Contains:

- Gold Crown logo
- CROWN wordmark

Typography:

- Font: Cormorant Garamond
- Large display size
- Wide tracking
- Black text

The crown icon sits centered above the wordmark.

---

# Game Selector

Located immediately below the title.

Acts as a segmented control.

Current options:

- Checkers
- Chess

---

## Checkers

Default selection.

Contains:

- Gold checker icon
- "CHECKERS"

Uses:

- Gold icon
- Gold text
- Elevated active background

---

## Chess

Currently unavailable.

Contains:

- Silver pawn icon
- "CHESS"
- Lock icon

Uses:

- Gray styling
- Disabled interaction

Tapping displays:

> Chess is coming soon.

No navigation occurs.

---

# Player Summary Card

Largest card on the page.

Purpose:

Provide the player's current identity and competitive progress.

Contains:

## League Badge

Large decorative shield.

Displays:

Current league:

Examples:

- Bronze
- Silver
- Gold
- Platinum
- Diamond

Badge artwork matches the League screen.

The badge is part of the Player Summary Card's single tap target and has no separate destination.

---

## Player Name

Large typography.

Displays:

Current display name.

---

## Current League

Displayed beneath the player name.

Gold colored text.

Example:

Gold III

The label always uses the specific League Tier. The shield artwork may continue to represent the broader League family.

---

## Chevron

Appears on the far right.

Entire card is tappable.

Selecting the card opens:

Profile.

The badge, player name, League Tier label, chevron, and Statistics Row all open Profile. There are no nested League controls on the Home player card.

---

# Statistics Row

Displays four metrics.

Uses the same rated-only competitive aggregates as Profile and Matchmaking.

Each occupies equal width.

Separated by subtle dividers.

---

## Rating

Displays:

Current Elo

Example:

1242

Secondary label:

Current League

Example:

Gold III

---

## Win Streak

Displays:

Current streak

Includes completed rated matchmaking and rated friend matches only.

Example:

7

Also displays:

Best streak

Example:

Best: 12

Shows a flame icon beside the current streak.

If streak is zero:

No flame.

---

## Games Played

Displays:

Total completed rated games.

Includes:

- Rated matchmaking
- Rated friend matches

Bot matches and unrated friend matches are excluded.

---

## Win Rate

Displays:

Win percentage across completed rated matches.

Rounded to nearest whole percent.

Example:

61%

Hidden until the player has completed enough games to produce a meaningful statistic (minimum threshold configurable).

---

# Primary Actions

Three action cards.

---

# Play

Primary offline experience against one adaptive Crown Bot.

Purpose:

Quickly start or resume a match against Crown Bot.

Contains:

Large checker piece icon.

Title:

Play

Subtitle:

vs Crown Bot

CTA button:

Gold arrow.

Background:

Minimal checkerboard illustration.

---

## Interaction

Selecting anywhere on the card starts a new bot match immediately when no saved match exists. The MVP has no bot setup or difficulty-selection screen.

If a saved offline match exists:

Prompt:

Continue current game?

Options:

- Continue
- New Game

New Game replaces the one saved bot match only after confirmation. Crown Bot adapts internally within configured strength bounds; the player never selects a difficulty. Side assignment and save behavior follow [[Specs/MVP Scope Matrix]] and [[Specs/Auth Account and Offline]].

---

# Play Online

Primary multiplayer entry point.

Purpose:

Find an online opponent.

Contains:

Globe icon.

Title:

Play Online

Subtitle:

Find an opponent

Decorative checker pieces.

---

## Interaction

Opens matchmaking.

Player chooses:

- Rated
- Casual (future)

Current MVP:

Rated matchmaking only.

---

# Puzzles

Daily puzzle system.

Contains:

Puzzle piece icon.

Title:

Puzzles

Subtitle:

Improve your skills

Decorative puzzle pieces.

---

## Interaction

Opens today's puzzle.

If already completed:

Displays:

Today's puzzle complete.

Allows replay without changing completion statistics or the player's Daily Puzzle streak.

---

# Cards

All cards share a common design language.

Characteristics:

- White glass surface
- Rounded corners
- Soft shadows
- Thin highlights
- Frosted appearance
- Marble-inspired lighting

Cards gently elevate during press.

---

# Buttons

Circular glass buttons.

Contain only:

Gold arrow icon.

Press animation:

- Slight scale down
- Shadow compresses
- Returns with spring animation

Entire card remains tappable.

Buttons simply reinforce the primary action.

---

# Navigation

Bottom navigation remains persistent.

Tabs:

- Home
- League
- Feed
- Profile

---

## Home

Current screen.

Uses:

Gold icon

Gold text

Gold indicator dot

---

## League

Opens:

League system.

Contains:

- Current league
- Leaderboard
- Rating thresholds

---

## Feed

Opens:

Activity feed.

Contains:

- Friend activity
- Match results
- Replay links
- Announcements

---

## Profile

Opens:

Player profile.

Contains:

- Statistics
- Match history
- Appearance
- Settings

---

# Typography

Primary font:

Cormorant Garamond

Secondary font:

System UI font

Usage:

Cormorant:

- Titles
- Player name
- Major statistics
- Card headings

System font:

- Labels
- Navigation
- Buttons
- Supporting text

---

# Color Palette

Primary:

Warm Gold

Used for:

- Active navigation
- League highlights
- Icons
- Buttons
- Selected game
- Accents

Secondary:

Black

Used for:

- Titles
- Statistics

Neutral:

Soft gray

Used for:

- Secondary labels
- Disabled controls

Surface:

Warm white

---

# Motion

Animations should feel luxurious rather than playful.

Recommended durations:

- Tap: 120–180 ms
- Navigation: 250 ms
- Card elevation: 150 ms
- Page transition: 300 ms

Spring animations should be subtle.

No exaggerated bouncing.

---

# Loading States

While player data loads:

- Display skeleton placeholders
- Preserve overall layout
- Avoid layout shifts

Cards fade into place once loaded.

---

# Empty States

## New Player

Player summary displays:

- Rating: 800
- Games Played: 0
- Win Rate: —
- Win Streak: —

League displays:

Bronze I

Play Online remains available.

---

## Offline

Player summary remains visible using cached data.

Play Online card becomes visually disabled.

Subtitle changes to:

Offline

Selecting the card prompts the player to reconnect.

---

# Accessibility

Support:

- Dynamic Type where practical
- VoiceOver
- High contrast mode
- Reduced Motion

Interactive targets:

Minimum 44×44 pt.

Icons should never be the sole means of communication.

---

# Future Expansion

The Home screen is intentionally designed to grow without requiring structural redesign.

Potential future additions include:

- Seasonal collection banner
- Membership banner
- Limited-time events
- Daily quests
- Challenge cards and goals
- Featured replay
- New game tabs beyond Checkers and Chess

Additional game tabs should appear within the existing segmented control without altering the remainder of the screen layout.
