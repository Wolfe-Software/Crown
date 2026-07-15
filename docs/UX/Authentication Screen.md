**Screen:** Authentication  
**Platforms:** iOS (Primary), Android  
**Purpose:** Authenticate every player with a durable Crown account before they enter the app, while making the first interaction feel clear, trustworthy, and premium.
**Mockup:** [[AuthenticationScreen.png]]

---

Canonical account and offline behavior: [[Specs/Auth Account and Offline]]. First-launch optional-data choice: [[Privacy Consent Screen]].

---

# Design Principles

The Authentication screen should feel:

- Welcoming
- Trustworthy
- Focused
- Premium
- Private

The player should understand why an account is required without reading technical language.

Authentication is required during Alpha. Anonymous guest mode and a skip action are not offered.

On a new installation, [[Privacy Consent Screen]] appears before Authentication and before optional SDK collection. Accepting or declining optional data does not change the authentication methods or account capabilities shown here.

---

# Screen Layout

From top to bottom:

1. Crown identity
2. Welcome card
3. Authentication provider buttons
4. Terms and Privacy notice

The screen does not normally scroll on standard phone sizes.

On smaller displays, the welcome card may scroll while the system safe areas remain respected.

Bottom navigation is not displayed.

---

# Background

Uses the shared Crown visual language.

- Warm ivory marble
- Soft lighting gradients
- Gentle vignette
- Decorative game pieces near the outer edges

Decorative pieces must not overlap controls or compete with authentication choices.

No distracting animation.

---

# Header

Centered above the welcome card.

Contains:

- Gold Crown logo
- CROWN wordmark

The header does not contain navigation or a back button during initial launch.

---

# Welcome Card

The primary content surface.

Uses:

- Frosted warm glass
- Rounded corners
- Soft internal lighting
- Thin highlights
- Gentle shadow

---

## Title

Displays:

Welcome to Crown

Large serif typography.

---

## Supporting Text

Displays:

Sign in to save your progress, track your rank, and compete.

The copy explains player value rather than implementation requirements.

---

# Authentication Methods

Methods appear in this order on iOS:

1. Continue with Apple
2. Continue with Google
3. Continue with Email

On Android, Continue with Google appears first, followed by Continue with Apple and Continue with Email.

All methods create or restore the same Crown account model and permanent user identifier.

Provider ordering does not imply different account capabilities.

---

# Continue with Apple

Displays:

- Apple logo
- Continue with Apple

Selecting opens the native Apple authentication flow.

If the player hides their email address, Crown uses the private relay address supplied by Apple.

Cancellation returns to the Authentication screen without showing an error.

---

# Continue with Google

Displays:

- Google logo
- Continue with Google

Selecting opens the Google account chooser.

Cancellation returns to the Authentication screen without showing an error.

---

# Continue with Email

Displays:

- Envelope icon
- Continue with Email

Selecting opens the Email Authentication screen.

---

## Email Authentication Screen

Contains:

1. Back button
2. Title
3. Email field
4. Password field
5. Primary action
6. Sign-in or account-creation switch
7. Password recovery action

The initial mode is Sign In.

---

## Sign In

Title:

Welcome Back

Primary action:

Sign In

Fields are validated after the player leaves a field and again when the primary action is selected.

Error copy must not reveal whether an email address belongs to an account.

---

## Create Account

Title:

Create Your Account

Contains:

- Display name
- Email
- Password
- Confirm password

Primary action:

Create Account

The display name follows the same requirements used by Edit Profile.

After successful creation, the player proceeds into Crown.

Email-password accounts must verify their email before matchmaking, Friends, social Feed reads, or rated and unrated friend play. Unverified players may use adaptive bot play, their own settings, and the current Daily Puzzle while online or an already assigned puzzle while offline.

Apple or Google satisfies the gate when the provider returns a verified email claim.

---

## Password Recovery

Selecting Forgot Password opens a focused recovery view.

Contains:

- Email field
- Send Reset Link button
- Return to Sign In action

After submission, display neutral confirmation copy whether or not the address is registered.

Example:

If an account matches that email, a reset link is on its way.

---

# Terms and Privacy

Displayed beneath the provider buttons.

Copy:

By continuing, you agree to our Terms of Service and Privacy Policy.

Terms of Service and Privacy Policy are separate interactive links.

Selecting either opens an in-app browser. Returning from the browser preserves the Authentication screen state.

Selecting an authentication method confirms agreement to the current Terms of Service and Privacy Policy.

---

# Existing Account Handling

If a provider credential matches an existing Crown account:

- Restore that account
- Preserve its progress and purchases
- Continue to the appropriate app destination

