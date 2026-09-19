import 'dart:collection';

const checkersRulesetId = 'checkers-wcdf-gayp-v1.0.0';

enum Side {
  black,
  white;

  Side get opponent => this == black ? white : black;
}

enum PieceRank { man, king }

enum ResultReason { noPieces, noLegalMove, repetition, quietKings, resignation }

class Square {
  const Square(this.row, this.column);

  final int row;
  final int column;

  bool get isOnBoard => row >= 0 && row < 8 && column >= 0 && column < 8;
  bool get isPlayable => isOnBoard && (row + column).isOdd;
  String get notation => '${String.fromCharCode(97 + column)}${8 - row}';

  Map<String, Object> toJson() => {'row': row, 'column': column};
  factory Square.fromJson(Map<String, Object?> json) =>
      Square(json['row']! as int, json['column']! as int);

  @override
  bool operator ==(Object other) =>
      other is Square && row == other.row && column == other.column;

  @override
  int get hashCode => Object.hash(row, column);

  @override
  String toString() => notation;
}

class Piece {
  const Piece(this.side, this.rank);
  const Piece.blackMan() : this(Side.black, PieceRank.man);
  const Piece.whiteMan() : this(Side.white, PieceRank.man);

  final Side side;
  final PieceRank rank;

  Piece crowned() => Piece(side, PieceRank.king);

  Map<String, Object> toJson() => {'side': side.name, 'rank': rank.name};
  factory Piece.fromJson(Map<String, Object?> json) => Piece(
    Side.values.byName(json['side']! as String),
    PieceRank.values.byName(json['rank']! as String),
  );

  @override
  bool operator ==(Object other) =>
      other is Piece && side == other.side && rank == other.rank;

  @override
  int get hashCode => Object.hash(side, rank);
}

class Turn {
  const Turn._(this.origin, this.landings, this.captures);

  factory Turn.step(Square origin, Square destination) =>
      Turn._(origin, List.unmodifiable([destination]), const []);

  factory Turn.capture(
    Square origin,
    List<Square> landings,
    List<Square> captures,
  ) => Turn._(origin, List.unmodifiable(landings), List.unmodifiable(captures));

  final Square origin;
  final List<Square> landings;
  final List<Square> captures;

  Square get destination => landings.last;
  bool get isCapture => captures.isNotEmpty;

  Map<String, Object> toJson() => {
    'origin': origin.toJson(),
    'landings': landings.map((square) => square.toJson()).toList(),
    'captures': captures.map((square) => square.toJson()).toList(),
  };

  factory Turn.fromJson(Map<String, Object?> json) => Turn._(
    Square.fromJson((json['origin']! as Map).cast<String, Object?>()),
    List.unmodifiable(
      (json['landings']! as List).map(
        (value) => Square.fromJson((value as Map).cast<String, Object?>()),
      ),
    ),
    List.unmodifiable(
      (json['captures']! as List).map(
        (value) => Square.fromJson((value as Map).cast<String, Object?>()),
      ),
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is Turn &&
      origin == other.origin &&
      _listEquals(landings, other.landings) &&
      _listEquals(captures, other.captures);

  @override
  int get hashCode =>
      Object.hash(origin, Object.hashAll(landings), Object.hashAll(captures));

  @override
  String toString() => '$origin-${landings.join('-')}';
}

enum PerspectiveOutcome { victory, defeat, draw }

class GameResult {
  const GameResult.win(this.winner, this.reason);
  const GameResult.draw(this.reason) : winner = null;

  final Side? winner;
  final ResultReason reason;
  bool get isDraw => winner == null;

  PerspectiveOutcome outcomeFor(Side perspective) => isDraw
      ? PerspectiveOutcome.draw
      : winner == perspective
      ? PerspectiveOutcome.victory
      : PerspectiveOutcome.defeat;

  Map<String, Object?> toJson() => {
    'winner': winner?.name,
    'reason': reason.name,
  };
  factory GameResult.fromJson(Map<String, Object?> json) {
    final winnerName = json['winner'] as String?;
    final reason = ResultReason.values.byName(json['reason']! as String);
    return winnerName == null
        ? GameResult.draw(reason)
        : GameResult.win(Side.values.byName(winnerName), reason);
  }

  @override
  bool operator ==(Object other) =>
      other is GameResult && winner == other.winner && reason == other.reason;

  @override
  int get hashCode => Object.hash(winner, reason);
}

class GameState {
  GameState._({
    required Map<Square, Piece> pieces,
    required this.sideToMove,
    required this.quietKingPlyCount,
    required Map<String, int> positionCounts,
    required List<Turn> turns,
    this.result,
    this.rulesetId = checkersRulesetId,
  }) : pieces = UnmodifiableMapView(Map.of(pieces)),
       positionCounts = UnmodifiableMapView(Map.of(positionCounts)),
       turns = List.unmodifiable(turns);

  factory GameState.initial() {
    final pieces = <Square, Piece>{};
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 8; column++) {
        final square = Square(row, column);
        if (square.isPlayable) pieces[square] = const Piece.blackMan();
      }
    }
    for (var row = 5; row < 8; row++) {
      for (var column = 0; column < 8; column++) {
        final square = Square(row, column);
        if (square.isPlayable) pieces[square] = const Piece.whiteMan();
      }
    }
    final key = _positionKey(pieces, Side.black);
    return GameState._(
      pieces: pieces,
      sideToMove: Side.black,
      quietKingPlyCount: 0,
      positionCounts: {key: 1},
      turns: const [],
    );
  }

