import 'package:flutter/foundation.dart';

import '../../game_engine/checkers_engine.dart';
import '../../game_engine/crown_ai.dart';
import '../../persistence/crown_repository.dart';
import '../match/match_controller.dart';
import 'lesson_definition.dart';

enum GuidedMatchPhase { introduction, match, result, review, complete }

/// Owns a disposable, isolated match and the win-then-review completion gate.
class GuidedMatchController extends ChangeNotifier {
  GuidedMatchController({
    required this.definition,
    this.reducedMotion = false,
    this.aiMoveChooser,
    this.aiDelay,
    this.minimumAiTurnDuration = const Duration(milliseconds: 800),
    this.onAttemptCompleted,
    GameState? initialState,
  }) {
    _createMatch(initialState);
  }

  final GuidedMatchDefinition definition;
  final bool reducedMotion;
  final AiMoveChooser? aiMoveChooser;
  final AiDelay? aiDelay;
  final Duration minimumAiTurnDuration;
  final MatchCompleted? onAttemptCompleted;
  late MatchController _match;
  MatchController get match => _match;
  final ChangeNotifier _landingEvents = ChangeNotifier();

  /// One event for every accepted landing across all retry attempts.
  Listenable get landings => _landingEvents;
  GuidedMatchPhase _phase = GuidedMatchPhase.introduction;
  GuidedMatchPhase get phase => _phase;
  final Set<ReviewConcept> _encountered = {};
  Set<ReviewConcept> get encountered => Set.unmodifiable(_encountered);
  bool get lessonComplete => phase == GuidedMatchPhase.complete;
  bool get won => match.state.result?.winner == definition.humanSide;
  bool _disposed = false;
  int _observedTurns = 0;
  GuidedCoachCue? _eventCue;

  void _createMatch(GameState? state) {
    _match =
        MatchController(
            session: MatchSession.newGame(
              mode: MatchMode.ai,
              humanSide: definition.humanSide,
              bottomSide: definition.humanSide,
              blackName: definition.humanSide == Side.black
                  ? 'You'
                  : 'Crown AI',
              whiteName: definition.humanSide == Side.white
                  ? 'You'
                  : 'Crown AI',
              initialState: state,
            ),
            repository: MemoryCrownRepository(),
            policy: MatchSessionPolicy.lesson,
            lessonAiProfile: AiProfile(skill: definition.aiSkill),
            aiMoveChooser: aiMoveChooser,
            aiDelay: aiDelay,
            minimumAiTurnDuration: minimumAiTurnDuration,
            onCompleted: onAttemptCompleted,
            animateJumps: !reducedMotion,
          )
          ..addListener(_onMatchChanged)
          ..landings.addListener(_landed);
  }

  void _landed() {
    if (!_disposed) _landingEvents.notifyListeners();
  }

  String get feedback {
    final cue = match.aiError != null
        ? GuidedCoachCue.aiError
        : match.hasCaptureInProgress
        ? GuidedCoachCue.continueJump
        : match.mandatoryOrigins.isNotEmpty
        ? GuidedCoachCue.compulsoryCapture
        : match.inputFeedback != null
        ? switch (match.inputFeedback!) {
            MatchInputFeedback.selected => GuidedCoachCue.selected,
            MatchInputFeedback.invalidPiece => GuidedCoachCue.invalidPiece,
            MatchInputFeedback.invalidDestination =>
              GuidedCoachCue.invalidDestination,
            MatchInputFeedback.compulsoryCapture =>
              GuidedCoachCue.compulsoryCapture,
            MatchInputFeedback.continueJump => GuidedCoachCue.continueJump,
          }
        : _eventCue ??
              (match.isAiThinking
                  ? GuidedCoachCue.awaitingReply
                  : match.state.turns.isEmpty
                  ? GuidedCoachCue.opening
                  : GuidedCoachCue.yourTurn);
    return definition.coaching[cue]!;
  }

  Future<void> begin() async {
    if (_disposed || phase != GuidedMatchPhase.introduction) return;
    _phase = GuidedMatchPhase.match;
    _encountered.add(ReviewConcept.board);
    _onMatchChanged();
    await match.start();
  }

  Future<void> tapSquare(Square square) async {
    if (_disposed || phase != GuidedMatchPhase.match) return;
    if (!match.isHumanTurn || match.isAiThinking || match.isAnimatingJump) {
      return;
    }
    _eventCue = null;
    await match.tapSquare(square);
  }

  Future<void> resign() async {
    if (_disposed || phase != GuidedMatchPhase.match) return;
    await match.resign(definition.humanSide);
  }

  Future<void> retryAi() async {
    if (_disposed || phase != GuidedMatchPhase.match) return;
    await match.playAiIfNeeded();
  }

  void _onMatchChanged() {
    if (_disposed) return;
    final state = match.state;
    if (state.turns.length > _observedTurns) {
      _observedTurns = state.turns.length;
      final turn = state.turns.last;
      final piece = match.lastTurnStart!.pieces[turn.origin]!;
      if (turn.isCapture) {
        _encountered.add(ReviewConcept.compulsoryCapture);
        _record(ReviewConcept.captures, GuidedCoachCue.captures);
      } else if (piece.rank == PieceRank.man) {
        _encountered.add(ReviewConcept.movement);
      }
      if (turn.captures.length > 1) {
        _record(ReviewConcept.multipleJumps, GuidedCoachCue.multipleJumps);
      }
      if (piece.rank == PieceRank.king) {
        _record(ReviewConcept.kings, GuidedCoachCue.kings);
      } else if (state.pieces[turn.destination]?.rank == PieceRank.king) {
        _record(ReviewConcept.promotion, GuidedCoachCue.promotion);
      }
    }
    if (match.mandatoryOrigins.isNotEmpty) {
      _encountered.add(ReviewConcept.compulsoryCapture);
    }
    final result = state.result;
    if (result != null && phase == GuidedMatchPhase.match) {
      _encountered.add(switch (result.reason) {
        ResultReason.noPieces ||
        ResultReason.noLegalMove => ReviewConcept.winning,
        ResultReason.resignation => ReviewConcept.resignation,
        ResultReason.repetition => ReviewConcept.repetition,
        ResultReason.quietKings => ReviewConcept.quietKings,
      });
      _phase = GuidedMatchPhase.result;
    }
    notifyListeners();
  }

  void _record(ReviewConcept concept, GuidedCoachCue cue) {
    if (_encountered.add(concept)) _eventCue = cue;
  }

  void openReview() {
    if (_disposed || phase != GuidedMatchPhase.result || !won) return;
    _phase = GuidedMatchPhase.review;
    notifyListeners();
  }

  void complete() {
    if (_disposed || phase != GuidedMatchPhase.review || !won) {
      return;
    }
    _phase = GuidedMatchPhase.complete;
    notifyListeners();
  }

  void retry() {
    if (_disposed || lessonComplete) return;
    _match.removeListener(_onMatchChanged);
    _match.landings.removeListener(_landed);
    _match.dispose();
    _encountered.clear();
    _observedTurns = 0;
    _eventCue = null;
    _phase = GuidedMatchPhase.introduction;
    _createMatch(null);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _match.removeListener(_onMatchChanged);
    _match.landings.removeListener(_landed);
    _match.dispose();
    _landingEvents.dispose();
    super.dispose();
  }
}
