import 'package:flutter/material.dart';

import '../../app/crown_icon.dart';
import '../../app/crown_theme.dart';
import '../../game_engine/checkers_engine.dart';

class PlayerStrip extends StatelessWidget {
  const PlayerStrip({
    required this.name,
    required this.side,
    required this.isCrownAi,
    required this.active,
    required this.pieces,
    super.key,
  });

  final String name;
  final Side side;
  final bool isCrownAi;
  final bool active;
  final int pieces;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        '$name, ${side.name}, $pieces pieces, ${active ? 'active turn' : 'waiting'}',
    child: ExcludeSemantics(
      child: AnimatedContainer(
        key: ValueKey('player-strip-${side.name}'),
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: active ? .72 : .42),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? CrownColors.gold : Colors.white70,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            SizedBox.square(
              key: ValueKey('side-indicator-${side.name}'),
              dimension: 30,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: side == Side.black
                          ? CrownColors.obsidian
                          : Colors.white,
                      border: Border.all(color: CrownColors.gold),
                    ),
                    child: const SizedBox.expand(),
                  ),
                  if (isCrownAi)
                    const CrownIcon(
                      variant: CrownIconVariant.jeweled,
                      size: 18,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '$pieces PIECES',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: active ? CrownColors.gold : CrownColors.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
