import 'package:flutter/foundation.dart';

import '../../game_engine/checkers_engine.dart';

enum LessonBoardSource {
  initial,
  initialWithRemovedPieces,
  custom,
  previousExerciseResult,
}

enum LessonInteractionType {
  placement,
  turn,
  choice,
  squareSelection,
  observation,
}

enum LessonChoiceIcon { blackChecker, whiteChecker, draw }

@immutable
class LessonChoiceOptionDefinition {
  const LessonChoiceOptionDefinition({
    required this.id,
    required this.label,
    required this.feedback,
    this.icon,
  });

  final String id;
  final String label;
  final String feedback;
  final LessonChoiceIcon? icon;
}

@immutable
class LessonFeedbackDefinition {
  const LessonFeedbackDefinition({
    required this.initial,
    required this.success,
    this.progress = '',
    this.invalidPiece = '',
    this.invalidDestination = '',
    this.selected = 'Selected. Choose a highlighted destination.',
    this.awaitingReply,
    this.goalMiss = '',
    this.opening,
  });

  final String initial;
  final String progress;
  final String success;
  final String invalidPiece;
  final String invalidDestination;
  final String selected;
  final String? awaitingReply;
  final String goalMiss;
  final String? opening;
}

@immutable
class LessonTurnPhaseDefinition {
  const LessonTurnPhaseDefinition({
    required this.instruction,
    required this.feedback,
    this.acceptAllLegalTurns = false,
    this.acceptLegalSubset = false,
    this.authoredTurns = const [],
    this.opponentReply,
    this.opponentPause = Duration.zero,
  });

  final String instruction;
  final LessonFeedbackDefinition feedback;
  final bool acceptAllLegalTurns;
  final bool acceptLegalSubset;
  final List<Turn> authoredTurns;
  final Turn? opponentReply;
  final Duration opponentPause;
}

@immutable
class LessonTurnFollowUpDefinition {
  const LessonTurnFollowUpDefinition({
    required this.afterTurn,
    required this.phase,
  });

  final Turn afterTurn;
  final LessonTurnPhaseDefinition phase;
}

@immutable
class LessonPreparationStage {
  const LessonPreparationStage({
    required this.question,
    this.previewTurns = const [],
    this.threat,
  });

  final LessonExerciseDefinition question;

  /// Applied to a copy of the starting position, never to the live game.
  final List<Turn> previewTurns;
  final LessonThreatDefinition? threat;
}

@immutable
class LessonThreatDefinition {
  const LessonThreatDefinition({
    required this.label,
    required this.routes,
    this.afterTurn,
  });
  final String label;
  final List<Turn> routes;

  /// A conditional threat: what becomes possible if this learner move is made.
  final Turn? afterTurn;
}

@immutable
class LessonExerciseDefinition {
  const LessonExerciseDefinition({
    required this.id,
    required this.title,
    required this.instruction,
    required this.perspective,
    required this.boardSource,
    required this.initialPieces,
    required this.sideToMove,
    required this.interactionType,
    required this.feedback,
    this.placementPiece,
    this.placementTargets = const {},
    this.acceptAllLegalTurns = false,
    this.acceptLegalSubset = false,
    this.authoredTurns = const [],
    this.openingTurns = const [],
    this.openingPause = const Duration(milliseconds: 550),
    this.opponentReply,
    this.opponentPause = Duration.zero,
    this.followUps = const [],
    this.choiceOptions = const [],
    this.correctChoiceId,
    this.squareTargets = const [],
    this.outcome,
    this.preparation = const [],
    this.threat,
  });

  final String id;
  final String title;
  final String instruction;
  final Side perspective;
  final LessonBoardSource boardSource;
  final Map<Square, Piece> initialPieces;
  final Side sideToMove;
  final LessonInteractionType interactionType;
  final LessonFeedbackDefinition feedback;
  final Piece? placementPiece;
  final Set<Square> placementTargets;
  final bool acceptAllLegalTurns;
  final bool acceptLegalSubset;
  final List<Turn> authoredTurns;
  final List<Turn> openingTurns;
  final Duration openingPause;
  final Turn? opponentReply;
  final Duration opponentPause;
  final List<LessonTurnFollowUpDefinition> followUps;
  final List<LessonChoiceOptionDefinition> choiceOptions;
  final String? correctChoiceId;
  final List<Square> squareTargets;
  final GameResult? outcome;
  final List<LessonPreparationStage> preparation;
  final LessonThreatDefinition? threat;

  LessonTurnPhaseDefinition get turnPhase => LessonTurnPhaseDefinition(
    instruction: instruction,
    feedback: feedback,
    acceptAllLegalTurns: acceptAllLegalTurns,
    acceptLegalSubset: acceptLegalSubset,
    authoredTurns: authoredTurns,
    opponentReply: opponentReply,
    opponentPause: opponentPause,
  );

  List<String> get feedbackMessages => List.unmodifiable(
    {
      feedback.initial,
      feedback.progress,
      feedback.success,
      feedback.invalidPiece,
      feedback.invalidDestination,
      feedback.selected,
      ?feedback.awaitingReply,
      feedback.goalMiss,
      ?feedback.opening,
      for (final followUp in followUps) ...[
        followUp.phase.feedback.initial,
        followUp.phase.feedback.selected,
        followUp.phase.feedback.success,
        followUp.phase.feedback.invalidPiece,
        followUp.phase.feedback.invalidDestination,
        followUp.phase.feedback.goalMiss,
        ?followUp.phase.feedback.awaitingReply,
      ],
      for (final option in choiceOptions) option.feedback,
      for (final stage in preparation) ...stage.question.feedbackMessages,
    }.where((message) => message.isNotEmpty),
  );
}

@immutable
class LessonDefinition {
  const LessonDefinition({
    required this.id,
    required this.number,
    required this.name,
    required this.exercises,
  });

  final String id;
  final int number;
  final String name;
  final List<LessonExerciseDefinition> exercises;
}

enum ReviewConcept {
  board(1),
  movement(1),
  captures(1),
  compulsoryCapture(1),
  multipleJumps(1),
  promotion(1),
  kings(1),
  winning(1),
  resignation(1),
  repetition(1),
  quietKings(1),
  threatAnatomy(2),
  openedLanes(2),
  safeDestinations(2),
  protection(2),
  exchanges(2),
  hiddenJumps(2),
  safetyCheck(2);

  const ReviewConcept(this.unit);
  final int unit;
}

enum GuidedCoachCue {
  opening,
  selected,
  invalidPiece,
  invalidDestination,
  compulsoryCapture,
  continueJump,
  captures,
  multipleJumps,
  promotion,
  kings,
  awaitingReply,
  yourTurn,
  aiError,
}

@immutable
class LessonReviewItem {
  const LessonReviewItem({
    required this.concept,
    required this.title,
    required this.body,
  });

  final ReviewConcept concept;
  final String title;
  final String body;
}

/// Schema-v3 full-game lessons; exercise lessons retain their schema-v2 runner.
@immutable
class GuidedMatchDefinition extends LessonDefinition {
  const GuidedMatchDefinition({
    required super.id,
    required super.number,
    required super.name,
    required this.introduction,
    required this.humanSide,
    required this.aiSkill,
    required this.coaching,
    required this.review,
  }) : super(exercises: const []);

  final String introduction;
  final Side humanSide;
  final int aiSkill;
  final Map<GuidedCoachCue, String> coaching;
  final List<LessonReviewItem> review;
}
