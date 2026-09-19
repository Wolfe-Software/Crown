import 'package:crown/app/crown_theme.dart';
import 'package:crown/features/learn/lesson_one_controller.dart';
import 'package:crown/features/learn/lesson_one_screen.dart';
import 'package:crown/features/match/checker_piece.dart';
import 'package:crown/features/match/checkers_board.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('faces each exercise toward the active color', (tester) async {
    final controller = LessonOneController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: crownTheme(),
        home: LessonOneScreen(
          controller: controller,
          highContrast: false,
          reducedMotion: true,
        ),
      ),
    );

    CheckersBoard board() =>
        tester.widget<CheckersBoard>(find.byType(CheckersBoard));
    expect(board().bottomSide, Side.black);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('board-square-7-7'))).dx,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('board-square-0-0'))).dx,
      ),
    );

    for (final square in const [Square(0, 1), Square(1, 2), Square(2, 3)]) {
      controller.tapSquare(square);
    }
    controller.continueExercise();
    await tester.pump();
    expect(board().bottomSide, Side.white);

    for (final square in const [Square(5, 0), Square(6, 1), Square(7, 2)]) {
      controller.tapSquare(square);
    }
    controller.continueExercise();
    await tester.pump();
    expect(board().bottomSide, Side.black);

    final turn = const CheckersEngine()
        .legalTurns(
          GameState.custom(pieces: controller.pieces, sideToMove: Side.black),
        )
        .first;
    controller.tapSquare(turn.origin);
    controller.tapSquare(turn.destination);
    await tester.pump();
    expect(board().bottomSide, Side.black);

    controller.continueExercise();
    await tester.pump();
    expect(board().bottomSide, Side.white);
  });

  testWidgets('places missing black pieces before resetting for white', (
    tester,
  ) async {
    final controller = LessonOneController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: crownTheme(),
        home: LessonOneScreen(
          controller: controller,
          highContrast: false,
          reducedMotion: true,
          showCoordinates: false,
        ),
      ),
    );

    expect(find.text('Set up the black pieces'), findsOneWidget);
    expect(find.byType(CheckersBoard), findsOneWidget);
    expect(find.byType(CheckerPiece), findsNWidgets(21));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('coordinate-'),
      ),
      findsNothing,
    );

    for (final square in const [(0, 1), (1, 2), (2, 3)]) {
      final target = find.byKey(
        ValueKey('board-square-${square.$1}-${square.$2}'),
      );
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pump();
    }
    expect(find.byType(CheckerPiece), findsNWidgets(24));
    final continueButton = find.widgetWithText(FilledButton, 'CONTINUE');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pump();

    expect(find.text('Set up the white pieces'), findsOneWidget);
    expect(find.byType(CheckerPiece), findsNWidgets(21));
  });

  testWidgets('renders all board coordinates when the setting is enabled', (
    tester,
  ) async {
    final controller = LessonOneController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: crownTheme(),
        home: LessonOneScreen(
          controller: controller,
          highContrast: false,
          reducedMotion: true,
          showCoordinates: true,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('coordinate-0-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('coordinate-7-7')), findsOneWidget);
  });
}
