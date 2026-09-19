import 'package:flutter/foundation.dart';

import '../../game_engine/checkers_engine.dart';

enum LessonOneExercise { placeBlack, placeWhite, moveBlack, moveWhite }

final _blackMissing = {
  const Square(0, 1),
  const Square(1, 2),
  const Square(2, 3),
};
final _whiteMissing = {
  const Square(5, 0),
  const Square(6, 1),
  const Square(7, 2),
};

class LessonOneController extends ChangeNotifier {
  static const _engine = CheckersEngine();

  LessonOneExercise _exercise = LessonOneExercise.placeBlack;
  Map<Square, Piece> _pieces = _startingPiecesWithout(_blackMissing);
  GameState? _movementState;
  Square? _selectedSquare;
  String _feedback = 'Find and replace the three missing black pieces.';
  int _placementCount = 0;
  int _exerciseMoveCount = 0;
  bool _exerciseComplete = false;
  bool _lessonComplete = false;

  LessonOneExercise get exercise => _exercise;
  Map<Square, Piece> get pieces => Map.unmodifiable(_pieces);
  Square? get selectedSquare => _selectedSquare;
  String get feedback => _feedback;
  int get placementCount => _placementCount;
  int get exerciseMoveCount => _exerciseMoveCount;
  bool get exerciseComplete => _exerciseComplete;
  bool get lessonComplete => _lessonComplete;
  bool get showsBoard => true;
  bool get isFinalExercise => _exercise == LessonOneExercise.moveWhite;
  Side get perspectiveSide => switch (_exercise) {
    LessonOneExercise.placeBlack || LessonOneExercise.moveBlack => Side.black,
    LessonOneExercise.placeWhite || LessonOneExercise.moveWhite => Side.white,
  };
  int get exerciseNumber => _exercise.index + 1;
  int get exerciseCount => LessonOneExercise.values.length;

  String get title => switch (_exercise) {
    LessonOneExercise.placeBlack => 'Set up the black pieces',
    LessonOneExercise.placeWhite => 'Set up the white pieces',
    LessonOneExercise.moveBlack => 'Make Black\'s first move',
    LessonOneExercise.moveWhite => 'Reply as White',
  };

  String get instruction => switch (_exercise) {
    LessonOneExercise.placeBlack => 'Black begins on the three rows nearest you. Tap the three gaps in Black\'s starting position.',
    LessonOneExercise.placeWhite => 'White begins on the three rows nearest you. Tap the three gaps in White\'s starting position.',
    LessonOneExercise.moveBlack => 'Black moves first. Select a black checker, then move it diagonally forward to an empty dark square.',
    LessonOneExercise.moveWhite => 'Turns alternate. Select a white checker and make one legal forward diagonal move.',
  };

  Set<Square> get destinations {
    if (_exerciseComplete || _selectedSquare == null) return const {};
    return _legalTurns
        .where((turn) => turn.origin == _selectedSquare)
        .map((turn) => turn.destination)
        .toSet();
  }

  List<Turn> get _legalTurns =>
      _movementState == null ? const [] : _engine.legalTurns(_movementState!);

  void tapSquare(Square square) {
    if (_exerciseComplete || _lessonComplete) return;
    switch (_exercise) {
      case LessonOneExercise.placeBlack:
        _placePiece(square, Side.black, _blackMissing);
      case LessonOneExercise.placeWhite:
        _placePiece(square, Side.white, _whiteMissing);
      case LessonOneExercise.moveBlack:
      case LessonOneExercise.moveWhite:
        _tapMovementSquare(square);
    }
  }

  void _placePiece(Square square, Side side, Set<Square> missing) {
    if (!missing.contains(square) || _pieces.containsKey(square)) {
      _feedback = _pieces.containsKey(square)
          ? 'That square already has a piece. Find an empty gap.'
          : 'That is not a gap in ${side == Side.black ? 'Black\'s' : 'White\'s'} starting rows.';
      notifyListeners();
      return;
    }
    _pieces[square] = side == Side.black
        ? const Piece.blackMan()
        : const Piece.whiteMan();
    _placementCount++;
    final remaining = 3 - _placementCount;
    _exerciseComplete = remaining == 0;
    _feedback = _exerciseComplete
        ? '${side == Side.black ? 'Black' : 'White'} now has all 12 starting pieces.'
        : 'Correct. Place $remaining more ${side.name} ${remaining == 1 ? 'piece' : 'pieces'}.';
    notifyListeners();
  }

  void _tapMovementSquare(Square square) {
    final state = _movementState!;
    final expectedSide = state.sideToMove;
    final turnsFromSquare = _legalTurns
        .where((turn) => turn.origin == square)
        .toList();
    if (turnsFromSquare.isNotEmpty) {
      _selectedSquare = square;
      _feedback = 'Selected. Choose a highlighted destination.';
      notifyListeners();
      return;
    }

    if (_selectedSquare != null) {
      final matchingTurns = _legalTurns.where(
        (turn) => turn.origin == _selectedSquare && turn.destination == square,
      );
      if (matchingTurns.isNotEmpty) {
        _movementState = _engine.applyTurn(state, matchingTurns.first);
        _pieces = Map.of(_movementState!.pieces);
        _selectedSquare = null;
        _exerciseMoveCount = 1;
        _exerciseComplete = true;
        _feedback =
            'Legal move. ${expectedSide == Side.black ? 'Black' : 'White'} moves forward toward the far side of the board.';
        notifyListeners();
        return;
      }
    }

    _feedback =
        'Select a ${expectedSide.name} piece that has a legal forward diagonal move.';
    notifyListeners();
  }

  void continueExercise() {
    if (!_exerciseComplete || _lessonComplete) return;
    if (isFinalExercise) {
      _lessonComplete = true;
      notifyListeners();
      return;
    }
    _exercise = LessonOneExercise.values[_exercise.index + 1];
    _configureExercise();
    notifyListeners();
  }

  void _configureExercise() {
    _selectedSquare = null;
    _placementCount = 0;
    _exerciseMoveCount = 0;
    _exerciseComplete = false;
    switch (_exercise) {
      case LessonOneExercise.placeBlack:
        _pieces = _startingPiecesWithout(_blackMissing);
        _movementState = null;
        _feedback = 'Find and replace the three missing black pieces.';
      case LessonOneExercise.placeWhite:
        _pieces = _startingPiecesWithout(_whiteMissing);
        _movementState = null;
        _feedback = 'Find and replace the three missing white pieces.';
      case LessonOneExercise.moveBlack:
        _movementState = GameState.initial();
        _pieces = Map.of(_movementState!.pieces);
        _feedback = 'Select a black piece that can move.';
      case LessonOneExercise.moveWhite:
        _pieces = Map.of(_movementState!.pieces);
        _feedback = 'Now select a white piece that can move.';
    }
  }
}

Map<Square, Piece> _startingPiecesWithout(Set<Square> missing) =>
    Map<Square, Piece>.of(GameState.initial().pieces)
      ..removeWhere((square, _) => missing.contains(square));
