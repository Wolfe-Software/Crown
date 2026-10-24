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
      if (definition is! GuidedMatchDefinition &&
          definition.number >= 9 &&
          definition.number <= 15 &&
          definition.exercises.length != 5) {
        throw const FormatException(
          'Unit 2 standard lessons require exactly five exercises',
        );
      }
      for (final exercise in definition.exercises) {
        _validateExercise(
          exercise,
          shortPaths: definition.number >= 9 && definition.number <= 15,
        );
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
  final unit = ((json['number']! as int) - 1) ~/ 8 + 1;
  final requiredConcepts = ReviewConcept.values
      .where((concept) => concept.unit == unit)
      .toSet();
  if (review.length != requiredConcepts.length ||
      review.map((item) => item.concept).toSet().length !=
          requiredConcepts.length ||
      !review
          .map((item) => item.concept)
          .toSet()
          .containsAll(requiredConcepts)) {
    throw FormatException('review must cover every Unit $unit concept once');
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
  if (type == LessonInteractionType.turn &&
      !const [
        'exactLegalSet',
        'allLegal',
        'legalSubset',
      ].contains(interaction['acceptance'])) {
    throw const FormatException('turn requires a supported acceptance mode');
  }
  if (type != LessonInteractionType.turn &&
      (interaction.containsKey('openingTurns') ||
          interaction.containsKey('followUps'))) {
    throw const FormatException(
      'opening turns and follow-ups require a turn interaction',
    );
  }
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
      goalMiss: (feedback['goalMiss'] as String?) ?? '',
      opening: feedback['opening'] as String?,
    ),
    placementPiece: type == LessonInteractionType.placement
        ? Piece.fromJson((interaction['piece']! as Map).cast<String, Object?>())
        : null,
    placementTargets: type == LessonInteractionType.placement
        ? Set.unmodifiable((interaction['targets']! as List).map(_parseSquare))
        : const {},
    acceptAllLegalTurns: interaction['acceptance'] == 'allLegal',
    acceptLegalSubset: interaction['acceptance'] == 'legalSubset',
    openingTurns: List.unmodifiable(
      ((interaction['openingTurns'] as List?) ?? const []).map(
        (value) => Turn.fromJson((value as Map).cast<String, Object?>()),
      ),
    ),
    openingPause: Duration(
      milliseconds: (interaction['openingPauseMs'] as int?) ?? 550,
    ),
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
    followUps: List.unmodifiable(
      ((interaction['followUps'] as List?) ?? const []).map((value) {
        final followUp = (value as Map).cast<String, Object?>();
        if (followUp.containsKey('followUps') ||
            followUp.containsKey('openingTurns')) {
          throw const FormatException(
            'follow-ups allow only one additional learner phase',
          );
        }
        if (!const [
          'exactLegalSet',
          'legalSubset',
          'allLegal',
        ].contains(followUp['acceptance'])) {
          throw const FormatException(
            'follow-up requires a supported acceptance mode',
          );
        }
        final reply = followUp['opponentReply'];
        return LessonTurnFollowUpDefinition(
          afterTurn: Turn.fromJson(
            (followUp['afterTurn']! as Map).cast<String, Object?>(),
          ),
          phase: LessonTurnPhaseDefinition(
            instruction: _requiredText(followUp, 'instruction'),
            acceptAllLegalTurns: followUp['acceptance'] == 'allLegal',
            acceptLegalSubset: followUp['acceptance'] == 'legalSubset',
            authoredTurns: List.unmodifiable(
              ((followUp['turns'] as List?) ?? const []).map(
                (value) =>
                    Turn.fromJson((value as Map).cast<String, Object?>()),
              ),
            ),
            opponentReply: reply == null
                ? null
                : Turn.fromJson((reply as Map).cast<String, Object?>()),
            opponentPause: Duration(
              milliseconds: (followUp['opponentPauseMs'] as int?) ?? 0,
            ),
            feedback: _parsePhaseFeedback(
              (followUp['feedback']! as Map).cast<String, Object?>(),
            ),
          ),
        );
      }),
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
    threat: _parseThreat(json['threat']),
    preparation: List.unmodifiable(
      ((json['preparation'] as List?) ?? const []).asMap().entries.map((entry) {
        final stage = (entry.value as Map).cast<String, Object?>();
        if (stage.containsKey('preparation')) {
          throw const FormatException('preparation stages cannot be nested');
        }
        return LessonPreparationStage(
          question: _parseExercise({
            ...stage,
            'id': '${json['id']}-preparation-${entry.key}',
            'title': json['title'],
            'threat': null,
            'perspective': json['perspective'],
            'board': json['board'],
          }),
          previewTurns: List.unmodifiable(
            ((stage['previewTurns'] as List?) ?? const []).map(
              (value) => Turn.fromJson((value as Map).cast<String, Object?>()),
            ),
          ),
          threat: _parseThreat(stage['threat']),
        );
      }),
    ),
    squareTargets: type == LessonInteractionType.squareSelection
        ? List.unmodifiable((interaction['targets']! as List).map(_parseSquare))
        : const [],
    outcome: outcome == null
        ? null
        : GameResult.fromJson((outcome as Map).cast<String, Object?>()),
  );
}

