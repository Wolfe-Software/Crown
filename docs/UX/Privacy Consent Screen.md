**Screen:** Privacy Consent  
**Platforms:** iOS (Primary), Android  
**Purpose:** Obtain the player's first-launch choice about optional data collection before Authentication and before any optional telemetry collection begins.
**Mockup:** Not yet available

---

Canonical event definitions and collection behavior: [[Analytics Measurement Plan]]. Canonical SDK ownership, initialization, and environment behavior: [[Firebase Environments and Services]].

---

# Design Principles

The Privacy Consent screen should feel:

- Clear
- Neutral
- Trustworthy
- Unhurried
- Easy to understand

The screen asks for one explicit choice. It must not pressure the player toward either outcome or imply that optional collection is required to play Crown.

The final player-facing title, description, category explanations, Privacy Policy text, and link treatment require legal review and finalization before launch. This document defines product behavior and does not claim that any wording or implementation satisfies a legal or regulatory requirement.

---

# Launch Order

The Privacy Consent screen appears on first launch before the Authentication screen.

Until the player makes a choice:

- Analytics collection is disabled
- Advertising data use and personalization are disabled
- Crashlytics collection is disabled
- Performance collection is disabled
- Optional telemetry SDK collection does not begin
- Optional events, identifiers, traces, diagnostics, and advertising signals are not buffered for later submission

SDK configuration and initialization follow [[Firebase Environments and Services]]. Event names, properties, and allowed collection follow [[Analytics Measurement Plan]].

The consent screen remains the active launch destination until a choice is successfully applied for the current session. Bottom navigation and Authentication are not displayed behind it.

---

# Consent Model

One explicit choice controls all optional data collection categories together:

- Analytics
- Advertising data use and personalization
- Crashlytics
- Performance

There are no category-level toggles on this screen. The default state is denied, including when no saved choice exists, a saved choice cannot be read, or a state transition fails.

Consent is device-scoped rather than account-scoped. The saved choice applies before sign-in and does not follow the player to another device through their Crown account.

The runtime collection state must be derived from the persisted device choice before an optional telemetry SDK can collect. A missing or unreadable value is treated as denied.

---

# Screen Layout

From top to bottom:

1. Crown identity
2. Privacy title
3. Plain-language explanation
4. Optional data category summary
5. Privacy Policy link
6. Accept optional data action
7. Continue without optional data action

The content may scroll on compact displays or at large text sizes. Both actions remain reachable without requiring precise gestures or horizontal scrolling.

No close, dismiss, skip, or back action bypasses the explicit choice.

---

# Content

The explanation must state that optional collection helps Crown understand usage, use advertising data and personalize advertising where offered, diagnose crashes, and measure performance.

It must also state that:

- The choice is optional
- Declining does not restrict gameplay
- The choice can be changed later in Settings
- Accepting starts future collection only
- Data is not collected or held for later submission before acceptance

The screen links to the current Privacy Policy. Returning from the policy preserves the consent screen and does not change the player's choice.

Player-facing legal copy must be finalized before launch. Placeholder or unreviewed legal copy is a launch blocker.

---

# Actions

The screen provides exactly two decision actions:

- Accept optional data
- Continue without optional data

The actions have equal visual prominence, size, contrast, placement weight, and touch-target treatment. Neither action is styled as a secondary text link, hidden below unrelated content, preselected, or made harder to reach.

Selecting either action is an explicit decision. Simply viewing the screen, opening the Privacy Policy, backgrounding the app, or timing out does not grant consent.

---

## Accept Optional Data

Selecting Accept optional data:

1. Records the granted device-scoped choice.
2. Applies granted collection settings to Analytics, advertising data use and personalization, Crashlytics, and Performance.
3. Allows only future optional collection.
4. Continues to Authentication after the choice is successfully applied.

Granting consent does not create, reconstruct, or submit events from before the choice. No pre-consent buffer is replayed.

---

## Continue Without Optional Data

Selecting Continue without optional data:

