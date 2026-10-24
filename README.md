# Crown

Crown is a premium, entirely offline English checkers app for iOS and Android. It supports pass-and-play local multiplayer and single-player matches against an adaptive AI.

## Gameplay

Crown implements WCDF English draughts under Go As You Please opening play:

- Black moves first.
- Captures and continued captures are mandatory.
- Men move and capture forward; kings move and capture in both directions.
- Crowning ends the current turn.
- No-piece and no-legal-move wins are detected automatically.
- Threefold repetition and the 80-ply quiet-king rule produce automatic draws.

The rules engine is pure Dart and shared by live play, AI search, save restoration, and replay.

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

No Firebase project or network service is required.

## Learn Lessons

`assets/learn/catalog.json` is the sole curriculum source. It contains all 64
lesson records and marks each lesson as `planned` or `available`. Available
records reference a versioned definition under `assets/learn/lessons/`; planned
records must not expose an executable definition.

Schema-v2 lesson definitions contain all lesson-specific text, board positions,
perspective, accepted actions, feedback, optional outcomes, and optional
opponent replies. The supported board sources are `initial`,
`initialWithRemovedPieces`, `custom`, and `previousExerciseResult`. The
supported interactions are `placement`, `turn`, `choice`, and ordered
`squareSelection`. Turns accept `allLegal` engine moves, an `exactLegalSet` of
authored moves, or a `legalSubset` of moves satisfying an exercise's goal.
Goal exercises show all engine-legal destinations, require `feedback.goalMiss`
for legal attempts that miss the goal, and restore the position for a retry.
Choices identify one correct option and provide feedback for every answer.
Choice options may declare `blackChecker`, `whiteChecker`, or `draw` icons for
visual answer cards. Squares use the engine's `{row, column}` JSON
representation. Authored turn outcomes are validated against `CheckersEngine`,
and all outcome indicators use the same bottom-sheet result presentation as
matches.

Turn interactions may include `openingTurns` and `openingPauseMs` (default 550)
to demonstrate a short sequence before the learner moves. They require
`feedback.opening`; `feedback.initial` is shown when control passes to the
learner. Accepted turns are validated against the position after the opening.
An optional `opponentReply` must be legal after every accepted learner turn and
requires `feedback.awaitingReply`. Input is disabled during demonstrations,
replies, and jump animations. Automatic turns are not recorded as player turns.

An interaction can add `followUps` to let the learner play a second turn after
the reply. Supply exactly one branch for every accepted first turn. Each branch
contains `afterTurn` (the complete first turn), `instruction`, `acceptance`,
`turns`, and `feedback`, plus an optional closing `opponentReply` and
`opponentPauseMs`. Branches are validated against their own resulting board,
including any closing reply and final outcome. Nested follow-ups are not
supported: a practice exercise has at most two learner phases. Instruction,
feedback, accepted moves, and retry state switch together when control returns
to the learner. Continue appears only after the full sequence is resolved.

A move exercise with an explicit board may declare a read-only `threat`:
`label`, complete opponent capture `routes`, and an optional learner `afterTurn`
for a conditional threat. The loader checks the routes against the engine,
after any opening and conditional move. Conditional routes stay on the live
board with an explicit "if" label. The overlay marks attackers, targets, arrows,
and numbered landings without intercepting taps or replacing move hints. Threats
disappear during moves, replies, and after completion.

Optional exercise-level `preparation` stages supply `instruction`, `feedback`,
and a passive `observation` or `choice` interaction. They retain the exercise
title and standard Continue control. Optional `previewTurns` animate an
engine-legal worked example on a separate board copy; shared prefixes between
stages are retained, so the reply continues from the demonstrated candidate.
Continue and answer input wait until the demonstration finishes. Reduced motion
keeps a pre-move pause. These examples never alter the live position or record
player turns; finishing preparation restores the live board for a real move.
Choices use the shared lesson cards, with optional icons and short labels.
Stages may include their own `threat`, and cannot be nested. Preparation does
not support indicative square-selection questions.

Unit 2's standard lessons (9–15) each contain five exercises ending in player
moves. Their move sequences use at most two learner turns and six board taps,
with at most three taps per turn: piece selection and up to two jump landings.
Lesson 14 shows capture threats and immediately asks for actual defensive moves.
Lesson 15 introduces the four-step safety check through a worked example, then
applies it through moves and one exchange question: check your captures, test a
candidate move, inspect their complete reply, then count and decide.
Opening demonstrations and replies show threats and exchanges without replacing
the learner's move. Ordinary opponent steps are visibly animated too; reduced
motion retains a readable pre-move pause and the resulting last-move highlight.
Lesson 16 applies these skills in a complete guided match.

### Lesson priorities

- Never require the learner to deliberately make a bad move to demonstrate its
  cost. Let them escape a threat, preserve protection, block a capture, or
  otherwise correct a preexisting poor position.
