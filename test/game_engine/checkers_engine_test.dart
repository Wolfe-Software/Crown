import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = CheckersEngine();

  group('initial position', () {
    test('contains twelve men per side with black to move', () {
      final state = GameState.initial();

      expect(state.sideToMove, Side.black);
      expect(
        state.pieces.values.where((p) => p.side == Side.black),
        hasLength(12),
      );
      expect(
        state.pieces.values.where((p) => p.side == Side.white),
        hasLength(12),
      );
      expect(state.pieces.values.every((p) => p.rank == PieceRank.man), isTrue);
      expect(state.pieces.keys.every((square) => square.isPlayable), isTrue);
    });

    test('black has seven legal opening turns', () {
      expect(engine.legalTurns(GameState.initial()), hasLength(7));
    });
  });

  group('movement', () {
    test('men only step and capture forward', () {
      final state = position(
        sideToMove: Side.black,
        pieces: {
          const Square(3, 2): const Piece.blackMan(),
          const Square(4, 3): const Piece.whiteMan(),
          const Square(2, 3): const Piece.whiteMan(),
        },
      );

      expect(engine.legalTurns(state), [
        Turn.capture(
          const Square(3, 2),
          const [Square(5, 4)],
          const [Square(4, 3)],
        ),
      ]);
    });

    test('kings step in all four diagonal directions', () {
      final state = position(
        sideToMove: Side.black,
        pieces: {const Square(3, 2): const Piece(Side.black, PieceRank.king)},
      );

      expect(engine.legalTurns(state), hasLength(4));
    });
  });

  group('captures', () {
    test('a capture anywhere suppresses every ordinary move', () {
      final state = position(
        sideToMove: Side.black,
        pieces: {
          const Square(2, 1): const Piece.blackMan(),
          const Square(2, 5): const Piece.blackMan(),
          const Square(3, 6): const Piece.whiteMan(),
        },
      );

      final turns = engine.legalTurns(state);
      expect(turns, hasLength(1));
      expect(turns.single.isCapture, isTrue);
      expect(turns.single.origin, const Square(2, 5));
    });

    test('generates complete branching multi-capture turns', () {
      final state = position(
        sideToMove: Side.black,
        pieces: {
          const Square(1, 2): const Piece.blackMan(),
          const Square(2, 3): const Piece.whiteMan(),
          const Square(4, 3): const Piece.whiteMan(),
          const Square(4, 5): const Piece.whiteMan(),
        },
      );

      expect(engine.legalTurns(state).toSet(), {
        Turn.capture(
          const Square(1, 2),
          const [Square(3, 4), Square(5, 2)],
          const [Square(2, 3), Square(4, 3)],
        ),
        Turn.capture(
          const Square(1, 2),
          const [Square(3, 4), Square(5, 6)],
          const [Square(2, 3), Square(4, 5)],
        ),
      });
    });

    test('rejects a partial capture without mutating state', () {
      final state = position(
        sideToMove: Side.black,
        pieces: {
          const Square(1, 0): const Piece.blackMan(),
          const Square(2, 1): const Piece.whiteMan(),
          const Square(4, 3): const Piece.whiteMan(),
        },
      );
      final partial = Turn.capture(
        const Square(1, 0),
        const [Square(3, 2)],
        const [Square(2, 1)],
      );

      expect(() => engine.applyTurn(state, partial), throwsArgumentError);
      expect(state.pieces[const Square(1, 0)], const Piece.blackMan());
    });
  });

  group('crowning and outcomes', () {
    test('classifies results from either side perspective', () {
      const blackWin = GameResult.win(Side.black, ResultReason.noPieces);
      const draw = GameResult.draw(ResultReason.repetition);

      expect(blackWin.outcomeFor(Side.black), PerspectiveOutcome.victory);
      expect(blackWin.outcomeFor(Side.white), PerspectiveOutcome.defeat);
      expect(draw.outcomeFor(Side.black), PerspectiveOutcome.draw);
      expect(draw.outcomeFor(Side.white), PerspectiveOutcome.draw);
    });

    test('resignation awards the game to the opponent', () {
      final resigned = engine.resign(GameState.initial(), Side.black);

      expect(
        resigned.result,
        const GameResult.win(Side.white, ResultReason.resignation),
      );
      expect(resigned.pieces, GameState.initial().pieces);
    });

    test('crowns a man and ends its capture turn immediately', () {
      final state = position(
        sideToMove: Side.black,
        pieces: {
          const Square(5, 0): const Piece.blackMan(),
          const Square(6, 1): const Piece.whiteMan(),
          const Square(6, 3): const Piece.whiteMan(),
        },
      );

      final turn = engine.legalTurns(state).single;
      expect(turn.landings, const [Square(7, 2)]);

      final next = engine.applyTurn(state, turn);
      expect(
        next.pieces[const Square(7, 2)],
        const Piece(Side.black, PieceRank.king),
      );
      expect(next.pieces[const Square(6, 3)], isNotNull);
    });

    test('capturing the final piece wins the game', () {
      final state = position(
        sideToMove: Side.black,
        pieces: {
          const Square(2, 1): const Piece.blackMan(),
          const Square(3, 2): const Piece.whiteMan(),
        },
      );

      final next = engine.applyTurn(state, engine.legalTurns(state).single);
      expect(
        next.result,
        const GameResult.win(Side.black, ResultReason.noPieces),
      );
    });

    test('a side with pieces but no legal turn loses', () {
      final state = position(
        sideToMove: Side.white,
        pieces: {
          const Square(5, 6): const Piece.whiteMan(),
          const Square(0, 1): const Piece.blackMan(),
          const Square(1, 0): const Piece.whiteMan(),
          const Square(1, 2): const Piece.whiteMan(),
          const Square(2, 3): const Piece.whiteMan(),
        },
      );

      final next = engine.applyTurn(
        state,
        Turn.step(const Square(5, 6), const Square(4, 5)),
      );
      expect(
        next.result,
        const GameResult.win(Side.white, ResultReason.noLegalMove),
      );
    });
  });

  group('draws and serialization', () {
    test('declares a draw on the third occurrence of a position', () {
      var state = position(
        sideToMove: Side.black,
        pieces: {
          const Square(2, 1): const Piece(Side.black, PieceRank.king),
          const Square(5, 6): const Piece(Side.white, PieceRank.king),
        },
      );
      final cycle = [
        Turn.step(const Square(2, 1), const Square(3, 0)),
        Turn.step(const Square(5, 6), const Square(4, 7)),
        Turn.step(const Square(3, 0), const Square(2, 1)),
        Turn.step(const Square(4, 7), const Square(5, 6)),
      ];

      for (var repetition = 0; repetition < 2; repetition++) {
        for (final turn in cycle) {
          state = engine.applyTurn(state, turn);
        }
      }

      expect(state.result, const GameResult.draw(ResultReason.repetition));
    });

    test('declares a draw after eighty quiet king plies', () {
      final state = position(
        sideToMove: Side.black,
        quietKingPlyCount: 79,
        pieces: {
          const Square(2, 1): const Piece(Side.black, PieceRank.king),
          const Square(5, 6): const Piece(Side.white, PieceRank.king),
        },
      );

      final next = engine.applyTurn(
        state,
        Turn.step(const Square(2, 1), const Square(3, 0)),
      );
      expect(next.result, const GameResult.draw(ResultReason.quietKings));
    });

    test('round trips a state through JSON', () {
      final state = engine.applyTurn(
        GameState.initial(),
        engine.legalTurns(GameState.initial()).first,
      );
      expect(GameState.fromJson(state.toJson()), state);
    });
  });
}

GameState position({
  required Side sideToMove,
  required Map<Square, Piece> pieces,
  int quietKingPlyCount = 0,
}) => GameState.custom(
  pieces: pieces,
  sideToMove: sideToMove,
  quietKingPlyCount: quietKingPlyCount,
);