  factory GameState.custom({
    required Map<Square, Piece> pieces,
    required Side sideToMove,
    int quietKingPlyCount = 0,
  }) {
    _validatePieces(pieces, quietKingPlyCount);
    return GameState._(
      pieces: pieces,
      sideToMove: sideToMove,
      quietKingPlyCount: quietKingPlyCount,
      positionCounts: {_positionKey(pieces, sideToMove): 1},
      turns: const [],
    );
  }

  final Map<Square, Piece> pieces;
  final Side sideToMove;
  final int quietKingPlyCount;
  final Map<String, int> positionCounts;
  final List<Turn> turns;
  final GameResult? result;
  final String rulesetId;

  Map<String, Object?> toJson() => {
    'version': 1,
    'rulesetId': rulesetId,
    'sideToMove': sideToMove.name,
    'quietKingPlyCount': quietKingPlyCount,
    'pieces': pieces.entries
        .map(
          (entry) => {
            'square': entry.key.toJson(),
            'piece': entry.value.toJson(),
          },
        )
        .toList(),
    'positionCounts': positionCounts,
    'turns': turns.map((turn) => turn.toJson()).toList(),
    'result': result?.toJson(),
  };

  factory GameState.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1 || json['rulesetId'] != checkersRulesetId) {
      throw const FormatException('Unsupported saved game');
    }
    final pieces = <Square, Piece>{};
    for (final value in json['pieces']! as List) {
      final entry = (value as Map).cast<String, Object?>();
      pieces[Square.fromJson(
        (entry['square']! as Map).cast<String, Object?>(),
      )] = Piece.fromJson(
        (entry['piece']! as Map).cast<String, Object?>(),
      );
    }
    _validatePieces(pieces, json['quietKingPlyCount']! as int);
    final resultJson = json['result'];
    return GameState._(
      pieces: pieces,
      sideToMove: Side.values.byName(json['sideToMove']! as String),
      quietKingPlyCount: json['quietKingPlyCount']! as int,
      positionCounts: (json['positionCounts']! as Map).map(
        (key, value) => MapEntry(key as String, value as int),
      ),
      turns: (json['turns']! as List)
          .map((value) => Turn.fromJson((value as Map).cast<String, Object?>()))
          .toList(),
      result: resultJson == null
          ? null
          : GameResult.fromJson((resultJson as Map).cast<String, Object?>()),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameState &&
      _mapEquals(pieces, other.pieces) &&
      sideToMove == other.sideToMove &&
      quietKingPlyCount == other.quietKingPlyCount &&
      _mapEquals(positionCounts, other.positionCounts) &&
      _listEquals(turns, other.turns) &&
      result == other.result &&
      rulesetId == other.rulesetId;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(pieces.entries),
    sideToMove,
    quietKingPlyCount,
    Object.hashAllUnordered(positionCounts.entries),
    Object.hashAll(turns),
    result,
    rulesetId,
  );
}

class CheckersEngine {
  const CheckersEngine();

  GameState resign(GameState state, Side resigningSide) {
    if (state.result != null) throw StateError('The game is already complete');
    return GameState._(
      pieces: state.pieces,
      sideToMove: state.sideToMove,
      quietKingPlyCount: state.quietKingPlyCount,
      positionCounts: state.positionCounts,
      turns: state.turns,
      result: GameResult.win(resigningSide.opponent, ResultReason.resignation),
      rulesetId: state.rulesetId,
    );
  }

  List<Turn> legalTurns(GameState state) {
    if (state.result != null) return const [];
    final captures = <Turn>[];
    for (final entry in state.pieces.entries) {
      if (entry.value.side == state.sideToMove) {
        captures.addAll(_captureTurns(state.pieces, entry.key, entry.value));
      }
    }
    if (captures.isNotEmpty) return captures;

    final steps = <Turn>[];
    for (final entry in state.pieces.entries) {
      final piece = entry.value;
      if (piece.side != state.sideToMove) continue;
      for (final direction in _directions(piece)) {
        final destination = Square(
          entry.key.row + direction.$1,
          entry.key.column + direction.$2,
        );
        if (destination.isPlayable && !state.pieces.containsKey(destination)) {
          steps.add(Turn.step(entry.key, destination));
        }
      }
    }
    return steps;
  }

