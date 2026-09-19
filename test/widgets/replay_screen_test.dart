import 'package:crown/app/crown_icon.dart';
import 'package:crown/features/history/replay_screen.dart';
import 'package:crown/features/match/player_strip.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:crown/persistence/crown_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('autoplay advances every 700ms and can pause', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReplayScreen(
          record: _record(),
          repository: MemoryCrownRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Opening position'), findsNothing);
    expect(find.textContaining(RegExp(r'Move \d+ of \d+')), findsNothing);
    expect(_slider(tester).value, 0);
    expect(_slider(tester).max, 2);
    expect(_slider(tester).divisions, 2);
    expect(_slider(tester).semanticFormatterCallback!(0), 'Opening position');
    expect(_slider(tester).semanticFormatterCallback!(1), 'Move 1 of 2');
    expect(
      _slider(tester).semanticFormatterCallback!(2),
      'Final position, move 2 of 2',
    );
    expect(find.byType(PlayerStrip), findsNWidgets(2));
    expect(
      tester
          .widgetList<CrownIcon>(find.byType(CrownIcon))
          .where((icon) => icon.variant == CrownIconVariant.jeweled),
      hasLength(1),
    );

    await tester.ensureVisible(find.byTooltip('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byKey(const ValueKey('jumping-piece')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 260));
    expect(_slider(tester).value, 1);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_slider(tester).value, 1);
  });

  testWidgets('previous animates the move in reverse', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReplayScreen(
          record: _record(),
          repository: MemoryCrownRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(_slider(tester).value, 1);

    await tester.tap(find.byTooltip('Previous'));
    await tester.pump();
    expect(find.byKey(const ValueKey('jumping-piece')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 260));
    expect(_slider(tester).value, 0);
  });

  testWidgets('scrubbing during playback cancels the move and resumes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReplayScreen(
          record: _record(turnCount: 3),
          repository: MemoryCrownRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Play'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(find.byKey(const ValueKey('jumping-piece')), findsOneWidget);

    final slider = _slider(tester);
    slider.onChangeStart!(slider.value);
    slider.onChanged!(2);
    slider.onChangeEnd!(2);
    await tester.pump();

    expect(_slider(tester).value, 2);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byKey(const ValueKey('jumping-piece')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 260));
    expect(_slider(tester).value, 3);
    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('scrubbing to the end remains paused', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReplayScreen(
          record: _record(),
          repository: MemoryCrownRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final slider = _slider(tester);
    slider.onChangeStart!(slider.value);
    slider.onChanged!(2);
    slider.onChangeEnd!(2);
    await tester.pump();

    expect(_slider(tester).value, 2);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byKey(const ValueKey('jumping-piece')), findsNothing);
  });

  testWidgets('zero-turn replay has a disabled timeline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReplayScreen(
          record: _record(turnCount: 0),
          repository: MemoryCrownRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final slider = _slider(tester);
    expect(slider.value, 0);
    expect(slider.max, 1);
    expect(slider.divisions, isNull);
    expect(slider.onChanged, isNull);
    expect(slider.semanticFormatterCallback!(0), 'Opening position');
  });
}

Slider _slider(WidgetTester tester) =>
    tester.widget<Slider>(find.byType(Slider));

MatchRecord _record({int turnCount = 2}) {
  const engine = CheckersEngine();
  final initial = GameState.initial();
  var state = initial;
  for (var index = 0; index < turnCount; index++) {
    state = engine.applyTurn(state, engine.legalTurns(state).first);
  }
  final completed = MatchSession.newGame(
    mode: MatchMode.ai,
    humanSide: Side.black,
    bottomSide: Side.black,
    blackName: 'You',
    whiteName: 'Crown AI',
    initialState: initial,
  ).copyWith(state: engine.resign(state, state.sideToMove));
  return MatchRecord.fromSession(completed);
}
