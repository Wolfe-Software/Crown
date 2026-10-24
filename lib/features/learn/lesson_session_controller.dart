import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../game_engine/checkers_engine.dart';
import '../match/jump_animation.dart';
import 'lesson_definition.dart';

class LessonSessionController extends ChangeNotifier {
  LessonSessionController({
    required this.definition,
    this.reducedMotion = false,
  }) {
    _configureExercise();
  }

  static const jumpDuration = Duration(milliseconds: 420);
  static const _engine = CheckersEngine();

  final LessonDefinition definition;
  final bool reducedMotion;
  final List<Turn> _recordedPlayerTurns = [];
  final ChangeNotifier _landingEvents = ChangeNotifier();

  Listenable get landings => _landingEvents;

  int _exerciseIndex = 0;
  late GameState _state;
  late Map<Square, Piece> _pieces;
  Square? _turnOrigin;
  final List<Square> _landingPrefix = [];
  final List<Square> _selectedAnswerSquares = [];
  JumpAnimation? _activeJump;
  Turn? _lastTurn;
  late String _feedback;
  bool _exerciseComplete = false;
  bool _lessonComplete = false;
  bool _awaitingOpponent = false;
  bool _awaitingOpening = false;
  bool _disposed = false;
  Timer? _timer;
  LessonTurnPhaseDefinition? _followUpPhase;
  LessonTurnPhaseDefinition? _pendingFollowUp;
  int _preparationIndex = 0;
  bool _preparationComplete = false;
  bool _demonstrating = false;
  GameState? _previewState;
  Map<Square, Piece>? _previewPieces;

  LessonPreparationStage? get preparationStage =>
      !_awaitingOpening && _preparationIndex < exercise.preparation.length
      ? exercise.preparation[_preparationIndex]
      : null;
  LessonExerciseDefinition get _question =>
      preparationStage?.question ?? exercise;
  LessonInteractionType get interactionType => _question.interactionType;
  bool get canContinuePreparation =>
      !_demonstrating &&
      preparationStage != null &&
      (_preparationComplete ||
          interactionType == LessonInteractionType.observation);
  LessonThreatDefinition? get visibleThreat =>
      _awaitingOpening ||
          _awaitingOpponent ||
          _exerciseComplete ||
          _activeJump != null ||
          _demonstrating ||
          _landingPrefix.isNotEmpty ||
          _followUpPhase != null
      ? null
      : preparationStage != null
      ? preparationStage!.threat
      : exercise.threat;
  String? get previewLabel => preparationStage?.previewTurns.isNotEmpty == true
      ? 'WORKED EXAMPLE — NOT YOUR MOVE'
      : visibleThreat?.label;
  Map<Square, Piece> get displayedPieces {
    return _previewPieces == null ? pieces : Map.unmodifiable(_previewPieces!);
  }

  LessonExerciseDefinition get exercise => definition.exercises[_exerciseIndex];
  String get exerciseId => exercise.id;
  int get exerciseNumber => _exerciseIndex + 1;
  int get exerciseCount => definition.exercises.length;
  String get title => exercise.title;
  String get instruction =>
      preparationStage?.question.instruction ?? turnPhase.instruction;
  LessonTurnPhaseDefinition get turnPhase =>
      _followUpPhase ?? exercise.turnPhase;
  int get playerPhaseNumber => _followUpPhase == null ? 1 : 2;
  List<Turn> get acceptedTurns =>
      turnPhase.acceptAllLegalTurns ? legalTurns : turnPhase.authoredTurns;
  Side get perspectiveSide => exercise.perspective;
  Side get sideToMove => _state.sideToMove;
  Map<Square, Piece> get pieces => Map.unmodifiable(_pieces);
  Square? get selectedSquare => _selectedAnswerSquares.isNotEmpty
      ? _selectedAnswerSquares.last
      : _landingPrefix.isEmpty
      ? _turnOrigin
      : _landingPrefix.last;
  List<Square> get selectedAnswerSquares =>
      List.unmodifiable(_selectedAnswerSquares);
  JumpAnimation? get activeJump => _activeJump;
  Turn? get lastTurn => _lastTurn;
  String get feedback => _feedback;
  bool get exerciseComplete => _exerciseComplete;
  bool get lessonComplete => _lessonComplete;
  bool get acceptsInput => _acceptsInput;
  bool get isFinalExercise => _exerciseIndex == exerciseCount - 1;
  Duration get opponentPause => turnPhase.opponentPause;
  Set<Square> get placementTargets => exercise.placementTargets;
  List<LessonChoiceOptionDefinition> get choiceOptions =>
      _question.choiceOptions;
  GameResult? get visibleOutcome => _exerciseComplete ? exercise.outcome : null;
  List<Turn> get recordedPlayerTurns => List.unmodifiable(_recordedPlayerTurns);

