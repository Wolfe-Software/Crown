import 'package:crown/features/learn/lesson_asset_loader.dart';
import 'package:crown/features/learn/lesson_definition.dart';
import 'package:crown/features/learn/lesson_session_controller.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _engine = CheckersEngine();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<LessonDefinition> lessons;
  Iterable<LessonExerciseDefinition> exercises() =>
      lessons.expand((lesson) => lesson.exercises);
  setUpAll(() async {
    final catalog = await LessonAssetLoader().loadCatalog(
      'assets/learn/catalog.json',
    );
    lessons = [
      for (var number = 9; number <= 15; number++)
        catalog.definitions['lesson-${number.toString().padLeft(3, '0')}']!,
    ];
  });

  test('all 35 exercises use short constructive learner paths', () {
    expect(lessons, hasLength(7));
    for (final lesson in lessons) {
      expect(lesson.exercises, hasLength(5));
      for (final exercise in lesson.exercises) {
        expect(exercise.interactionType, LessonInteractionType.turn);
        expect(exercise.choiceOptions, isEmpty);
        expect(exercise.squareTargets, isEmpty);
        for (final path in _paths(exercise)) {
          expect(path.playerTurns.length, lessThanOrEqualTo(2));
          expect(
            path.playerTurns.every((turn) => turn.landings.length <= 2),
            isTrue,
          );
          final initial = _initial(exercise);
          final finalState = _result(exercise, path);
          int losses(Side side) =>
              _count(initial, side) - _count(finalState, side);
          expect(
            losses(exercise.perspective.opponent),
            greaterThanOrEqualTo(losses(exercise.perspective)),
            reason: '${exercise.id}: never require a losing demonstration',
          );
          if (finalState.sideToMove == exercise.perspective) {
            expect(
              _engine.legalTurns(finalState).any((turn) => turn.isCapture),
              isFalse,
              reason: '${exercise.id}: do not end before the enabled recapture',
            );
          }
        }
      }
    }
  });

  test('support lessons include the learner payoff for every setup branch', () {
    for (final id in ['before-5', 'protect-2', 'protect-5', 'check-4']) {
      final exercise = exercises().firstWhere((exercise) => exercise.id == id);
      expect(
        exercise.followUps,
        hasLength(exercise.authoredTurns.length),
        reason: id,
      );
      for (final path in _paths(exercise)) {
        expect(path.payoff?.isCapture, isTrue, reason: id);
      }
    }
  });

  test(
    'Lesson 14 uses real moves and accepts every defense meeting its goal',
    () {
      final lesson = lessons.firstWhere((lesson) => lesson.number == 14);
      for (final exercise in lesson.exercises) {
        final state = _ready(exercise);
        final safe = _engine.legalTurns(state).where((turn) {
          if (exercise.id == 'jump-1' && turn.origin != const Square(3, 2)) {
            return false;
          }
          if (exercise.id == 'jump-2' && turn.origin != const Square(2, 3)) {
            return false;
          }
          final after = _engine.applyTurn(state, turn);
          return !_engine.legalTurns(after).any((reply) => reply.isCapture);
        }).toSet();
        expect(exercise.authoredTurns.toSet(), safe, reason: exercise.id);
        expect(exercise.preparation, isEmpty);
        expect(exercise.threat, isNotNull);
      }
    },
  );

  test(
    'Lesson 15 teaches four steps with a worked example and one card question',
    () {
      final lesson = lessons.firstWhere((lesson) => lesson.number == 15);
      final worked = lesson.exercises.first.preparation;
      expect(worked, hasLength(4));
      for (var index = 0; index < worked.length; index++) {
        expect(worked[index].question.instruction, startsWith('${index + 1}.'));
        expect(
          worked[index].question.interactionType,
          LessonInteractionType.observation,
        );
      }
      final stages = lesson.exercises.expand(
        (exercise) => exercise.preparation,
      );
      expect(
        stages.where(
          (stage) =>
              stage.question.interactionType == LessonInteractionType.choice,
        ),
        hasLength(1),
      );
      expect(
        stages.any(
          (stage) =>
              stage.question.interactionType ==
              LessonInteractionType.squareSelection,
        ),
        isFalse,
      );
      expect(lesson.exercises.last.preparation, isEmpty);
    },
  );

  test(
    'predicted double jumps and the late recapture have the stated costs',
    () {
      for (final id in [
        'jump-1',
        'jump-2',
        'jump-4',
        'jump-5',
        'check-2',
        'check-3',
      ]) {
        final exercise = exercises().firstWhere(
          (exercise) => exercise.id == id,
        );
        final threat = exercise.threat!;
        var state = _ready(exercise);
        if (threat.afterTurn case final turn?) {
          state = _engine.applyTurn(state, turn);
        }
        state = GameState.custom(
          pieces: state.pieces,
          sideToMove: exercise.perspective.opponent,
        );
        final replies = _engine
            .legalTurns(state)
            .where((turn) => turn.isCapture)
            .toList();
        expect(replies, isNotEmpty, reason: id);
        for (final reply in replies) {
          expect(reply.captures, hasLength(2), reason: id);
        }
        expect(threat.routes.toSet(), replies.toSet(), reason: id);
        final reply = replies.first;
        final afterReply = _engine.applyTurn(state, reply);
        expect(
          _count(state, exercise.perspective) -
              _count(afterReply, exercise.perspective),
          2,
        );
        if (id == 'jump-5') {
          final recapture = _engine.legalTurns(afterReply).single;
          expect(recapture.captures, hasLength(1));
          final afterRecapture = _engine.applyTurn(afterReply, recapture);
          expect(
            _count(state, exercise.perspective.opponent) -
                _count(afterRecapture, exercise.perspective.opponent),
            1,
          );
        }
      }
    },
  );

  test(
    'capture-choice checks reject a king-for-man loss and accept a clean gain',
    () {
      for (final id in ['check-1', 'check-5']) {
        final exercise = exercises().firstWhere(
          (exercise) => exercise.id == id,
        );
        final initial = _ready(exercise);
        final rejected = _engine
            .legalTurns(initial)
            .singleWhere((turn) => !exercise.authoredTurns.contains(turn));
        expect(initial.pieces[rejected.captures.single]?.rank, PieceRank.man);
        final after = _engine.applyTurn(initial, rejected);
        final reply = _engine.legalTurns(after).single;
        expect(reply.captures, [rejected.destination]);
        expect(after.pieces[reply.captures.single]?.rank, PieceRank.king);
        final finalState = _engine.applyTurn(after, reply);
        expect(
          _count(initial, exercise.perspective) -
              _count(finalState, exercise.perspective),
          1,
        );
        expect(
          _count(initial, exercise.perspective.opponent) -
              _count(finalState, exercise.perspective.opponent),
          1,
        );
        expect(
          _engine.legalTurns(finalState).any((turn) => turn.isCapture),
          isFalse,
        );
        final accepted = exercise.authoredTurns.single;
        final safeState = _engine.applyTurn(initial, accepted);
        expect(
          _engine.legalTurns(safeState).any((turn) => turn.isCapture),
          isFalse,
        );
        expect(
          initial.pieces[accepted.captures.single]?.rank,
          id == 'check-5' ? PieceRank.king : PieceRank.man,
        );
      }
    },
  );

  test('exploited opponent moves are shown from their pre-move positions', () {
    const shownOpenings = {
      'threat-4',
      'safe-5',
      'exchange-2',
      'exchange-3',
      'exchange-4',
      'exchange-5',
    };
    for (final exercise in exercises().where(
      (exercise) => shownOpenings.contains(exercise.id),
    )) {
      expect(exercise.openingTurns, isNotEmpty, reason: exercise.id);
      var state = _initial(exercise);
      final before = GameState.custom(
        pieces: state.pieces,
        sideToMove: exercise.perspective,
      );
      for (final opening in exercise.openingTurns) {
        expect(
          state.sideToMove,
          exercise.perspective.opponent,
          reason: exercise.id,
        );
        expect(
          state.pieces[opening.origin]?.side,
          exercise.perspective.opponent,
        );
        state = _engine.applyTurn(state, opening);
      }
      expect(state.sideToMove, exercise.perspective);
      expect(
        exercise.authoredTurns.any(
          (turn) => !_engine.legalTurns(before).contains(turn),
        ),
        isTrue,
        reason:
            '${exercise.id}: show the move that changes the capture opportunity',
      );
    }
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'every complete branch reaches its engine result (reduced motion: $reducedMotion)',
      (tester) async {
        for (final exercise in exercises()) {
          for (final path in _paths(exercise)) {
            final controller = _controller(
              exercise,
              reducedMotion: reducedMotion,
            );
            for (final opening in exercise.openingTurns) {
              await _automatic(
                tester,
                controller,
                opening,
                exercise.openingPause,
                reducedMotion,
              );
            }
            expect(controller.sideToMove, exercise.perspective);
            await _prepare(tester, controller, reducedMotion);
            await _play(tester, controller, path.first, reducedMotion);
            if (exercise.opponentReply case final reply?) {
              await _automatic(
                tester,
                controller,
                reply,
                exercise.opponentPause,
                reducedMotion,
              );
            }
            if (path.followUp case final followUp?) {
              expect(controller.exerciseComplete, isFalse, reason: exercise.id);
              expect(controller.playerPhaseNumber, 2);
              expect(controller.instruction, followUp.phase.instruction);
              expect(controller.feedback, followUp.phase.feedback.initial);
              expect(controller.selectedSquare, isNull);
              expect(controller.sideToMove, exercise.perspective);
              controller.continueExercise();
              expect(controller.lessonComplete, isFalse);
              await _play(tester, controller, path.payoff!, reducedMotion);
              if (followUp.phase.opponentReply case final reply?) {
                await _automatic(
                  tester,
                  controller,
                  reply,
                  followUp.phase.opponentPause,
                  reducedMotion,
                );
              }
            }
            expect(controller.exerciseComplete, isTrue, reason: exercise.id);
            expect(
              controller.pieces,
              _result(exercise, path).pieces,
              reason: exercise.id,
            );
            expect(controller.recordedPlayerTurns, path.playerTurns);
            expect(controller.feedback, controller.turnPhase.feedback.success);
            controller.continueExercise();
            expect(controller.lessonComplete, isTrue);
            controller.dispose();
          }
        }
      },
    );
  }

  testWidgets(
    'legal distractors in either learner phase restore that phase for retry',
    (tester) async {
      for (final exercise in exercises()) {
        for (final path in _paths(exercise)) {
          for (final phaseNumber in [1, if (path.followUp != null) 2]) {
            final controller = _controller(exercise, reducedMotion: true);
            for (final _ in exercise.openingTurns) {
              await tester.pump(exercise.openingPause);
            }
            await _prepare(tester, controller, true);
            if (phaseNumber == 2) {
              await _play(tester, controller, path.first, true);
              await tester.pump(exercise.opponentPause);
            }
            final phase = controller.turnPhase;
            if (!phase.acceptLegalSubset) {
              controller.dispose();
              continue;
            }
            final initial = controller.pieces;
            final recorded = controller.recordedPlayerTurns;
            final rejected = controller.legalTurns
                .where((turn) => !phase.authoredTurns.contains(turn))
                .toList();
            expect(rejected, isNotEmpty, reason: exercise.id);
            for (final turn in rejected) {
              await _play(tester, controller, turn, true);
              expect(controller.exerciseComplete, isFalse);
              expect(controller.pieces, initial);
              expect(controller.recordedPlayerTurns, recorded);
              expect(controller.feedback, phase.feedback.goalMiss);
              expect(controller.selectedSquare, isNull);
            }
            controller.dispose();
          }
        }
      }
    },
  );

  test(
    'escape and safety goals accept every safe move of the requested piece',
    () {
      final origins = {
        'threat-1': const Square(3, 2),
        'threat-2': const Square(4, 3),
        'threat-3': const Square(4, 1),
        'before-1': const Square(3, 2),
        'before-3': const Square(5, 4),
        'before-4': const Square(3, 2),
        'safe-1': const Square(5, 2),
        'safe-2': const Square(2, 3),
        'safe-3': const Square(4, 3),
        'safe-4': const Square(5, 0),
      };
      for (final exercise in exercises().where(
        (exercise) => origins.containsKey(exercise.id),
      )) {
        final state = _ready(exercise);
        final safe = _engine
            .legalTurns(state)
            .where((turn) => turn.origin == origins[exercise.id])
            .where((turn) {
              final after = _engine.applyTurn(state, turn);
              return !_engine
                  .legalTurns(after)
                  .any((reply) => reply.captures.contains(turn.destination));
            });
        expect(
          exercise.authoredTurns.toSet(),
          safe.toSet(),
          reason: exercise.id,
        );
      }
    },
  );

  test('complete exchanges match their stated losses and ranks', () {
    final losses = <String, (int, int)>{
      'before-1': (0, 0),
      'before-4': (0, 0),
      'before-5': (1, 0),
      'safe-4': (0, 0),
      'protect-1': (1, 1),
      'protect-2': (1, 1),
      'protect-5': (1, 1),
      'exchange-1': (1, 1),
      'exchange-2': (0, 1),
      'exchange-3': (1, 1),
      'exchange-4': (1, 2),
      'exchange-5': (1, 1),
      'check-3': (0, 0),
      'check-4': (1, 1),
    };
    for (final exercise in exercises().where(
      (exercise) => losses.containsKey(exercise.id),
    )) {
      for (final path in _paths(exercise)) {
        final initial = _initial(exercise);
        final finalState = _result(exercise, path);
        expect(
          (
            _count(initial, Side.black) - _count(finalState, Side.black),
            _count(initial, Side.white) - _count(finalState, Side.white),
          ),
          losses[exercise.id],
          reason: exercise.id,
        );
        if (exercise.id == 'exchange-5') {
          expect(
            _ready(exercise).pieces[path.first.captures.single]?.rank,
            PieceRank.king,
          );
          expect(
            _ready(exercise).pieces[path.first.origin]?.rank,
            PieceRank.man,
          );
        }
      }
    }
  });

  test('blocking goals deny captures and preserve the teammate', () {
    final pairs = {
      'threat-5': const [Square(3, 2), Square(4, 3)],
      'before-2': const [Square(3, 2), Square(4, 3)],
      'protect-3': const [Square(4, 5), Square(3, 4)],
      'protect-4': const [Square(3, 2), Square(4, 3)],
    };
    for (final exercise in exercises().where(
      (exercise) => pairs.containsKey(exercise.id),
    )) {
      final initial = _ready(exercise);
      for (final turn in exercise.authoredTurns) {
        final after = _engine.applyTurn(initial, turn);
        final pair = pairs[exercise.id]!;
        expect(after.pieces[pair.first], initial.pieces[pair.first]);
        expect(after.pieces[pair.last]?.side, exercise.perspective);
        expect(
          _engine.legalTurns(after).any((reply) => reply.isCapture),
          isFalse,
        );
      }
    }
  });
}

