import 'dart:convert';

import 'package:crown/features/learn/learn_curriculum.dart';
import 'package:crown/features/learn/lesson_asset_loader.dart';
import 'package:crown/features/learn/lesson_session_controller.dart';
import 'package:crown/features/learn/lesson_screen.dart';
import 'package:crown/features/learn/lesson_choice_row.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.json);
  final Map<String, Object?> json;
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(jsonEncode(json))));
}

final _candidate = Turn.step(const Square(1, 0), const Square(2, 1));
final _reply = Turn.step(const Square(6, 7), const Square(5, 6));

Future<LessonSessionController> _controller({
  bool reducedMotion = true,
  void Function(Map<String, Object?>)? modify,
}) async {
  final json = <String, Object?>{
    'schemaVersion': 2,
    'id': 'test',
    'number': 4,
    'name': 'Test',
    'exercises': [
      {
        'id': 'practice',
        'title': 'Safety practice',
        'instruction': 'Play the move.',
        'perspective': 'black',
        'board': {
          'source': 'custom',
          'sideToMove': 'black',
          'pieces': [
            {
              'square': {'row': 1, 'column': 0},
              'side': 'black',
              'rank': 'man',
            },
            {
              'square': {'row': 6, 'column': 7},
              'side': 'white',
              'rank': 'man',
            },
          ],
        },
        'preparation': [
          {
            'instruction': '1. Check your captures.',
            'interaction': {'type': 'observation'},
            'feedback': {
              'initial': 'Scan the board.',
              'success': 'Scan the board.',
            },
          },
          {
            'instruction': '2. Test a candidate.',
            'previewTurns': [_candidate.toJson()],
            'interaction': {'type': 'observation'},
            'feedback': {
              'initial': 'Watch the example.',
              'success': 'Watch the example.',
            },
          },
          {
            'instruction': '3. Inspect their reply.',
            'previewTurns': [_candidate.toJson(), _reply.toJson()],
            'interaction': {'type': 'observation'},
            'feedback': {'initial': 'Watch White.', 'success': 'Watch White.'},
          },
          {
            'instruction': '4. Count and decide.',
            'previewTurns': [_candidate.toJson(), _reply.toJson()],
            'interaction': {
              'type': 'choice',
              'correctOptionId': 'safe',
              'options': [
                {
                  'id': 'unsafe',
                  'label': 'Lose material',
                  'feedback': 'Neither piece was captured.',
                },
                {'id': 'safe', 'label': 'No loss', 'feedback': 'Correct.'},
              ],
            },
            'feedback': {
              'initial': 'Count both sides.',
              'success': 'No loss: play the move.',
            },
          },
        ],
        'interaction': {
          'type': 'turn',
          'acceptance': 'exactLegalSet',
          'turns': [_candidate.toJson()],
        },
        'feedback': {'initial': 'Now move.', 'success': 'Done.'},
      },
    ],
  };
  modify?.call(json);
  final definition = await LessonAssetLoader(bundle: _Bundle(json))
      .loadDefinition(
        LearnLesson.fromJson({
          'id': 'test',
          'number': 4,
          'name': 'Test',
          'objective': 'Test',
          'overview': 'Test',
          'status': 'available',
          'definitionAsset': 'test.json',
        }),
      );
  return LessonSessionController(
    definition: definition,
    reducedMotion: reducedMotion,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'passive walkthrough preserves the live board and records only the final move',
    (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final initial = Map.of(controller.pieces);
      expect(controller.title, 'Safety practice');
      expect(controller.instruction, '1. Check your captures.');
      controller.tapSquare(const Square(1, 0));
      expect(controller.selectedSquare, isNull);
      controller.continueExercise();
      await tester.pump(const Duration(milliseconds: 550));
      expect(controller.instruction, '2. Test a candidate.');
      expect(controller.pieces, initial);
      controller.continueExercise();
      await tester.pump(const Duration(milliseconds: 550));
      expect(controller.instruction, '3. Inspect their reply.');
      expect(controller.pieces, initial);
      controller.continueExercise();
      expect(controller.instruction, '4. Count and decide.');
      controller.selectChoice('unsafe');
      expect(controller.feedback, 'Neither piece was captured.');
      controller.continueExercise();
      expect(controller.instruction, '4. Count and decide.');
      controller.selectChoice('safe');
      expect(controller.exerciseComplete, isFalse);
      controller.continueExercise();
      expect(controller.instruction, 'Play the move.');
      expect(controller.pieces, initial);
      expect(controller.recordedPlayerTurns, isEmpty);
      controller.tapSquare(_candidate.origin);
      controller.tapSquare(_candidate.destination);
      expect(controller.exerciseComplete, isTrue);
      expect(controller.recordedPlayerTurns, [_candidate]);
    },
  );

  testWidgets('text answers use the shared lesson cards', (tester) async {
    final controller = await _controller(
      modify: (json) {
        final exercise = (json['exercises'] as List).single as Map;
        (exercise['preparation'] as List).removeRange(0, 3);
        ((exercise['preparation'] as List).single as Map)['previewTurns'] =
            <Object?>[];
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: LessonScreen(
          controller: controller,
          highContrast: true,
          reducedMotion: true,
          sound: false,
        ),
      ),
    );
    expect(find.byType(LessonChoiceRow), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('lesson-choice-safe'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('lesson-choice-safe')),
    );
    await tester.tap(find.byKey(const ValueKey('lesson-choice-safe')));
    await tester.pump();
    expect(controller.feedback, 'No loss: play the move.');
    expect(tester.takeException(), isNull);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'worked turns finish before Continue (reduced motion: $reducedMotion)',
      (tester) async {
        final controller = await _controller(reducedMotion: reducedMotion);
        addTearDown(controller.dispose);
        final live = Map.of(controller.pieces);
        controller.continueExercise();
        expect(controller.canContinuePreparation, isFalse);
        controller.continueExercise();
        expect(controller.instruction, '2. Test a candidate.');
        await tester.pump(const Duration(milliseconds: 550));
        if (!reducedMotion) {
          expect(controller.activeJump?.to, _candidate.destination);
          await tester.pump(LessonSessionController.jumpDuration);
        }
        expect(controller.canContinuePreparation, isTrue);
        expect(controller.pieces, live);
        expect(
          controller.displayedPieces[_candidate.destination],
          const Piece.blackMan(),
        );
        controller.continueExercise();
        expect(
          controller.displayedPieces[_candidate.destination],
          const Piece.blackMan(),
        );
        await tester.pump(const Duration(milliseconds: 550));
        if (!reducedMotion) {
          expect(controller.activeJump?.piece.side, Side.white);
          await tester.pump(LessonSessionController.jumpDuration);
        }
        expect(controller.pieces, live);
        expect(controller.recordedPlayerTurns, isEmpty);
        expect(
          controller.displayedPieces[_reply.destination],
          const Piece.whiteMan(),
        );
      },
    );
  }

  testWidgets(
    'threat diagram allows real defensive moves and disappears after success',
    (tester) async {
      final controller = await _controller(
        modify: (json) {
          final exercise = (json['exercises'] as List).single as Map;
          exercise.remove('preparation');
          exercise['perspective'] = 'white';
          exercise['board'] = {
            'source': 'custom',
            'sideToMove': 'white',
            'pieces': [
              {
                'square': {'row': 0, 'column': 1},
                'side': 'black',
                'rank': 'man',
              },
              {
                'square': {'row': 2, 'column': 1},
                'side': 'black',
                'rank': 'man',
              },
              {
                'square': {'row': 1, 'column': 0},
                'side': 'white',
                'rank': 'man',
              },
              {
                'square': {'row': 3, 'column': 2},
                'side': 'white',
                'rank': 'man',
              },
              {
                'square': {'row': 5, 'column': 4},
                'side': 'white',
                'rank': 'man',
              },
            ],
          };
          exercise['threat'] = {
            'label': 'Black threatens two jumps',
            'routes': [
              Turn.capture(
                const Square(2, 1),
                const [Square(4, 3), Square(6, 5)],
                const [Square(3, 2), Square(5, 4)],
              ).toJson(),
            ],
          };
          exercise['interaction'] = {
            'type': 'turn',
            'acceptance': 'legalSubset',
            'turns': [
              Turn.step(const Square(3, 2), const Square(2, 3)).toJson(),
              Turn.step(const Square(5, 4), const Square(4, 3)).toJson(),
            ],
          };
          (exercise['feedback'] as Map)['goalMiss'] = 'Save both pieces.';
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            controller: controller,
            highContrast: true,
            reducedMotion: true,
            sound: false,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('board-threat-routes')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('board-square-3-2')),
      );
      await tester.tap(find.byKey(const ValueKey('board-square-3-2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('board-square-2-3')));
      await tester.pump();
      expect(controller.exerciseComplete, isTrue);
      expect(find.byKey(const ValueKey('board-threat-routes')), findsNothing);
    },
  );

  test(
    'loader rejects incomplete or impossible opponent threat routes',
    () async {
      await expectLater(
        _controller(
          modify: (json) {
            final exercise = (json['exercises'] as List).single as Map;
            exercise['threat'] = {
              'label': 'Opponent threat',
              'routes': [
                Turn.capture(
                  const Square(6, 7),
                  const [Square(4, 5)],
                  const [Square(5, 6)],
                ).toJson(),
              ],
            };
          },
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('complete engine legal opponent capture'),
          ),
        ),
      );
    },
  );

  test('preparation rejects indicative square selection', () async {
    await expectLater(
      _controller(
        modify: (json) {
          final exercise = (json['exercises'] as List).single as Map;
          final stage = (exercise['preparation'] as List).first as Map;
          stage['interaction'] = {
            'type': 'squareSelection',
            'targets': [
              {'row': 2, 'column': 1},
            ],
          };
        },
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('passive observation'),
        ),
      ),
    );
  });

  test('loader rejects an illegal worked-example turn', () async {
    await expectLater(
      _controller(
        modify: (json) {
          final exercise = (json['exercises'] as List).single as Map;
          final stage = (exercise['preparation'] as List)[1] as Map;
          stage['previewTurns'] = [
            Turn.step(const Square(1, 0), const Square(4, 3)).toJson(),
          ];
        },
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('preview turn must be engine legal'),
        ),
      ),
    );
  });

  testWidgets('worked examples start from the position after opening turns', (
    tester,
  ) async {
    final controller = await _controller(
      modify: (json) {
        final exercise = (json['exercises'] as List).single as Map;
        (exercise['board'] as Map)['sideToMove'] = 'white';
        (exercise['interaction'] as Map)['openingTurns'] = [_reply.toJson()];
        (exercise['feedback'] as Map)['opening'] = 'Watch White first.';
        (exercise['preparation'] as List).removeRange(2, 4);
      },
    );
    addTearDown(controller.dispose);
    expect(controller.preparationStage, isNull);
    expect(controller.canContinuePreparation, isFalse);
    await tester.pump(const Duration(milliseconds: 550));
    expect(controller.instruction, '1. Check your captures.');
    controller.continueExercise();
    await tester.pump(const Duration(milliseconds: 550));
    expect(controller.pieces[_reply.destination], const Piece.whiteMan());
    expect(
      controller.displayedPieces[_reply.destination],
      const Piece.whiteMan(),
    );
    expect(
      controller.displayedPieces[_candidate.destination],
      const Piece.blackMan(),
    );
    controller.continueExercise();
    expect(controller.displayedPieces, controller.pieces);
    expect(controller.previewLabel, isNull);
    expect(controller.selectedSquare, isNull);
  });
}
