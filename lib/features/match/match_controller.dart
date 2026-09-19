import 'package:flutter/foundation.dart';

import '../../game_engine/checkers_engine.dart';
import '../../game_engine/crown_ai.dart';
import '../../persistence/crown_repository.dart';
import 'jump_animation.dart';

typedef AiMoveChooser = Future<Turn> Function(
  GameState state,
  AiProfile profile,
);
typedef AiDelay = Future<void> Function(Duration duration);
typedef JumpDelay = Future<void> Function(Duration duration);

class MatchController extends ChangeNotifier {
  MatchController({
    required this.session,
    required this.repository,
    AiMoveChooser? aiMoveChooser,
    this.minimumAiTurnDuration = const Duration(milliseconds: 800),
    AiDelay? aiDelay,
    this.animateJumps = false,
    this.jumpDuration = const Duration(milliseconds: 260),
    JumpDelay? jumpDelay,
  }) : _aiMoveChooser =
           aiMoveChooser ??
           ((state, profile) => const CrownAi().chooseTurn(state, profile)),
       _aiDelay = aiDelay ?? Future<void>.delayed,
       _jumpDelay = jumpDelay ?? Future<void>.delayed;

  final CrownRepository repository;
  final CheckersEngine _engine = const CheckersEngine();
  final AiMoveChooser _aiMoveChooser;
  final AiDelay _aiDelay;
  final Duration minimumAiTurnDuration;
  final Duration jumpDuration;
  final JumpDelay _jumpDelay;
  bool animateJumps;
  MatchSession session;
  Square? _origin;
  final List<Square> _prefix = [];
  bool _isAiThinking = false;
  bool _isAnimatingJump = false;
  Map<Square, Piece>? _animationBoard;
  JumpAnimation? _activeJump;
  final ChangeNotifier _landingEvents = ChangeNotifier();
  bool _disposed = false;

  /// One event per accepted landing, after its animation (if any).
  Listenable get landings => _landingEvents;

  void _landed() {
    if (!_disposed) _landingEvents.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _landingEvents.dispose();
    super.dispose();
  }

  GameState get state => session.state;
  Square? get selectedSquare => _prefix.isEmpty ? _origin : _prefix.last;
  bool get isAiThinking => _isAiThinking;
  bool get isAnimatingJump => _isAnimatingJump;
  JumpAnimation? get activeJump => _activeJump;
  bool get isHumanTurn =>
      session.mode == MatchMode.local || session.humanSide == state.sideToMove;

  List<Turn> get _selectedTurns {
    if (_origin == null) return const [];
    return _engine.legalTurns(state).where((turn) {
      if (turn.origin != _origin || turn.landings.length < _prefix.length) {
        return false;
      }
      for (var index = 0; index < _prefix.length; index++) {
        if (turn.landings[index] != _prefix[index]) return false;
      }
      return true;
    }).toList();
  }

  Set<Square> get legalDestinations {
    final index = _prefix.length;
    return _selectedTurns
        .where((turn) => turn.landings.length > index)
        .map((turn) => turn.landings[index])
        .toSet();
  }

  List<Turn> get _mandatoryTurns {
    if (!isHumanTurn || _isAiThinking || state.result != null) return const [];
    final turns = _origin == null ? _engine.legalTurns(state) : _selectedTurns;
    return turns.where((turn) => turn.isCapture).toList();
  }

  Set<Square> get mandatoryOrigins {
    final turns = _mandatoryTurns;
    if (turns.isEmpty) return const {};
    if (_origin != null) return {selectedSquare!};
    return turns.map((turn) => turn.origin).toSet();
  }

  Set<Square> get mandatoryDestinations {
    final index = _prefix.length;
    return _mandatoryTurns
        .where((turn) => turn.landings.length > index)
        .map((turn) => turn.landings[index])
        .toSet();
  }

  bool get hasSingleRequiredAction {
    final destinations = mandatoryDestinations;
    if (mandatoryOrigins.isEmpty || destinations.isEmpty) return false;
    if (_origin != null) return destinations.length == 1;
    final actions = <(Square, Square)>{};
    for (final turn in _mandatoryTurns) {
      actions.add((turn.origin, turn.landings.first));
    }
    return actions.length == 1;
  }

  Map<Square, Piece> get previewPieces {
    final board = Map<Square, Piece>.of(state.pieces);
    if (_origin == null || _prefix.isEmpty) return board;
    final matching = _selectedTurns.first;
    final piece = board.remove(_origin)!;
    for (var index = 0; index < _prefix.length; index++) {
      if (matching.isCapture) board.remove(matching.captures[index]);
    }
    board[_prefix.last] = piece;
    return board;
  }

  Map<Square, Piece> get displayPieces => _animationBoard ?? previewPieces;

