import 'package:crown/game_engine/checkers_engine.dart';
import 'package:crown/game_engine/crown_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = CheckersEngine();

  test('always returns a legal complete turn', () async {
    final state = GameState.initial();
    final turn = await const CrownAi().chooseTurn(
      state,
      const AiProfile(),
      seed: 4,
    );

    expect(engine.legalTurns(state), contains(turn));
  });

  test('takes an immediate win', () async {
    final state = GameState.custom(
      sideToMove: Side.white,
      pieces: {
        const Square(4, 3): const Piece.whiteMan(),
        const Square(3, 2): const Piece.blackMan(),
      },
    );

    final turn = await const CrownAi().chooseTurn(
      state,
      const AiProfile(skill: 10),
      seed: 1,
    );
    final result = engine.applyTurn(state, turn).result;

    expect(result, const GameResult.win(Side.white, ResultReason.noPieces));
  });

  test('a fixed seed produces the same turn', () async {
    final first = await const CrownAi().chooseTurn(
      GameState.initial(),
      const AiProfile(),
      seed: 42,
    );
    final second = await const CrownAi().chooseTurn(
      GameState.initial(),
      const AiProfile(),
      seed: 42,
    );

    expect(first, second);
  });

  test('skill adapts gradually and remains bounded', () {
    var profile = const AiProfile(skill: 5);
    for (var index = 0; index < 100; index++) {
      profile = profile.afterHumanResult(HumanResult.win);
    }
    expect(profile.skill, 10);

    for (var index = 0; index < 100; index++) {
      profile = profile.afterHumanResult(HumanResult.loss);
    }
    expect(profile.skill, 0);
  });

  test('cannot choose a turn from a completed game', () async {
    final active = GameState.custom(
      sideToMove: Side.black,
      pieces: {
        const Square(2, 1): const Piece.blackMan(),
        const Square(3, 2): const Piece.whiteMan(),
      },
    );
    final completed = engine.applyTurn(
      active,
      engine.legalTurns(active).single,
    );

    expect(
      () => const CrownAi().chooseTurn(completed, const AiProfile()),
      throwsStateError,
    );
  });
}
