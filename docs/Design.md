
Crown is designed around the feeling of a beautifully crafted tabletop game brought into the modern era.

This document describes the long-term design language. The MVP product boundary is [[Specs/MVP Scope Matrix]]; collectible styling does not imply MVP ownership, purchases, shops, collections, rewards, or memberships.

It combines the refinement of traditional board games with contemporary glass interfaces, producing an experience that feels calm, collectible, and premium rather than competitive or flashy.

Three words define every design decision:

- **Elegant**
- **Warm**
- **Timeless**

---

# Design Principles

## Quiet Confidence

The interface never needs to compete for attention.

Large typography.

Generous whitespace.

Restrained color.

Subtle motion.

The game itself is always the centerpiece.

---

## Premium Craftsmanship

Every surface should feel intentional.

Glass feels polished.

Icons feel engraved.

Cards feel like premium game components.

Animations feel physical.

Nothing should resemble a free-to-play mobile game.

---

## Human Scale

The interface should feel comfortable rather than dense.

Touch targets are large.

Margins are generous.

Reading is effortless.

Interactions require minimal precision.

---

## Timeless

Avoid trends that will quickly age.

Avoid neon colors.

Avoid esports styling.

Avoid excessive gradients.

Instead, draw inspiration from heirloom board games, printed books, and luxury industrial design.

---

# Visual Language

The visual identity combines modern Liquid Glass materials with traditional tabletop craftsmanship.

The hierarchy of visual inspiration is:

1. Glass
2. Marble
3. Paper

Glass provides depth.

Marble provides permanence.

Paper provides warmth.

Every screen should feel softly illuminated, with subtle translucency rather than high contrast.

---

# Color System

Unlike many modern applications, Crown intentionally avoids a saturated accent color.

The interface is almost entirely neutral, allowing metallic gold to become meaningful.

## Accent Gold

The primary application color.

```
#B8842E
```

Used for:

- Active navigation
- League shields
- Progress indicators
- Primary actions
- Active tabs
- Achievement accents
- Membership accents

Gold should never dominate the interface.

It is reserved for moments of importance.

---

## Warm White Background

```
#F7F5F2
```

Not pure white.

Slightly warm.

---

## Glass Surface

```
rgba(255,255,255,0.72)
```

---

## Surface Border

```
rgba(255,255,255,0.40)
```

---

## Primary Text

```
#1D1A17
```

---

## Secondary Text

```
#6D6964
```

---

## Divider

```
#E8E3DC
```

---

## Success

Muted green.

```
#5D8C67
```

---

## Warning

Warm amber.

```
#C98A2C
```

---

## Error

Muted red.

```
#B65454
```

---

# Typography

Typography is fundamental to Crown's identity.

Unlike most mobile games, Crown intentionally avoids geometric sans-serif fonts for headings.

Its typography should resemble a beautifully printed chess manual or classic book.

## Primary Typeface

Cormorant Garamond

Used for:

- Titles
- Cards
- Navigation titles
- League names
- Headlines

The generous serifs establish the premium identity of the application.

---

## Secondary Typeface

Use the platform's system sans-serif (SF Pro on Apple platforms, Roboto on Android) only for supporting UI where clarity is more important than personality.

Examples include:

- timestamps
- metadata
- captions
- settings
- small labels
- accessibility text

---

# Type Scale

## Hero

48pt

Cormorant Garamond SemiBold

Used only for:

- CROWN wordmark
- major onboarding screens

---

## Large Title

36pt

Cormorant Garamond

---

## Section Title

28pt

Cormorant Garamond

---

## Card Title

22pt

Cormorant Garamond

---

## Body

17pt

System Sans

---

## Secondary

15pt

System Sans

---

## Caption

13pt

System Sans

---

## Label

11pt

System Sans Medium

Uppercase only for metadata such as:

CURRENT LEAGUE

FEED

RATING

---

# Iconography

Icons should resemble engraved symbols.

Rounded.

Thin.

Elegant.

Never playful.

Filled variants are reserved exclusively for active states.

---

# Navigation