  Future<void> tapSquare(Square square) async {
    if (state.result != null ||
        _isAiThinking ||
        _isAnimatingJump ||
        !isHumanTurn) {
      return;
    }
    final legal = _engine.legalTurns(state);
    if (_origin == null) {
      final destinationTurns = legal
          .where((turn) => turn.isCapture && turn.landings.first == square)
          .toList();
      final possibleOrigins = destinationTurns
          .map((turn) => turn.origin)
          .toSet();
      if (possibleOrigins.length == 1) {
        _origin = possibleOrigins.single;
        _prefix.clear();
      } else if (possibleOrigins.length > 1) {
        return;
      } else if (legal.any((turn) => turn.origin == square)) {
        _origin = square;
        _prefix.clear();
        notifyListeners();
        return;
      } else {
        return;
      }
    }

    if (legalDestinations.contains(square)) {
      final animated = animateJumps && _selectedTurns.first.isCapture;
      if (animated) {
        final index = _prefix.length;
        final matching = _selectedTurns.firstWhere(
          (turn) => turn.landings[index] == square,
        );
        await _animateJump(
          from: selectedSquare!,
          to: square,
          captured: matching.captures[index],
        );
      }
      _prefix.add(square);
      if (!animated) _landed();
      final matches = _selectedTurns;
      final complete = matches.where(
        (turn) => turn.landings.length == _prefix.length,
      );
      if (complete.isNotEmpty &&
          !matches.any((turn) => turn.landings.length > _prefix.length)) {
        await _commit(complete.first);
      } else {
        notifyListeners();
      }
      return;
    }

    if (_prefix.isEmpty && legal.any((turn) => turn.origin == square)) {
      _origin = square;
      notifyListeners();
    } else if (_prefix.isEmpty && square == _origin) {
      _origin = null;
      notifyListeners();
    }
  }

  Future<void> start() async {
    await repository.saveActiveMatch(session);
    await playAiIfNeeded();
  }

  Future<void> playAiIfNeeded() async {
    if (session.mode != MatchMode.ai ||
        state.result != null ||
        state.sideToMove == session.humanSide ||
        _isAiThinking) {
      return;
    }
    _isAiThinking = true;
    notifyListeners();
    try {
      final minimumWait = _aiDelay(minimumAiTurnDuration);
      final profile = await repository.loadAiProfile();
      final turn = await _aiMoveChooser(state, profile);
      await minimumWait;
      if (state.result != null) return;
      if (animateJumps && turn.isCapture) await _animateTurn(turn);
      await _commit(
        turn,
        triggerAi: false,
        landingCount: animateJumps && turn.isCapture ? 0 : turn.landings.length,
      );
    } finally {
      _isAiThinking = false;
      notifyListeners();
    }
  }

  Future<void> resign(Side side) async {
    if (state.result != null || _isAnimatingJump) return;
    session = session.copyWith(state: _engine.resign(state, side));
    _clearSelection();
    await _finish();
    notifyListeners();
  }

  Future<void> _commit(
    Turn turn, {
    bool triggerAi = true,
    int landingCount = 0,
  }) async {
    session = session.copyWith(state: _engine.applyTurn(state, turn));
    _animationBoard = null;
    _activeJump = null;
    _clearSelection();
    for (var index = 0; index < landingCount; index++) {
      _landed();
    }
    if (state.result == null) {
      await repository.saveActiveMatch(session);
    } else {
      await _finish();
    }
    notifyListeners();
    if (triggerAi) await playAiIfNeeded();
  }

  Future<void> _finish() async {
    await repository.clearActiveMatch();
    await repository.addHistory(MatchRecord.fromSession(session));
    if (session.mode == MatchMode.ai && session.humanSide != null) {
      final profile = await repository.loadAiProfile();
      final result = state.result!;
      final humanResult = result.isDraw
          ? HumanResult.draw
          : result.winner == session.humanSide
          ? HumanResult.win
          : HumanResult.loss;
      await repository.saveAiProfile(profile.afterHumanResult(humanResult));
    }
  }

  void _clearSelection() {
    _origin = null;
    _prefix.clear();
  }

  Future<void> _animateTurn(Turn turn) async {
    _animationBoard = Map<Square, Piece>.of(state.pieces);
    var from = turn.origin;
    for (var index = 0; index < turn.landings.length; index++) {
      await _animateJump(
        from: from,
        to: turn.landings[index],
        captured: turn.captures[index],
      );
      from = turn.landings[index];
    }
  }

  Future<void> _animateJump({
    required Square from,
    required Square to,
    required Square captured,
  }) async {
    _animationBoard ??= Map<Square, Piece>.of(previewPieces);
    final piece = _animationBoard!.remove(from)!;
    _activeJump = JumpAnimation(
      piece: piece,
      from: from,
      to: to,
      captured: captured,
      duration: jumpDuration,
    );
    _isAnimatingJump = true;
    notifyListeners();
    await _jumpDelay(jumpDuration);
    _animationBoard!
      ..remove(captured)
      ..[to] = piece;
    _activeJump = null;
    _isAnimatingJump = false;
    _landed();
    notifyListeners();
  }
}
