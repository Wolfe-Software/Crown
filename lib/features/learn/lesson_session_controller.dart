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

  int _exerciseIndex = 0;
  late GameState _state;
  late Map<Square, Piece> _pieces;
  Square? _turnOrigin;
  final List<Square> _landingPrefix = [];
  JumpAnimation? _activeJump;
  Turn? _lastTurn;
  late String _feedback;
  bool _exerciseComplete = false;
  bool _lessonComplete = false;
  bool _awaitingOpponent = false;
  bool _disposed = false;
  Timer? _timer;

  LessonExerciseDefinition get exercise => definition.exercises[_exerciseIndex];
  String get exerciseId => exercise.id;
  int get exerciseNumber => _exerciseIndex + 1;
  int get exerciseCount => definition.exercises.length;
  String get title => exercise.title;
  String get instruction => exercise.instruction;
  Side get perspectiveSide => exercise.perspective;
  Side get sideToMove => _state.sideToMove;
  Map<Square, Piece> get pieces => Map.unmodifiable(_pieces);
  Square? get selectedSquare =>
      _landingPrefix.isEmpty ? _turnOrigin : _landingPrefix.last;
  JumpAnimation? get activeJump => _activeJump;
  Turn? get lastTurn => _lastTurn;
  String get feedback => _feedback;
  bool get exerciseComplete => _exerciseComplete;
  bool get lessonComplete => _lessonComplete;
  bool get isFinalExercise => _exerciseIndex == exerciseCount - 1;
  Duration get opponentPause => exercise.opponentPause;
  Set<Square> get placementTargets => exercise.placementTargets;
  List<LessonChoiceOptionDefinition> get choiceOptions =>
      exercise.choiceOptions;
  GameResult? get visibleOutcome => _exerciseComplete ? exercise.outcome : null;
  List<Turn> get recordedPlayerTurns => List.unmodifiable(_recordedPlayerTurns);

  List<Turn> get legalTurns {
    if (exercise.interactionType != LessonInteractionType.turn) return const [];
    return exercise.acceptAllLegalTurns
        ? _engine.legalTurns(_state)
        : exercise.authoredTurns;
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
      !_exerciseComplete &&
      !_lessonComplete &&
      !_awaitingOpponent &&
      _activeJump == null;

  void tapSquare(Square square) {
    if (!_acceptsInput) return;
    if (exercise.interactionType == LessonInteractionType.placement) {
      _placePiece(square);
    } else if (exercise.interactionType == LessonInteractionType.turn) {
      _tapTurnSquare(square);
    }
  }

  void selectChoice(String optionId) {
    if (!_acceptsInput ||
        exercise.interactionType != LessonInteractionType.choice) {
      return;
    }
    final option = exercise.choiceOptions.where(
      (candidate) => candidate.id == optionId,
    );
    if (option.isEmpty) return;
    if (optionId == exercise.correctChoiceId) {
      _exerciseComplete = true;
      _feedback = exercise.feedback.success;
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
        _feedback = _pieces[square]?.side == perspectiveSide
            ? exercise.feedback.invalidPiece
            : exercise.feedback.invalidDestination;
        notifyListeners();
        return;
      }
      _turnOrigin = square;
      _landingPrefix.clear();
      _feedback = exercise.feedback.selected;
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
      _feedback = exercise.feedback.selected;
    } else if (_pieces[square]?.side == perspectiveSide) {
      if (_landingPrefix.isEmpty) _turnOrigin = null;
      _feedback = exercise.feedback.invalidPiece;
    } else {
      _feedback = exercise.feedback.invalidDestination;
    }
    notifyListeners();
  }

  void _acceptPlayerLanding(Square landing) {
    final index = _landingPrefix.length;
    final turn = _selectedTurns.firstWhere(
      (candidate) => candidate.landings[index] == landing,
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

    _feedback = exercise.feedback.selected;
    notifyListeners();
  }

  void _finishPlayerTurn(Turn turn) {
    if (_disposed) return;
    _recordedPlayerTurns.add(turn);
    _turnOrigin = null;
    _landingPrefix.clear();
    _applyTurn(turn);
    if (exercise.opponentReply != null) {
      _awaitingOpponent = true;
      _feedback = exercise.feedback.awaitingReply!;
      notifyListeners();
      _schedule(exercise.opponentPause, _startOpponentReply);
      return;
    }
    _exerciseComplete = true;
    _feedback = exercise.feedback.success;
    notifyListeners();
  }

  void _startOpponentReply() {
    final reply = exercise.opponentReply!;
    _startTurnAnimation(reply, onFinished: () => _finishOpponentReply(reply));
  }

  void _finishOpponentReply(Turn turn) {
    if (_disposed) return;
    _applyTurn(turn);
    _awaitingOpponent = false;
    _exerciseComplete = true;
    _feedback = exercise.feedback.success;
    notifyListeners();
  }

  void _startTurnAnimation(Turn turn, {required VoidCallback onFinished}) {
    if (!turn.isCapture || reducedMotion) {
      onFinished();
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
      captured: turn.captures[index],
      duration: jumpDuration,
    );
    notifyListeners();
    _schedule(jumpDuration, () {
      _pieces.remove(turn.captures[index]);
      _activeJump = null;
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
    _activeJump = null;
    _lastTurn = null;
    _exerciseComplete = false;
    _awaitingOpponent = false;
    _feedback = next.feedback.initial;
  }

  void _schedule(Duration duration, VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (!_disposed) callback();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
