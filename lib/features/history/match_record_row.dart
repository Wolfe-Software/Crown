import 'package:flutter/material.dart';

import '../../app/crown_icon.dart';
import '../../app/crown_theme.dart';
import '../../game_engine/checkers_engine.dart';
import '../../persistence/crown_repository.dart';

class FeedEntryRow extends StatelessWidget {
  const FeedEntryRow({required this.entry, required this.onReplay, super.key});

  final FeedEntry entry;
  final ValueChanged<MatchRecord> onReplay;

  @override
  Widget build(BuildContext context) => switch (entry) {
    MatchFeedEntry(:final record) => MatchRecordRow(
      record: record,
      onReplay: () => onReplay(record),
    ),
    ChallengeAttemptFeedEntry(:final lessonNumber, :final record) =>
      MatchRecordRow(
        record: record,
        title: 'Challenge $lessonNumber',
        onReplay: () => onReplay(record),
      ),
    LessonCompletionFeedEntry(:final lessonNumber) => GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Image.asset(
            'assets/LearnLogo.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            semanticLabel: 'Lesson completed',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Lesson $lessonNumber',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    ),
  };
}

class MatchRecordRow extends StatelessWidget {
  const MatchRecordRow({
    required this.record,
    required this.onReplay,
    this.title,
    super.key,
  });

  final MatchRecord record;
  final VoidCallback onReplay;
  final String? title;

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
              title ?? record.opponentName,
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