LessonThreatDefinition? _parseThreat(Object? value) {
  if (value == null) return null;
  final json = (value as Map).cast<String, Object?>();
  return LessonThreatDefinition(
    label: _requiredText(json, 'label'),
    routes: List.unmodifiable(
      (json['routes']! as List).map(
        (value) => Turn.fromJson((value as Map).cast<String, Object?>()),
      ),
    ),
    afterTurn: json['afterTurn'] == null
        ? null
        : Turn.fromJson((json['afterTurn'] as Map).cast<String, Object?>()),
  );
}

void _validateThreat(
  String id,
  LessonThreatDefinition? threat,
  GameState state,
  Side learner,
) {
  if (threat == null) return;
  const engine = CheckersEngine();
  if (threat.routes.isEmpty) {
    throw FormatException('$id: threat requires capture routes');
  }
  if (threat.afterTurn case final candidate?) {
    if (state.sideToMove != learner ||
        !engine.legalTurns(state).contains(candidate)) {
      throw FormatException(
        '$id: conditional threat requires an engine legal learner move',
      );
    }
    state = engine.applyTurn(state, candidate);
  }
  final opponent = GameState.custom(
    pieces: state.pieces,
    sideToMove: learner.opponent,
  );
  for (final route in threat.routes) {
    if (!route.isCapture || !engine.legalTurns(opponent).contains(route)) {
      throw FormatException(
        '$id: threat route must be a complete engine legal opponent capture',
      );
    }
  }
}

LessonFeedbackDefinition _parsePhaseFeedback(Map<String, Object?> feedback) =>
    LessonFeedbackDefinition(
      initial: _requiredText(feedback, 'initial'),
      success: _requiredText(feedback, 'success'),
      selected:
          (feedback['selected'] as String?) ??
          'Selected. Choose a highlighted destination.',
      invalidPiece: (feedback['invalidPiece'] as String?) ?? '',
      invalidDestination: (feedback['invalidDestination'] as String?) ?? '',
      goalMiss: (feedback['goalMiss'] as String?) ?? '',
      awaitingReply: feedback['awaitingReply'] as String?,
    );

