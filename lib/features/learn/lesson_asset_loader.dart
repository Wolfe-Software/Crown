import 'dart:convert';

import 'package:flutter/services.dart';

import '../../game_engine/checkers_engine.dart';
import 'learn_curriculum.dart';
import 'lesson_definition.dart';

class LessonAssetLoader {
  LessonAssetLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<LearnCatalog> loadCatalog(String assetPath) async {
    final json = await _loadObject(assetPath);
    _requireSchema(json, assetPath, 1);
    try {
      final units = (json['units']! as List)
          .map(
            (value) =>
                LearnUnit.fromJson((value as Map).cast<String, Object?>()),
          )
          .toList(growable: false);
      final definitions = <String, LessonDefinition>{};
      for (final lesson in units.expand((unit) => unit.lessons)) {
        if (lesson.status == LessonStatus.available &&
            lesson.definitionAsset == null) {
          throw FormatException(
            '${lesson.id}: available lesson requires definitionAsset',
          );
        }
        if (lesson.status == LessonStatus.planned &&
            lesson.definitionAsset != null) {
          throw FormatException(
            '${lesson.id}: planned lesson cannot have definitionAsset',
          );
        }
        if (lesson.definitionAsset != null) {
          definitions[lesson.id] = await loadDefinition(lesson);
        }
      }
      return LearnCatalog(
        List.unmodifiable(units),
        definitions: Map.unmodifiable(definitions),
      );
    } on Object catch (error) {
      throw FormatException('$assetPath: invalid catalog: $error');
    }
  }

  Future<LessonDefinition> loadDefinition(LearnLesson lesson) async {
    final assetPath = lesson.definitionAsset;
    if (assetPath == null) {
      throw FormatException('${lesson.id}: lesson is not available');
    }
    final json = await _loadObject(assetPath);
    _requireSchema(json, assetPath, json['schemaVersion'] == 3 ? 3 : 2);
    try {
      final definition = json['schemaVersion'] == 3
          ? _parseGuidedMatch(json)
          : LessonDefinition(
              id: json['id']! as String,
              number: json['number']! as int,
              name: json['name']! as String,
              exercises: List.unmodifiable(
                (json['exercises']! as List).map(
                  (value) =>
                      _parseExercise((value as Map).cast<String, Object?>()),
                ),
              ),
            );
      if (definition.id != lesson.id ||
          definition.number != lesson.number ||
          definition.name != lesson.name) {
        throw const FormatException(
          'definition metadata does not match catalog',
        );
      }
      if (definition is! GuidedMatchDefinition &&
          definition.exercises.isEmpty) {
        throw const FormatException('available lesson has no exercises');
      }
      for (final exercise in definition.exercises) {
        _validateExercise(exercise);
      }
      return definition;
    } on FormatException catch (error) {
      throw FormatException('$assetPath: ${error.message}');
    } on Object catch (error) {
      throw FormatException('$assetPath: invalid definition: $error');
    }
  }

  Future<Map<String, Object?>> _loadObject(String assetPath) async {
    try {
      final source = await _bundle.loadString(assetPath);
      return (jsonDecode(source) as Map).cast<String, Object?>();
    } on FormatException catch (error) {
      throw FormatException('$assetPath: invalid JSON: ${error.message}');
    } on Object catch (error) {
      throw FormatException('$assetPath: could not load asset: $error');
    }
  }

  void _requireSchema(
    Map<String, Object?> json,
    String assetPath,
    int expected,
  ) {
    if (json['schemaVersion'] != expected) {
      throw FormatException('$assetPath: unsupported schemaVersion');
    }
  }
}

GuidedMatchDefinition _parseGuidedMatch(Map<String, Object?> json) {
  if (json['type'] != 'guidedMatch' ||
      json['startingPosition'] != 'initial' ||
      json['completion'] != 'winAndReview' ||
      json.containsKey('exercises')) {
    throw const FormatException('invalid guided-match configuration');
  }
  final skill = json['aiSkill'];
  if (skill is! int || skill < 0 || skill > 10) {
    throw const FormatException('aiSkill must be between 0 and 10');
  }
  final coaching = (json['coaching']! as Map).cast<String, Object?>();
  final review = (json['review']! as List).map((value) {
    final item = (value as Map).cast<String, Object?>();
    return LessonReviewItem(
      concept: ReviewConcept.values.byName(item['concept']! as String),
      title: _requiredText(item, 'title'),
      body: _requiredText(item, 'body'),
    );
  }).toList();
  if (review.length != ReviewConcept.values.length ||
      review.map((item) => item.concept).toSet().length !=
          ReviewConcept.values.length) {
    throw const FormatException('review must cover every Unit 1 concept once');
  }
  return GuidedMatchDefinition(
    id: _requiredText(json, 'id'),
    number: json['number']! as int,
    name: _requiredText(json, 'name'),
    introduction: _requiredText(json, 'introduction'),
    humanSide: Side.values.byName(json['humanSide']! as String),
    aiSkill: skill,
    coaching: Map.unmodifiable({
      for (final cue in GuidedCoachCue.values)
        cue: _requiredText(coaching, cue.name),
    }),
    review: List.unmodifiable(review),
  );
}