- If a coached move enables a capture or recapture, keep the exercise active
  until the learner plays that payoff. Do not complete on a message that merely
  says a capture is now available.
- When an opponent mistake creates the opportunity being exploited, start before
  that mistake and show the actual move through an opening or reply. Do not
  initialize the board after the mistake.
- Keep the learner's side consistent within an exercise. Automatic opponent
  moves must never substitute for the learner's setup or payoff.
- Equal exchanges and favorable man-for-king trades can be sound moves. Resolve
  the whole exchange and explain both losses and ranks accurately.
- Defensive exercises may begin with an existing threat. Accept all moves that
  satisfy the stated goal, and distinguish legal but unsuitable attempts from
  illegal moves when giving retry feedback.

`LessonAssetLoader` parses the assets and validates authored positions and
turns against `CheckersEngine`. Every available lesson then runs through the
same `LessonSessionController`, `LessonScreen`, and
`LessonExerciseScaffold`. Do not add lesson-specific controllers, screens, or
routing branches.

Completed exercises remain visible until the player chooses `CONTINUE`.
Completed final exercises remain visible until the player chooses
`COMPLETE LESSON`. Player turns use the same tap flow as a match: every landing
in a multiple jump requires its own tap. Authored opponent actions may run
automatically within an exercise, but timers must not advance to another
exercise or complete a lesson. The generic screen passes accessibility
settings to the board and its widget tests use
`expectStandardLessonPresentation`.

Validate every authored board fixture against the production rules engine and
test every accepted solution branch before changing a lesson to `available`.
Adding a lesson should require JSON and data-driven tests only.

## Move Audio

`assets/move.wav` is a processed, real recording of a wooden board-game piece
landing on a board. Regenerate it offline from the checked-in source excerpt:

```sh
python3 tool/generate_move_audio.py
python3 tool/generate_move_audio.py --check
python3 -B -m unittest discover -s test/tool -p '*_test.py'
```

See [audio source and processing notes](tool/audio_sources/README.md) for the
CC0 license, source attribution, excerpt location, and processing settings.
The current Version B adds gentle low-mid EQ and compression, RMS-matched to
the original. `tool/audio_sources/move-baseline.wav` preserves that original
as a development-only listening reference.

## App Icon

`assets/AppIcon.png` is the original icon artwork. Android uses an opaque,
full-bleed crop with no additional adaptive-icon inset. Regenerate that master,
the runtime logo assets, and the source layers for Apple's Icon Composer with:

```sh
dart run tool/generate_app_icon.dart
cp assets/generated/app_icon/DefaultIcon.png ios/Runner/AppIcon.icon/Assets/
cp assets/generated/app_icon/MarbleTexture.png ios/Runner/AppIcon.icon/Assets/
cp assets/generated/app_icon/CrownForeground.png ios/Runner/AppIcon.icon/Assets/
dart run flutter_launcher_icons
```

`flutter_launcher_icons` manages Android only. The canonical iOS and iPadOS
icon is `ios/Runner/AppIcon.icon`, authored with Icon Composer from Xcode 26 or
later. It provides separate default, dark, monochrome, clear, and tinted
renderings; Xcode generates fallback resources when building for iOS 15-25.
Marble appears only in the default rendering. Dark uses Apple's standard
system-dark background, while clear and tinted backgrounds are generated
dynamically from the system appearance and the user's selected tint.
Open that document in Icon Composer after replacing a layer to review every
appearance before committing the complete `.icon` package. Do not restore an
`AppIcon.appiconset` beside it because the two sources conflict.

The generated Icon Composer sources are `DefaultIcon.png`, the original
flattened default artwork; `MarbleTexture.png`, a neutral alpha texture that can
be recolored for each appearance; `CrownForeground.png`, the gold crown without
marble or cast shadow; and `CrownMask.png`, the matching monochrome silhouette
used to verify clear and tinted artwork. The `.icon` document embeds the first
three files, so rerun the three `cp` commands whenever the generated layers
change.

The same generator creates `assets/CrownLogo.png`, a transparent `1024x1024`
asset containing the crown at exactly the same scale and position as the app
icon. The marble background and cast shadow are excluded. It also creates
`assets/BrokenCrownLogo.png`, which separates the crown and base along a jagged
diagonal fracture, tilts the halves outward, and gives them a mostly
desaturated metal finish.

It also creates `assets/MarbleBackground.png`, an opaque `1024x1024` warm ivory
marble texture sampled from the app icon palette without embedded crown artwork.

`assets/JeweledCrownLogo.png` is a standalone runtime asset used on the Play
Crown AI card. It is not generated by the app icon tooling.

The generator also creates `assets/DrawLogo.png`, a detailed metallic-gold
balanced-scales symbol used for drawn match results and history entries.
