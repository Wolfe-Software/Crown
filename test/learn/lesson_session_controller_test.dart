import 'package:crown/features/learn/lesson_asset_loader.dart';
import 'package:crown/features/learn/lesson_definition.dart';
import 'package:crown/features/learn/lesson_session_controller.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<LessonDefinition> lessons;

  setUpAll(() async {
    final loader = LessonAssetLoader();
    final catalog = await loader.loadCatalog('assets/learn/catalog.json');
    lessons = [];
    for (final lesson in catalog.units.first.lessons.take(7)) {
      lessons.add(await loader.loadDefinition(lesson));
    }
  });

  test('Lesson 1 uses declarative placement and previous-result state', () {
    final controller = LessonSessionController(
      definition: lessons[0],
      reducedMotion: true,
    );
    addTearDown(controller.dispose);

    expect(controller.exerciseId, 'place-black');
    expect(controller.pieces, hasLength(21));
    controller.tapSquare(const Square(3, 0));
    expect(controller.feedback, contains('not a gap'));
    for (final target in controller.placementTargets) {
      controller.tapSquare(target);
    }
    expect(controller.exerciseComplete, isTrue);
    expect(controller.feedback, 'Black now has all 12 starting pieces.');

    controller.continueExercise();
    expect(controller.exerciseId, 'place-white');
    expect(controller.pieces, hasLength(21));
    for (final target in controller.placementTargets) {
      controller.tapSquare(target);
    }
    controller.continueExercise();

    expect(controller.exerciseId, 'move-black');
    final blackTurn = controller.legalTurns.first;
    controller.tapSquare(blackTurn.origin);
    controller.tapSquare(blackTurn.destination);
    final resultingPieces = Map<Square, Piece>.of(controller.pieces);
    expect(controller.exerciseComplete, isTrue);
    controller.continueExercise();

    expect(controller.exerciseId, 'move-white');
    expect(controller.pieces, resultingPieces);
    expect(controller.sideToMove, Side.white);
    final whiteTurn = controller.legalTurns.first;
    controller.tapSquare(whiteTurn.origin);
    controller.tapSquare(whiteTurn.destination);
    expect(controller.exerciseComplete, isTrue);
    expect(controller.lessonComplete, isFalse);
    controller.continueExercise();
    expect(controller.lessonComplete, isTrue);
  });

  testWidgets('Lesson 2 runs every authored capture and waits for Continue', (
    tester,
  ) async {
    final controller = LessonSessionController(
      definition: lessons[1],
      reducedMotion: true,
    );
    addTearDown(controller.dispose);

    for (var index = 0; index < 5; index++) {
      expect(controller.exerciseNumber, index + 1);
      expect(controller.legalTurns, hasLength(1));
      final turn = controller.legalTurns.single;
      _tapTurn(controller, turn);
      expect(controller.exerciseComplete, isTrue);
      await tester.pump(const Duration(seconds: 5));
      expect(controller.exerciseNumber, index + 1);
      controller.continueExercise();
    }

    expect(controller.lessonComplete, isTrue);
  });

  testWidgets('Lesson 3 accepts every branch and performs its authored reply', (
    tester,
  ) async {
    Future<LessonSessionController> reach(int index) async {
      final controller = LessonSessionController(
        definition: lessons[2],
        reducedMotion: true,
      );
      for (var current = 0; current < index; current++) {
        final turn = controller.legalTurns.first;
        _tapTurn(controller, turn);
        if (!controller.exerciseComplete) {
          await tester.pump(controller.opponentPause);
        }
        controller.continueExercise();
      }
      return controller;
    }

    for (final index in [2, 3]) {
      for (final expected in lessons[2].exercises[index].authoredTurns) {
        final controller = await reach(index);
        _tapTurn(controller, expected);
        expect(controller.recordedPlayerTurns.last, expected);
        expect(controller.exerciseComplete, isTrue);
        expect(controller.pieces, isNot(contains(expected.captures.single)));
        controller.dispose();
      }
    }

    final controller = await reach(4);
    addTearDown(controller.dispose);
    final playerTurn = controller.legalTurns.single;
    _tapTurn(controller, playerTurn);
    expect(controller.exerciseComplete, isFalse);
    expect(controller.feedback, contains('Watch the reply'));
    await tester.pump(controller.opponentPause);
    expect(controller.exerciseComplete, isTrue);
    expect(controller.lastTurn, lessons[2].exercises.last.opponentReply);
    expect(controller.lessonComplete, isFalse);
    controller.continueExercise();
    expect(controller.lessonComplete, isTrue);
  });

  testWidgets('requires a tap before every animated jump', (tester) async {
    final definition = _multiJumpDefinition();
    final turn = definition.exercises.single.authoredTurns.single;
    final controller = LessonSessionController(definition: definition);
    addTearDown(controller.dispose);

    controller.tapSquare(turn.origin);
    expect(controller.destinations, {turn.landings.first});

    controller.tapSquare(turn.landings.first);
    expect(controller.activeJump?.from, turn.origin);
    expect(controller.activeJump?.to, turn.landings.first);

    await tester.pump(LessonSessionController.jumpDuration);
    expect(controller.activeJump, isNull);
    expect(controller.exerciseComplete, isFalse);
    expect(controller.recordedPlayerTurns, isEmpty);
    expect(controller.selectedSquare, turn.landings.first);
    expect(controller.destinations, {turn.landings.last});
    expect(controller.pieces[turn.landings.first], const Piece.blackMan());
    expect(controller.pieces, isNot(contains(turn.captures.first)));
    expect(controller.pieces, contains(turn.captures.last));

    await tester.pump(LessonSessionController.jumpDuration);
    expect(controller.activeJump, isNull);
    expect(controller.exerciseComplete, isFalse);

    controller.tapSquare(turn.landings.last);
    expect(controller.activeJump?.from, turn.landings.first);
    expect(controller.activeJump?.to, turn.landings.last);
    await tester.pump(LessonSessionController.jumpDuration);

    expect(controller.activeJump, isNull);
    expect(controller.exerciseComplete, isTrue);
    expect(controller.recordedPlayerTurns, [turn]);
    expect(controller.pieces[turn.destination], const Piece.blackMan());
    expect(controller.pieces, isNot(contains(turn.captures.last)));
  });

  test('reduced motion still requires every landing tap', () {
    final definition = _multiJumpDefinition();
    final turn = definition.exercises.single.authoredTurns.single;
    final controller = LessonSessionController(
      definition: definition,
      reducedMotion: true,
    );
    addTearDown(controller.dispose);

    controller.tapSquare(turn.origin);
    controller.tapSquare(turn.destination);
    expect(controller.exerciseComplete, isFalse);
    expect(controller.recordedPlayerTurns, isEmpty);

    controller.tapSquare(turn.landings.first);
    expect(controller.exerciseComplete, isFalse);
    expect(controller.selectedSquare, turn.landings.first);
    expect(controller.destinations, {turn.landings.last});

    controller.tapSquare(turn.landings.last);
    expect(controller.exerciseComplete, isTrue);
    expect(controller.recordedPlayerTurns, [turn]);
  });

  testWidgets('Lesson 4 animates its complete multi-jump turns', (
    tester,
  ) async {
    final controller = LessonSessionController(definition: lessons[3]);
    addTearDown(controller.dispose);
    final turn = controller.legalTurns.single;

    controller.tapSquare(turn.origin);
    controller.tapSquare(turn.landings.first);
    expect(controller.activeJump?.to, turn.landings.first);
    await tester.pump(LessonSessionController.jumpDuration);
    expect(controller.activeJump, isNull);
    expect(controller.exerciseComplete, isFalse);
    controller.tapSquare(turn.landings.last);
    expect(controller.activeJump?.to, turn.landings.last);
    await tester.pump(LessonSessionController.jumpDuration);

    expect(controller.exerciseComplete, isTrue);
    expect(controller.pieces[turn.destination], const Piece.blackMan());
    for (final captured in turn.captures) {
      expect(controller.pieces, isNot(contains(captured)));
    }
  });

  test('Lesson 5 promotes on both crown rows and stops after crowning', () {
    const engine = CheckersEngine();
    final definition = lessons[4];

    for (final turn in _legalTurns(definition.exercises[0])) {
      final result = engine.applyTurn(_state(definition.exercises[0]), turn);
      expect(turn.destination.row, 7);
      expect(result.pieces[turn.destination]?.rank, PieceRank.king);
    }
    for (final turn in _legalTurns(definition.exercises[1])) {
      final result = engine.applyTurn(_state(definition.exercises[1]), turn);
      expect(turn.destination.row, 0);
      expect(result.pieces[turn.destination]?.rank, PieceRank.king);
    }

    final capturePromotion = definition.exercises[2];
    final promoted = engine.applyTurn(
      _state(capturePromotion),
      capturePromotion.authoredTurns.single,
    );
    expect(
      promoted.pieces[capturePromotion.authoredTurns.single.destination]?.rank,
      PieceRank.king,
    );

    final stopForCrown = definition.exercises[3];
    final crownTurn = stopForCrown.authoredTurns.single;
    expect(crownTurn.landings, hasLength(1));
    expect(crownTurn.destination.row, 7);
    expect(
      engine
          .applyTurn(_state(stopForCrown), crownTurn)
          .pieces[crownTurn.destination]
          ?.rank,
      PieceRank.king,
    );
  });

  test('Lesson 6 covers backward movement, captures, and king choices', () {
    final definition = lessons[5];

    expect(
      _legalTurns(definition.exercises[0])
          .map((turn) => turn.destination)
          .toSet(),
      {const Square(6, 1), const Square(6, 3)},
    );
    expect(_legalTurns(definition.exercises[1]), hasLength(4));
    expect(
      definition.exercises[2].authoredTurns.single,
      Turn.capture(
        const Square(3, 2),
        const [Square(1, 4)],
        const [Square(2, 3)],
      ),
    );
    expect(definition.exercises[3].authoredTurns.single.landings, hasLength(2));
    expect(definition.exercises[4].authoredTurns, hasLength(2));
  });

  testWidgets('Lessons 4 and 6 accept every authored choice', (tester) async {
    for (final choice in [(lesson: 3, exercise: 3), (lesson: 5, exercise: 4)]) {
      final exercise = lessons[choice.lesson].exercises[choice.exercise];
      for (final expected in exercise.authoredTurns) {
        final controller = await _reachExercise(
          tester,
          lessons[choice.lesson],
          choice.exercise,
        );
        _tapTurn(controller, expected);

        expect(controller.recordedPlayerTurns.last, expected);
        expect(controller.exerciseComplete, isTrue);
        expect(controller.pieces[expected.destination], isNotNull);
        controller.dispose();
      }
    }
  });

  test('Lesson 7 winning turns produce their authored engine outcomes', () {
    const engine = CheckersEngine();
    final definition = lessons[6];

    for (final exercise in definition.exercises.take(2)) {
      final state = GameState.custom(
        pieces: exercise.initialPieces,
        sideToMove: exercise.sideToMove,
      );
      final legalTurns = engine.legalTurns(state);
      expect(legalTurns, exercise.authoredTurns);
      expect(
        engine.applyTurn(state, legalTurns.single).result,
        exercise.outcome,
      );
    }
  });

  test('Lesson 7 classifies resignation and both draw rules', () {
    final exercises = lessons[6].exercises.skip(2);

    expect(exercises.map((exercise) => exercise.correctChoiceId), [
      'black-wins',
      'draw',
      'draw',
    ]);
    expect(exercises.map((exercise) => exercise.outcome), const [
      GameResult.win(Side.black, ResultReason.resignation),
      GameResult.draw(ResultReason.repetition),
      GameResult.draw(ResultReason.quietKings),
    ]);
  });

  test(
    'choice exercises allow retries and reveal their outcome on success',
    () {
      final definition = LessonDefinition(
        id: 'lesson-007',
        number: 7,
        name: 'How Games End',
        exercises: [
          LessonExerciseDefinition(
            id: 'resignation',
            title: 'Resignation',
            instruction: 'White resigned.',
            perspective: Side.black,
            boardSource: LessonBoardSource.custom,
            initialPieces: {
              const Square(2, 1): const Piece.blackMan(),
              const Square(5, 0): const Piece.whiteMan(),
            },
            sideToMove: Side.black,
            interactionType: LessonInteractionType.choice,
            feedback: const LessonFeedbackDefinition(
              initial: 'Choose the result.',
              success: 'Black wins.',
            ),
            choiceOptions: const [
              LessonChoiceOptionDefinition(
                id: 'black-wins',
                label: 'Black wins',
                feedback: 'Correct.',
              ),
              LessonChoiceOptionDefinition(
                id: 'draw',
                label: 'Draw',
                feedback: 'Resignation is not a draw.',
              ),
            ],
            correctChoiceId: 'black-wins',
            outcome: const GameResult.win(Side.black, ResultReason.resignation),
          ),
        ],
      );
      final controller = LessonSessionController(definition: definition);
      addTearDown(controller.dispose);

      controller.selectChoice('draw');
      expect(controller.exerciseComplete, isFalse);
      expect(controller.feedback, 'Resignation is not a draw.');
      expect(controller.visibleOutcome, isNull);

      controller.selectChoice('black-wins');
      expect(controller.exerciseComplete, isTrue);
      expect(controller.feedback, 'Black wins.');
      expect(
        controller.visibleOutcome,
        const GameResult.win(Side.black, ResultReason.resignation),
      );
    },
  );
}

