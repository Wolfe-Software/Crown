import 'package:flutter/material.dart';

import '../../app/crown_bottom_modal.dart';
import '../../app/crown_theme.dart';
import '../../game_engine/checkers_engine.dart';
import 'game_result_summary.dart';

class MatchResultSheet extends StatelessWidget {
  const MatchResultSheet({
    required this.result,
    required this.perspective,
    required this.actionLabel,
    required this.onAction,
    this.message,
    this.onReturnToLearn,
    super.key,
  });

  final GameResult result;
  final Side perspective;
  final String actionLabel;
  final VoidCallback onAction;
  final String? message;
  final VoidCallback? onReturnToLearn;

  @override
  Widget build(BuildContext context) => CrownBottomSheet(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CrownSheetHandle(),
          const SizedBox(height: 24),
          GameResultSummary(
            result: result,
            perspective: perspective,
            iconSize: 44,
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          GoldButton(label: actionLabel, onPressed: onAction),
          if (onReturnToLearn != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onReturnToLearn,
              child: const Text('RETURN TO LEARN'),
            ),
          ],
        ],
      ),
    ),
  );
}
