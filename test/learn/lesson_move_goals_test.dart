import 'dart:convert';

import 'package:crown/features/learn/learn_curriculum.dart';
import 'package:crown/features/learn/lesson_asset_loader.dart';
import 'package:crown/features/learn/lesson_definition.dart';
import 'package:crown/features/learn/lesson_session_controller.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Unit 2 rejects completion before an enabled recapture', () async {
    final exercise = _supportedExchange();
    (exercise['interaction']! as Map<String, Object?>).remove('followUps');
    await expectLater(
      _load(exercise, number: 9),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'Unit 2 opening sequences cannot play the learner turns automatically',
    () async {
      final exercise = _recapture();
      exercise['perspective'] = 'black';
      final interaction = exercise['interaction']! as Map<String, Object?>;
      interaction['openingTurns'] = [
        _attack.toJson(),
        Turn.capture(
          const Square(5, 2),
          const [Square(3, 4)],
          const [Square(4, 3)],
        ).toJson(),
      ];
      interaction['turns'] = [
        Turn.step(const Square(0, 7), const Square(1, 6)).toJson(),
      ];
      await expectLater(
        _load(exercise, number: 9),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'Unit 2 rejects a learner phase requiring more than three board taps',
    () async {
      final exercise = _safeMove();
      exercise['perspective'] = 'black';
      exercise['board'] = _board(Side.black, {
        const Square(1, 0): const Piece.blackMan(),
        const Square(2, 1): const Piece.whiteMan(),
        const Square(4, 3): const Piece.whiteMan(),
        const Square(6, 5): const Piece.whiteMan(),
      });
      exercise['interaction'] = {
        'type': 'turn',
        'acceptance': 'exactLegalSet',
        'turns': [
          Turn.capture(
            const Square(1, 0),
            const [Square(3, 2), Square(5, 4), Square(7, 6)],
            const [Square(2, 1), Square(4, 3), Square(6, 5)],
          ).toJson(),
        ],
      };
      await expectLater(
        _load(exercise, number: 9),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('three board taps'),
          ),
        ),
      );
    },
  );

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'a closing reply resolves before completion without repeating the follow-up (reduced motion: $reducedMotion)',
      (tester) async {
        final exercise = _supportedExchange();
        final interaction = exercise['interaction']! as Map<String, Object?>;
        interaction['turns'] = [
          Turn.step(const Square(6, 3), const Square(5, 2)).toJson(),
        ];
        final followUps =
            interaction['followUps']! as List<Map<String, Object?>>;
        followUps.removeLast();
        followUps.single['opponentReply'] = Turn.step(
          const Square(1, 0),
          const Square(2, 1),
        ).toJson();
        followUps.single['opponentPauseMs'] = 100;
        (followUps.single['feedback']!
                as Map<String, Object?>)['awaitingReply'] =
            'Watch Black finish its reply.';
        final controller = LessonSessionController(
          definition: await _load(exercise, number: 9),
          reducedMotion: reducedMotion,
        );
        addTearDown(controller.dispose);
        controller.tapSquare(const Square(6, 3));
        controller.tapSquare(const Square(5, 2));
        await tester.pump(const Duration(milliseconds: 100));
        if (!reducedMotion) {
          await tester.pump(LessonSessionController.jumpDuration);
        }
        controller.tapSquare(const Square(5, 2));
        controller.tapSquare(const Square(3, 4));
        if (!reducedMotion) {
          await tester.pump(LessonSessionController.jumpDuration);
        }
        expect(controller.feedback, 'Watch Black finish its reply.');
        expect(controller.exerciseComplete, isFalse);
        expect(controller.acceptsInput, isFalse);
        await tester.pump(const Duration(milliseconds: 100));
        if (!reducedMotion) {
          expect(controller.activeJump?.from, const Square(1, 0));
          expect(controller.activeJump?.captured, isNull);
          await tester.pump(LessonSessionController.jumpDuration);
        }
        expect(controller.exerciseComplete, isTrue);
        expect(controller.playerPhaseNumber, 2);
        expect(controller.pieces[const Square(2, 1)], const Piece.blackMan());
        expect(controller.recordedPlayerTurns, hasLength(2));
        controller.continueExercise();
        expect(controller.playerPhaseNumber, 1);
        expect(controller.selectedSquare, isNull);
        expect(controller.feedback, 'Arrange support.');
      },
    );
  }

  testWidgets(
    'a missed follow-up goal restores the payoff position, not the setup',
    (tester) async {
      final exercise = _supportedExchange();
      exercise['board'] = _board(Side.white, {
        const Square(1, 0): const Piece.blackMan(),
        const Square(2, 1): const Piece.blackMan(),
        const Square(4, 1): const Piece.blackMan(),
        const Square(3, 2): const Piece.whiteMan(),
        const Square(6, 1): const Piece.whiteMan(),
        const Square(6, 3): const Piece(Side.white, PieceRank.king),
        const Square(6, 5): const Piece.whiteMan(),
      });
      final interaction = exercise['interaction']! as Map<String, Object?>;
      interaction['turns'] = [
        Turn.step(const Square(6, 3), const Square(5, 2)).toJson(),
      ];
      final followUps = interaction['followUps']! as List<Map<String, Object?>>;
      followUps.removeLast();
      followUps.single['acceptance'] = 'legalSubset';
      (followUps.single['feedback']! as Map<String, Object?>)['goalMiss'] =
          'Recapture the attacker, not the other man.';
      final controller = LessonSessionController(
        definition: await _load(exercise),
        reducedMotion: true,
      );
      addTearDown(controller.dispose);
      controller.tapSquare(const Square(6, 3));
      controller.tapSquare(const Square(5, 2));
      await tester.pump(const Duration(milliseconds: 100));
      final ready = controller.pieces;
      controller.tapSquare(const Square(5, 2));
      expect(controller.destinations, {const Square(3, 0), const Square(3, 4)});
      controller.tapSquare(const Square(3, 0));
      expect(controller.feedback, 'Recapture the attacker, not the other man.');
      expect(controller.pieces, ready);
      expect(controller.playerPhaseNumber, 2);
      expect(controller.recordedPlayerTurns, hasLength(1));
      controller.tapSquare(const Square(5, 2));
      controller.tapSquare(const Square(3, 4));
      expect(controller.exerciseComplete, isTrue);
      expect(controller.recordedPlayerTurns, hasLength(2));
    },
  );

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'setup branches continue through the learner recapture (reduced motion: $reducedMotion)',
      (tester) async {
        final definition = await _load(_supportedExchange());
        for (final destination in const [Square(5, 2), Square(5, 4)]) {
          final controller = LessonSessionController(
            definition: definition,
            reducedMotion: reducedMotion,
          );
          controller.tapSquare(const Square(6, 3));
          controller.tapSquare(destination);
          expect(controller.exerciseComplete, isFalse);
          await tester.pump(const Duration(milliseconds: 100));
          if (!reducedMotion) {
            await tester.pump(LessonSessionController.jumpDuration);
          }
          expect(controller.exerciseComplete, isFalse);
          expect(
            controller.instruction,
            'Recapture with the supporter you moved.',
          );
          expect(controller.feedback, 'Now take the attacker back.');
          expect(controller.selectedSquare, isNull);
          expect(controller.sideToMove, Side.white);
          controller.continueExercise();
          expect(controller.lessonComplete, isFalse);
          final ready = controller.pieces;
          controller.tapSquare(destination);
          controller.tapSquare(const Square(0, 3));
          expect(controller.pieces, ready);
          expect(controller.feedback, 'Choose the recapture landing.');
          final landing = destination.column == 2
              ? const Square(3, 4)
              : const Square(3, 2);
          controller.tapSquare(landing);
          if (!reducedMotion) {
            await tester.pump(LessonSessionController.jumpDuration);
          }
          expect(controller.exerciseComplete, isTrue);
          expect(controller.feedback, 'You completed the equal exchange.');
          expect(controller.pieces, isNot(contains(const Square(4, 3))));
          expect(controller.recordedPlayerTurns, hasLength(2));
          controller.continueExercise();
          expect(controller.lessonComplete, isTrue);
          controller.dispose();
        }
      },
    );
  }

  testWidgets(
    'ordinary opponent mistakes are visibly animated before learner control',
    (tester) async {
      final exercise = _safeMove();
      exercise['perspective'] = 'black';
      exercise['board'] = _board(Side.white, {
        const Square(2, 1): const Piece.blackMan(),
        const Square(4, 3): const Piece.whiteMan(),
      });
      exercise['interaction'] = {
        'type': 'turn',
        'acceptance': 'exactLegalSet',
        'openingTurns': [
          Turn.step(const Square(4, 3), const Square(3, 2)).toJson(),
        ],
        'openingPauseMs': 100,
        'turns': [_attack.toJson()],
      };
      (exercise['feedback']! as Map<String, Object?>)['opening'] =
          'Watch White step into danger.';
      final controller = LessonSessionController(
        definition: await _load(exercise),
      );
      addTearDown(controller.dispose);
      expect(controller.pieces[const Square(4, 3)], const Piece.whiteMan());
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.activeJump?.from, const Square(4, 3));
      expect(controller.activeJump?.to, const Square(3, 2));
      expect(controller.activeJump?.captured, isNull);
      expect(controller.acceptsInput, isFalse);
      await tester.pump(LessonSessionController.jumpDuration);
      expect(controller.pieces[const Square(3, 2)], const Piece.whiteMan());
      expect(controller.acceptsInput, isTrue);
    },
  );

  testWidgets('disposing during a follow-up reply prevents phase handoff', (
    tester,
  ) async {
    final controller = LessonSessionController(
      definition: await _load(_supportedExchange()),
    );
    controller.tapSquare(const Square(6, 3));
    controller.tapSquare(const Square(5, 2));
    await tester.pump(const Duration(milliseconds: 100));
    final pieces = controller.pieces;
    controller.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(controller.pieces, pieces);
    expect(controller.exerciseComplete, isFalse);
  });

  for (final invalid in [
    'missingBranch',
    'duplicateBranch',
    'illegalPayoff',
    'noReply',
    'wrongSide',
    'nestedPhase',
    'nonTurn',
  ]) {
    test('loader rejects invalid follow-up $invalid', () async {
      final exercise = _supportedExchange();
      final interaction = exercise['interaction']! as Map<String, Object?>;
      final followUps = interaction['followUps']! as List<Map<String, Object?>>;
      switch (invalid) {
        case 'missingBranch':
          followUps.removeLast();
        case 'duplicateBranch':
          followUps.add(followUps.first);
        case 'illegalPayoff':
          followUps.first['turns'] = [_attack.toJson()];
        case 'noReply':
          interaction.remove('opponentReply');
        case 'wrongSide':
          exercise['perspective'] = 'black';
        case 'nestedPhase':
          followUps.first['followUps'] = [];
        case 'nonTurn':
          interaction['type'] = 'squareSelection';
          interaction['targets'] = [const Square(6, 3).toJson()];
      }
      await expectLater(_load(exercise), throwsA(isA<FormatException>()));
    });
  }

  test('legal goal subsets expose alternatives and allow retry', () async {
    final definition = await _load(_safeMove());
    final controller = LessonSessionController(
      definition: definition,
      reducedMotion: true,
    );
    addTearDown(controller.dispose);
    final initial = controller.pieces;
    var landings = 0;
    controller.landings.addListener(() => landings++);

    controller.tapSquare(const Square(5, 2));
    expect(controller.destinations, {const Square(4, 1), const Square(4, 3)});
    controller.tapSquare(const Square(4, 3));
    expect(controller.feedback, 'That move leaves the piece capturable.');
    expect(controller.exerciseComplete, isFalse);
    expect(controller.pieces, initial);
    expect(controller.selectedSquare, isNull);
    expect(controller.recordedPlayerTurns, isEmpty);
    expect(landings, 0);

    controller.tapSquare(const Square(5, 2));
    controller.tapSquare(const Square(4, 1));
    expect(controller.exerciseComplete, isTrue);
    expect(controller.pieces[const Square(4, 1)], const Piece.whiteMan());
    expect(controller.pieces, isNot(contains(const Square(5, 2))));
    expect(controller.recordedPlayerTurns, hasLength(1));
    expect(landings, 1);
  });

  test('illegal moves have different feedback from missed goals', () async {
    final controller = LessonSessionController(
      definition: await _load(_safeMove()),
    );
    addTearDown(controller.dispose);
    controller.tapSquare(const Square(5, 2));
    controller.tapSquare(const Square(3, 0));
    expect(controller.feedback, 'Choose a legal destination.');
    expect(controller.exerciseComplete, isFalse);
  });

  testWidgets('a rejected second jump restores the whole starting position', (
    tester,
  ) async {
    final exercise = _safeMove();
    exercise['perspective'] = 'black';
    exercise['board'] = _board(Side.black, {
      const Square(1, 2): const Piece.blackMan(),
      const Square(2, 3): const Piece.whiteMan(),
      const Square(4, 3): const Piece.whiteMan(),
      const Square(4, 5): const Piece.whiteMan(),
    });
    exercise['interaction'] = {
      'type': 'turn',
      'acceptance': 'legalSubset',
      'turns': [
        Turn.capture(
          const Square(1, 2),
          const [Square(3, 4), Square(5, 2)],
          const [Square(2, 3), Square(4, 3)],
        ).toJson(),
      ],
    };
    final controller = LessonSessionController(
      definition: await _load(exercise),
    );
    addTearDown(controller.dispose);
    final initial = controller.pieces;
    controller.tapSquare(const Square(1, 2));
    controller.tapSquare(const Square(3, 4));
    await tester.pump(LessonSessionController.jumpDuration);
    expect(controller.destinations, {const Square(5, 2), const Square(5, 6)});
    controller.tapSquare(const Square(5, 6));
    expect(controller.pieces, initial);
    expect(controller.activeJump, isNull);
    expect(controller.selectedSquare, isNull);
    expect(controller.recordedPlayerTurns, isEmpty);
    expect(controller.exerciseComplete, isFalse);
    controller.tapSquare(const Square(1, 2));
    controller.tapSquare(const Square(3, 4));
    await tester.pump(LessonSessionController.jumpDuration);
    controller.tapSquare(const Square(5, 2));
    await tester.pump(LessonSessionController.jumpDuration);
    expect(controller.exerciseComplete, isTrue);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'opening capture hands control to the recapturing side (reduced motion: $reducedMotion)',
      (tester) async {
        final controller = LessonSessionController(
          definition: await _load(_recapture()),
          reducedMotion: reducedMotion,
        );
        addTearDown(controller.dispose);
        var landings = 0;
        controller.landings.addListener(() => landings++);
        expect(controller.feedback, 'Watch Black capture first.');
        controller.tapSquare(const Square(5, 2));
        controller.continueExercise();
        expect(controller.selectedSquare, isNull);
        expect(controller.exerciseComplete, isFalse);
        expect(controller.legalTurns, isEmpty);

        await tester.pump(const Duration(milliseconds: 100));
        if (!reducedMotion) {
          expect(controller.activeJump?.from, const Square(2, 1));
          controller.tapSquare(const Square(5, 2));
          expect(controller.selectedSquare, isNull);
          await tester.pump(LessonSessionController.jumpDuration);
        }
        expect(controller.sideToMove, Side.white);
        expect(controller.feedback, 'Now recapture as White.');
        expect(controller.pieces[const Square(4, 3)], const Piece.blackMan());
        expect(controller.pieces, isNot(contains(const Square(3, 2))));
        expect(controller.recordedPlayerTurns, isEmpty);
        expect(landings, 1);
        controller.tapSquare(const Square(5, 2));
        controller.tapSquare(const Square(3, 4));
        if (!reducedMotion) {
          await tester.pump(LessonSessionController.jumpDuration);
        }
        expect(controller.exerciseComplete, isTrue);
        expect(controller.pieces, isNot(contains(const Square(4, 3))));
        expect(controller.recordedPlayerTurns, hasLength(1));
        expect(landings, 2);
      },
    );
  }

  testWidgets('multiple opening turns are applied in order', (tester) async {
    final exercise = _recapture();
    final interaction = exercise['interaction']! as Map<String, Object?>;
    interaction['openingTurns'] = [
      _attack.toJson(),
      Turn.capture(
        const Square(5, 2),
        const [Square(3, 4)],
        const [Square(4, 3)],
      ).toJson(),
    ];
    interaction['turns'] = [
      Turn.step(const Square(0, 7), const Square(1, 6)).toJson(),
    ];
    exercise['board'] = _board(Side.black, {
      ..._exchangePieces,
      const Square(7, 0): const Piece.whiteMan(),
    });
    final controller = LessonSessionController(
      definition: await _load(exercise),
      reducedMotion: true,
    );
    addTearDown(controller.dispose);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.legalTurns, isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.sideToMove, Side.black);
    expect(controller.pieces[const Square(3, 4)], const Piece.whiteMan());
    controller.tapSquare(const Square(0, 7));
    controller.tapSquare(const Square(1, 6));
    expect(controller.exerciseComplete, isTrue);
  });

  testWidgets('disposing during an opening cancels subsequent changes', (
    tester,
  ) async {
    final controller = LessonSessionController(
      definition: await _load(_recapture()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final pieces = controller.pieces;
    controller.dispose();
    await tester.pump(const Duration(seconds: 2));
    controller.tapSquare(const Square(5, 2));
    expect(controller.pieces, pieces);
    expect(controller.exerciseComplete, isFalse);
  });

  testWidgets('one authored reply can demonstrate both accepted setup moves', (
    tester,
  ) async {
    final exercise = _safeMove();
    exercise['board'] = _board(Side.white, {
      const Square(1, 0): const Piece.blackMan(),
      const Square(2, 1): const Piece.blackMan(),
      const Square(3, 2): const Piece.whiteMan(),
      const Square(6, 1): const Piece.whiteMan(),
      const Square(6, 3): const Piece.whiteMan(),
      const Square(6, 5): const Piece.whiteMan(),
    });
    final interaction = exercise['interaction']! as Map<String, Object?>;
    interaction['turns'] = [
      Turn.step(const Square(6, 3), const Square(5, 2)).toJson(),
      Turn.step(const Square(6, 3), const Square(5, 4)).toJson(),
    ];
    interaction['opponentReply'] = _attack.toJson();
    interaction['opponentPauseMs'] = 100;
    (exercise['feedback']! as Map<String, Object?>)['awaitingReply'] =
        'Watch the attack.';
    final definition = await _load(exercise);
    for (final destination in const [Square(5, 2), Square(5, 4)]) {
      final controller = LessonSessionController(
        definition: definition,
        reducedMotion: true,
      );
      controller.tapSquare(const Square(6, 3));
      controller.tapSquare(destination);
      expect(controller.exerciseComplete, isFalse);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.exerciseComplete, isTrue);
      expect(controller.pieces[const Square(4, 3)], const Piece.blackMan());
      controller.dispose();
    }
  });

  for (final invalid in [
    'emptyGoal',
    'illegalGoal',
    'missingGoalFeedback',
    'illegalOpening',
    'missingOpeningFeedback',
    'negativePause',
    'unknownAcceptance',
    'nonTurnOpening',
  ]) {
    test('loader rejects $invalid', () async {
      final exercise = invalid.contains('Opening') || invalid == 'negativePause'
          ? _recapture()
          : _safeMove();
      final interaction = exercise['interaction']! as Map<String, Object?>;
      final feedback = exercise['feedback']! as Map<String, Object?>;
      switch (invalid) {
        case 'emptyGoal':
          interaction['turns'] = [];
        case 'illegalGoal':
          interaction['turns'] = [
            Turn.step(const Square(5, 2), const Square(2, 3)).toJson(),
          ];
        case 'missingGoalFeedback':
          feedback.remove('goalMiss');
        case 'illegalOpening':
          interaction['openingTurns'] = [
            Turn.step(const Square(2, 1), const Square(3, 0)).toJson(),
          ];
        case 'missingOpeningFeedback':
          feedback.remove('opening');
        case 'negativePause':
          interaction['openingPauseMs'] = -1;
        case 'unknownAcceptance':
          interaction['acceptance'] = 'guess';
        case 'nonTurnOpening':
          interaction['type'] = 'squareSelection';
          interaction['targets'] = [const Square(5, 2).toJson()];
      }
      await expectLater(_load(exercise), throwsA(isA<FormatException>()));
    });
  }
}

