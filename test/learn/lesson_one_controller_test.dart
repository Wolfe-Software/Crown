import 'package:crown/features/learn/lesson_one_controller.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter_test/flutter_test.dart';

final blackMissing = {
  const Square(0, 1),
  const Square(1, 2),
  const Square(2, 3),
};
final whiteMissing = {
  const Square(5, 0),
  const Square(6, 1),
  const Square(7, 2),
};

void placeMissing(LessonOneController controller, Set<Square> squares) {
  for (final square in squares) {
    controller.tapSquare(square);
  }
}

void advanceTo(LessonOneController controller, LessonOneExercise target) {
  if (target == LessonOneExercise.placeBlack) return;
  placeMissing(controller, blackMissing);
  controller.continueExercise();
  if (target == LessonOneExercise.placeWhite) return;
  placeMissing(controller, whiteMissing);
  controller.continueExercise();
  if (target == LessonOneExercise.moveBlack) return;
  final turn = const CheckersEngine()
      .legalTurns(
        GameState.custom(pieces: controller.pieces, sideToMove: Side.black),
      )
      .first;
  controller.tapSquare(turn.origin);
  controller.tapSquare(turn.destination);
  controller.continueExercise();
}

void main() {
  test('perspective follows the exercise color until Continue', () {
    final controller = LessonOneController();
    expect(controller.perspectiveSide, Side.black);

    placeMissing(controller, blackMissing);
    controller.continueExercise();
    expect(controller.perspectiveSide, Side.white);

    placeMissing(controller, whiteMissing);
    controller.continueExercise();
    expect(controller.perspectiveSide, Side.black);

    final state = GameState.custom(
      pieces: controller.pieces,
      sideToMove: Side.black,
    );
    final turn = const CheckersEngine().legalTurns(state).first;
    controller.tapSquare(turn.origin);
    controller.tapSquare(turn.destination);
    expect(controller.perspectiveSide, Side.black);

    controller.continueExercise();
    expect(controller.perspectiveSide, Side.white);
  });

  test('places only the three missing black starting pieces', () {
    final controller = LessonOneController();

    expect(controller.exercise, LessonOneExercise.placeBlack);
    expect(controller.pieces.length, 21);
    expect(blackMissing.where(controller.pieces.containsKey), isEmpty);
    expect(
      controller.pieces.values.where((piece) => piece.side == Side.white),
      hasLength(12),
    );

    controller.tapSquare(const Square(3, 0));
    controller.tapSquare(const Square(5, 0));
    expect(controller.placementCount, 0);
    expect(controller.exerciseComplete, isFalse);

    placeMissing(controller, blackMissing);
    expect(controller.placementCount, 3);
    expect(controller.exerciseMoveCount, 0);
    expect(controller.exerciseComplete, isTrue);
    for (final square in blackMissing) {
      expect(controller.pieces[square], const Piece.blackMan());
    }
  });

  test('resets to three missing white starting pieces', () {
    final controller = LessonOneController();
    placeMissing(controller, blackMissing);
    controller.continueExercise();

    expect(controller.exercise, LessonOneExercise.placeWhite);
    expect(controller.pieces.length, 21);
    expect(whiteMissing.where(controller.pieces.containsKey), isEmpty);
    expect(
      controller.pieces.values.where((piece) => piece.side == Side.black),
      hasLength(12),
    );

    controller.tapSquare(const Square(2, 3));
    expect(controller.placementCount, 0);
    placeMissing(controller, whiteMissing);
    expect(controller.exerciseComplete, isTrue);
    for (final square in whiteMissing) {
      expect(controller.pieces[square], const Piece.whiteMan());
    }
  });

  test('requires selecting and making one legal black move', () {
    final controller = LessonOneController();
    advanceTo(controller, LessonOneExercise.moveBlack);
    final state = GameState.custom(
      pieces: controller.pieces,
      sideToMove: Side.black,
    );
    final legalTurn = const CheckersEngine().legalTurns(state).first;

    controller.tapSquare(const Square(7, 0));
    expect(controller.selectedSquare, isNull);
    expect(controller.exerciseMoveCount, 0);

    controller.tapSquare(legalTurn.origin);
    expect(controller.selectedSquare, legalTurn.origin);
    expect(controller.destinations, contains(legalTurn.destination));

    controller.tapSquare(legalTurn.destination);
    expect(controller.exerciseMoveCount, 1);
    expect(controller.exerciseComplete, isTrue);
    expect(controller.pieces[legalTurn.origin], isNull);
    expect(controller.pieces[legalTurn.destination], const Piece.blackMan());
  });

  test('white replies legally to the black move and completes the lesson', () {
    final controller = LessonOneController();
    advanceTo(controller, LessonOneExercise.moveWhite);
    final before = Map<Square, Piece>.of(controller.pieces);
    final state = GameState.custom(
      pieces: controller.pieces,
      sideToMove: Side.white,
    );
    final legalTurn = const CheckersEngine().legalTurns(state).first;

    expect(controller.exercise, LessonOneExercise.moveWhite);
    expect(
      before.values.where((piece) => piece.side == Side.black),
      hasLength(12),
    );
    controller.tapSquare(legalTurn.origin);
    controller.tapSquare(legalTurn.destination);

    expect(controller.exerciseMoveCount, 1);
    expect(controller.exerciseComplete, isTrue);
    controller.continueExercise();
    expect(controller.lessonComplete, isTrue);
  });
}