void _validateExercise(
  LessonExerciseDefinition exercise, {
  bool shortPaths = false,
}) {
  if ((exercise.preparation.isNotEmpty || exercise.threat != null) &&
      (exercise.interactionType != LessonInteractionType.turn ||
          exercise.boardSource == LessonBoardSource.previousExerciseResult)) {
    throw FormatException(
      '${exercise.id}: guidance requires a move exercise with an explicit board',
    );
  }
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
  if (exercise.interactionType == LessonInteractionType.squareSelection) {
    if (exercise.squareTargets.isEmpty || exercise.squareTargets.length > 3) {
      throw FormatException(
        '${exercise.id}: square selection requires one to three targets',
      );
    }
    if (exercise.squareTargets.any((square) => !square.isPlayable)) {
      throw FormatException('${exercise.id}: square target must be playable');
    }
    return;
  }
  if (exercise.interactionType == LessonInteractionType.observation) return;
  if (exercise.openingPause.isNegative || exercise.opponentPause.isNegative) {
    throw FormatException('${exercise.id}: pauses must not be negative');
  }
  if (exercise.acceptLegalSubset && exercise.feedback.goalMiss.trim().isEmpty) {
    throw FormatException(
      '${exercise.id}: legal subset requires goalMiss feedback',
    );
  }
  if (exercise.openingTurns.isNotEmpty &&
      (exercise.feedback.opening?.trim().isEmpty ?? true)) {
    throw FormatException(
      '${exercise.id}: opening turns require opening feedback',
    );
  }
  if (exercise.opponentReply != null &&
      (exercise.feedback.awaitingReply?.trim().isEmpty ?? true)) {
    throw FormatException(
      '${exercise.id}: opponent reply requires awaitingReply feedback',
    );
  }
  if (exercise.boardSource == LessonBoardSource.previousExerciseResult) {
    if (exercise.openingTurns.isNotEmpty ||
        exercise.acceptLegalSubset ||
        exercise.followUps.isNotEmpty) {
      throw FormatException(
        '${exercise.id}: move goals and openings require an explicit board',
      );
    }
    return;
  }
  var state = GameState.custom(
    pieces: exercise.initialPieces,
    sideToMove: exercise.sideToMove,
  );
  const engine = CheckersEngine();
  for (final turn in exercise.openingTurns) {
    if (shortPaths && state.sideToMove == exercise.perspective) {
      throw FormatException(
        '${exercise.id}: opening turns must belong to the opponent',
      );
    }
    if (!engine.legalTurns(state).contains(turn)) {
      throw FormatException(
        '${exercise.id}: opening turn must be engine legal',
      );
    }
    state = engine.applyTurn(state, turn);
  }
  if ((shortPaths || exercise.followUps.isNotEmpty) &&
      state.sideToMove != exercise.perspective) {
    throw FormatException(
      '${exercise.id}: learner phases must use the perspective side',
    );
  }
  final accepted = _validateTurnPhase(
    exercise.id,
    exercise.turnPhase,
    state,
    shortPaths: shortPaths,
  );
  _validateThreat(exercise.id, exercise.threat, state, exercise.perspective);
  for (final stage in exercise.preparation) {
    if (!const [
      LessonInteractionType.choice,
      LessonInteractionType.observation,
    ].contains(stage.question.interactionType)) {
      throw FormatException(
        '${exercise.id}: preparation requires a choice or passive observation',
      );
    }
    _validateExercise(stage.question);
    var preview = state;
    for (final turn in stage.previewTurns) {
      if (!engine.legalTurns(preview).contains(turn)) {
        throw FormatException(
          '${exercise.id}: preview turn must be engine legal',
        );
      }
      preview = engine.applyTurn(preview, turn);
    }
    _validateThreat(exercise.id, stage.threat, preview, exercise.perspective);
  }
  if (exercise.followUps.isNotEmpty) {
    final keys = exercise.followUps
        .map((followUp) => followUp.afterTurn)
        .toSet();
    if (exercise.opponentReply == null ||
        keys.length != exercise.followUps.length ||
        keys.length != accepted.length ||
        !accepted.every(keys.contains)) {
      throw FormatException(
        '${exercise.id}: follow-ups require a reply and exactly one branch per accepted turn',
      );
    }
  }
  final finalStates = <GameState>[];
  for (final turn in accepted) {
    var after = engine.applyTurn(state, turn);
    if (exercise.opponentReply case final reply?) {
      after = engine.applyTurn(after, reply);
    }
    if (exercise.followUps.isEmpty) {
      finalStates.add(after);
      continue;
    }
    if (after.sideToMove != exercise.perspective) {
      throw FormatException(
        '${exercise.id}: follow-up must return control to the learner',
      );
    }
    final phase = exercise.followUps
        .firstWhere((followUp) => followUp.afterTurn == turn)
        .phase;
    for (final payoff in _validateTurnPhase(
      exercise.id,
      phase,
      after,
      shortPaths: shortPaths,
    )) {
      var finalState = engine.applyTurn(after, payoff);
      if (phase.opponentReply case final reply?) {
        finalState = engine.applyTurn(finalState, reply);
      }
      finalStates.add(finalState);
    }
  }
  if (shortPaths &&
      finalStates.any(
        (state) =>
            state.sideToMove == exercise.perspective &&
            engine.legalTurns(state).any((turn) => turn.isCapture),
      )) {
    throw FormatException(
      '${exercise.id}: exercise must include the enabled learner capture',
    );
  }
  _validateOutcome(exercise, finalStates: finalStates);
}

List<Turn> _validateTurnPhase(
  String id,
  LessonTurnPhaseDefinition phase,
  GameState state, {
  required bool shortPaths,
}) {
  const engine = CheckersEngine();
  if (phase.opponentPause.isNegative) {
    throw FormatException('$id: pauses must not be negative');
  }
  if (phase.acceptLegalSubset && phase.feedback.goalMiss.trim().isEmpty) {
    throw FormatException('$id: legal subset requires goalMiss feedback');
  }
  if (phase.opponentReply != null &&
      (phase.feedback.awaitingReply?.trim().isEmpty ?? true)) {
    throw FormatException(
      '$id: opponent reply requires awaitingReply feedback',
    );
  }
  final legalTurns = engine.legalTurns(state);
  if (legalTurns.isEmpty) {
    throw FormatException('$id: learner phase has no engine legal turns');
  }
  if (phase.acceptLegalSubset) {
    if (phase.authoredTurns.isEmpty ||
        phase.authoredTurns.toSet().length != phase.authoredTurns.length ||
        !phase.authoredTurns.every(legalTurns.contains)) {
      throw FormatException(
        '$id: goal turns must be a nonempty subset of engine legal turns',
      );
    }
  } else if (!phase.acceptAllLegalTurns &&
      !_sameTurns(legalTurns, phase.authoredTurns)) {
    throw FormatException(
      '$id: authored turns must equal the engine legal turns',
    );
  }
  final accepted = phase.acceptAllLegalTurns ? legalTurns : phase.authoredTurns;
  if (shortPaths && accepted.any((turn) => turn.landings.length > 2)) {
    throw FormatException(
      '$id: each learner phase allows at most three board taps',
    );
  }
  final reply = phase.opponentReply;
  if (reply != null) {
    for (final turn in accepted) {
      final replyState = engine.applyTurn(state, turn);
      if (!engine.legalTurns(replyState).contains(reply)) {
        throw FormatException(
          '$id: opponent reply must be engine legal after every accepted turn',
        );
      }
    }
  }
  return accepted;
}

void _validateOutcome(
  LessonExerciseDefinition exercise, {
  List<GameState>? finalStates,
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
  for (final resultState in finalStates!) {
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
