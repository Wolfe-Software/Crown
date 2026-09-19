import 'package:flutter/material.dart';

import '../../app/crown_icon.dart';
import '../../app/crown_theme.dart';

enum CheckerPieceStyle { black, white, split }

class CheckerPiece extends StatelessWidget {
  const CheckerPiece({
    required this.style,
    this.isKing = false,
    this.crownQuarterTurns = 0,
    this.selected = false,
    this.reducedMotion = false,
    this.faceKey,
    super.key,
  });

  final CheckerPieceStyle style;
  final bool isKing;
  final int crownQuarterTurns;
  final bool selected;
  final bool reducedMotion;
  final Key? faceKey;

  bool get _isBlack => style == CheckerPieceStyle.black;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: selected ? 1.08 : 1,
    duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 150),
    child: DecoratedBox(
      key: faceKey,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: switch (style) {
          CheckerPieceStyle.black => const RadialGradient(
            center: Alignment(-.3, -.4),
            colors: [Color(0xFF62594F), CrownColors.obsidian],
          ),
          CheckerPieceStyle.white => const RadialGradient(
            center: Alignment(-.3, -.4),
            colors: [Colors.white, Color(0xFFCFC5B7)],
          ),
          CheckerPieceStyle.split => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              CrownColors.obsidian,
              Color(0xFF514A42),
              Color(0xFFE9E3DA),
              Colors.white,
            ],
            stops: [0, .49, .51, 1],
          ),
        },
        border: Border.all(
          color: selected || isKing || style == CheckerPieceStyle.split
              ? CrownColors.paleGold
              : (_isBlack ? Colors.black : Colors.white),
          width: selected ? 3 : 2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 3)),
        ],
      ),
      child: isKing
          ? Center(
              child: FractionallySizedBox(
                widthFactor: .54,
                heightFactor: .54,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RotatedBox(
                    quarterTurns: crownQuarterTurns,
                    child: const CrownIcon(size: 24),
                  ),
                ),
              ),
            )
          : null,
    ),
  );
}
