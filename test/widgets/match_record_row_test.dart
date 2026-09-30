import 'package:crown/app/crown_icon.dart';
import 'package:crown/features/history/match_record_row.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:crown/persistence/crown_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows opponent, perspective outcome, and replay action', (
    tester,
  ) async {
    for (final (record, variant, label) in [
      (_record(PerspectiveOutcome.victory), CrownIconVariant.normal, 'Victory'),
      (_record(PerspectiveOutcome.defeat), CrownIconVariant.broken, 'Defeat'),
      (_record(PerspectiveOutcome.draw), CrownIconVariant.draw, 'Draw'),
    ]) {
      var replayed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MatchRecordRow(record: record, onReplay: () => replayed = true),
        ),
      );

      expect(find.text('Crown AI'), findsOneWidget);
      expect(find.text('Replay'), findsOneWidget);
      expect(tester.widget<CrownIcon>(find.byType(CrownIcon)).variant, variant);
      expect(find.bySemanticsLabel(label), findsOneWidget);
      await tester.tap(find.text('Replay'));
      expect(replayed, isTrue);
    }
  });

  testWidgets('lesson feed entry uses the Learn icon and Lesson X label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FeedEntryRow(
          entry: LessonCompletionFeedEntry(
            lessonId: 'lesson-003',
            lessonNumber: 3,
            completedAt: DateTime(2026),
          ),
          onReplay: (_) {},
        ),
      ),
    );

    expect(find.text('Lesson 3'), findsOneWidget);
    expect(find.text('Replay'), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/LearnLogo.png');
    expect(find.bySemanticsLabel('Lesson completed'), findsOneWidget);
  });

  testWidgets('challenge feed entry shows its outcome and can replay', (
    tester,
  ) async {
    final record = _record(PerspectiveOutcome.draw);
    MatchRecord? replayed;
    await tester.pumpWidget(
      MaterialApp(
        home: FeedEntryRow(
          entry: ChallengeAttemptFeedEntry(
            lessonId: 'lesson-008',
            lessonNumber: 8,
            record: record,
          ),
          onReplay: (value) => replayed = value,
        ),
      ),
    );

    expect(find.text('Challenge 8'), findsOneWidget);
    expect(find.bySemanticsLabel('Draw'), findsOneWidget);
    await tester.tap(find.text('Replay'));
    expect(replayed, record);
  });
}

MatchRecord _record(PerspectiveOutcome outcome) {
  final initial = outcome == PerspectiveOutcome.draw
      ? GameState.custom(
          sideToMove: Side.black,
          quietKingPlyCount: 79,
          pieces: {
            const Square(2, 1): const Piece(Side.black, PieceRank.king),
            const Square(5, 6): const Piece(Side.white, PieceRank.king),
          },
        )
      : GameState.initial();
  final session = MatchSession.newGame(
    mode: MatchMode.ai,
    humanSide: Side.black,
    bottomSide: Side.black,
    blackName: 'You',
    whiteName: 'Crown AI',
    initialState: initial,
  );
  final finalState = switch (outcome) {
    PerspectiveOutcome.victory => const CheckersEngine().resign(
      initial,
      Side.white,
    ),
    PerspectiveOutcome.defeat => const CheckersEngine().resign(
      initial,
      Side.black,
    ),
    PerspectiveOutcome.draw => const CheckersEngine().applyTurn(
      initial,
      Turn.step(Square(2, 1), Square(3, 0)),
    ),
  };
  return MatchRecord.fromSession(session.copyWith(state: finalState));
}
