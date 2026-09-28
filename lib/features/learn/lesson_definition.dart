import 'package:flutter/foundation.dart';

import '../../game_engine/checkers_engine.dart';

enum LessonBoardSource {
  initial,
  initialWithRemovedPieces,
  custom,
  previousExerciseResult,
}

enum LessonInteractionType { placement, turn, choice }

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
  });

  final String initial;
  final String progress;
  final String success;
  final String invalidPiece;
  final String invalidDestination;
  final String selected;
  final String? awaitingReply;
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
    this.authoredTurns = const [],
    this.opponentReply,
    this.opponentPause = Duration.zero,
    this.choiceOptions = const [],
    this.correctChoiceId,
    this.outcome,
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
  final List<Turn> authoredTurns;
  final Turn? opponentReply;
  final Duration opponentPause;
  final List<LessonChoiceOptionDefinition> choiceOptions;
  final String? correctChoiceId;
  final GameResult? outcome;

  List<String> get feedbackMessages => List.unmodifiable(
    {
      feedback.initial,
      feedback.progress,
      feedback.success,
      feedback.invalidPiece,
      feedback.invalidDestination,
      feedback.selected,
      ?feedback.awaitingReply,
      for (final option in choiceOptions) option.feedback,
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
  board,
  movement,
  captures,
  compulsoryCapture,
  multipleJumps,
  promotion,
  kings,
  winning,
  resignation,
  repetition,
  quietKings,
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
