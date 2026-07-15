**Screen:** League  
**Platforms:** iOS (Primary), Android  
**Purpose:** Present the player's persistent competitive standing, leaderboard position, rating progress, and Elo-derived League structure while encouraging continued competitive play.
**Mockup:** [[LeagueScreen.png]]

---

Canonical rating and scope behavior: [[Specs/Match and Rating State Machine]] and [[Specs/MVP Scope Matrix]].

---

# Design Principles

The League screen should evoke:

- Prestige
- Progression
- Competition
- Clarity
- Achievement

Unlike traditional ranked ladders that emphasize constant pressure, Crown's League screen should feel aspirational and rewarding. The interface should communicate meaningful progress without overwhelming the player with statistics.

Visual hierarchy should emphasize:

1. Current League
2. Player Progress
3. Leaderboard
4. League System

---

# Screen Layout

From top to bottom:

1. Crown header
2. Game selector
3. Current League card
4. Leaderboard card
5. League overview
6. Social invitation
7. Bottom navigation

The screen scrolls vertically.

Safe area padding should always be respected.

**Note:** The mockup is out of date where it shows season countdowns, XP, leaderboard-based promotion, rewards, or ownership-based avatars. The MVP is persistent, nonseasonal, and Elo-derived.

---

# Background

Matches the rest of the application.

- Warm white
- Soft marble texture
- Gentle lighting gradients
- Extremely subtle vignette

No harsh contrast.

---

# Header

Centered.

Contains:

- Gold Crown logo
- CROWN wordmark

Typography:

- Cormorant Garamond
- Large display size
- Black

Identical to the Home screen.

---

# Game Selector

Shared with the Home screen.

Segmented control containing:

- Checkers
- Chess

---

## Checkers

Active.

Uses:

- Gold icon
- Gold typography
- Elevated selected segment

---

## Chess

Disabled until release.

Displays:

- Silver pawn
- Lock icon

Selecting displays:

> Chess is coming soon.

---

# Current League Card

The primary focus of the screen.

Purpose:

Provide a quick overview of the player's current competitive status.

---

## League Header

Displays:

Current League

Small uppercase label.

---

## League Badge

Large decorative shield.

Uses the artwork for the player's current league.

Examples:

- Bronze
- Silver
- Gold
- Platinum
- Diamond

Artwork should be identical throughout the application.

---

## League Name

Large heading.

### Examples:
- Gold II
- Diamond
- Silver III

**Note:** The mockup is out of date, and shows simply "Gold League". This should instead show the specific League Tier, and the progress bar should show the user's nearness to promoting into the next League Tier (e.g. from Gold II to Gold I, or from Platinum I to Diamond).

---

## Promotion Description

Displays the promotion requirement.
### Examples:
- "Reach a rating of 1400 to advance to Gold I"
- "Reach a rating of 800 to advance to Bronze I"

**Note:** The mockup is out of date, and shows "Top 10 advance to Platinum". Instead, conform to the standard laid out in this document. 

---

## Progress Bar

Visual representation of current placement.

The bar represents Elo within the current League Tier's rating thresholds.

Marker position updates immediately after Elo changes.

---

### Left End

Represents the current tier's minimum Elo.

---

### Right End

Represents the next tier's promotion threshold.

---

### Marker

Gold circular indicator.

Animates smoothly when placement changes.

---

## Promotion Indicator

Appears on the right side.

Contains:

- Trophy icon
- Next League Tier
- Rating required

Example:

Gold I at 1400

---

## Information Button

Located in the upper-right corner.

Selecting opens:

League Information modal.

Contents include:

- How leagues work
- Promotion
- Demotion
- Matchmaking
- Frequently asked questions

---

# League Information Modal

Displays:

## Current League

Description of the current league.

## Promotion Rules

How players move upward.

## Demotion Rules

How players move downward.

## Matchmaking Rules

Automatic matchmaking only pairs players within the same broad League. It prefers the same League Tier, then the closest Elo and connection quality.

League and League Tier are derived directly from Elo. Direct friend matches are outside the automatic queue and may be rated across League boundaries with both players' consent.

# Leaderboard Card

Displays the current standings.

Purpose:

