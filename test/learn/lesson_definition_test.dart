import 'package:crown/features/learn/lesson_asset_loader.dart';
import 'package:crown/features/learn/lesson_definition.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and validates every available lesson definition', () async {
    final loader = LessonAssetLoader();
    final catalog = await loader.loadCatalog('assets/learn/catalog.json');
    final available = catalog.units
        .expand((unit) => unit.lessons)
        .where((lesson) => lesson.definitionAsset != null)
        .toList();

    expect(
      available.map((lesson) => lesson.number),
      List.generate(16, (i) => i + 1),
    );

    final definitions = <LessonDefinition>[];
    for (final lesson in available) {
      definitions.add(await loader.loadDefinition(lesson));
    }

    expect(definitions.map((definition) => definition.exercises.length), [
      4,
      5,
      5,
      5,
      5,
      5,
      5,
      0,
      5,
      5,
      5,
      5,
      5,
      5,
      5,
      0,
    ]);
    expect(definitions[7], isA<GuidedMatchDefinition>());
    expect(definitions.last, isA<GuidedMatchDefinition>());
    final challenge = definitions[7] as GuidedMatchDefinition;
    expect(challenge.humanSide, Side.black);
    expect(challenge.aiSkill, 0);
    expect(
      challenge.review.map((item) => item.concept).toSet(),
      ReviewConcept.values.where((concept) => concept.unit == 1).toSet(),
    );
    final unitTwoChallenge = definitions.last as GuidedMatchDefinition;
    expect(
      unitTwoChallenge.review.map((item) => item.concept).toSet(),
      ReviewConcept.values.where((concept) => concept.unit == 2).toSet(),
    );
    expect(
      definitions.first.exercises.last.boardSource,
      LessonBoardSource.previousExerciseResult,
    );
    expect(
      definitions[1].exercises.every(
        (exercise) =>
            exercise.authoredTurns.length == 1 &&
            exercise.authoredTurns.single.isCapture,
      ),
      isTrue,
    );
    expect(definitions[2].exercises[2].authoredTurns, hasLength(2));
    expect(definitions[2].exercises[3].authoredTurns, hasLength(2));
    expect(definitions[2].exercises.last.opponentReply, isNotNull);
    expect(
      definitions[2].exercises.last.opponentPause,
      const Duration(milliseconds: 550),
    );
    expect(
      definitions[2].exercises.last.opponentReply,
      Turn.capture(
        const Square(2, 3),
        const [Square(4, 5)],
        const [Square(3, 4)],
      ),
    );
    expect(
      definitions[3].exercises.every(
        (exercise) => exercise.authoredTurns.every(
          (turn) => turn.isCapture && turn.captures.length >= 2,
        ),
      ),
      isTrue,
    );
    expect(definitions[4].exercises.last.opponentReply, isNotNull);
    expect(definitions[5].exercises[1].acceptAllLegalTurns, isTrue);
    expect(
      definitions[6].exercises.map((exercise) => exercise.interactionType),
      [
        LessonInteractionType.turn,
        LessonInteractionType.turn,
        LessonInteractionType.choice,
        LessonInteractionType.choice,
        LessonInteractionType.choice,
      ],
    );
    expect(
      definitions[6].exercises.map((exercise) => exercise.outcome?.reason),
      [
        ResultReason.noPieces,
        ResultReason.noLegalMove,
        ResultReason.resignation,
        ResultReason.repetition,
        ResultReason.quietKings,
      ],
    );
    expect(
      definitions[6].exercises
          .where(
            (exercise) =>
                exercise.interactionType == LessonInteractionType.choice,
          )
          .expand((exercise) => exercise.choiceOptions)
          .every((option) => option.icon != null),
      isTrue,
    );
  });
}