String _requiredText(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be nonempty text');
  }
  return value;
}

LessonExerciseDefinition _parseExercise(Map<String, Object?> json) {
  final board = (json['board']! as Map).cast<String, Object?>();
  final interaction = (json['interaction']! as Map).cast<String, Object?>();
  final feedback = (json['feedback']! as Map).cast<String, Object?>();
  final boardSource = LessonBoardSource.values.byName(
    board['source']! as String,
  );
  final sideToMove = Side.values.byName(
    (board['sideToMove'] as String?) ?? json['perspective']! as String,
  );
  final pieces = _parseBoard(boardSource, board);
  final type = LessonInteractionType.values.byName(
    interaction['type']! as String,
  );
  final opponentReply = interaction['opponentReply'];
  final outcome = json['outcome'];
  return LessonExerciseDefinition(
    id: json['id']! as String,
    title: json['title']! as String,
    instruction: json['instruction']! as String,
    perspective: Side.values.byName(json['perspective']! as String),
    boardSource: boardSource,
    initialPieces: Map.unmodifiable(pieces),
    sideToMove: sideToMove,
    interactionType: type,
    feedback: LessonFeedbackDefinition(
      initial: feedback['initial']! as String,
      progress: (feedback['progress'] as String?) ?? '',
      success: feedback['success']! as String,
      invalidPiece: (feedback['invalidPiece'] as String?) ?? '',
      invalidDestination: (feedback['invalidDestination'] as String?) ?? '',
      selected:
          (feedback['selected'] as String?) ??
          'Selected. Choose a highlighted destination.',
      awaitingReply: feedback['awaitingReply'] as String?,
    ),
    placementPiece: type == LessonInteractionType.placement
        ? Piece.fromJson((interaction['piece']! as Map).cast<String, Object?>())
        : null,
    placementTargets: type == LessonInteractionType.placement
        ? Set.unmodifiable((interaction['targets']! as List).map(_parseSquare))
        : const {},
    acceptAllLegalTurns: interaction['acceptance'] == 'allLegal',
    authoredTurns: List.unmodifiable(
      ((interaction['turns'] as List?) ?? const []).map(
        (value) => Turn.fromJson((value as Map).cast<String, Object?>()),
      ),
    ),
    opponentReply: opponentReply == null
        ? null
        : Turn.fromJson((opponentReply as Map).cast<String, Object?>()),
    opponentPause: Duration(
      milliseconds: (interaction['opponentPauseMs'] as int?) ?? 0,
    ),
    choiceOptions: type == LessonInteractionType.choice
        ? List.unmodifiable(
            (interaction['options']! as List).map((value) {
              final option = (value as Map).cast<String, Object?>();
              return LessonChoiceOptionDefinition(
                id: option['id']! as String,
                label: option['label']! as String,
                feedback: option['feedback']! as String,
                icon: option['icon'] == null
                    ? null
                    : LessonChoiceIcon.values.byName(option['icon']! as String),
              );
            }),
          )
        : const [],
    correctChoiceId: interaction['correctOptionId'] as String?,
    outcome: outcome == null
        ? null
        : GameResult.fromJson((outcome as Map).cast<String, Object?>()),
  );
}

