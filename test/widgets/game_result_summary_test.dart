import 'package:crown/app/crown_icon.dart';
import 'package:crown/features/match/game_result_summary.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('presents the shared draw indicator and reason', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameResultSummary(
            result: GameResult.draw(ResultReason.repetition),
            perspective: Side.black,
          ),
        ),
      ),
    );

    expect(find.text('Draw'), findsOneWidget);
    expect(
      find.text('The same position occurred three times.'),
      findsOneWidget,
    );
    expect(
      tester.widget<CrownIcon>(find.byType(CrownIcon)).variant,
      CrownIconVariant.draw,
    );
  });
}
