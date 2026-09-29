import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:crown/features/match/move_audio.dart';
import 'package:crown/features/match/match_controller.dart';
import 'package:crown/features/match/match_screen.dart';
import 'package:crown/features/learn/guided_match_controller.dart';
import 'package:crown/features/learn/guided_match_screen.dart';
import 'package:crown/features/learn/lesson_asset_loader.dart';
import 'package:crown/features/learn/lesson_definition.dart';
import 'package:crown/features/learn/lesson_screen.dart';
import 'package:crown/features/learn/lesson_session_controller.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:crown/persistence/crown_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingPlayer implements AudioPlayer {
  final calls = <String>[];
  final completions = StreamController<void>.broadcast();
  @override
  Stream<void> get onPlayerComplete => completions.stream;
  @override
  Future<void> setReleaseMode(ReleaseMode mode) async =>
      calls.add('mode:$mode');
  @override
  Future<void> setVolume(double volume) async => calls.add('volume:$volume');
  @override
  Future<void> setSource(Source source) async =>
      calls.add('source:${(source as AssetSource).path}');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> resume() async {
    calls.add('resume');
    scheduleMicrotask(() => completions.add(null));
  }

  @override
  Future<void> dispose() async => calls.add('dispose');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingMoveAudio extends MoveAudio {
  int prepares = 0;
  int plays = 0;
  int disposals = 0;

  @override
  Future<void> prepare() async => prepares++;

  @override
  Future<void> play() async => plays++;

  @override
  Future<void> dispose() async => disposals++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GuidedMatchDefinition guidedDefinition;
  late LessonDefinition standardDefinition;
  setUpAll(() async {
    final catalog = await LessonAssetLoader().loadCatalog(
      'assets/learn/catalog.json',
    );
    guidedDefinition =
        catalog.definitions['lesson-008']! as GuidedMatchDefinition;
    standardDefinition = catalog.definitions['lesson-001']!;
  });
  test('iOS preloads and reuses its native audio player', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <MethodCall>[];
    const channel = MethodChannel('crown/move_audio');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'prepare' ? 42 : null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final audio = MoveAudio();
    await audio.prepare();
    await audio.play();
    await audio.play();
    await audio.dispose();
    await audio.play();
    expect(calls.map((call) => call.method), [
      'prepare',
      'play',
      'play',
      'dispose',
    ]);
    expect(calls.skip(1).map((call) => call.arguments), everyElement(42));
  });

  test(
    'failed iOS preparation retries without bypassing playback volume',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('crown/move_audio');
      var attempts = 0;
      var clicks = 0;
      final nativeCalls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        nativeCalls.add(call.method);
        if (call.method == 'prepare') {
          attempts++;
          if (attempts == 1) throw PlatformException(code: 'asset-error');
          return 42;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemSound.play') clicks++;
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final audio = MoveAudio();
      await audio.play();
      expect(clicks, 0);
      await audio.play();
      expect(attempts, 2);
      expect(nativeCalls, ['prepare', 'prepare', 'play']);
      expect(clicks, 0);
      await audio.dispose();
    },
  );

  for (final sound in [true, false]) {
    testWidgets('standard lessons respect sound=$sound across exercises', (
      tester,
    ) async {
      final audio = RecordingMoveAudio();
      var audioCreations = 0;
      final controller = LessonSessionController(
        definition: standardDefinition,
        reducedMotion: true,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            controller: controller,
            highContrast: false,
            reducedMotion: true,
            sound: sound,
            createMoveAudio: () {
              audioCreations++;
              return audio;
            },
          ),
        ),
      );

      for (final target in controller.placementTargets) {
        controller.tapSquare(target);
      }
      controller.continueExercise();
      controller.tapSquare(controller.placementTargets.first);
      await tester.pump();

      expect(audioCreations, sound ? 1 : 0);
      expect(audio.prepares, sound ? 1 : 0);
      expect(audio.plays, sound ? 4 : 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(audio.disposals, sound ? 1 : 0);
    });
  }

  testWidgets('standard lesson audio follows a replacement controller', (
    tester,
  ) async {
    final audio = RecordingMoveAudio();
    final first = LessonSessionController(
      definition: standardDefinition,
      reducedMotion: true,
    );
    final second = LessonSessionController(
      definition: standardDefinition,
      reducedMotion: true,
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    Widget lesson(LessonSessionController controller) => MaterialApp(
      home: LessonScreen(
        controller: controller,
        highContrast: false,
        reducedMotion: true,
        sound: true,
        createMoveAudio: () => audio,
      ),
    );

    await tester.pumpWidget(lesson(first));
    first.tapSquare(first.placementTargets.first);
    expect(audio.plays, 1);

    await tester.pumpWidget(lesson(second));
    first.tapSquare(first.placementTargets.elementAt(1));
    second.tapSquare(second.placementTargets.first);
    expect(audio.plays, 2);
  });

  for (final sound in [true, false]) {
    testWidgets('Lesson 8 human and AI turns respect sound=$sound', (
      tester,
    ) async {
      final audio = RecordingMoveAudio();
      var audioCreations = 0;
      final controller = GuidedMatchController(
        definition: guidedDefinition,
        reducedMotion: true,
        minimumAiTurnDuration: Duration.zero,
        aiDelay: (_) async {},
        aiMoveChooser: (state, _) async =>
            const CheckersEngine().legalTurns(state).first,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedMatchScreen(
            controller: controller,
            highContrast: false,
            reducedMotion: true,
            sound: sound,
            createMoveAudio: () {
              audioCreations++;
              return audio;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BEGIN MATCH'));
      await tester.pumpAndSettle();
      await controller.tapSquare(const Square(2, 1));
      final move = controller.tapSquare(const Square(3, 0));
      await tester.pump();
      await move;
      await tester.pumpAndSettle();

      expect(audioCreations, sound ? 1 : 0);
      expect(audio.plays, sound ? 2 : 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(audio.disposals, sound ? 1 : 0);
    });
  }

  testWidgets('Lesson 8 clicks on each landing and stays wired after retry', (
    tester,
  ) async {
    final audio = RecordingMoveAudio();
    final controller = GuidedMatchController(
      definition: guidedDefinition,
      reducedMotion: true,
      initialState: GameState.custom(
        sideToMove: Side.black,
        pieces: {
          const Square(1, 0): const Piece.blackMan(),
          const Square(2, 1): const Piece.whiteMan(),
          const Square(4, 3): const Piece.whiteMan(),
          const Square(7, 6): const Piece.whiteMan(),
        },
      ),
      minimumAiTurnDuration: Duration.zero,
      aiDelay: (_) async {},
      aiMoveChooser: (state, _) async =>
          const CheckersEngine().legalTurns(state).first,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: GuidedMatchScreen(
          controller: controller,
          highContrast: false,
          reducedMotion: true,
          sound: true,
          createMoveAudio: () => audio,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('BEGIN MATCH'));
    await tester.pumpAndSettle();
    await controller.tapSquare(const Square(1, 0));
    await controller.tapSquare(const Square(3, 2));
    final capture = controller.tapSquare(const Square(5, 4));
    await tester.pump();
    await capture;
    await tester.pumpAndSettle();
    expect(audio.plays, 3);

    controller.retry();
    await controller.begin();
    await controller.tapSquare(const Square(2, 1));
    final move = controller.tapSquare(const Square(3, 0));
    await tester.pump();
    await move;
    await tester.pumpAndSettle();
    expect(audio.plays, 5);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  test(
    'rapid landing sounds wait for completion and disposal cancels the queue',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('crown/move_audio');
      final first = Completer<void>();
      var plays = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'prepare') return 42;
        if (call.method == 'play') {
          plays++;
          if (plays == 1) await first.future;
        }
        if (call.method == 'dispose' && !first.isCompleted) first.complete();
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final audio = MoveAudio();
      await audio.prepare();
      final pending = [audio.play(), audio.play(), audio.play()];
      await Future<void>.delayed(Duration.zero);
      expect(plays, 1);
      first.complete();
      await Future.wait(pending);
      expect(plays, 3);
      await audio.dispose();

      // Disposing in the middle of a burst must skip the remaining requests.
      plays = 0;
      final gate = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'prepare') return 43;
        if (call.method == 'play') {
          plays++;
          await gate.future;
        }
        if (call.method == 'dispose') gate.complete();
        return null;
      });
      final second = MoveAudio();
      final cancelled = [second.play(), second.play(), second.play()];
      await Future<void>.delayed(Duration.zero);
      await second.dispose();
      await Future.wait(cancelled);
      expect(plays, 1);
    },
  );

  for (final animated in [false, true]) {
    testWidgets('human multi-jumps click on each landing, animated=$animated', (
      tester,
    ) async {
      final player = RecordingPlayer();
      final repository = MemoryCrownRepository();
      await repository.saveSettings(CrownSettings(reducedMotion: !animated));
      final gates = <Completer<void>>[];
      final controller = MatchController(
        session: MatchSession.newGame(
          mode: MatchMode.local,
          blackName: 'Black',
          whiteName: 'White',
          initialState: GameState.custom(
            sideToMove: Side.black,
            pieces: {
              const Square(1, 0): const Piece.blackMan(),
              const Square(2, 1): const Piece.whiteMan(),
              const Square(4, 3): const Piece.whiteMan(),
              const Square(6, 5): const Piece.whiteMan(),
            },
          ),
        ),
        repository: repository,
        jumpDelay: (_) {
          final gate = Completer<void>();
          gates.add(gate);
          return gate.future;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MatchScreen(
            controller: controller,
            createMoveAudio: () => MoveAudio(player: player),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await controller.tapSquare(const Square(1, 0));
      await controller.tapSquare(const Square(0, 1)); // Invalid destination.
      expect(player.calls.where((call) => call == 'resume'), isEmpty);
      var count = 0;
      for (final landing in [
        const Square(3, 2),
        const Square(5, 4),
        const Square(7, 6),
      ]) {
        final move = controller.tapSquare(landing);
        await tester.pump();
        if (animated) {
          expect(
            player.calls.where((call) => call == 'resume'),
            hasLength(count),
          );
          gates.last.complete();
        }
        await move;
        await tester.pumpAndSettle();
        expect(
          player.calls.where((call) => call == 'resume'),
          hasLength(++count),
        );
      }
      expect(controller.state.turns, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  for (final sound in [true, false]) {
    for (final animated in [false, true]) {
      testWidgets(
        'AI two-jump capture clicks per landing, animated=$animated sound=$sound',
        (tester) async {
          final player = RecordingPlayer();
          final repository = MemoryCrownRepository();
          await repository.saveSettings(
            CrownSettings(sound: sound, reducedMotion: !animated),
          );
          final gates = <Completer<void>>[];
          final controller = MatchController(
            session: MatchSession.newGame(
              mode: MatchMode.ai,
              humanSide: Side.white,
              blackName: 'AI',
              whiteName: 'You',
              initialState: GameState.custom(
                sideToMove: Side.black,
                pieces: {
                  const Square(1, 0): const Piece.blackMan(),
                  const Square(2, 1): const Piece.whiteMan(),
                  const Square(4, 3): const Piece.whiteMan(),
                },
              ),
            ),
            repository: repository,
            aiMoveChooser: (state, profile) async =>
                const CheckersEngine().legalTurns(state).first,
            aiDelay: (_) async {},
            jumpDelay: (_) {
              final gate = Completer<void>();
              gates.add(gate);
              return gate.future;
            },
          );
          await tester.pumpWidget(
            MaterialApp(
              home: MatchScreen(
                controller: controller,
                createMoveAudio: () => MoveAudio(player: player),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (animated) {
            expect(player.calls.where((call) => call == 'resume'), isEmpty);
            gates[0].complete();
            await tester.pumpAndSettle();
            expect(
              player.calls.where((call) => call == 'resume'),
              hasLength(sound ? 1 : 0),
            );
            gates[1].complete();
            await tester.pumpAndSettle();
          }
          expect(controller.state.turns, hasLength(1));
          expect(
            player.calls.where((call) => call == 'resume'),
            hasLength(sound ? 2 : 0),
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
    testWidgets('completed human and AI turns respect sound=$sound', (
      tester,
    ) async {
      final player = RecordingPlayer();
      final repository = MemoryCrownRepository();
      await repository.saveSettings(
        CrownSettings(sound: sound, reducedMotion: true),
      );
      final controller = MatchController(
        session: MatchSession.newGame(
          mode: MatchMode.ai,
          humanSide: Side.black,
          blackName: 'You',
          whiteName: 'Crown AI',
        ),
        repository: repository,
        aiMoveChooser: (state, profile) async =>
            const CheckersEngine().legalTurns(state).first,
        minimumAiTurnDuration: Duration.zero,
        aiDelay: (_) async {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MatchScreen(
            controller: controller,
            createMoveAudio: () => MoveAudio(player: player),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await controller.tapSquare(const Square(2, 1));
      await tester.pumpAndSettle();
      expect(player.calls.where((call) => call == 'resume'), isEmpty);
      await controller.tapSquare(const Square(3, 0));
      await tester.pumpAndSettle();
      expect(controller.state.turns, hasLength(2));
      expect(
        player.calls.where((call) => call == 'resume'),
        hasLength(sound ? 2 : 0),
      );
      await controller.resign(Side.black);
      await tester.pumpAndSettle();
      expect(
        player.calls.where((call) => call == 'resume'),
        hasLength(sound ? 2 : 0),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  test(
    'move effect is preloaded at full volume and reused until disposed',
    () async {
      final player = RecordingPlayer();
      final audio = MoveAudio(player: player);
      await audio.prepare();
      expect(player.calls, [
        'mode:ReleaseMode.stop',
        'volume:1.0',
        'source:move.wav',
      ]);
      await audio.play();
      await audio.play();
      await audio.dispose();
      await audio.play();
      expect(player.calls.skip(3), [
        'stop',
        'resume',
        'stop',
        'resume',
        'dispose',
      ]);
    },
  );
}