Encourage competition while allowing players to quickly determine their position.

---

## Header

Contains:

Leaderboard

No season countdown or reward status appears in the MVP.

---

## Entries

Each row displays:

- Position
- Bundled appearance marker
- Display name
- Rating

Rows have equal height.

Soft separators divide entries.

---

## Top Three

Receive medal coloring.

### First

Gold

### Second

Silver

### Third

Bronze

---

## Current Player

Always visible.

Even if outside the displayed range.

Displayed using:

- Warm highlighted background
- Gold name
- Gold rating

This row "floats" independently if necessary.

Example:

Top entries:

1

2

3

...

Player:

57

This allows players to immediately identify their standing.

---

## Rating Display

Right aligned.

Format:
820

**Note:** The mockup is out of date, and shows "XP". This should not be included, as the app should use elo ratings, not XP. 

---

## Appearance Marker

Uses the player's currently selected bundled appearance. It does not imply ownership, purchase, rarity, or collection status.

---

# Full Leaderboard Button

Appears below the preview.

Selecting opens:

Full Leaderboard.

---

# Full Leaderboard

Displays:

The player's current League Tier.

Supports:

- Infinite scrolling
- Search by player name (future)
- Player profile preview (future)

Current player remains pinned while scrolling.

---

# League Overview

Displays every league.

Current implementation:

Bronze

Silver

Gold

Platinum

Diamond

---

## Current League

Receives:

- Elevated card
- Gold glow
- Larger visual emphasis

---

## Other Leagues

Remain visible.

Provide context for future progression.

---

## Interaction

Selecting another league opens a modal describing:

- Required rating range
- Promotion rules
- Typical rating range
- Typical player skill

No navigation occurs.

---

# Social Invitation Card

Appears beneath league overview.

Purpose:

Encourage viral growth.

Contains:

Icon

Title:

Compete with friends!

Subtitle:

Invite friends and climb the ranks together.

Chevron on the right.

---

## Interaction

Selecting opens:

Friends screen.

Authentication is already required before the player can reach the League screen.

---

# Bottom Navigation

Persistent.

Tabs:

- Home
- League
- Feed
- Profile

---

## League

Current screen.

Uses:

- Gold icon
- Gold typography
- Gold indicator
- Elevated glass background

---

# Promotion Rules

Promotion is determined exclusively by **Rating (Elo)**.

Promotion thresholds are configured per league.

Example:
Rating of 1400 promotes to Gold I.

---

# Demotion Rules

Demotion is determined exclusively by **Rating (Elo)**.

Example:
Rating below 1400 is demoted to Gold II.

---

# Cards

Shared design language.

Characteristics:

- Frosted glass
- Soft shadows
- Rounded corners
- Marble-inspired highlights
- Thin borders

Cards gently elevate while pressed.

---

# Motion

Animations should reinforce progress.

Examples:

Progress bar:

250ms ease

League badge:

Gentle glow when promoted.

Leaderboard:

Rows animate into updated positions after match completion.

Current player highlight softly fades into place.

---

# Loading States

Skeleton placeholders preserve layout.

Leaderboard rows display:

- Circular placeholders
- Text placeholders
- Rating placeholders

No layout shift should occur.

---

# Empty States

## New Player

Displays:

Starting League

The player begins at rating 800 in Bronze I.

Current League card explains:

Complete a rated match to begin changing Elo and League Tier.

---

## Offline

Cached leaderboard remains visible and is labelled as potentially stale.

Actions requiring online access are disabled.

---

# Accessibility

Supports:

- VoiceOver
- Dynamic Type where practical
- Reduced Motion
- High Contrast

Interactive elements meet Apple's minimum touch target size.

---

# Future Expansion

The League screen is designed to accommodate future competitive features without requiring structural redesign.

Potential additions include:

- Seasonal rewards preview
- Rank history graph
- Promotion animation
- Friends-only leaderboard
- Regional leaderboard filters
- Global leaderboard filters
- League statistics
- Win/loss trend chart
- Match history integration
- Live promotion zone highlighting
- End-of-season countdown banner
- Competitive achievements
- Seasonal cosmetic rewards
- Tournament qualification indicators