final _attack = Turn.capture(
  const Square(2, 1),
  const [Square(4, 3)],
  const [Square(3, 2)],
);

Map<String, Object?> _supportedExchange() => {
  'id': 'support',
  'title': 'Arrange protection',
  'instruction': 'Move the central rear white man to support its teammate.',
  'perspective': 'white',
  'board': _board(Side.white, {
    const Square(1, 0): const Piece.blackMan(),
    const Square(2, 1): const Piece.blackMan(),
    const Square(3, 2): const Piece.whiteMan(),
    const Square(6, 1): const Piece.whiteMan(),
    const Square(6, 3): const Piece.whiteMan(),
    const Square(6, 5): const Piece.whiteMan(),
  }),
  'interaction': {
    'type': 'turn',
    'acceptance': 'legalSubset',
    'turns': [
      for (final destination in const [Square(5, 2), Square(5, 4)])
        Turn.step(const Square(6, 3), destination).toJson(),
    ],
    'opponentReply': _attack.toJson(),
    'opponentPauseMs': 100,
    'followUps': [
      for (final destination in const [Square(5, 2), Square(5, 4)])
        {
          'afterTurn': Turn.step(const Square(6, 3), destination).toJson(),
          'instruction': 'Recapture with the supporter you moved.',
          'acceptance': 'exactLegalSet',
          'turns': [
            Turn.capture(
              destination,
              [
                destination.column == 2
                    ? const Square(3, 4)
                    : const Square(3, 2),
              ],
              const [Square(4, 3)],
            ).toJson(),
          ],
          'feedback': {
            'initial': 'Now take the attacker back.',
            'selected': 'Complete the recapture.',
            'success': 'You completed the equal exchange.',
            'invalidPiece': 'Use the capturing supporter.',
            'invalidDestination': 'Choose the recapture landing.',
          },
        },
    ],
  },
  'feedback': {
    'initial': 'Arrange support.',
    'selected': 'Choose either supporting step.',
    'awaitingReply': 'Watch Black capture.',
    'success': 'You completed the equal exchange.',
    'goalMiss': 'Move the central rear man.',
    'invalidPiece': 'Select a white piece.',
    'invalidDestination': 'Choose a legal step.',
  },
};
final _exchangePieces = {
  const Square(0, 7): const Piece.blackMan(),
  const Square(2, 1): const Piece.blackMan(),
  const Square(3, 2): const Piece.whiteMan(),
  const Square(5, 2): const Piece.whiteMan(),
  const Square(6, 1): const Piece.whiteMan(),
};

