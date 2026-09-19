import 'package:flutter/material.dart';

import '../../app/crown_icon.dart';
import '../../app/crown_theme.dart';
import '../../game_engine/checkers_engine.dart';
import '../../persistence/crown_repository.dart';

class MatchRecordRow extends StatelessWidget {
  const MatchRecordRow({
    required this.record,
    required this.onReplay,
    super.key,
  });

  final MatchRecord record;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final (variant, label) = switch (record.perspectiveOutcome) {
      PerspectiveOutcome.victory => (CrownIconVariant.normal, 'Victory'),
      PerspectiveOutcome.defeat => (CrownIconVariant.broken, 'Defeat'),
      PerspectiveOutcome.draw => (CrownIconVariant.draw, 'Draw'),
    };
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CrownIcon(variant: variant, size: 32, semanticLabel: label),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              record.opponentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton(onPressed: onReplay, child: const Text('Replay')),
        ],
      ),
    );
  }
}
