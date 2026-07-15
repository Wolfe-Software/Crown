**Screen:** Profile  
**Platforms:** iOS (Primary), Android  
**Purpose:** Provide the player's personal hub for identity, rated statistics, bundled appearance, friends, replay access, privacy, and settings.
**Mockup:** [[ProfileScreen.png]]

---

Canonical scope, account, Friends, privacy, and optional-data behavior: [[Specs/MVP Scope Matrix]], [[Specs/Auth Account and Offline]], [[Specs/Friends and Invitations]], [[Specs/Feed and Privacy]], and [[Specs/Analytics Measurement Plan]].

---

# Design Principles

The Profile screen should communicate:

- Identity
- Prestige
- Personalization
- Progress
- Personalization

Unlike the Home screen, which emphasizes actions, or the League screen, which emphasizes competition, the Profile screen is centered entirely around the player.

It should feel like a premium digital player card.

Visual hierarchy should emphasize:

1. Player identity
2. Competitive statistics
3. Friends and replays
4. Settings and privacy

---

# Screen Layout

From top to bottom:

1. Crown header
2. Player identity card
3. Statistics card
4. Appearance card
5. Navigation list
6. Bottom navigation

The screen scrolls vertically.

Bottom navigation remains fixed.

Safe area padding is always respected.

**Note:** The mockup is out of date where it presents Membership, collection ownership, achievements, or future Chess statistics as active MVP content. The MVP layout uses Appearance, Friends, Replays, and Settings instead.

---

# Background

Shared throughout Crown.

- Warm ivory
- Soft marble texture
- Gentle directional lighting
- Extremely subtle vignette

No distracting patterns.

---

# Header

Centered.

Contains:

- Gold Crown logo
- CROWN wordmark

Typography:

- Cormorant Garamond

Consistent across all primary screens.

---

# Player Identity Card

The player's primary identity.

Purpose:

Display the player's current competitive identity while providing quick access to profile customization.

---

## League Badge

Large decorative shield.

Displays the player's current league.

Examples:

- Bronze
- Silver
- Gold
- Platinum
- Diamond

The badge artwork is shared across the application.

Selecting the badge opens:

League screen.

---

## Player Name

Large display text.

Example:

Nate Wolfe

Uses Cormorant Garamond.

---

## Edit Button

Small circular glass button beside the player name.

Contains:

Pencil icon.

Selecting opens:

Edit Profile.

---

# Edit Profile

Allows the player to modify:

- Display name
- Active bundled board
- Active bundled piece set
- Privacy preferences
- Friend request settings
- Online visibility

Display names contain 1-30 trimmed grapheme clusters. Exact lookup uses a stable player identifier so duplicate display names do not identify the wrong account.

The player's Crown handle is displayed with a copy action for friend lookup. Handle-change policy is not part of Edit Profile in the MVP.

Profile pictures are intentionally **not supported**.

The player identity remains centered around League, bundled appearance, and rated play rather than uploaded profile pictures.

---

## League Label

Displayed beneath the player name.

Example:

Gold III

Gold typography.

Chevron indicates navigation to the League screen.

Selecting the label opens:

League screen.

---

## Decorative Artwork

The right side of the card displays the player's currently equipped board and pieces.

Purpose:

Showcase the selected bundled appearance.

Artwork updates automatically whenever the bundled board or piece-set selection changes.

---

# Statistics Card

Displays the player's competitive statistics across all supported games.

All match aggregates use completed rated matches only. Rated matchmaking and rated friend matches are included. Bot and unrated friend matches are excluded.

Current MVP:

- Checkers
- Chess (future)

---

## Header

Displays:

Stats

Uppercase.

Small label.

---

# Game Rows

Each game occupies its own row.

Rows are separated by subtle dividers.

---

## Checkers Row

Leading icon:

Gold checker.

Displays:

### Rating

Current Elo.

Example:

1242

Secondary label:

Current League.

Example:

Gold III

---

### Win Streak

Current streak.

Calculated from completed rated matches only.

Example:

7

Displays:

Best: 12

Flame icon shown only when streak > 0.

---

### Games Played

Completed rated games only.

Includes rated matchmaking and rated friend matches.

---

### Win Rate

Win percentage across completed rated matches.

Rounded to nearest whole percent.

---

## Chess Row

Identical layout.

Leading icon:

Chess pawn.

Displays chess-specific statistics.

Until Chess launches:

- Statistics remain hidden, **or**
- A placeholder row is shown indicating that Chess statistics will appear after the player completes their first Chess match.

---

## View Full Stats

Appears beneath the rows.

Centered.

Selecting opens:

Full Statistics.

---

# Full Statistics Screen

Displays significantly more detailed analytics.

All match totals, streaks, win rates, and rating history remain rated-only. Puzzle Statistics are a separate category and are not match aggregates.

Examples include:

## Overall