GameState _state(LessonExerciseDefinition exercise) => GameState.custom(
  pieces: exercise.initialPieces,
  sideToMove: exercise.sideToMove,
);

List<Turn> _legalTurns(LessonExerciseDefinition exercise) =>
    const CheckersEngine().legalTurns(_state(exercise));

Future<LessonSessionController> _reachExercise(
  WidgetTester tester,
  LessonDefinition definition,
  int target,
) async {
  final controller = LessonSessionController(
    definition: definition,
    reducedMotion: true,
  );
  for (var index = 0; index < target; index++) {
    final turn = controller.legalTurns.first;
    _tapTurn(controller, turn);
    if (!controller.exerciseComplete) {
      await tester.pump(controller.opponentPause);
    }
    controller.continueExercise();
  }
  return controller;
}

void _tapTurn(LessonSessionController controller, Turn turn) {
  controller.tapSquare(turn.origin);
  for (final landing in turn.landings) {
    controller.tapSquare(landing);
  }
}

LessonDefinition _multiJumpDefinition() {
  final turn = Turn.capture(
    const Square(1, 2),
    const [Square(3, 4), Square(5, 2)],
    const [Square(2, 3), Square(4, 3)],
  );
  return LessonDefinition(
    id: 'multi-jump',
    number: 4,
    name: 'Keep Jumping',
    exercises: [
      LessonExerciseDefinition(
        id: 'complete-turn',
        title: 'Complete the jump',
        instruction: 'Keep jumping.',
        perspective: Side.black,
        boardSource: LessonBoardSource.custom,
        initialPieces: {
          const Square(1, 2): const Piece.blackMan(),
          const Square(2, 3): const Piece.whiteMan(),
          const Square(4, 3): const Piece.whiteMan(),
        },
        sideToMove: Side.black,
        interactionType: LessonInteractionType.turn,
        feedback: const LessonFeedbackDefinition(
          initial: 'Move.',
          progress: '',
          success: 'Done.',
          invalidPiece: 'Wrong piece.',
          invalidDestination: 'Wrong square.',
        ),
        authoredTurns: [turn],
      ),
    ],
  );
}