If the same email is already associated with another provider, explain that the player must use the original sign-in method before linking another method from Settings.

Never create a duplicate account automatically when an existing credential can be identified safely.

---

# First-Time Profile Setup

After a provider authenticates a new account, collect:

- Display name
- Crown handle
- Stored IANA time zone derived from the device and confirmed by the player

Display names contain 1-30 trimmed grapheme clusters and do not need to be unique.

The Crown handle is the globally unique, player-facing identifier used for exact friend lookup. Availability is checked by the server and reserved atomically. Email addresses are never used as public lookup identifiers.

Account initialization is idempotent. Retrying setup cannot reset rating, create a second profile, or reserve multiple handles.

After setup, continue to Home.

---

# Linked Accounts

Additional sign-in methods are managed from Profile Settings after authentication.

Linking another provider does not create a new Crown profile.

At least one usable sign-in method must remain connected to the account.

---

# Returning Player Behavior

If a valid authenticated session exists:

- Do not display the Authentication screen
- Restore the session
- Open the last appropriate primary destination

If the network is unavailable but the device has a valid cached account session, enter authenticated-offline mode. Do not force a returning player through Authentication solely because token refresh cannot reach the network.

If credentials need refreshing, show the Crown launch state while refresh occurs.

If refresh fails because the session is invalid, return to Authentication and display:

Your session has expired. Sign in again to continue.

---

# Success Behavior

After successful authentication:

1. Confirm the account session.
2. Load essential player data.
3. Crossfade into the Home screen.

The Authentication screen must not briefly reappear during normal app launch after a session is established.

---

# Error Handling

Errors appear near the affected control and remain concise.

Examples:

- We couldn't sign you in. Try again.
- Check your email and password.
- This sign-in method is already linked to another account.
- Too many attempts. Wait a moment and try again.

Technical provider codes are never shown.

Retrying does not clear valid field values.

---

# Network Handling

New sign-in, account creation, provider linking, and verification refresh require a network connection.

If connectivity is lost during a provider flow:

Display:

Connection interrupted.

Primary button:

Try Again

Secondary action:

Return to Sign In

---

# Buttons

Provider buttons use the shared Crown button construction while preserving required provider branding.

Characteristics:

- Minimum 56pt height
- Large rounded corners
- Clear provider icon
- Centered label
- Full-width touch target
- Pressed elevation and shadow response

Only one authentication request may be active at a time.

Other provider buttons are temporarily disabled while a request is active.

---

# Motion

Motion should feel calm and immediate.

Examples:

Welcome card:

Soft fade and slight upward movement.

Provider press:

Subtle compression.

Success transition:

Crossfade into Home.

Reduced Motion replaces movement with opacity changes.

---

# Loading States

When a provider request begins:

- Keep the selected provider label visible
- Show a compact progress indicator
- Disable repeated submission
- Preserve the rest of the layout

If initial account data takes longer than expected, display:

Preparing your Crown account...

---

# Empty States

Not applicable.

The screen always provides at least the supported authentication methods and legal links.

---

# Accessibility

Supports:

- VoiceOver
- TalkBack
- Dynamic Type
- Reduced Motion
- High Contrast

Interactive elements meet the 44×44pt minimum touch target.

Provider buttons expose their full label and state.

Example accessibility label:

"Continue with Apple. Button."

Decorative game pieces are hidden from accessibility navigation.

Errors are announced when they appear and focus moves to the first invalid field.

---

# Offline Behavior

If the Authentication screen opens without connectivity and no eligible cached session exists:

Display:

You're offline.

Connect to the internet to sign in to Crown.

Primary button:

Retry

Authentication provider buttons remain visible but disabled until connectivity returns.

---

# Privacy and Security

- Passwords are never displayed in plain text by default.
- Password managers and platform autofill are supported.
- Sensitive provider tokens are never shown in copy or logs visible to the player.
- Authentication errors avoid confirming whether another person has an account.
- Legal links remain accessible before authentication.
- Authentication does not implicitly grant optional-data consent. The saved device choice remains authoritative.

Sign-out is managed from Profile Settings and follows [[Specs/Auth Account and Offline]], including queue cancellation and account-scoped cache clearing. Detailed account-deletion policy remains a launch-readiness requirement.

---

# Future Expansion

The Authentication screen can support additional compliant providers without changing its core hierarchy.

Potential future additions include:

- Passkeys
- Age or regional consent when required
- Account recovery codes
- Additional identity providers

Anonymous guest mode is not planned for the current MVP and must not be added without defining progress ownership, account merging, purchases, and rated-play eligibility.
