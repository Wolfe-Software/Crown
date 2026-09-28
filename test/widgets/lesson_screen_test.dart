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
      final initialBoardRect = tester.getRect(find.byType(CheckersBoard));

      await tester.tap(find.byKey(drawKey));
      await tester.pump();
      expect(
        find.text('Resignation awards the opponent a win.'),
        findsOneWidget,
      );
      expect(find.byType(GameResultSummary), findsNothing);
      expect(tester.getRect(find.byType(CheckersBoard)), initialBoardRect);

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

  testWidgets('Lesson 7 fits a 320 by 568 viewport without scrolling', (
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

      expect(find.byType(SingleChildScrollView), findsNothing);
      final viewport = Offset.zero & tester.view.physicalSize;
      final board = find.byType(CheckersBoard);
      final visible = [
        board,
        find.byKey(const ValueKey('lesson-feedback')),
        if (exercise.interactionType == LessonInteractionType.choice)
          find.byKey(const ValueKey('lesson-choice-row')),
      ];
      for (final finder in visible) {
        expect(viewport.contains(tester.getTopLeft(finder)), isTrue);
        expect(viewport.contains(tester.getBottomRight(finder)), isTrue);
      }
      expect(tester.getSize(board).width, tester.getSize(board).height);
      expect(tester.getSize(board).width, greaterThan(0));
      final initialBoardRect = tester.getRect(board);
      if (exercise.interactionType == LessonInteractionType.choice) {
        final incorrect = exercise.choiceOptions.firstWhere(
          (option) => option.id != exercise.correctChoiceId,
        );
        controller.selectChoice(incorrect.id);
        await tester.pump();
        expect(tester.getRect(board), initialBoardRect);
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

    expect(find.byType(SingleChildScrollView), findsNothing);
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
