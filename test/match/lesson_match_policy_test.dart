import 'dart:async';

import 'package:crown/features/match/match_controller.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:crown/game_engine/crown_ai.dart';
import 'package:crown/persistence/crown_repository.dart';
import 'package:flutter_test/flutter_test.dart';

MatchSession lessonSession({GameState? state, Side human = Side.black}) =>
    MatchSession.newGame(
      mode: MatchMode.ai,
      humanSide: human,
      blackName: 'You',
      whiteName: 'Crown AI',
      initialState: state,
    );

void main() {
  test(
    'lesson policy isolates active game, history, and adaptive strength',
    () async {
      final repository = MemoryCrownRepository();
      final active = lessonSession();
      await repository.saveActiveMatch(active);
      await repository.saveAiProfile(
        const AiProfile(skill: 9, gamesPlayed: 12),
      );
      int? skill;
      final controller = MatchController(
        session: lessonSession(),
        repository: repository,
        policy: MatchSessionPolicy.lesson,
        minimumAiTurnDuration: Duration.zero,
        aiMoveChooser: (state, profile) async {
          skill = profile.skill;
          return const CheckersEngine().legalTurns(state).first;
        },
      );
      addTearDown(controller.dispose);
      await controller.start();
      await controller.tapSquare(const Square(2, 1));
      await controller.tapSquare(const Square(3, 0));
      expect(controller.state.turns, hasLength(2));
      expect(skill, 0);
      await controller.resign(Side.black);
      expect(await repository.loadActiveMatch(), active);
      expect(await repository.loadHistory(), isEmpty);
      expect((await repository.loadAiProfile()).toJson(), {
        'skill': 9,
        'gamesPlayed': 12,
      });
    },
  );

  test(
    'lesson policy reports a completed replay without saving history',
    () async {
      final repository = MemoryCrownRepository();
      MatchRecord? completed;
      final controller = MatchController(
        session: lessonSession(),
        repository: repository,
        policy: MatchSessionPolicy.lesson,
        onCompleted: (record) async => completed = record,
      );
      addTearDown(controller.dispose);

      await controller.resign(Side.black);

      expect(completed?.perspectiveOutcome, PerspectiveOutcome.defeat);
      expect(await repository.loadFeed(), isEmpty);
    },
  );

  test('disposed match ignores a late AI answer', () async {
    final answer = Completer<Turn>();
    final controller = MatchController(
      session: lessonSession(human: Side.white),
      repository: MemoryCrownRepository(),
      policy: MatchSessionPolicy.lesson,
      minimumAiTurnDuration: Duration.zero,
      aiMoveChooser: (_, _) => answer.future,
    );
    final pending = controller.start();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    answer.complete(const CheckersEngine().legalTurns(controller.state).first);
    await pending;
    expect(controller.state.turns, isEmpty);
  });

  test('AI failure can be retried without losing the human turn', () async {
    var attempts = 0;
    final controller = MatchController(
      session: lessonSession(),
      repository: MemoryCrownRepository(),
      policy: MatchSessionPolicy.lesson,
      minimumAiTurnDuration: Duration.zero,
      aiMoveChooser: (state, _) async {
        if (++attempts == 1) throw StateError('AI unavailable');
        return const CheckersEngine().legalTurns(state).first;
      },
    );
    addTearDown(controller.dispose);
    await controller.tapSquare(const Square(2, 1));
    await controller.tapSquare(const Square(3, 0));
    expect(controller.aiError, isNotNull);
    expect(controller.isAiThinking, isFalse);
    expect(controller.state.turns, hasLength(1));
    await controller.playAiIfNeeded();
    expect(controller.aiError, isNull);
    expect(controller.state.turns, hasLength(2));
  });
}