  List<Turn> get legalTurns {
    if (interactionType != LessonInteractionType.turn || _awaitingOpening) {
      return const [];
    }
    return _engine.legalTurns(_state);
  }

  List<Turn> get _selectedTurns {
    if (_turnOrigin == null) return const [];
    return legalTurns.where((turn) {
      if (turn.origin != _turnOrigin ||
          turn.landings.length < _landingPrefix.length) {
        return false;
      }
      for (var index = 0; index < _landingPrefix.length; index++) {
        if (turn.landings[index] != _landingPrefix[index]) return false;
      }
      return true;
    }).toList();
  }

  Set<Square> get destinations {
    if (!_acceptsInput || _turnOrigin == null) return const {};
    final index = _landingPrefix.length;
    return _selectedTurns
        .where((turn) => turn.landings.length > index)
        .map((turn) => turn.landings[index])
        .toSet();
  }

  bool get _acceptsInput =>
      !_disposed &&
      !_exerciseComplete &&
      !_lessonComplete &&
      !_awaitingOpening &&
      !_awaitingOpponent &&
      !_preparationComplete &&
      !_demonstrating &&
      interactionType != LessonInteractionType.observation &&
      _activeJump == null;

  void tapSquare(Square square) {
    if (!_acceptsInput) return;
    if (interactionType == LessonInteractionType.placement) {
      _placePiece(square);
    } else if (interactionType == LessonInteractionType.turn) {
      _tapTurnSquare(square);
    } else if (interactionType == LessonInteractionType.squareSelection) {
      _selectSquare(square);
    }
  }

  void _selectSquare(Square square) {
    final index = _selectedAnswerSquares.length;
    if (_question.squareTargets[index] != square) {
      _selectedAnswerSquares.clear();
      _feedback = _question.feedback.invalidDestination;
      notifyListeners();
      return;
    }
    _selectedAnswerSquares.add(square);
    final complete =
        _selectedAnswerSquares.length == _question.squareTargets.length;
    _exerciseComplete = complete;
    _feedback = complete
        ? _question.feedback.success
        : _question.feedback.progress;
    notifyListeners();
  }

  void selectChoice(String optionId) {
    if (!_acceptsInput || interactionType != LessonInteractionType.choice) {
      return;
    }
    final option = _question.choiceOptions.where(
      (candidate) => candidate.id == optionId,
    );
    if (option.isEmpty) return;
    if (optionId == _question.correctChoiceId) {
      if (preparationStage != null) {
        _preparationComplete = true;
      } else {
        _exerciseComplete = true;
      }
      _feedback = _question.feedback.success;
    } else {
      _feedback = option.single.feedback;
    }
    notifyListeners();
  }

  void _placePiece(Square square) {
    if (_pieces.containsKey(square)) {
      _feedback = exercise.feedback.invalidPiece;
      notifyListeners();
      return;
    }
    if (!exercise.placementTargets.contains(square)) {
      _feedback = exercise.feedback.invalidDestination;
      notifyListeners();
      return;
    }
    _pieces[square] = exercise.placementPiece!;
    _landed();
    final remaining = exercise.placementTargets
        .where((target) => !_pieces.containsKey(target))
        .length;
    _exerciseComplete = remaining == 0;
    _feedback = _exerciseComplete
        ? exercise.feedback.success
        : exercise.feedback.progress
              .replaceAll('{remaining}', '$remaining')
              .replaceAll('{pieceWord}', remaining == 1 ? 'piece' : 'pieces');
    notifyListeners();
  }

  void _tapTurnSquare(Square square) {
    if (_turnOrigin == null) {
      final turnsFromSquare = legalTurns.where((turn) => turn.origin == square);
      if (turnsFromSquare.isEmpty) {
        _feedback = _pieces[square]?.side == sideToMove
            ? turnPhase.feedback.invalidPiece
            : turnPhase.feedback.invalidDestination;
        notifyListeners();
        return;
      }
      _turnOrigin = square;
      _landingPrefix.clear();
      _feedback = turnPhase.feedback.selected;
      notifyListeners();
      return;
    }

    if (destinations.contains(square)) {
      _acceptPlayerLanding(square);
      return;
    }

    if (_landingPrefix.isEmpty &&
        legalTurns.any((turn) => turn.origin == square)) {
      _turnOrigin = square;
      _feedback = turnPhase.feedback.selected;
    } else if (_pieces[square]?.side == sideToMove) {
      if (_landingPrefix.isEmpty) _turnOrigin = null;
      _feedback = turnPhase.feedback.invalidPiece;
    } else {
      _feedback = turnPhase.feedback.invalidDestination;
    }
    notifyListeners();
  }

