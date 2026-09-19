import 'package:crown/app/crown_icon.dart';
import 'package:crown/features/match/player_strip.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('marks Crown AI inside its side indicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlayerStrip(
          name: 'Crown AI',
          side: Side.white,
          isCrownAi: true,
          active: true,
          pieces: 12,
        ),
      ),
    );

    final indicator = tester.getRect(
      find.byKey(const ValueKey('side-indicator-white')),
    );
    final crown = tester.getRect(find.byType(CrownIcon));
    expect(indicator.contains(crown.topLeft), isTrue);
    expect(indicator.contains(crown.bottomRight), isTrue);
    expect(
      tester.widget<CrownIcon>(find.byType(CrownIcon)).variant,
      CrownIconVariant.jeweled,
    );
    expect(
      find.bySemanticsLabel('Crown AI, white, 12 pieces, active turn'),
      findsOneWidget,
    );
  });

  testWidgets('does not infer AI identity from a local player name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlayerStrip(
          name: 'Crown AI',
          side: Side.black,
          isCrownAi: false,
          active: false,
          pieces: 9,
        ),
      ),
    );

    expect(find.byType(CrownIcon), findsNothing);
  });
}