  GameState applyTurn(GameState state, Turn turn) {
    if (!legalTurns(state).contains(turn)) {
      throw ArgumentError.value(
        turn,
        'turn',
        'Turn is not legal in this position',
      );
    }
    final board = Map<Square, Piece>.of(state.pieces);
    var piece = board.remove(turn.origin)!;
    for (var index = 0; index < turn.landings.length; index++) {
      if (turn.isCapture) board.remove(turn.captures[index]);
    }
    final destination = turn.destination;
    if (piece.rank == PieceRank.man &&
        _isCrownRow(piece.side, destination.row)) {
      piece = piece.crowned();
    }
    board[destination] = piece;

    final originalPiece = state.pieces[turn.origin]!;
    final quietCount = turn.isCapture || originalPiece.rank == PieceRank.man
        ? 0
        : state.quietKingPlyCount + 1;
    final nextSide = state.sideToMove.opponent;
    final counts = Map<String, int>.of(state.positionCounts);
    final key = _positionKey(board, nextSide);
    counts[key] = (counts[key] ?? 0) + 1;

    GameResult? result;
    final opponentPieces = board.values.where(
      (value) => value.side == nextSide,
    );
    if (opponentPieces.isEmpty) {
      result = GameResult.win(state.sideToMove, ResultReason.noPieces);
    } else {
      final provisional = GameState._(
        pieces: board,
        sideToMove: nextSide,
        quietKingPlyCount: quietCount,
        positionCounts: counts,
        turns: [...state.turns, turn],
      );
      if (legalTurns(provisional).isEmpty) {
        result = GameResult.win(state.sideToMove, ResultReason.noLegalMove);
      } else if (counts[key]! >= 3) {
        result = const GameResult.draw(ResultReason.repetition);
      } else if (quietCount >= 80) {
        result = const GameResult.draw(ResultReason.quietKings);
      }
    }

    return GameState._(
      pieces: board,
      sideToMove: nextSide,
      quietKingPlyCount: quietCount,
      positionCounts: counts,
      turns: [...state.turns, turn],
      result: result,
    );
  }

  List<Turn> _captureTurns(
    Map<Square, Piece> board,
    Square origin,
    Piece piece,
  ) {
    final turns = <Turn>[];

    void search(
      Map<Square, Piece> currentBoard,
      Square current,
      List<Square> landings,
      List<Square> captures,
    ) {
      var continued = false;
      for (final direction in _directions(piece)) {
        final jumped = Square(
          current.row + direction.$1,
          current.column + direction.$2,
        );
        final landing = Square(
          current.row + direction.$1 * 2,
          current.column + direction.$2 * 2,
        );
        final target = currentBoard[jumped];
        if (!landing.isPlayable ||
            currentBoard.containsKey(landing) ||
            target == null ||
            target.side == piece.side) {
          continue;
        }
        continued = true;
        final nextBoard = Map<Square, Piece>.of(currentBoard)
          ..remove(current)
          ..remove(jumped)
          ..[landing] = piece;
        final nextLandings = [...landings, landing];
        final nextCaptures = [...captures, jumped];
        if (piece.rank == PieceRank.man &&
            _isCrownRow(piece.side, landing.row)) {
          turns.add(Turn.capture(origin, nextLandings, nextCaptures));
        } else {
          search(nextBoard, landing, nextLandings, nextCaptures);
        }
      }
      if (!continued && captures.isNotEmpty) {
        turns.add(Turn.capture(origin, landings, captures));
      }
    }

    search(board, origin, const [], const []);
    return turns;
  }
}

List<(int, int)> _directions(Piece piece) {
  if (piece.rank == PieceRank.king) {
    return const [(-1, -1), (-1, 1), (1, -1), (1, 1)];
  }
  final rowDelta = piece.side == Side.black ? 1 : -1;
  return [(rowDelta, -1), (rowDelta, 1)];
}

bool _isCrownRow(Side side, int row) =>
    side == Side.black ? row == 7 : row == 0;

String _positionKey(Map<Square, Piece> pieces, Side sideToMove) {
  final entries = pieces.entries.toList()
    ..sort((a, b) {
      final row = a.key.row.compareTo(b.key.row);
      return row != 0 ? row : a.key.column.compareTo(b.key.column);
    });
  return '$checkersRulesetId|${sideToMove.name}|${entries.map((entry) => '${entry.key.row}${entry.key.column}${entry.value.side.name[0]}${entry.value.rank.name[0]}').join()}';
}

void _validatePieces(Map<Square, Piece> pieces, int quietKingPlyCount) {
  if (quietKingPlyCount < 0 ||
      pieces.keys.any((square) => !square.isPlayable)) {
    throw const FormatException('Invalid checkers position');
  }
  for (final side in Side.values) {
    if (pieces.values.where((piece) => piece.side == side).length > 12) {
      throw const FormatException('A side cannot have more than twelve pieces');
    }
  }
  for (final entry in pieces.entries) {
    if (entry.value.rank == PieceRank.man &&
        _isCrownRow(entry.value.side, entry.key.row)) {
      throw const FormatException('A man cannot remain on its crown row');
    }
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