Future<void> _prepare(
  WidgetTester tester,
  LessonSessionController controller,
  bool reducedMotion,
) async {
  for (final stage in controller.exercise.preparation) {
    while (!controller.canContinuePreparation && !controller.acceptsInput) {
      await tester.pump(controller.exercise.openingPause);
      if (!reducedMotion && controller.activeJump != null) {
        await tester.pump(LessonSessionController.jumpDuration);
      }
    }
    final question = stage.question;
    if (question.interactionType == LessonInteractionType.choice) {
      controller.selectChoice(question.correctChoiceId!);
    }
    expect(controller.exerciseComplete, isFalse);
    expect(controller.canContinuePreparation, isTrue);
    controller.continueExercise();
  }
}

class _Path {
  _Path(this.first, [this.followUp, this.payoff]);
  final Turn first;
  final LessonTurnFollowUpDefinition? followUp;
  final Turn? payoff;
  List<Turn> get playerTurns => [first, ?payoff];
}

List<_Path> _paths(LessonExerciseDefinition exercise) {
  final ready = _ready(exercise);
  final paths = <_Path>[];
  for (final first
      in exercise.acceptAllLegalTurns
          ? _engine.legalTurns(ready)
          : exercise.authoredTurns) {
    final followUps = exercise.followUps.where(
      (followUp) => followUp.afterTurn == first,
    );
    if (followUps.isEmpty) {
      paths.add(_Path(first));
      continue;
    }
    final followUp = followUps.single;
    var state = _engine.applyTurn(ready, first);
    state = _engine.applyTurn(state, exercise.opponentReply!);
    for (final payoff
        in followUp.phase.acceptAllLegalTurns
            ? _engine.legalTurns(state)
            : followUp.phase.authoredTurns) {
      paths.add(_Path(first, followUp, payoff));
    }
  }
  return paths;
}

