import '../../game_engine/checkers_engine.dart';

class JumpAnimation {
  const JumpAnimation({
    required this.piece,
    required this.from,
    required this.to,
    this.captured,
    required this.duration,
  });

  final Piece piece;
  final Square from;
  final Square to;
  final Square? captured;
  final Duration duration;
}
