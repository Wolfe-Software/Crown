import 'package:flutter/material.dart';

import '../../app/crown_icon.dart';
import '../../game_engine/checkers_engine.dart';

class GameResultSummary extends StatelessWidget {
  const GameResultSummary({
    required this.result,
    required this.perspective,
    this.iconSize = 38,
    super.key,
  });

  final GameResult result;
  final Side perspective;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final outcome = result.outcomeFor(perspective);
    final title = gameOutcomeTitle(outcome);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CrownIcon(
          variant: switch (outcome) {
            PerspectiveOutcome.victory => CrownIconVariant.normal,
            PerspectiveOutcome.defeat => CrownIconVariant.broken,
            PerspectiveOutcome.draw => CrownIconVariant.draw,
          },
          size: iconSize,
          semanticLabel: title,
        ),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(gameResultReasonText(result.reason), textAlign: TextAlign.center),
      ],
    );
  }
}

String gameResultReasonText(ResultReason reason) => switch (reason) {
  ResultReason.noPieces => 'The final opposing piece was captured.',
  ResultReason.noLegalMove => 'No legal move remained.',
  ResultReason.repetition => 'The same position occurred three times.',
  ResultReason.quietKings => 'Eighty quiet king turns were completed.',
  ResultReason.resignation => 'The match ended by resignation.',
};

String gameOutcomeTitle(PerspectiveOutcome outcome) => switch (outcome) {
  PerspectiveOutcome.victory => 'Victory',
  PerspectiveOutcome.defeat => 'Defeat',
  PerspectiveOutcome.draw => 'Draw',
};