- Total wins
- Total losses
- Draws
- Current rating for the selected game
- Peak rating for the selected game

## Streaks

- Current streak
- Best streak

## Rated Performance

Includes rated matchmaking and rated friend matches.

Bot and unrated friend performance are not included in Profile statistics.

## Puzzle Statistics

- Daily puzzle completion
- Average solve time
- Best streak

Future statistics may include:

- Games played over time
- Win rate over time
- Rating history graph
- Opening preferences
- Average move time
- Replay views
- Bundled appearance usage

---

# Appearance Card

Displays the player's selected bundled board and piece set.

Purpose:

Allow MVP personalization without ownership, entitlement, shop, collection, rarity, or purchase behavior.

Selecting opens Appearance.

---

# Appearance Screen

Displays every board and piece set bundled with the MVP application.

Each option displays:

- Preview artwork
- Board and piece-set name
- Selected state
- Accessible contrast confirmation

Every bundled option is available to every player. Selecting an option updates the account preference and local cache. No option is locked or purchasable.

---

# Navigation List

Simple list of secondary destinations.

Each row spans the full card width.

Rows are separated by subtle dividers.

Trailing chevrons indicate navigation.

---

## Friends

Displays:

Friends icon.

Selecting opens:

Friends screen. See [[Friends Screen]].

---

# Friends Screen

The complete layout, request states, invitation consent, errors, notifications, offline behavior, and accessibility requirements are defined in [[Friends Screen]]. Backend transitions are defined in [[Specs/Friends and Invitations]].

---

## Replays

Displays:

Replay icon.

Selecting opens the Replay Library defined in [[Replay Screen]].

---

## Settings

Displays:

Gear icon.

Selecting opens:

Settings.

---

# Settings Screen

Contains:

## Account

- Display name
- Crown handle (read-only with copy action)
- Linked accounts
- Sign in methods
- Verification status and resend action
- Sign Out

## Gameplay

- Move confirmations
- Sound
- Haptics
- Animations

## Notifications

- Friend Requests
- Match Invitations
- Match Ready
- Daily Puzzle

## Privacy

- Online status
- Current game
- Friend requests
- Friendship activity
- Match visibility
- Puzzle activity
- Friends list
- League visibility

## Optional Data

- One toggle for Analytics, advertising data use and personalization, Crashlytics, and Performance Monitoring
- Current device-scoped granted or denied state
- Link to the Privacy Policy

The toggle defaults to denied on a new installation. Granting enables future optional collection only. Withdrawing applies the disabled state before reporting success, clears GA4 User-ID and user properties, and resets local analytics state. It does not promise deletion of already transmitted data. The choice does not synchronize to another device and declining never restricts gameplay. Complete behavior and error states are defined in [[Privacy Consent Screen]].

## Appearance

- Theme
- Reduced motion
- Accessibility

## Support

- Help
- Privacy Policy
- Terms
- Contact

## About

- App version
- Licenses

---

# Cards

Shared Crown design language.

Characteristics:

- Frosted glass
- Rounded corners
- Soft lighting
- Thin highlights
- Gentle shadows

Cards slightly elevate during press.

---

# Motion

Animations should feel refined.

Examples:

League badge:

Subtle glow.

Statistics:

Animated counting after match completion.

Appearance artwork:

Gentle parallax while scrolling.

Navigation rows:

Small horizontal movement during press.

---

# Loading States

Skeleton placeholders preserve layout.

Player identity loads first.

Statistics load independently.

No visible layout shift.

---

# Empty States

## New Player

Statistics display:

- 800
- 0 games
- —
- —

Appearance:

The default bundled board and piece set are selected.

---

## Offline

Cached profile remains available.

Statistics continue to display.

Friend-related functionality becomes unavailable until reconnection.

---

# Accessibility

Supports:

- VoiceOver
- Dynamic Type where practical
- High Contrast
- Reduced Motion

Touch targets meet Apple's minimum accessibility guidelines.

Every statistic exposes descriptive accessibility labels.

Example:

"Checkers rating: 1,242. Gold III."

---

# Privacy

Players control the visibility of:

- Online status
- Match history
- Puzzle activity
- Friends list
- League participation
- Bundled appearance

Privacy settings are available from Settings.

Friends-only is the default for shareable profile and activity categories. Replay access remains participant-only. Privacy changes apply retroactively on the next server response as defined in [[Specs/Feed and Privacy]].

---

# Future Expansion

The Profile screen is designed to evolve alongside Crown without requiring structural redesign.

Potential future additions include:

- Rating history charts
- Seasonal profile banners
- Featured achievement showcase
- Trophy cabinet
- Collection completion percentage
- Recently unlocked cosmetics
- Tournament history
- Lifetime milestones
- Favorite openings (Chess)
- Favorite board themes
- Profile sharing
- Public profile URLs
- Player bio (short, optional)
- Developer badges
- Founder badges
- Seasonal profile decorations