GameState _initial(LessonExerciseDefinition exercise) => GameState.custom(
  pieces: exercise.initialPieces,
  sideToMove: exercise.sideToMove,
);
GameState _ready(LessonExerciseDefinition exercise) {
  var state = _initial(exercise);
  for (final opening in exercise.openingTurns) {
    state = _engine.applyTurn(state, opening);
  }
  return state;
}

GameState _result(LessonExerciseDefinition exercise, _Path path) {
  var state = _engine.applyTurn(_ready(exercise), path.first);
  if (exercise.opponentReply case final reply?) {
    state = _engine.applyTurn(state, reply);
  }
  if (path.payoff case final payoff?) state = _engine.applyTurn(state, payoff);
  if (path.followUp?.phase.opponentReply case final reply?) {
    state = _engine.applyTurn(state, reply);
  }
  return state;
}

int _count(GameState state, Side side) =>
    state.pieces.values.where((piece) => piece.side == side).length;
LessonSessionController _controller(
  LessonExerciseDefinition exercise, {
  required bool reducedMotion,
}) => LessonSessionController(
  definition: LessonDefinition(
    id: 'test',
    number: 9,
    name: 'Test',
    exercises: [exercise],
  ),
  reducedMotion: reducedMotion,
);
Future<void> _play(
  WidgetTester tester,
  LessonSessionController controller,
  Turn turn,
  bool reducedMotion,
) async {
  controller.tapSquare(turn.origin);
  for (final landing in turn.landings) {
    controller.tapSquare(landing);
    if (!reducedMotion && turn.isCapture) {
      await tester.pump(LessonSessionController.jumpDuration);
    }
  }
}

Future<void> _automatic(
  WidgetTester tester,
  LessonSessionController controller,
  Turn turn,
  Duration pause,
  bool reducedMotion,
) async {
  expect(controller.acceptsInput, isFalse);
  expect(controller.exerciseComplete, isFalse);
  controller.continueExercise();
  expect(controller.lessonComplete, isFalse);
  await tester.pump(pause);
  if (!reducedMotion) {
    for (final _ in turn.landings) {
      await tester.pump(LessonSessionController.jumpDuration);
    }
  }
}