void _validateExercise(LessonExerciseDefinition exercise) {
  for (final square in exercise.initialPieces.keys) {
    if (!square.isPlayable) {
      throw FormatException('${exercise.id}: $square is not playable');
    }
  }
  if (exercise.interactionType == LessonInteractionType.placement) {
    if (exercise.placementTargets.isEmpty || exercise.placementPiece == null) {
      throw FormatException(
        '${exercise.id}: placement requires targets and a piece',
      );
    }
    if (exercise.placementTargets.any(
      (square) =>
          !square.isPlayable || exercise.initialPieces.containsKey(square),
    )) {
      throw FormatException(
        '${exercise.id}: placement target must be an empty playable square',
      );
    }
    return;
  }
  if (exercise.interactionType == LessonInteractionType.choice) {
    final ids = exercise.choiceOptions.map((option) => option.id).toList();
    if (ids.length < 2 ||
        ids.any((id) => id.isEmpty) ||
        ids.toSet().length != ids.length) {
      throw FormatException(
        '${exercise.id}: choice requires at least two unique option ids',
      );
    }
    if (!ids.contains(exercise.correctChoiceId)) {
      throw FormatException(
        '${exercise.id}: correctOptionId must identify an option',
      );
    }
    if (exercise.choiceOptions.any(
      (option) => option.label.isEmpty || option.feedback.isEmpty,
    )) {
      throw FormatException(
        '${exercise.id}: choice options require labels and feedback',
      );
    }
    final visualOptionCount = exercise.choiceOptions
        .where((option) => option.icon != null)
        .length;
    if (visualOptionCount != 0 &&
        visualOptionCount != exercise.choiceOptions.length) {
      throw FormatException(
        '${exercise.id}: choice option icons must be supplied for every option',
      );
    }
    _validateOutcome(exercise);
    return;
  }
  if (exercise.boardSource == LessonBoardSource.previousExerciseResult) return;
  final state = GameState.custom(
    pieces: exercise.initialPieces,
    sideToMove: exercise.sideToMove,
  );
  final legalTurns = const CheckersEngine().legalTurns(state);
  if (exercise.acceptAllLegalTurns) {
    if (legalTurns.isEmpty) {
      throw FormatException(
        '${exercise.id}: position has no engine legal turns',
      );
    }
  } else if (!_sameTurns(legalTurns, exercise.authoredTurns)) {
    throw FormatException(
      '${exercise.id}: authored turns must equal the engine legal turns',
    );
  }
  final reply = exercise.opponentReply;
  if (reply != null) {
    if (exercise.authoredTurns.length != 1) {
      throw FormatException(
        '${exercise.id}: opponent reply requires one player turn',
      );
    }
    final replyState = const CheckersEngine().applyTurn(
      state,
      exercise.authoredTurns.single,
    );
    final replies = const CheckersEngine().legalTurns(replyState);
    if (replies.length != 1 || replies.single != reply) {
      throw FormatException(
        '${exercise.id}: opponent reply must be the only engine legal turn',
      );
    }
  }
  _validateOutcome(exercise, state: state, legalTurns: legalTurns);
}

void _validateOutcome(
  LessonExerciseDefinition exercise, {
  GameState? state,
  List<Turn>? legalTurns,
}) {
  final outcome = exercise.outcome;
  if (outcome == null) return;
  final drawReason =
      outcome.reason == ResultReason.repetition ||
      outcome.reason == ResultReason.quietKings;
  if (drawReason != outcome.isDraw) {
    throw FormatException(
      '${exercise.id}: outcome winner does not match its reason',
    );
  }
  if (exercise.interactionType != LessonInteractionType.turn) return;
  for (final turn in legalTurns!) {
    var resultState = const CheckersEngine().applyTurn(state!, turn);
    final reply = exercise.opponentReply;
    if (reply != null) {
      resultState = const CheckersEngine().applyTurn(resultState, reply);
    }
    if (resultState.result != outcome) {
      throw FormatException(
        '${exercise.id}: outcome does not match the engine result',
      );
    }
  }
}

bool _sameTurns(List<Turn> left, List<Turn> right) =>
    left.length == right.length && left.every(right.contains);

Map<Square, Piece> _parseBoard(
  LessonBoardSource source,
  Map<String, Object?> board,
) {
  switch (source) {
    case LessonBoardSource.initial:
      return Map.of(GameState.initial().pieces);
    case LessonBoardSource.initialWithRemovedPieces:
      return Map.of(GameState.initial().pieces)..removeWhere(
        (square, _) =>
            ((board['removed']! as List).map(_parseSquare)).contains(square),
      );
    case LessonBoardSource.custom:
      return {
        for (final value in board['pieces']! as List)
          _parseSquare((value as Map)['square']): Piece.fromJson(
            value.cast<String, Object?>(),
          ),
      };
    case LessonBoardSource.previousExerciseResult:
      return const {};
  }
}

Square _parseSquare(Object? value) =>
    Square.fromJson((value as Map).cast<String, Object?>());