Map<String, Object?> _safeMove() => {
  'id': 'safe',
  'title': 'Find safety',
  'instruction': 'Move the right-hand white piece safely.',
  'perspective': 'white',
  'board': _board(Side.white, {
    const Square(3, 2): const Piece.blackMan(),
    const Square(5, 0): const Piece.whiteMan(),
    const Square(5, 2): const Piece.whiteMan(),
  }),
  'interaction': {
    'type': 'turn',
    'acceptance': 'legalSubset',
    'turns': [Turn.step(const Square(5, 2), const Square(4, 1)).toJson()],
  },
  'feedback': {
    'initial': 'Find a safe move.',
    'selected': 'Compare the legal destinations.',
    'success': 'The landing is blocked.',
    'invalidPiece': 'Select a movable piece.',
    'invalidDestination': 'Choose a legal destination.',
    'goalMiss': 'That move leaves the piece capturable.',
  },
};

Map<String, Object?> _recapture() => {
  'id': 'recapture',
  'title': 'Recapture',
  'instruction': 'Watch Black, then recapture as White.',
  'perspective': 'white',
  'board': _board(Side.black, _exchangePieces),
  'interaction': {
    'type': 'turn',
    'acceptance': 'exactLegalSet',
    'openingTurns': [_attack.toJson()],
    'openingPauseMs': 100,
    'turns': [
      Turn.capture(
        const Square(5, 2),
        const [Square(3, 4)],
        const [Square(4, 3)],
      ).toJson(),
    ],
  },
  'feedback': {
    'opening': 'Watch Black capture first.',
    'initial': 'Now recapture as White.',
    'success': 'One man lost on each side.',
  },
};

Map<String, Object?> _board(Side side, Map<Square, Piece> pieces) => {
  'source': 'custom',
  'sideToMove': side.name,
  'pieces': [
    for (final entry in pieces.entries)
      {'square': entry.key.toJson(), ...entry.value.toJson()},
  ],
};

Future<LessonDefinition> _load(
  Map<String, Object?> exercise, {
  int number = 1,
}) =>
    LessonAssetLoader(
      bundle: _Bundle(
        jsonEncode({
          'schemaVersion': 2,
          'id': 'lesson-${number.toString().padLeft(3, '0')}',
          'number': number,
          'name': 'Test moves',
          'exercises': [
            for (
              var index = 0;
              index < (number >= 9 && number <= 15 ? 5 : 1);
              index++
            )
              exercise,
          ],
        }),
      ),
    ).loadDefinition(
      LearnLesson.fromJson({
        'id': 'lesson-${number.toString().padLeft(3, '0')}',
        'number': number,
        'name': 'Test moves',
        'objective': 'Move.',
        'overview': 'Move.',
        'status': 'available',
        'definitionAsset': 'lesson.json',
      }),
    );

class _Bundle extends CachingAssetBundle {
  _Bundle(this.json);
  final String json;
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
}
