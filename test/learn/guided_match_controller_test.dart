import 'dart:async';

import 'package:crown/features/learn/guided_match_controller.dart';
import 'package:crown/features/learn/lesson_asset_loader.dart';
import 'package:crown/features/learn/lesson_definition.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:crown/game_engine/crown_ai.dart';
import 'package:crown/persistence/crown_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GuidedMatchDefinition definition;
  setUp(() async {
    final catalog = await LessonAssetLoader().loadCatalog(
      'assets/learn/catalog.json',
    );
    definition = catalog.definitions['lesson-008']! as GuidedMatchDefinition;
  });

  GuidedMatchController create({
    GameState? state,
    Future<void> Function(MatchRecord record)? onAttemptCompleted,
  }) {
    final controller = GuidedMatchController(
      definition: definition,
      initialState: state,
      reducedMotion: true,
      minimumAiTurnDuration: Duration.zero,
      aiMoveChooser: (state, _) async =>
          const CheckersEngine().legalTurns(state).first,
      onAttemptCompleted: onAttemptCompleted,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('starts with 24 pieces and waits for the introduction', () async {
    final controller = create();
    expect(controller.phase, GuidedMatchPhase.introduction);
    expect(controller.match.state.pieces, hasLength(24));
    await controller.tapSquare(const Square(2, 1));
    expect(controller.match.selectedSquare, isNull);
    await controller.begin();
    await controller.tapSquare(const Square(2, 1));
    await controller.tapSquare(const Square(3, 0));
    expect(controller.match.state.turns, hasLength(2));
    expect(controller.match.state.sideToMove, Side.black);
    expect(controller.encountered, contains(ReviewConcept.movement));
  });

  test('only a win followed by the full recap completes the lesson', () async {
    final controller = create(
      state: GameState.custom(
        sideToMove: Side.black,
        pieces: {
          const Square(2, 1): const Piece.blackMan(),
          const Square(3, 2): const Piece.whiteMan(),
        },
      ),
    );
    controller.complete();
    expect(controller.lessonComplete, isFalse);
    await controller.begin();
    await controller.tapSquare(const Square(4, 3));
    expect(controller.phase, GuidedMatchPhase.result);
    expect(controller.lessonComplete, isFalse);
    controller.complete();
    expect(controller.lessonComplete, isFalse);
    controller.openReview();
    expect(controller.phase, GuidedMatchPhase.review);
    expect(controller.lessonComplete, isFalse);
    controller.complete();
    expect(controller.lessonComplete, isTrue);
  });

  test('loss, draw, and resignation require retry', () async {
    final states = [
      GameState.custom(
        sideToMove: Side.white,
        pieces: {
          const Square(2, 1): const Piece.blackMan(),
          const Square(3, 2): const Piece.whiteMan(),
        },
      ),
      GameState.custom(
        sideToMove: Side.black,
        quietKingPlyCount: 79,
        pieces: {
          const Square(0, 1): const Piece(Side.black, PieceRank.king),
          const Square(7, 6): const Piece(Side.white, PieceRank.king),
        },
      ),
      GameState.initial(),
    ];
    for (var index = 0; index < states.length; index++) {
      final controller = create(state: states[index]);
      await controller.begin();
      if (index == 1) {
        await controller.tapSquare(const Square(0, 1));
        await controller.tapSquare(const Square(1, 0));
      } else if (index == 2) {
        await controller.resign();
      }
      expect(controller.phase, GuidedMatchPhase.result);
      controller.openReview();
      controller.complete();
      expect(controller.phase, GuidedMatchPhase.result);
      expect(controller.lessonComplete, isFalse);
      controller.retry();
      expect(controller.phase, GuidedMatchPhase.introduction);
      expect(controller.match.state.pieces, hasLength(24));
      expect(controller.encountered, isEmpty);
    }
  });

  test('reports every finished attempt before a retry', () async {
    final attempts = <MatchRecord>[];
    final controller = create(
      onAttemptCompleted: (record) async => attempts.add(record),
    );

    await controller.begin();
    await controller.resign();
    expect(attempts, hasLength(1));
    expect(attempts.single.perspectiveOutcome, PerspectiveOutcome.defeat);

    controller.retry();
    await controller.begin();
    await controller.resign();
    expect(attempts, hasLength(2));
    expect(attempts[1].id, isNot(attempts[0].id));
  });

  test('coaches compulsory captures and every landing of a jump', () async {
    final controller = create(
      state: GameState.custom(
        sideToMove: Side.black,
        pieces: {
          const Square(1, 0): const Piece.blackMan(),
          const Square(2, 1): const Piece.whiteMan(),
          const Square(4, 3): const Piece.whiteMan(),
        },
      ),
    );
    await controller.begin();
    await controller.tapSquare(const Square(2, 3));
    expect(
      controller.feedback,
      definition.coaching[GuidedCoachCue.compulsoryCapture],
    );
    await controller.tapSquare(const Square(1, 0));
    expect(
      controller.feedback,
      definition.coaching[GuidedCoachCue.compulsoryCapture],
      reason: 'mandatory captures take priority over generic selection advice',
    );
    await controller.tapSquare(const Square(3, 2));
    expect(
      controller.feedback,
      definition.coaching[GuidedCoachCue.continueJump],
    );
    expect(controller.match.state.turns, isEmpty);
    await controller.tapSquare(const Square(5, 4));
    expect(
      controller.encountered,
      containsAll([
        ReviewConcept.captures,
        ReviewConcept.compulsoryCapture,
        ReviewConcept.multipleJumps,
      ]),
    );
  });

  test('records promotion by Crown AI and king movement', () async {
    final controller = create(
      state: GameState.custom(
        sideToMove: Side.white,
        pieces: {
          const Square(7, 6): const Piece(Side.black, PieceRank.king),
          const Square(1, 2): const Piece.whiteMan(),
        },
      ),
    );
    await controller.begin();
    expect(controller.encountered, contains(ReviewConcept.promotion));
    expect(controller.feedback, definition.coaching[GuidedCoachCue.promotion]);
    await controller.tapSquare(const Square(7, 6));
    await controller.tapSquare(const Square(6, 5));
    expect(controller.encountered, contains(ReviewConcept.kings));
  });

  test('retry invalidates an outstanding AI response', () async {
    final answer = Completer<Turn>();
    final controller = GuidedMatchController(
      definition: definition,
      reducedMotion: true,
      minimumAiTurnDuration: Duration.zero,
      aiMoveChooser: (_, _) => answer.future,
    );
    addTearDown(controller.dispose);
    await controller.begin();
    await controller.tapSquare(const Square(2, 1));
    final pending = controller.tapSquare(const Square(3, 0));
    await Future<void>.delayed(Duration.zero);
    final old = controller.match;
    controller.retry();
    answer.complete(const CheckersEngine().legalTurns(old.state).first);
    await pending;
    expect(controller.match.state.turns, isEmpty);
    expect(controller.phase, GuidedMatchPhase.introduction);
  });

  test('a full seeded Crown AI match reaches a real result from the starting board', () async {
    const ai = CrownAi();
    final controller = GuidedMatchController(
      definition: definition,
      reducedMotion: true,
      minimumAiTurnDuration: Duration.zero,
      aiMoveChooser: (state, profile) =>
          ai.chooseTurn(state, profile, seed: state.turns.length + 8),
    );
    addTearDown(controller.dispose);
    await controller.begin();
    for (
      var turns = 0;
      turns < 300 && controller.match.state.result == null;
      turns++
    ) {
      expect(controller.match.state.sideToMove, Side.black);
      final turn = await ai.chooseTurn(
        controller.match.state,
        const AiProfile(skill: 8),
        seed: turns,
      );
      await controller.tapSquare(turn.origin);
      for (final landing in turn.landings) {
        await controller.tapSquare(landing);
      }
      expect(controller.match.aiError, isNull);
    }
    expect(controller.match.state.result, isNotNull);
    expect(controller.phase, GuidedMatchPhase.result);
    expect(
      controller.encountered,
      containsAll([
        ReviewConcept.board,
        ReviewConcept.movement,
        ReviewConcept.captures,
      ]),
    );
    expect(controller.lessonComplete, isFalse);
    if (controller.won) {
      controller.openReview();
      controller.complete();
      expect(controller.lessonComplete, isTrue);
    }
  });
}