  void _acceptPlayerLanding(Square landing) {
    final index = _landingPrefix.length;
    if (turnPhase.acceptLegalSubset &&
        !turnPhase.authoredTurns.any(
          (turn) =>
              turn.origin == _turnOrigin &&
              turn.landings.length > index &&
              listEquals(turn.landings.take(index).toList(), _landingPrefix) &&
              turn.landings[index] == landing,
        )) {
      // A legal attempt can miss the teaching goal. Restore even a partially
      // played multi-jump so the learner can retry from the same position.
      _pieces = Map.of(_state.pieces);
      _turnOrigin = null;
      _landingPrefix.clear();
      _feedback = turnPhase.feedback.goalMiss;
      notifyListeners();
      return;
    }
    final turn = _selectedTurns.firstWhere(
      (candidate) =>
          candidate.landings.length > index &&
          candidate.landings[index] == landing,
    );
    final from = selectedSquare!;
    final movingPiece = _pieces.remove(from)!;
    if (!turn.isCapture || reducedMotion) {
      _finishPlayerLanding(turn, landing, movingPiece);
      return;
    }

    _activeJump = JumpAnimation(
      piece: movingPiece,
      from: from,
      to: landing,
      captured: turn.captures[index],
      duration: jumpDuration,
    );
    notifyListeners();
    _schedule(
      jumpDuration,
      () => _finishPlayerLanding(turn, landing, movingPiece),
    );
  }

  void _finishPlayerLanding(Turn turn, Square landing, Piece movingPiece) {
    if (_disposed) return;
    final index = _landingPrefix.length;
    if (turn.isCapture) _pieces.remove(turn.captures[index]);
    _pieces[landing] = movingPiece;
    _landingPrefix.add(landing);
    _activeJump = null;
    _landed();

    final matches = _selectedTurns;
    final complete = matches.where(
      (candidate) => candidate.landings.length == _landingPrefix.length,
    );
    if (complete.isNotEmpty &&
        !matches.any(
          (candidate) => candidate.landings.length > _landingPrefix.length,
        )) {
      _finishPlayerTurn(complete.first);
      return;
    }

    _feedback = turnPhase.feedback.selected;
    notifyListeners();
  }

  void _finishPlayerTurn(Turn turn) {
    if (_disposed) return;
    _recordedPlayerTurns.add(turn);
    _turnOrigin = null;
    _landingPrefix.clear();
    _selectedAnswerSquares.clear();
    _applyTurn(turn);
    if (_followUpPhase == null) {
      for (final followUp in exercise.followUps) {
        if (followUp.afterTurn == turn) _pendingFollowUp = followUp.phase;
      }
    }
    if (turnPhase.opponentReply != null) {
      _awaitingOpponent = true;
      _feedback = turnPhase.feedback.awaitingReply!;
      notifyListeners();
      _schedule(opponentPause, _startOpponentReply);
      return;
    }
    _exerciseComplete = true;
    _feedback = turnPhase.feedback.success;
    notifyListeners();
  }

  void _startOpponentReply() {
    final reply = turnPhase.opponentReply!;
    _startTurnAnimation(reply, onFinished: () => _finishOpponentReply(reply));
  }

  void _finishOpponentReply(Turn turn) {
    if (_disposed) return;
    _applyTurn(turn);
    _awaitingOpponent = false;
    if (_pendingFollowUp != null) {
      _followUpPhase = _pendingFollowUp;
      _pendingFollowUp = null;
      _feedback = turnPhase.feedback.initial;
    } else {
      _exerciseComplete = true;
      _feedback = turnPhase.feedback.success;
    }
    notifyListeners();
  }

  void _startTurnAnimation(Turn turn, {required VoidCallback onFinished}) {
    if (reducedMotion) {
      onFinished();
      _landed(turn.landings.length);
      return;
    }
    final movingPiece = _state.pieces[turn.origin]!;
    _pieces = Map.of(_state.pieces)..remove(turn.origin);
    _animateJumpSegment(turn, 0, movingPiece, onFinished);
  }

  void _animateJumpSegment(
    Turn turn,
    int index,
    Piece movingPiece,
    VoidCallback onFinished,
  ) {
    final from = index == 0 ? turn.origin : turn.landings[index - 1];
    _activeJump = JumpAnimation(
      piece: movingPiece,
      from: from,
      to: turn.landings[index],
      captured: turn.isCapture ? turn.captures[index] : null,
      duration: jumpDuration,
    );
    notifyListeners();
    _schedule(jumpDuration, () {
      if (turn.isCapture) _pieces.remove(turn.captures[index]);
      _activeJump = null;
      _landed();
      final next = index + 1;
      if (next < turn.landings.length) {
        _animateJumpSegment(turn, next, movingPiece, onFinished);
      } else {
        onFinished();
      }
    });
  }

