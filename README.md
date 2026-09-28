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
supported interactions are `placement`, `turn`, and `choice`; turns either
accept `allLegal` engine moves or an `exactLegalSet` of authored moves, while
choices identify one correct option and provide feedback for every answer.
Choice options may declare `blackChecker`, `whiteChecker`, or `draw` icons for
visual answer cards. Squares use the engine's `{row, column}` JSON
representation. Authored turn outcomes are validated against `CheckersEngine`,
and all outcome indicators use the same bottom-sheet result presentation as
matches.

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
