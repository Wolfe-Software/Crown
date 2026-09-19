import 'dart:isolate';
import 'dart:math';

import 'checkers_engine.dart';

enum HumanResult { win, loss, draw }

class AiProfile {
  const AiProfile({this.skill = 5, this.gamesPlayed = 0});

  final int skill;
  final int gamesPlayed;

  AiProfile afterHumanResult(HumanResult result) {
    final adjustment = switch (result) {
      HumanResult.win => 1,
      HumanResult.loss => -1,
      HumanResult.draw => 0,
    };
    return AiProfile(
      skill: (skill + adjustment).clamp(0, 10),
      gamesPlayed: gamesPlayed + 1,
    );
  }

  Map<String, Object> toJson() => {'skill': skill, 'gamesPlayed': gamesPlayed};
  factory AiProfile.fromJson(Map<String, Object?> json) => AiProfile(
    skill: (json['skill'] as int? ?? 5).clamp(0, 10),
    gamesPlayed: json['gamesPlayed'] as int? ?? 0,
  );
}

class CrownAi {
  const CrownAi();

  Future<Turn> chooseTurn(
    GameState state,
    AiProfile profile, {
    int? seed,
  }) async {
    if (state.result != null) {
      throw StateError('Cannot choose a turn for a completed game');
    }
    final legalTurns = const CheckersEngine().legalTurns(state);
    if (legalTurns.isEmpty) throw StateError('No legal turn is available');
    final payload = <String, Object?>{
      'state': state.toJson(),
      'skill': profile.skill,
      'seed': seed ?? DateTime.now().microsecondsSinceEpoch,
    };
    final result = await Isolate.run(() => _chooseTurn(payload));
    final turn = Turn.fromJson(result);
    return legalTurns.contains(turn) ? turn : legalTurns.first;
  }
}

Map<String, Object?> _chooseTurn(Map<String, Object?> payload) {
  final state = GameState.fromJson(
    (payload['state']! as Map).cast<String, Object?>(),
  );
  final skill = payload['skill']! as int;
  final random = Random(payload['seed']! as int);
  final engine = const CheckersEngine();
  final aiSide = state.sideToMove;
  final depth = 2 + (skill / 3).floor();
  final scored = <(Turn, int)>[];

  for (final turn in engine.legalTurns(state)) {
    final next = engine.applyTurn(state, turn);
    scored.add((
      turn,
      _search(engine, next, depth - 1, aiSide, -1000000, 1000000),
    ));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));

  // At lower strength Crown occasionally chooses among near-best moves, while
  // terminal wins are always respected.
  final best = scored.first.$2;
  final candidates = scored
      .where((entry) => best >= 90000 || entry.$2 >= best - (10 - skill) * 12)
      .take(skill >= 8 ? 1 : 3)
      .toList();
  return candidates[random.nextInt(candidates.length)].$1.toJson();
}

int _search(
  CheckersEngine engine,
  GameState state,
  int depth,
  Side aiSide,
  int alpha,
  int beta,
) {
  final result = state.result;
  if (result != null) {
    if (result.isDraw) return 0;
    return result.winner == aiSide ? 100000 + depth : -100000 - depth;
  }
  if (depth == 0) return _evaluate(state, aiSide, engine);

  final maximizing = state.sideToMove == aiSide;
  var best = maximizing ? -1000000 : 1000000;
  for (final turn in engine.legalTurns(state)) {
    final score = _search(
      engine,
      engine.applyTurn(state, turn),
      depth - 1,
      aiSide,
      alpha,
      beta,
    );
    if (maximizing) {
      best = max(best, score);
      alpha = max(alpha, best);
    } else {
      best = min(best, score);
      beta = min(beta, best);
    }
    if (beta <= alpha) break;
  }
  return best;
}

int _evaluate(GameState state, Side aiSide, CheckersEngine engine) {
  var score = 0;
  for (final entry in state.pieces.entries) {
    final piece = entry.value;
    var value = piece.rank == PieceRank.king ? 175 : 100;
    if (piece.rank == PieceRank.man) {
      final progress = piece.side == Side.black
          ? entry.key.row
          : 7 - entry.key.row;
      value += progress * 4;
    }
    if (entry.key.row >= 2 &&
        entry.key.row <= 5 &&
        entry.key.column >= 2 &&
        entry.key.column <= 5) {
      value += 6;
    }
    score += piece.side == aiSide ? value : -value;
  }
  final mobility = engine.legalTurns(state).length * 2;
  score += state.sideToMove == aiSide ? mobility : -mobility;
  return score;
}