  void _applyTurn(Turn turn) {
    _state = _engine.applyTurn(_state, turn);
    _pieces = Map.of(_state.pieces);
    _activeJump = null;
    _lastTurn = turn;
  }

  void continueExercise() {
    if (canContinuePreparation) {
      final previous = preparationStage!.previewTurns;
      _preparationIndex++;
      _preparationComplete = false;
      _selectedAnswerSquares.clear();
      _feedback = _question.feedback.initial;
      _configurePreparation(previous);
      notifyListeners();
      return;
    }
    if (!_exerciseComplete || _lessonComplete) return;
    if (isFinalExercise) {
      _lessonComplete = true;
      notifyListeners();
      return;
    }
    _exerciseIndex++;
    _configureExercise();
    notifyListeners();
  }

  void _configureExercise() {
    _timer?.cancel();
    final next = exercise;
    if (next.boardSource != LessonBoardSource.previousExerciseResult) {
      _state = GameState.custom(
        pieces: next.initialPieces,
        sideToMove: next.sideToMove,
      );
    }
    _pieces = Map.of(_state.pieces);
    _turnOrigin = null;
    _landingPrefix.clear();
    _selectedAnswerSquares.clear();
    _activeJump = null;
    _lastTurn = null;
    _exerciseComplete = false;
    _awaitingOpponent = false;
    _followUpPhase = null;
    _pendingFollowUp = null;
    _preparationIndex = 0;
    _preparationComplete = false;
    _demonstrating = false;
    _previewState = null;
    _previewPieces = null;
    _awaitingOpening = next.openingTurns.isNotEmpty;
    _feedback = _question.feedback.initial;
    if (_awaitingOpening) {
      _feedback = next.feedback.opening!;
      _schedule(next.openingPause, () => _startOpeningTurn(0));
    } else {
      _configurePreparation(const []);
    }
  }

  void _startOpeningTurn(int index) {
    final turn = exercise.openingTurns[index];
    _startTurnAnimation(
      turn,
      onFinished: () {
        if (_disposed) return;
        _applyTurn(turn);
        final next = index + 1;
        if (next < exercise.openingTurns.length) {
          _schedule(exercise.openingPause, () => _startOpeningTurn(next));
        } else {
          _awaitingOpening = false;
          _feedback = _question.feedback.initial;
          _configurePreparation(const []);
        }
        notifyListeners();
      },
    );
  }

  void _configurePreparation(List<Turn> previous) {
    final turns = preparationStage?.previewTurns;
    _previewState = null;
    _previewPieces = null;
    if (turns == null || turns.isEmpty) return;
    var common = 0;
    _previewState = _state;
    while (common < previous.length &&
        common < turns.length &&
        previous[common] == turns[common]) {
      _previewState = _engine.applyTurn(_previewState!, turns[common]);
      common++;
    }
    _previewPieces = Map.of(_previewState!.pieces);
    _demonstrating = common < turns.length;
    if (_demonstrating) {
      _schedule(exercise.openingPause, () => _startPreviewTurn(common));
    }
  }

  void _startPreviewTurn(int index) {
    final turn = preparationStage!.previewTurns[index];
    final piece = _previewState!.pieces[turn.origin]!;
    if (reducedMotion) {
      _finishPreviewTurn(index);
    } else {
      _previewPieces!.remove(turn.origin);
      _animatePreviewSegment(turn, 0, piece, () => _finishPreviewTurn(index));
    }
  }

  void _animatePreviewSegment(
    Turn turn,
    int index,
    Piece piece,
    VoidCallback onFinished,
  ) {
    _activeJump = JumpAnimation(
      piece: piece,
      from: index == 0 ? turn.origin : turn.landings[index - 1],
      to: turn.landings[index],
      captured: turn.isCapture ? turn.captures[index] : null,
      duration: jumpDuration,
    );
    notifyListeners();
    _schedule(jumpDuration, () {
      if (turn.isCapture) _previewPieces!.remove(turn.captures[index]);
      _activeJump = null;
      if (index + 1 < turn.landings.length) {
        _animatePreviewSegment(turn, index + 1, piece, onFinished);
      } else {
        onFinished();
      }
    });
  }

  void _finishPreviewTurn(int index) {
    final turns = preparationStage!.previewTurns;
    _previewState = _engine.applyTurn(_previewState!, turns[index]);
    _previewPieces = Map.of(_previewState!.pieces);
    if (index + 1 < turns.length) {
      _schedule(exercise.openingPause, () => _startPreviewTurn(index + 1));
    } else {
      _demonstrating = false;
    }
    notifyListeners();
  }

  void _schedule(Duration duration, VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (!_disposed) callback();
    });
  }

  void _landed([int count = 1]) {
    if (_disposed) return;
    for (var index = 0; index < count; index++) {
      _landingEvents.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _landingEvents.dispose();
    super.dispose();
  }
}
