**Screen:** Feed  
**Platforms:** iOS (Primary), Android  
**Purpose:** Present a private, reverse-chronological journal of the player's activity and permitted friend activity, encouraging players to revisit matches and stay connected.
**Mockup:** [[FeedScreen.png]]

---

Canonical event, audience, and privacy behavior: [[Specs/Feed and Privacy]].

---

# Design Principles

The Feed should feel like a premium activity journal rather than a traditional social media feed.

Its goals are to:

- Celebrate player accomplishments
- Surface meaningful activity
- Encourage healthy competition
- Promote social interaction
- Make replaying games effortless

The Feed should never feel noisy or overwhelming. Every item should communicate something actionable or interesting.

---

# Screen Layout

From top to bottom:

1. Crown header
2. Game selector
3. Feed card
4. Bottom navigation

The feed scrolls vertically.

The bottom navigation remains fixed.

Safe area padding should always be respected.

---

# Background

Shared throughout Crown.

- Warm white
- Soft marble texture
- Gentle lighting
- Subtle vignette

No distracting textures or gradients.

---

# Header

Centered.

Contains:

- Gold Crown logo
- CROWN wordmark

Typography:

- Cormorant Garamond

Identical across all primary screens.

---

# Game Selector

Shared with Home and League.

Contains:

- Checkers
- Chess

---

## Checkers

Selected.

Displays:

- Gold checker icon
- Gold typography
- Elevated active segment

---

## Chess

Disabled until release.

Displays:

- Silver pawn
- Lock icon

Selecting displays:

> Chess is coming soon.

---

# Feed Card

The feed is presented as a single continuous card rather than separate sections.

This reinforces the feeling of a chronological activity timeline.

The feed updates automatically when new activity occurs.

Newest items appear first.

Every item is ordered by event timestamp. No item type is pinned or promoted above a newer item.

**Note:** The mockup is out of date. Its Weekly Challenge and Friend Challenge rows are not part of the MVP, its remaining sample rows must be reordered newest first, and match rows must add their mode and Rated or Unrated status.

---

# Feed Filter

Located in the upper-right corner.

Default:

All

Selecting opens a menu.

Available filters:

- All
- Matches
- Friends
- League
- Puzzles
- System

Changing the filter updates the feed without leaving the page.

Every filtered result remains reverse chronological.

---

# Feed Item Types

Each item type shares a common visual structure while adapting to its specific content.

Each item contains:

- Leading icon
- Primary title
- Supporting text
- Optional metadata
- Optional action
- Timestamp

Rows are separated by soft dividers.

---

# League Movement Feed Items

Communicate competitive movement.

Examples:

- New League Tier reached
- Demoted to another League Tier
- Rating milestones

---

## League Promotion

Displays:

League badge

Example:

You reached Gold I!

Supporting text.

Chevron.

Selecting opens the League screen.

---

# Recent Match Items

One of the primary functions of the feed.

Every completed match automatically creates a feed entry.

Includes:

- Bot matches
- Rated matchmaking
- Rated friend matches
- Unrated friend matches

Feed inclusion does not make a match competitive. Bot and unrated friend results remain excluded from rated statistics.

---

## Layout

Displays:

Small label:

Recent Match

Primary text:

You vs Victor

Supporting text:

Gold III • You won

Match context is also displayed:

- Bot
- Rated
- Rated Friend Match
- Unrated Friend Match

Timestamp.

Replay button.

The Replay button appears only when the viewer is a participant with a current replay grant. Friend-activity summaries never display Replay.

---

## Replay Button

Selecting immediately launches the interactive replay.

Replay includes:

- Full move history
- Board playback
- Move navigation
- Speed controls

Replays remain available for each player's latest 50 completed non-void matches. Viewing is unlimited while retained. A stale row outside that set displays Replay unavailable rather than attempting playback.

AI Match Review is a separate future coaching feature and is not part of basic replay.

---

## Match Result Styling

Won:

Subtle positive accent.

