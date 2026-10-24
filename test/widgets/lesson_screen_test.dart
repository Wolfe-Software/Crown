import 'package:crown/app/crown_icon.dart';
import 'package:crown/features/learn/lesson_asset_loader.dart';
import 'package:crown/features/learn/lesson_definition.dart';
import 'package:crown/features/learn/learn_curriculum.dart';
import 'package:crown/features/learn/lesson_screen.dart';
import 'package:crown/features/learn/lesson_session_controller.dart';
import 'package:crown/features/match/checker_piece.dart';
import 'package:crown/features/match/checkers_board.dart';
import 'package:crown/features/match/game_result_summary.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lesson_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LearnCatalog catalog;

  setUpAll(() async {
    catalog = await LessonAssetLoader().loadCatalog(
      'assets/learn/catalog.json',
    );
  });

  testWidgets(
    'move goals show all legal destinations and preserve the board on retry',
    (tester) async {
      final lesson = catalog.definitions['lesson-011']!;
      final exercise = lesson.exercises.first;
      final controller = LessonSessionController(
        definition: LessonDefinition(
          id: lesson.id,
          number: lesson.number,
          name: lesson.name,
          exercises: [exercise],
        ),
        reducedMotion: true,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            controller: controller,
            highContrast: false,
            reducedMotion: true,
            sound: false,
          ),
        ),
      );
      final initial = controller.pieces;
      await tester.ensureVisible(find.byType(CheckersBoard));
      final boardRect = tester.getRect(find.byType(CheckersBoard));
      await tester.tap(find.byKey(const ValueKey('board-square-5-2')));
      await tester.pump();
      var board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
      expect(board.destinations, {const Square(4, 1), const Square(4, 3)});
      expect(find.byType(OutlinedButton), findsNothing);
      await tester.tap(find.byKey(const ValueKey('board-square-4-3')));
      await tester.pump();
      expect(find.text(exercise.feedback.goalMiss), findsOneWidget);
      expect(controller.pieces, initial);
      expect(tester.getRect(find.byType(CheckersBoard)), boardRect);
      expect(find.text('COMPLETE LESSON'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('board-square-5-2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('board-square-4-1')));
      await tester.pump();
      board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
      expect(board.pieces[const Square(4, 1)], const Piece.whiteMan());
      expect(board.pieces, isNot(contains(const Square(5, 2))));
      expect(board.onSquareTap, isNull);
      expect(find.text('COMPLETE LESSON'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'opening demonstrations disable board input until the learner can recapture',
    (tester) async {
      final lesson = catalog.definitions['lesson-012']!;
      final exercise = lesson.exercises.first;
      final controller = LessonSessionController(
        definition: LessonDefinition(
          id: lesson.id,
          number: lesson.number,
          name: lesson.name,
          exercises: [exercise],
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            controller: controller,
            highContrast: false,
            reducedMotion: false,
            sound: false,
          ),
        ),
      );
      var board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
      expect(board.onSquareTap, isNull);
      expect(find.text(exercise.feedback.opening!), findsOneWidget);
      expect(find.text('COMPLETE LESSON'), findsNothing);
      await tester.pump(exercise.openingPause);
      board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
      expect(board.activeJump, isNotNull);
      expect(board.onSquareTap, isNull);
      await tester.pump(LessonSessionController.jumpDuration);
      board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
      expect(board.onSquareTap, isNotNull);
      expect(board.bottomSide, Side.white);
      expect(find.text(exercise.feedback.initial), findsOneWidget);
      await tester.ensureVisible(find.byType(CheckersBoard));
      await tester.tap(find.byKey(const ValueKey('board-square-5-2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('board-square-3-4')));
      await tester.pump();
      expect(
        tester.widget<CheckersBoard>(find.byType(CheckersBoard)).onSquareTap,
        isNull,
      );
      await tester.pump(LessonSessionController.jumpDuration);
      expect(find.text(exercise.feedback.success), findsOneWidget);
      expect(find.text('COMPLETE LESSON'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Unit 2 plays through coaching, shared cards, and moves on a compact phone with scaled text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (var number = 9; number <= 15; number++) {
        final lesson =
            catalog.definitions['lesson-${number.toString().padLeft(3, '0')}']!;
        final controller = LessonSessionController(
          definition: lesson,
          reducedMotion: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: LessonScreen(
                controller: controller,
                highContrast: true,
                reducedMotion: true,
                sound: false,
              ),
            ),
          ),
        );
        for (final exercise in lesson.exercises) {
          expect(controller.exerciseId, exercise.id);
          expect(controller.selectedSquare, isNull);
          for (final _ in exercise.openingTurns) {
            await tester.pump(exercise.openingPause);
          }
          final livePieces = Map.of(controller.pieces);
          for (final stage in exercise.preparation) {
            while (!controller.canContinuePreparation &&
                !controller.acceptsInput) {
              await tester.pump(exercise.openingPause);
            }
            expect(find.text(stage.question.instruction), findsOneWidget);
            if (stage.question.interactionType ==
                LessonInteractionType.choice) {
              final answer = find.byKey(
                ValueKey('lesson-choice-${stage.question.correctChoiceId}'),
              );
              await tester.ensureVisible(answer);
              await tester.tap(answer);
              await tester.pump();
            } else {
              await tester.ensureVisible(find.byType(CheckersBoard));
              expect(
                tester.getSize(find.byType(CheckersBoard)),
                const Size(288, 288),
              );
              expect(
                stage.question.interactionType,
                LessonInteractionType.observation,
              );
            }
            expect(controller.pieces, livePieces);
            expect(controller.exerciseComplete, isFalse);
            expect(controller.canContinuePreparation, isTrue);
            expect(tester.takeException(), isNull);
            final action = find.byKey(
              const ValueKey('lesson-continue-compact'),
            );
            await tester.ensureVisible(action);
            await tester.tap(action);
            await tester.pump();
          }
          for (
            var phaseNumber = 1;
            phaseNumber <= 2 && !controller.exerciseComplete;
            phaseNumber++
          ) {
            expect(controller.playerPhaseNumber, phaseNumber);
            expect(controller.acceptsInput, isTrue);
            expect(find.text(controller.instruction), findsOneWidget);
            await tester.ensureVisible(find.byType(CheckersBoard));
            await tester.pump();
            expect(
              tester.getSize(find.byType(CheckersBoard)),
              const Size(288, 288),
            );
            expect(find.byType(OutlinedButton), findsNothing);
            final phase = controller.turnPhase;
            final turn = controller.acceptedTurns.first;
            await tester.tap(
              find.byKey(
                ValueKey(
                  'board-square-${turn.origin.row}-${turn.origin.column}',
                ),
              ),
            );
            await tester.pump();
            for (final landing in turn.landings) {
              await tester.tap(
                find.byKey(
                  ValueKey('board-square-${landing.row}-${landing.column}'),
                ),
              );
              await tester.pump();
            }
            if (phase.opponentReply != null) {
              expect(controller.exerciseComplete, isFalse);
              expect(
                find.byKey(const ValueKey('lesson-continue-compact')),
                findsNothing,
              );
              expect(
                tester
                    .widget<CheckersBoard>(find.byType(CheckersBoard))
                    .onSquareTap,
                isNull,
              );
              await tester.pump(phase.opponentPause);
            }
            if (!controller.exerciseComplete) {
              expect(controller.playerPhaseNumber, 2);
              expect(controller.selectedSquare, isNull);
              expect(
                find.byKey(const ValueKey('lesson-continue-compact')),
                findsNothing,
              );
              expect(find.text('COMPLETE LESSON'), findsNothing);
            }
          }
          expect(controller.exerciseComplete, isTrue, reason: exercise.id);
          expect(
            find.text(controller.turnPhase.feedback.success),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull, reason: exercise.id);
          if (controller.isFinalExercise) {
            expect(find.text('COMPLETE LESSON'), findsOneWidget);
          } else {
            final action = find.byKey(
              const ValueKey('lesson-continue-compact'),
            );
            await tester.ensureVisible(action);
            await tester.tap(action);
            await tester.pump();
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'the displayed opponent mistake moves from its original square before exploitation',
    (tester) async {
      final lesson = catalog.definitions['lesson-013']!;
      final exercise = lesson.exercises[1];
      final controller = LessonSessionController(
        definition: LessonDefinition(
          id: lesson.id,
          number: lesson.number,
          name: lesson.name,
          exercises: [exercise],
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            controller: controller,
            highContrast: false,
            reducedMotion: false,
            sound: false,
          ),
        ),
      );
      var board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
      expect(board.pieces[const Square(4, 3)], const Piece.whiteMan());
      expect(board.pieces[const Square(3, 2)], isNull);
      expect(board.onSquareTap, isNull);
      expect(find.text(exercise.feedback.opening!), findsOneWidget);
      await tester.pump(exercise.openingPause);
      board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
      expect(board.activeJump?.from, const Square(4, 3));
      expect(board.activeJump?.to, const Square(3, 2));
      expect(board.activeJump?.captured, isNull);
      expect(find.byKey(const ValueKey('jumping-piece')), findsOneWidget);
      expect(board.onSquareTap, isNull);
      await tester.pump(LessonSessionController.jumpDuration);
      board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
      expect(board.pieces[const Square(3, 2)], const Piece.whiteMan());
      expect(board.onSquareTap, isNotNull);
      await tester.ensureVisible(find.byType(CheckersBoard));
      await tester.tap(find.byKey(const ValueKey('board-square-2-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('board-square-4-3')));
      await tester.pump();
      await tester.pump(LessonSessionController.jumpDuration);
      expect(find.text(exercise.feedback.success), findsOneWidget);
      expect(find.text('COMPLETE LESSON'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a supporting move hands the board back for the branch-specific payoff',
    (tester) async {
      final lesson = catalog.definitions['lesson-012']!;
      final exercise = lesson.exercises.last;
      final controller = LessonSessionController(
        definition: LessonDefinition(
          id: lesson.id,
          number: lesson.number,
          name: lesson.name,
          exercises: [exercise],
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            controller: controller,
            highContrast: false,
            reducedMotion: false,
            sound: false,
          ),
        ),
      );
      await tester.ensureVisible(find.byType(CheckersBoard));
      await tester.tap(find.byKey(const ValueKey('board-square-6-3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('board-square-5-4')));
      await tester.pump();
      expect(find.text('COMPLETE LESSON'), findsNothing);
      await tester.pump(exercise.opponentPause);
      expect(
        tester.widget<CheckersBoard>(find.byType(CheckersBoard)).onSquareTap,
        isNull,
      );
      await tester.pump(LessonSessionController.jumpDuration);
      final phase = controller.turnPhase;
      expect(controller.playerPhaseNumber, 2);
      expect(find.text(phase.instruction), findsOneWidget);
      expect(find.text(phase.feedback.initial), findsOneWidget);
      expect(find.text('COMPLETE LESSON'), findsNothing);
      expect(controller.selectedSquare, isNull);
      expect(controller.recordedPlayerTurns, hasLength(1));
      await tester.ensureVisible(find.byType(CheckersBoard));
      await tester.tap(find.byKey(const ValueKey('board-square-5-4')));
      await tester.pump();
      expect(
        tester.widget<CheckersBoard>(find.byType(CheckersBoard)).destinations,
        {const Square(3, 2)},
      );
      await tester.tap(find.byKey(const ValueKey('board-square-3-2')));
      await tester.pump();
      expect(find.text('COMPLETE LESSON'), findsNothing);
      await tester.pump(LessonSessionController.jumpDuration);
      expect(controller.recordedPlayerTurns, hasLength(2));
      expect(find.text(phase.feedback.success), findsOneWidget);
      expect(find.text('COMPLETE LESSON'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('presents any definition through the standard lesson screen', (
    tester,
  ) async {
    final definition = catalog.definitions['lesson-002']!;
    final controller = LessonSessionController(
      definition: definition,
      reducedMotion: true,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: LessonScreen(
          controller: controller,
          highContrast: true,
          reducedMotion: true,
          showCoordinates: true,
        ),
      ),
    );

    expect(find.text('LESSON 2'), findsOneWidget);
    expect(find.text('MAKING CAPTURES'), findsOneWidget);
    expectStandardLessonPresentation(
      tester: tester,
      feedbackKey: const ValueKey('lesson-feedback'),
    );
    final board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
    expect(board.highContrast, isTrue);
    expect(board.showCoordinates, isTrue);
    expect(board.reducedMotion, isTrue);
    expect(board.bottomSide, Side.white);
    expect(board.draggableOrigins, isEmpty);
    expect(board.onPieceDrop, isNull);

    final turn = controller.legalTurns.single;
    controller.tapSquare(turn.origin);
    controller.tapSquare(turn.destination);
    await tester.pump();

    expect(find.text('CONTINUE'), findsOneWidget);
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    expect(find.text('EXERCISE 2 OF 5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('waits for a tap on each multi-jump landing', (tester) async {
    final definition = catalog.definitions['lesson-004']!;
    final controller = LessonSessionController(
      definition: definition,
      reducedMotion: true,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: LessonScreen(
          controller: controller,
          highContrast: false,
          reducedMotion: true,
        ),
      ),
    );

    final turn = controller.legalTurns.single;
    controller.tapSquare(turn.origin);
    await tester.pump();
    var board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
    expect(board.destinations, {turn.landings.first});

    controller.tapSquare(turn.landings.first);
    await tester.pump();
    board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
    expect(board.selected, turn.landings.first);
    expect(board.destinations, {turn.landings.last});
    expect(find.text('CONTINUE'), findsNothing);

    controller.tapSquare(turn.landings.last);
    await tester.pump();
    expect(find.text('CONTINUE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'outcome choices use king cards and advance from a result sheet',
    (tester) async {
      final lesson = catalog.definitions['lesson-007']!;
      final definition = LessonDefinition(
        id: lesson.id,
        number: lesson.number,
        name: lesson.name,
        exercises: [lesson.exercises[2], lesson.exercises[3]],
      );
      final controller = LessonSessionController(definition: definition);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            controller: controller,
            highContrast: false,
            reducedMotion: true,
          ),
        ),
      );

      const blackKey = ValueKey('lesson-choice-black-wins');
      const whiteKey = ValueKey('lesson-choice-white-wins');
      const drawKey = ValueKey('lesson-choice-draw');
      final blackPiece = tester.widget<CheckerPiece>(
        find.descendant(
          of: find.byKey(blackKey),
          matching: find.byType(CheckerPiece),
        ),
      );
      final whitePiece = tester.widget<CheckerPiece>(
        find.descendant(
          of: find.byKey(whiteKey),
          matching: find.byType(CheckerPiece),
        ),
      );
      final drawIcon = tester.widget<CrownIcon>(
        find.descendant(
          of: find.byKey(drawKey),
          matching: find.byType(CrownIcon),
        ),
      );
      expect(blackPiece.style, CheckerPieceStyle.black);
      expect(blackPiece.isKing, isTrue);
      expect(whitePiece.style, CheckerPieceStyle.white);
      expect(whitePiece.isKing, isTrue);
      expect(drawIcon.variant, CrownIconVariant.draw);
      final blackRect = tester.getRect(find.byKey(blackKey));
      final whiteRect = tester.getRect(find.byKey(whiteKey));
      final drawRect = tester.getRect(find.byKey(drawKey));
      expect(blackRect.center.dy, whiteRect.center.dy);
      expect(whiteRect.center.dy, drawRect.center.dy);
      expect(blackRect.width, closeTo(whiteRect.width, .01));
      expect(whiteRect.width, closeTo(drawRect.width, .01));
      expect(blackRect.left, lessThan(whiteRect.left));
      expect(whiteRect.left, lessThan(drawRect.left));
      expect(find.bySemanticsLabel('Black Wins'), findsOneWidget);
      expect(find.bySemanticsLabel('White Wins'), findsOneWidget);
      expect(find.bySemanticsLabel('Draw'), findsOneWidget);
      await tester.ensureVisible(find.byKey(drawKey));
      await tester.pumpAndSettle();
      final initialBoardRect = tester.getRect(find.byType(CheckersBoard));
      await tester.tap(find.byKey(drawKey));
      await tester.pump();
      expect(
        find.text('Resignation awards the opponent a win.'),
        findsOneWidget,
      );
      expect(find.byType(GameResultSummary), findsNothing);
      expect(tester.getRect(find.byType(CheckersBoard)), initialBoardRect);

      await tester.ensureVisible(find.byKey(blackKey));
      await tester.tap(find.byKey(blackKey));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(CheckersBoard)), initialBoardRect);
      expect(find.byKey(const ValueKey('lesson-result-sheet')), findsOneWidget);
      expect(find.byType(GameResultSummary), findsOneWidget);
      expect(find.text('Victory'), findsOneWidget);
      expect(find.text('The match ended by resignation.'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lesson-result-sheet')), findsNothing);
      expect(controller.exerciseId, 'how-games-end-4');
    },
  );

  testWidgets('Lesson 7 board stays fixed when turn feedback changes', (
    tester,
  ) async {
    final lesson = catalog.definitions['lesson-007']!;
    final definition = LessonDefinition(
      id: lesson.id,
      number: lesson.number,
      name: lesson.name,
      exercises: [lesson.exercises.first],
    );
    final controller = LessonSessionController(
      definition: definition,
      reducedMotion: true,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: LessonScreen(
          controller: controller,
          highContrast: false,
          reducedMotion: true,
        ),
      ),
    );
    final initialBoardRect = tester.getRect(find.byType(CheckersBoard));

    controller.tapSquare(controller.legalTurns.single.origin);
    await tester.pump();

    expect(tester.getRect(find.byType(CheckersBoard)), initialBoardRect);
  });

  testWidgets('Lesson 7 keeps a full-size board in a 320 by 568 viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lesson = catalog.definitions['lesson-007']!;
    for (final exercise in lesson.exercises) {
      final definition = LessonDefinition(
        id: lesson.id,
        number: lesson.number,
        name: lesson.name,
        exercises: [exercise],
      );
      final controller = LessonSessionController(definition: definition);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            controller: controller,
            highContrast: false,
            reducedMotion: true,
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final viewport = Offset.zero & tester.view.physicalSize;
      final board = find.byType(CheckersBoard);
      expect(viewport.contains(tester.getTopLeft(board)), isTrue);
      expect(viewport.contains(tester.getBottomRight(board)), isTrue);
      expect(tester.getSize(board).width, tester.getSize(board).height);
      expect(tester.getSize(board).width, 288);
      if (exercise.interactionType == LessonInteractionType.choice) {
        final incorrect = exercise.choiceOptions.firstWhere(
          (option) => option.id != exercise.correctChoiceId,
        );
        final choice = find.byKey(ValueKey('lesson-choice-${incorrect.id}'));
        await tester.ensureVisible(choice);
        await tester.pump();
        final initialBoardSize = tester.getSize(board);
        controller.selectChoice(incorrect.id);
        await tester.pump();
        expect(tester.getSize(board), initialBoardSize);
        await tester.ensureVisible(
          find.byKey(const ValueKey('lesson-feedback')),
        );
        await tester.pump();
        expect(
          viewport.contains(
            tester.getBottomRight(
              find.byKey(const ValueKey('lesson-feedback')),
            ),
          ),
          isTrue,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('Lesson 7 fits moderate text scaling on a typical phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lesson = catalog.definitions['lesson-007']!;
    final definition = LessonDefinition(
      id: lesson.id,
      number: lesson.number,
      name: lesson.name,
      exercises: [lesson.exercises.last],
    );
    final controller = LessonSessionController(definition: definition);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: LessonScreen(
            controller: controller,
            highContrast: false,
            reducedMotion: true,
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('lesson-feedback')));
    await tester.pump();
    final viewport = Offset.zero & tester.view.physicalSize;
    expect(
      viewport.contains(
        tester.getBottomRight(find.byKey(const ValueKey('lesson-feedback'))),
      ),
      isTrue,
    );
  });

  testWidgets('Lesson 7 result sheet fits a compact phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lesson = catalog.definitions['lesson-007']!;
    final definition = LessonDefinition(
      id: lesson.id,
      number: lesson.number,
      name: lesson.name,
      exercises: [lesson.exercises.first],
    );
    final controller = LessonSessionController(
      definition: definition,
      reducedMotion: true,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: LessonScreen(
          controller: controller,
          highContrast: false,
          reducedMotion: true,
        ),
      ),
    );
    final turn = controller.legalTurns.single;
    controller.tapSquare(turn.origin);
    controller.tapSquare(turn.destination);
    await tester.pumpAndSettle();

    final viewport = Offset.zero & tester.view.physicalSize;
    final sheet = find.byKey(const ValueKey('lesson-result-sheet'));
    expect(sheet, findsOneWidget);
    final sheetRect = tester.getRect(sheet);
    expect(sheetRect.left, greaterThanOrEqualTo(viewport.left));
    expect(sheetRect.top, greaterThanOrEqualTo(viewport.top));
    expect(sheetRect.right, lessThanOrEqualTo(viewport.right));
    expect(sheetRect.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(find.text('COMPLETE LESSON'), findsOneWidget);
  });
}