Bottom navigation contains exactly four destinations.

- Home
- League
- Feed
- Profile

The navigation bar floats above the content using a translucent glass material.

---

## Active State

The active destination is indicated using:

- gold icon
- gold label
- subtle circular glass highlight
- small gold indicator beneath the label

There should never be a blue active state.

Inactive tabs remain neutral gray.

---

# Game Selector

The Checkers / Chess selector functions as a segmented control.

Selected game:

- glass elevation
- gold icon
- gold label

Unavailable games display a lock icon.

---

# Cards

Cards define nearly every screen.

Characteristics:

- Glass material
- Soft internal lighting
- Large corner radius
- Minimal borders
- Generous whitespace

Cards should feel collectible.

---

## Feature Cards

Examples:

- Play
- Play Online
- Puzzles

Include:

- painterly illustration
- large title
- supporting description
- floating circular action button

---

## Information Cards

Examples:

- League
- Activity
- Profile
- Statistics

Prioritize typography over decoration.

---

## Feed Cards

Designed for quick scanning.

Contain:

- icon
- title
- description
- metadata
- optional action

Recent matches intentionally omit scores, emphasizing outcomes rather than point totals.

---

# Buttons

Buttons should feel tactile rather than flat.

## Primary Button

Warm glass.

Gold text.

Subtle shadow.

56pt height.

---

## Secondary Button

Transparent glass.

Neutral text.

---

## Circular Action Button

Floating circular glass button.

Contains only an arrow or icon.

Used throughout the home screen.

---

# Layout

Base spacing unit:

8pt

Preferred spacing scale:

4

8

12

16

24

32

40

48

64

Content width prioritizes comfortable reading over maximum density.

Horizontal page padding:

24pt

Vertical spacing between sections:

32pt

---

# Corners

Cards:

24pt

Buttons:

18pt

Circular controls:

Fully rounded

---

# Shadows

Very soft.

Large blur.

Low opacity.

Shadows should imply elevation without becoming visible objects.

---

# Motion

Motion should resemble physical objects moving beneath glass.

Standard duration:

250ms

Fast interactions:

150ms

Large transitions:

350ms

Preferred curves:

Ease Out

Gentle Spring

Avoid exaggerated bounce.

---

# Navigation Animation

Changing tabs:

- content crossfades
- navigation indicator slides
- glass highlight glides beneath the selected destination

---

# Cards

Cards lift approximately 2 points on press.

Buttons compress slightly before release.

League shields emit a subtle gold glow when promoted.

---

# League Identity

Leagues are represented by metallic shield emblems.

Unlike the earliest MVP concepts, Crown exposes both **Leagues** and **League Tiers**.

Example hierarchy:

- Bronze III
- Bronze II
- Bronze I
- Silver III
- Silver II
- Silver I
- Gold III
- Gold II
- Gold I
- Platinum III
- Platinum II
- Platinum I
- Diamond

Gold III progresses to Gold II, then Gold I before Platinum III.

The MVP League is persistent and nonseasonal. League and League Tier are derived directly from Elo.

Logical Checkers sides are Black and White, with Black moving first. Board and piece cosmetics must never be the only way ownership, legal moves, or turn state are communicated.

The League screen should make progression between tiers visually obvious while keeping the shield as the primary visual identity.

---

# Illustrations

Illustrations are softly rendered.

Never cartoonish.

Preferred subjects include:

- checkers pieces
- chess pieces
- marble boards
- crowns
- architectural interiors
- sunlight
- paper
- abstract game scenes

They should resemble editorial artwork more than concept art.

---

# Accessibility

Minimum touch target:

44×44pt

Support:

- Dynamic Type
- VoiceOver / TalkBack
- Reduced Motion
- Increased Contrast

Reduced Motion replaces movement with opacity transitions while preserving the interface hierarchy.

---

# Overall Experience

Using Crown should feel like opening a handcrafted game box, placing polished pieces onto a marble board, and settling in for a thoughtful match.

The interface should disappear into the background, leaving only the feeling of craftsmanship, clarity, and mastery.