Lost:

Neutral styling.

No aggressive red coloring.

The emphasis remains on learning rather than punishment.

---

# Friend Activity

Displays activity performed by friends.

Examples:

- Completed Daily Puzzle
- Completed a match
- Reached a new League Tier

---

## Puzzle Completion

Displays:

Puzzle thumbnail.

Example:

Malik solved Daily Puzzle #142

Supporting text:

Can you beat their time?

Selecting opens today's puzzle.

---

# Friend Requests

Appears when:

- Someone adds the player as a friend
- Friend request accepted

Displays:

Friend icon.

Example:

Aria added you as a friend.

Chevron.

Selecting opens that player's profile.

---

# League Activity

Displays notable competitive events.

Examples:

Player promoted.

Player demoted.


---

## Example

Victor reached Gold III

Selecting opens the League leaderboard.

---

# System Announcements

May appear within the feed.

Examples:

- Maintenance scheduled
- Chess beta available

System announcements are visually distinct but use the same card language.

---

# Icons

Each activity type has a unique icon.

Examples:

League:

Shield

Win streak:

Flame

Puzzle:

Puzzle piece

Friend:

People

Leaderboard:

Podium

Match:

Checker piece

System:

Crown

Icons help players quickly identify activity categories while scrolling.

---

# Timestamps

Displayed beneath supporting text.

Examples:

- Just now
- 2m ago
- 5h ago
- Yesterday
- 3d ago

Older entries display calendar dates.

---

# Infinite Scrolling

The feed loads incrementally.

Initial load:

20 items.

As the user approaches the bottom:

Additional items load automatically.

Older activity remains accessible.

---

# Pull to Refresh

Supported.

Refreshing:

- Fetches new feed items
- Refreshes friend activity
- Refreshes match results

Animation should use the application's gold accent.

---

# Empty State

If the player has no activity:

Display:

Welcome to Crown!

Play your first game to begin building your activity feed.

Primary button:

Play

---

# Cards

Shared Crown design language.

Characteristics:

- Frosted glass
- Rounded corners
- Soft shadows
- Thin borders
- Warm highlights

Cards gently elevate while pressed.

---

# Motion

Feed animations should feel calm and natural.

Examples:

New feed items:

Fade + slight upward movement.

Replay button:

Gentle scale animation.

League promotions:

Shield icon briefly glows.

---

# Accessibility

Supports:

- VoiceOver
- Dynamic Type where practical
- High Contrast
- Reduced Motion

Every feed item exposes meaningful accessibility labels.

Example:

"You defeated Victor in Gold III two hours ago. Double tap to replay."

---

# Offline Behavior

Cached feed remains visible.

Replay is available for previously downloaded matches.

Actions requiring online connectivity display an appropriate offline message.

---

# Notification Integration

Push notifications deep-link directly into relevant feed items.

Examples:

- Friend request
- New replay available
- League promotion
- Friend activity

Selecting the notification scrolls the feed to the associated item and briefly highlights it.

---

# Privacy

The Feed only displays the player's own events and friends-only projections the player is currently permitted to view.

Private information is never shown.

Friends-only visibility is the MVP default. Players may control the visibility of:

- Match history
- Puzzle activity
- Friend activity
- League visibility
- Online status

These settings are managed from the Profile screen.

Privacy changes apply retroactively after refresh. Removing a friendship revokes future server reads of that friend's projected activity. A visible match summary never grants replay access; replays remain participant-only.

---

# Future Expansion

The Feed is designed as Crown's long-term engagement hub and should support additional activity types without requiring structural redesign.

Potential future additions include:

- Challenge cards, goals, progress, and rewards
- AI match reviews
- Seasonal events
- Tournament participation
- Collection unlocks
- Cosmetic purchases
- Daily login rewards
- Achievement milestones
- Friend comments and reactions
- Club or guild activity
- Featured community matches
- Developer announcements
- Live event banners
- Cross-game activity (Chess, future board games)
- Shareable replay highlights