1. Records the denied device-scoped choice.
2. Keeps Analytics, advertising data use and personalization, Crashlytics, and Performance collection disabled.
3. Continues to Authentication after the choice is successfully applied.

Declining never restricts gameplay, account creation, authentication methods, online or offline modes, progression, social features, or settings access.

---

# Returning Launches

When a valid device-scoped choice exists, do not show the first-launch screen again during normal launch. Apply the saved choice before optional telemetry collection can begin, then continue to the appropriate Authentication or signed-in destination.

If the choice is missing, corrupt, or unreadable, treat collection as denied and show the Privacy Consent screen again.

Signing in, signing out, switching accounts, or deleting an account does not change the device-scoped choice.

---

# Settings Changes

The player can change the same all-or-nothing optional data choice later in Settings.

Granting from Settings:

- Enables future collection for all four categories
- Does not collect, infer, reconstruct, or upload activity from before the grant
- Does not replay any pre-consent events because no pre-consent buffer exists

Withdrawing from Settings:

- Disables Analytics, advertising data use and personalization, Crashlytics, and Performance collection
- Clears the Google Analytics user ID
- Clears Google Analytics user properties
- Resets local analytics state
- Prevents later submission of optional data generated after withdrawal

The disabled state is applied before the withdrawal action reports success. Data handling beyond these client-state requirements must be defined by the canonical plans and finalized legal policy; the interface must not promise deletion that the product does not implement.

---

# Pending States

Only one consent update may be active at a time.

After either action is selected:

- Keep both complete action labels visible
- Show a compact progress indicator on the selected action
- Disable repeated submission
- Keep the other action disabled while the update is applied
- Do not navigate to Authentication until the runtime collection state matches the recorded choice

The pending state does not start optional collection unless and until a granted choice has been successfully recorded and applied.

If the app enters the background while an update is pending, optional collection remains denied until the transition completes successfully.

---

# Error Handling

If the choice cannot be saved or applied, fail closed: optional collection remains disabled.

Display:

We couldn't save your privacy choice.

Actions:

- Try Again
- Continue without optional data

Try Again retries the selected choice. Continue without optional data proceeds for the current session with all optional collection disabled; if denial cannot be persisted, the screen appears again on the next launch.

Errors never silently convert a denial into a grant. Technical SDK or storage errors are not shown to the player.

---

# Offline Behavior

The player can make either choice without a network connection because the choice is stored on the device.

Offline acceptance permits future collection only. SDKs must not synthesize or recover activity from before acceptance, and any later transmission is subject to the active granted state at transmission time.

Offline decline continues to Authentication with optional collection disabled. Lack of connectivity does not block either decision or make one action less available than the other.

If local persistence is unavailable, use the error behavior and keep collection denied.

---

# Accessibility

Supports:

- VoiceOver
- TalkBack
- Dynamic Type
- Reduced Motion
- High Contrast

Both decision actions expose their full labels, button role, enabled or disabled state, and pending state. Their accessible names must not frame one choice as recommended.

The category summary is available as text and is not communicated by icons, color, or position alone.

Interactive elements meet a minimum 44x44pt touch target. Focus order follows the visual reading order, the Privacy Policy link is identified as a link, and errors are announced when they appear.

At large text sizes, content reflows vertically without clipping either decision action. Reduced Motion replaces decorative transitions with immediate state changes or restrained opacity changes.

---

# Motion

Motion should remain calm and must not draw disproportionate attention to either choice.

The screen may use a restrained fade on entry. Selection feedback is equivalent for both actions. No countdown, pulsing treatment, repeated animation, or automatic selection is used.

---

# Launch Readiness

Launch is blocked until:

- Final player-facing legal copy is approved and implemented
- The Privacy Policy destination and return behavior are verified
- Both choices are verified before Authentication and before optional SDK collection
- Default-denied and no-pre-consent-buffer behavior are verified
- Grant, withdrawal, offline, persistence-error, and returning-launch paths are verified
- Accessibility behavior is verified on iOS and Android

These gates verify the specified product behavior. They do not constitute or imply a claim of legal compliance.
