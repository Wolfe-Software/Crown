import 'package:crown/app/crown_bottom_modal.dart';
import 'package:crown/features/home/local_color_picker.dart';
import 'package:crown/features/match/checker_piece.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('presents black, white, and split random pieces', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocalColorPicker(onSelected: (_) {})),
      ),
    );

    expect(find.text('Choose host color'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Choose host color')).dx,
      closeTo(400, 1),
    );
    expect(find.text('BLACK'), findsOneWidget);
    expect(find.text('WHITE'), findsOneWidget);
    expect(find.text('RANDOM'), findsOneWidget);
    expect(find.byType(CrownBottomSheet), findsOneWidget);
    final styles = tester
        .widgetList<CheckerPiece>(find.byType(CheckerPiece))
        .map((piece) => piece.style);
    expect(
      styles,
      containsAll(const [
        CheckerPieceStyle.black,
        CheckerPieceStyle.white,
        CheckerPieceStyle.split,
      ]),
    );
  });

  testWidgets('direct color selection returns immediately', (tester) async {
    Side? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalColorPicker(onSelected: (side) => selected = side),
        ),
      ),
    );

    await tester.tap(find.text('BLACK'));
    await tester.pump();

    expect(selected, Side.black);
  });

  testWidgets('player role adapts copy without changing choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalColorPicker(
            role: ColorPickerRole.player,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Choose your color'), findsOneWidget);
    expect(
      find.text('Your pieces stay at the bottom of the board.'),
      findsOneWidget,
    );
    expect(find.text('BLACK'), findsOneWidget);
    expect(find.text('WHITE'), findsOneWidget);
    expect(find.text('RANDOM'), findsOneWidget);
  });

  testWidgets('random flips, lands on assignment, then auto-completes', (
    tester,
  ) async {
    Side? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalColorPicker(
            onSelected: (side) => selected = side,
            randomSideResolver: () => Side.white,
            flipDuration: const Duration(milliseconds: 300),
            resultDuration: const Duration(milliseconds: 200),
          ),
        ),
      ),
    );

    await tester.tap(find.text('RANDOM'));
    await tester.pump();
    expect(find.byKey(const ValueKey('random-piece-flip')), findsOneWidget);
    expect(selected, isNull);

    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
    expect(find.text('HOST PLAYS WHITE'), findsOneWidget);
    expect(
      tester.widget<CheckerPiece>(find.byType(CheckerPiece)).style,
      CheckerPieceStyle.white,
    );
    expect(selected, isNull);

    await tester.pump(const Duration(milliseconds: 200));
    expect(selected, Side.white);
  });

  testWidgets('reduced motion replaces rotation with a transition', (
    tester,
  ) async {
    Side? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalColorPicker(
            onSelected: (side) => selected = side,
            randomSideResolver: () => Side.black,
            reducedMotion: true,
            flipDuration: const Duration(milliseconds: 100),
            resultDuration: const Duration(milliseconds: 100),
          ),
        ),
      ),
    );

    await tester.tap(find.text('RANDOM'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('random-piece-reduced-transition')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('random-piece-flip')), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('HOST PLAYS BLACK'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(selected, Side.black);
  });

  testWidgets('player random result uses player wording', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalColorPicker(
            role: ColorPickerRole.player,
            onSelected: (_) {},
            randomSideResolver: () => Side.white,
            reducedMotion: true,
            flipDuration: const Duration(milliseconds: 100),
            resultDuration: const Duration(milliseconds: 100),
          ),
        ),
      ),
    );

    await tester.tap(find.text('RANDOM'));
    await tester.pumpAndSettle();
    expect(find.text('YOU PLAY WHITE'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
  });
}
