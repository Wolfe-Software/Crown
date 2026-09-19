import 'package:crown/app/crown_app.dart';
import 'package:crown/app/crown_icon.dart';
import 'package:crown/app/crown_theme.dart';
import 'package:crown/features/learn/learn_curriculum.dart';
import 'package:crown/features/learn/learn_screen.dart';
import 'package:crown/features/learn/lesson_board.dart';
import 'package:crown/features/learn/lesson_one_screen.dart';
import 'package:crown/features/match/checker_piece.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:crown/persistence/crown_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Finder tile(int number) => find.byKey(ValueKey('lesson-$number'));
Finder get sheet => find.byKey(const ValueKey('lesson-details-sheet'));

void main() {
  Future<void> pumpLearn(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    int lastCompletedLesson = 0,
    bool highContrast = false,
    bool showCoordinates = false,
    Future<void> Function(int lesson)? onLessonCompleted,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: crownTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: LearnScreen(
          bottomPadding: 100,
          lastCompletedLesson: lastCompletedLesson,
          highContrast: highContrast,
          showCoordinates: showCoordinates,
          onLessonCompleted: onLessonCompleted,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('all 64 board spaces open details; future lessons are locked', (
    tester,
  ) async {
    await pumpLearn(tester);
    for (final unit in learnCurriculum) {
      for (final lesson in unit.lessons) {
        await tester.ensureVisible(tile(lesson.number));
        await tester.tap(tile(lesson.number));
        await tester.pumpAndSettle();
        expect(sheet, findsOneWidget);
        expect(find.byKey(const ValueKey('lesson-objective')), findsOneWidget);
        for (final label in [
          'UNIT ${unit.number}',
          unit.name,
          'LESSON ${lesson.number}',
          lesson.name,
          lesson.objective,
        ]) {
          expect(
            find.descendant(of: sheet, matching: find.text(label)),
            findsOneWidget,
          );
        }
        final button = find.widgetWithText(
          FilledButton,
          lesson.number == 1 ? 'START' : 'LOCKED',
        );
        expect(
          tester.widget<FilledButton>(button).onPressed,
          lesson.number == 1 ? isNotNull : isNull,
        );
        await tester.tap(find.byTooltip('Close lesson details'));
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
      }
    }
  });

  testWidgets('Lesson 1 Start closes details and opens the lesson runner', (
    tester,
  ) async {
    await pumpLearn(tester, showCoordinates: true);
    await tester.tap(tile(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'START'));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(find.byType(LessonOneScreen), findsOneWidget);
    expect(find.text('Set up the black pieces'), findsOneWidget);
    expect(find.byKey(const ValueKey('coordinate-0-0')), findsOneWidget);
  });

  testWidgets('completing Lesson 1 unlocks Lesson 2 and reports progress', (
    tester,
  ) async {
    int? completedLesson;
    await pumpLearn(
      tester,
      onLessonCompleted: (lesson) async => completedLesson = lesson,
    );
    await tester.tap(tile(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'START'));
    await tester.pumpAndSettle();

    final controller = tester
        .widget<LessonOneScreen>(find.byType(LessonOneScreen))
        .controller;
    for (final square in const [Square(0, 1), Square(1, 2), Square(2, 3)]) {
      controller.tapSquare(square);
    }
    controller.continueExercise();
    for (final square in const [Square(5, 0), Square(6, 1), Square(7, 2)]) {
      controller.tapSquare(square);
    }
    controller.continueExercise();
    final blackTurn = const CheckersEngine()
        .legalTurns(
          GameState.custom(pieces: controller.pieces, sideToMove: Side.black),
        )
        .first;
    controller.tapSquare(blackTurn.origin);
    controller.tapSquare(blackTurn.destination);
    controller.continueExercise();
    final whiteTurn = const CheckersEngine()
        .legalTurns(
          GameState.custom(pieces: controller.pieces, sideToMove: Side.white),
        )
        .first;
    controller.tapSquare(whiteTurn.origin);
    controller.tapSquare(whiteTurn.destination);
    await tester.pump();
    final complete = find.widgetWithText(FilledButton, 'COMPLETE LESSON');
    await tester.ensureVisible(complete);
    await tester.tap(complete);
    await tester.pumpAndSettle();

    expect(completedLesson, 1);
    expect(find.byType(LessonOneScreen), findsNothing);
    expect(find.byKey(const ValueKey('next-lesson-2')), findsOneWidget);
    expect(
      tester.widget<Semantics>(tile(2)).properties.label,
      isNot(contains('Locked')),
    );
  });

  testWidgets('leaving Lesson 1 early does not report progress', (
    tester,
  ) async {
    int? completedLesson;
    await pumpLearn(
      tester,
      onLessonCompleted: (lesson) async => completedLesson = lesson,
    );
    await tester.tap(tile(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'START'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(completedLesson, isNull);
    expect(find.byKey(const ValueKey('next-lesson-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('completed-lesson-1')), findsNothing);
  });

  testWidgets('browsing never changes the progress-driven current unit', (
    tester,
  ) async {
    await pumpLearn(tester);
    expect(find.text('Eight units. One row at a time.'), findsNothing);
    expect(find.byKey(const ValueKey('learn-hero-logo')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('learn-header-logo'))),
      const Size.square(42),
    );
    final summary = find.byKey(const ValueKey('learn-unit-summary'));
    expect(
      find.descendant(of: summary, matching: find.text('UNIT 1 · LESSONS 1–8')),
      findsOneWidget,
    );
    final boardTop = tester.getTopLeft(find.byType(LessonBoard)).dy;
    expect(boardTop, lessThan(400));
    await tester.tap(tile(19));
    await tester.pumpAndSettle();
    expect(
      find.text('Find the setup move that creates a multiple-jump capture.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close lesson details'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: summary, matching: find.text('UNIT 1 · LESSONS 1–8')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('The Fundamentals')),
      findsOneWidget,
    );
    expect(tester.widget<Semantics>(tile(19)).properties.selected, isNull);
    expect(find.byType(CheckerPiece), findsNothing);
    expect(find.byKey(const ValueKey('next-lesson-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('active-unit-row-3')), findsNothing);
    expect(find.byKey(const ValueKey('active-unit-row-1')), findsNothing);
    expect(tester.getTopLeft(find.byType(LessonBoard)).dy, boardTop);
    await tester.tap(tile(8));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<Semantics>(tile(8)).properties.selected, isNull);
    expect(find.byKey(const ValueKey('next-lesson-1')), findsOneWidget);
  });

  for (final (completed, unit) in const [
    (0, 1),
    (7, 1),
    (8, 2),
    (15, 2),
    (16, 3),
    (63, 8),
    (64, 8),
  ]) {
    testWidgets('progress $completed shows Unit $unit', (tester) async {
      await pumpLearn(tester, lastCompletedLesson: completed);
      final summary = find.byKey(const ValueKey('learn-unit-summary'));
      expect(
        find.descendant(
          of: summary,
          matching: find.text(
            'UNIT $unit · LESSONS ${1 + (unit - 1) * 8}–${unit * 8}',
          ),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('challenge column has eight markers and a matching legend', (
    tester,
  ) async {
    await pumpLearn(tester);
    for (var number = 1; number <= 64; number++) {
      expect(
        find.byKey(ValueKey('lesson-challenge-$number')),
        number % 8 == 0 ? findsOneWidget : findsNothing,
      );
    }
    expect(find.text('Challenge'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lesson-challenge-8')),
        matching: find.byType(CrownIcon),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learn-challenge-legend')),
        matching: find.byType(CrownIcon),
      ),
      findsOneWidget,
    );
    expect(find.text('Unit challenge'), findsNothing);
    final challenge = tester.widget<Semantics>(tile(8));
    expect(challenge.properties.label, contains('Unit challenge.'));
    final numeral = tester.widget<Text>(
      find.descendant(of: tile(18), matching: find.text('18')),
    );
    expect(numeral.style!.fontFamily, 'Cormorant Garamond');
    expect(numeral.style!.fontSize, inInclusiveRange(12, 14));
    final square = tester.getRect(tile(18));
    final number = tester.getRect(
      find.byKey(const ValueKey('lesson-number-18')),
    );
    expect(square.right - number.right, closeTo(4, .1));
    expect(square.bottom - number.bottom, closeTo(3, .1));
  });

  testWidgets(
    'row-major order, accessible lesson labels and keyboard activation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpLearn(tester);
      expect(tester.getCenter(tile(1)).dy, tester.getCenter(tile(8)).dy);
      expect(
        tester.getCenter(tile(1)).dx,
        lessThan(tester.getCenter(tile(8)).dx),
      );
      expect(
        tester.getCenter(tile(9)).dy,
        greaterThan(tester.getCenter(tile(8)).dy),
      );
      expect(
        find.bySemanticsLabel(
          'Unit 1, The Fundamentals. Lesson 1, Meet the Board. Next lesson.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(tile(1));
      final focus = Focus.of(
        tester.element(
          find.descendant(of: tile(1), matching: find.byType(Text)),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lesson-focus-1')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      await tester.tap(tile(1));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 80));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('unit label follows the board and precedes the hint and legend', (
    tester,
  ) async {
    await pumpLearn(tester, size: const Size(700, 1000));
    final panel = find.byKey(const ValueKey('learn-board-panel'));
    final header = find.byKey(const ValueKey('learn-unit-summary'));
    final board = find.byType(LessonBoard);
    expect(find.descendant(of: panel, matching: header), findsOneWidget);
    expect(find.descendant(of: panel, matching: board), findsOneWidget);
    expect(find.byKey(const ValueKey('learn-panel-blur')), findsOneWidget);
    final clip = tester.widget<ClipRRect>(
      find.byKey(const ValueKey('learn-panel-clip')),
    );
    expect(
      (clip.borderRadius as BorderRadius).topLeft.x,
      lessThan((clip.borderRadius as BorderRadius).bottomLeft.x),
    );
    expect(tester.getRect(board).bottom, lessThan(tester.getRect(header).top));
    final instruction = tester.getRect(
      find.text('Tap a square to explore a lesson.'),
    );
    final legend = tester.getRect(
      find.byKey(const ValueKey('learn-challenge-legend')),
    );
    expect(tester.getRect(header).bottom, lessThan(instruction.top));
    expect(tester.getRect(header).bottom, lessThan(legend.top));
    expect(instruction.center.dy, closeTo(legend.center.dy, .1));
    expect(instruction.left, closeTo(tester.getRect(panel).left, .1));
    expect(legend.right, closeTo(tester.getRect(panel).right, .1));
  });

  testWidgets(
    'Learn wordmark stacks the enlarged logo above the display title',
    (tester) async {
      await pumpLearn(tester);
      final logo = find.byKey(const ValueKey('learn-header-logo'));
      final title = find.text('LEARN');
      expect(tester.getRect(logo).bottom, lessThan(tester.getRect(title).top));
      expect(tester.getCenter(logo).dx, tester.getCenter(title).dx);
      expect(
        tester.widget<Text>(title).style,
        Theme.of(tester.element(title)).textTheme.displayLarge,
      );
    },
  );

  testWidgets('unit list contains the current unit once in curriculum order', (
    tester,
  ) async {
    await pumpLearn(tester, lastCompletedLesson: 8);
    final header = find.byKey(const ValueKey('learn-unit-summary'));
    final boardRect = tester.getRect(find.byType(LessonBoard));
    await tester.tap(header);
    await tester.pumpAndSettle();
    final list = find.byKey(const ValueKey('learn-unit-list'));
    expect(list, findsOneWidget);
    expect(header.hitTestable(), findsNothing);
    expect(find.byType(LessonBoard).hitTestable(), findsNothing);
    expect(
      find.text('Tap a square to explore a lesson.').hitTestable(),
      findsNothing,
    );
    final first = find.byKey(const ValueKey('unit-list-label-1'));
    final current = find.byKey(const ValueKey('unit-list-label-2'));
    final third = find.byKey(const ValueKey('unit-list-label-3'));
    expect(current, findsOneWidget);
    expect(tester.getCenter(first).dy, lessThan(tester.getCenter(current).dy));
    expect(tester.getCenter(current).dy, lessThan(tester.getCenter(third).dy));
    expect(tester.getRect(list).overlaps(tester.getRect(current)), isTrue);
    await tester.tap(current);
    await tester.pumpAndSettle();
    expect(list.hitTestable(), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learn-unit-summary')),
        matching: find.text('UNIT 2 · LESSONS 9–16'),
      ),
      findsOneWidget,
    );
    expect(find.byType(LessonBoard).hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byType(LessonBoard)), boardRect);
    expect(find.byKey(const ValueKey('next-lesson-9')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('learn-unit-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LEARN'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonBoard).hitTestable(), findsOneWidget);
    expect(list.hitTestable(), findsNothing);
  });

  testWidgets('unit list scrolls the current final unit into view', (
    tester,
  ) async {
    await pumpLearn(tester, lastCompletedLesson: 63);
    await tester.tap(find.byKey(const ValueKey('learn-unit-summary')));
    await tester.pumpAndSettle();

    final list = find.byKey(const ValueKey('learn-unit-list'));
    final current = find.byKey(const ValueKey('unit-list-label-8'));
    expect(current, findsOneWidget);
    expect(current.hitTestable(), findsOneWidget);
    expect(tester.getRect(list).overlaps(tester.getRect(current)), isTrue);
  });

  testWidgets('unit directory opens from the label and fills its former area', (
    tester,
  ) async {
    await pumpLearn(tester, lastCompletedLesson: 8);
    final boardRect = tester.getRect(find.byType(LessonBoard));
    final summaryRect = tester.getRect(
      find.byKey(const ValueKey('learn-unit-summary')),
    );

    await tester.tap(find.byKey(const ValueKey('learn-unit-summary')));
    await tester.pump();

    final pane = find.byKey(const ValueKey('learn-unit-list-pane'));
    final current = find.byKey(const ValueKey('unit-list-header-2'));
    final first = find.byKey(const ValueKey('unit-list-header-1'));
    expect(find.byType(LessonBoard).hitTestable(), findsNothing);
    expect(find.text('Tap anywhere to return to the board.'), findsOneWidget);
    expect(tester.getRect(pane).top, closeTo(boardRect.top, .1));
    expect(tester.getRect(pane).bottom, closeTo(summaryRect.bottom, .1));
    expect(tester.getRect(current).top, closeTo(summaryRect.top, .1));

    final currentStart = tester.getTopLeft(current).dy;
    final firstStart = tester.getTopLeft(first).dy;
    await tester.pump(const Duration(milliseconds: 125));
    final currentDelta = tester.getTopLeft(current).dy - currentStart;
    final firstDelta = tester.getTopLeft(first).dy - firstStart;
    expect(currentDelta.abs(), greaterThan(1));
    expect(firstDelta, closeTo(currentDelta, .1));

    await tester.pumpAndSettle();
    expect(tester.getRect(pane).overlaps(tester.getRect(current)), isTrue);
  });

  testWidgets(
    'scrolling keeps the directory open but a tap returns the board',
    (tester) async {
      await pumpLearn(tester, lastCompletedLesson: 8);
      final boardRect = tester.getRect(find.byType(LessonBoard));
      await tester.tap(find.byKey(const ValueKey('learn-unit-summary')));
      await tester.pumpAndSettle();

      final list = find.byKey(const ValueKey('learn-unit-list'));
      await tester.drag(list, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('learn-unit-list-pane')),
        findsOneWidget,
      );
      expect(find.text('Tap anywhere to return to the board.'), findsOneWidget);

      await tester.tap(find.text('Tap anywhere to return to the board.'));
      await tester.pump();
      expect(find.byType(LessonBoard).hitTestable(), findsNothing);
      expect(
        find.byKey(const ValueKey('learn-unit-list-pane')),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(find.byType(LessonBoard).hitTestable(), findsOneWidget);
      expect(tester.getRect(find.byType(LessonBoard)), boardRect);
      expect(find.text('Tap a square to explore a lesson.'), findsOneWidget);
    },
  );

  testWidgets('Learn content keeps bottom-navigation clearance', (
    tester,
  ) async {
    await pumpLearn(tester);
    await tester.drag(
      find.byKey(const ValueKey('learn-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getRect(find.byKey(const ValueKey('learn-challenge-legend')))
          .bottom,
      lessThanOrEqualTo(844 - 100),
    );
  });

  for (final completed in [0, 8, 63, 64]) {
    testWidgets(
      'progress $completed locks only lessons after the next lesson',
      (tester) async {
        await pumpLearn(tester, lastCompletedLesson: completed);
        final numbers = {
          1,
          if (completed > 0) completed,
          if (completed < 64) completed + 1,
          if (completed < 63) completed + 2,
          64,
        };
        for (final number in numbers) {
          await tester.ensureVisible(tile(number));
          await tester.tap(tile(number));
          await tester.pumpAndSettle();
          final locked = number > completed + 1;
          final action = find.widgetWithText(
            FilledButton,
            locked ? 'LOCKED' : 'START',
          );
          final button = tester.widget<FilledButton>(action);
          expect(button.onPressed, locked ? isNull : isNotNull);
          final surface = tester.widget<DecoratedBox>(
            find.byKey(
              ValueKey(locked ? 'metal-surface-silver' : 'metal-surface-gold'),
            ),
          );
          final finish = surface.decoration as BoxDecoration;
          final gradient = finish.gradient! as RadialGradient;
          expect(gradient.center, Alignment.topLeft);
          expect(gradient.radius, greaterThan(1));
          final colors = gradient.colors;
          expect(colors.length, lessThanOrEqualTo(4));
          for (final color in colors) {
            expect(color.r, lessThan(.9));
            expect(color.g, lessThan(.9));
            expect(color.b, lessThan(.9));
          }
          final brightness = [
            for (final color in colors) color.r + color.g + color.b,
          ];
          for (var index = 1; index < brightness.length; index++) {
            expect(brightness[index - 1], greaterThan(brightness[index]));
          }
          if (!locked) {
            expect(colors.last.g, greaterThan(.54));
            expect(colors.last.b, greaterThan(.19));
            expect(colors.last.r - colors.last.g, lessThan(.18));
          }
          expect(finish.border, isNotNull);
          expect(
            find.descendant(
              of: find.byKey(
                ValueKey(
                  locked ? 'metal-surface-silver' : 'metal-surface-gold',
                ),
              ),
              matching: find.byKey(
                ValueKey(locked ? 'metal-brush-silver' : 'metal-brush-gold'),
              ),
            ),
            findsOneWidget,
          );
          await tester.tap(find.byTooltip('Close lesson details'));
          await tester.pumpAndSettle();
        }
      },
    );
  }

  for (final completed in [0, 1, 8, 63, 64]) {
    testWidgets(
      'progress $completed shows only the last completed checker and next hint',
      (tester) async {
        await pumpLearn(tester, lastCompletedLesson: completed);
        expect(
          find.byType(CheckerPiece),
          completed == 0 ? findsNothing : findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('next-lesson-${completed + 1}')),
          completed == 64 ? findsNothing : findsOneWidget,
        );
        if (completed > 0) {
          final checker = find.byKey(ValueKey('completed-lesson-$completed'));
          expect(
            find.descendant(of: tile(completed), matching: checker),
            findsOneWidget,
          );
          expect(
            tester.getCenter(checker),
            within(distance: .01, from: tester.getCenter(tile(completed))),
          );
          expect(
            find.byKey(ValueKey('lesson-number-$completed')),
            findsOneWidget,
          );
          expect(
            tester.widget<Semantics>(tile(completed)).properties.label,
            contains('Last completed lesson.'),
          );
        }
        if (completed < 64) {
          expect(
            find.descendant(
              of: tile(completed + 1),
              matching: find.byKey(ValueKey('next-lesson-${completed + 1}')),
            ),
            findsOneWidget,
          );
          final hint = find.byKey(ValueKey('next-lesson-${completed + 1}'));
          final highlight = find.byKey(
            ValueKey('next-lesson-highlight-${completed + 1}'),
          );
          expect(
            tester.getRect(highlight),
            tester.getRect(tile(completed + 1)),
          );
          final wash = tester.widget<ColoredBox>(
            find.descendant(of: highlight, matching: find.byType(ColoredBox)),
          );
          expect(wash.color, CrownColors.paleGold.withValues(alpha: .28));
          expect(tester.getSize(hint), const Size.square(16));
          expect(tester.getCenter(hint), tester.getCenter(tile(completed + 1)));
          final container = tester.widget<Container>(
            find.descendant(of: hint, matching: find.byType(Container)),
          );
          final decoration = container.decoration! as BoxDecoration;
          expect(decoration.color, CrownColors.paleGold.withValues(alpha: .85));
          expect(
            decoration.border,
            Border.all(color: CrownColors.gold, width: 1.5),
          );
        }
        await tester.ensureVisible(tile(19));
        await tester.tap(tile(19));
        await tester.pumpAndSettle();
        final action = find.widgetWithText(
          FilledButton,
          19 > completed + 1 ? 'LOCKED' : 'START',
        );
        await tester.ensureVisible(action);
        expect(
          tester.widget<FilledButton>(action).onPressed,
          19 > completed + 1 ? isNull : isNotNull,
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close lesson details'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<LessonBoard>(find.byType(LessonBoard))
              .lastCompletedLesson,
          completed,
        );
      },
    );
  }

  testWidgets(
    'large-text high-contrast progress centers the checker and keeps its number',
    (tester) async {
      await pumpLearn(
        tester,
        size: const Size(320, 480),
        textScale: 2,
        lastCompletedLesson: 8,
        highContrast: true,
      );
      await tester.ensureVisible(tile(8));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byKey(const ValueKey('completed-lesson-8'))),
        within(distance: .01, from: tester.getCenter(tile(8))),
      );
      expect(find.byKey(const ValueKey('lesson-number-8')), findsOneWidget);
      expect(find.byKey(const ValueKey('next-lesson-9')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact large-text layout scrolls to lesson 64 and keeps Locked reachable',
    (tester) async {
      await pumpLearn(tester, size: const Size(320, 480), textScale: 2);
      await tester.drag(
        find.byKey(const ValueKey('learn-scroll')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(tile(64));
      await tester.pumpAndSettle();
      expect(tester.getSize(tile(64)).width, greaterThanOrEqualTo(44));
      await tester.tap(tile(64));
      await tester.pumpAndSettle();
      expect(find.text('Final Challenge: A Complete Game'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'LOCKED'));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'LOCKED'))
            .onPressed,
        isNull,
      );
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'app shell passes Learn accessibility settings and clears bottom navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MemoryCrownRepository();
      await repository.saveSettings(
        const CrownSettings(
          highContrast: true,
          reducedMotion: true,
          showCoordinates: true,
        ),
      );
      await tester.pumpWidget(CrownApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LessonBoard>(find.byType(LessonBoard)).highContrast,
        isTrue,
      );
      await tester.tap(tile(1));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'START'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('coordinate-0-0')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(tile(64));
      await tester.drag(find.byType(LessonBoard), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(tile(64)).bottom,
        lessThan(tester.getRect(find.text('Profile')).top),
      );
      await tester.tap(tile(64));
      await tester.pump();
      expect(
        ModalRoute.of(tester.element(sheet))!.transitionDuration,
        Duration.zero,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
