import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';

/// Canonical presentation and progression controls for interactive lessons.
///
/// A completed exercise remains visible until the player explicitly continues.
/// `LessonScreen` supplies the current board here for every lesson rather than
/// recreating the header, progress, feedback, and completion controls.
class LessonExerciseScaffold extends StatelessWidget {
  const LessonExerciseScaffold({
    required this.lessonNumber,
    required this.lessonName,
    required this.exerciseNumber,
    required this.exerciseCount,
    required this.exerciseTitle,
    required this.instruction,
    required this.board,
    required this.feedback,
    required this.feedbackMessages,
    required this.feedbackKey,
    required this.exerciseComplete,
    required this.isFinalExercise,
    required this.onContinue,
    this.interaction,
    this.showCompletionAction = true,
    super.key,
  });

  final int lessonNumber;
  final String lessonName;
  final int exerciseNumber;
  final int exerciseCount;
  final String exerciseTitle;
  final String instruction;
  final Widget board;
  final String feedback;
  final List<String> feedbackMessages;
  final Key feedbackKey;
  final bool exerciseComplete;
  final bool isFinalExercise;
  final VoidCallback onContinue;
  final Widget? interaction;
  final bool showCompletionAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        children: [
          Text('LESSON $lessonNumber'),
          Text(
            lessonName,
            style: const TextStyle(
              color: CrownColors.gold,
              fontFamily: '.SF Pro Text',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    ),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 650;
          final gap = compact ? 6.0 : 16.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'EXERCISE $exerciseNumber OF $exerciseCount',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: CrownColors.gold),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: exerciseNumber / exerciseCount,
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(2),
                            color: CrownColors.gold,
                            backgroundColor: CrownColors.gold.withValues(
                              alpha: .14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gap),
                    GlassPanel(
                      padding: EdgeInsets.all(compact ? 10 : 16),
                      radius: compact ? 18 : 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              exerciseTitle,
                              style: compact
                                  ? Theme.of(context).textTheme.titleLarge
                                  : Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          SizedBox(height: compact ? 4 : 8),
                          Text(
                            instruction,
                            style:
                                (compact
                                        ? Theme.of(context).textTheme.bodyMedium
                                        : Theme.of(context).textTheme.bodyLarge)
                                    ?.copyWith(height: compact ? 1.2 : 1.45),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: gap),
                    Expanded(child: Center(child: board)),
                    if (interaction != null) ...[
                      SizedBox(height: gap),
                      interaction!,
                    ],
                    SizedBox(height: gap),
                    _StableLessonFeedback(
                      feedback: feedback,
                      messages: feedbackMessages,
                      feedbackKey: feedbackKey,
                      compact: compact,
                      exerciseComplete: exerciseComplete,
                    ),
                    if (exerciseComplete && showCompletionAction) ...[
                      SizedBox(height: gap),
                      GoldButton(
                        label: isFinalExercise ? 'COMPLETE LESSON' : 'CONTINUE',
                        onPressed: onContinue,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _StableLessonFeedback extends StatelessWidget {
  const _StableLessonFeedback({
    required this.feedback,
    required this.messages,
    required this.feedbackKey,
    required this.compact,
    required this.exerciseComplete,
  });

  final String feedback;
  final List<String> messages;
  final Key feedbackKey;
  final bool compact;
  final bool exerciseComplete;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        (compact
                ? Theme.of(context).textTheme.bodyMedium
                : Theme.of(context).textTheme.bodyLarge)
            ?.copyWith(height: compact ? 1.15 : null);
    final style = baseStyle?.copyWith(
      color: exerciseComplete ? CrownColors.gold : CrownColors.muted,
      fontWeight: exerciseComplete ? FontWeight.w700 : null,
    );
    final measurementStyles = [
      baseStyle,
      baseStyle?.copyWith(fontWeight: FontWeight.w700),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        var height = 0.0;
        for (final message in {...messages, feedback}) {
          for (final measurementStyle in measurementStyles) {
            final painter = TextPainter(
              text: TextSpan(text: message, style: measurementStyle),
              textAlign: TextAlign.center,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: constraints.maxWidth);
            height = math.max(height, painter.height);
          }
        }
        return SizedBox(
          height: height.ceilToDouble(),
          child: Center(
            child: Semantics(
              key: feedbackKey,
              liveRegion: true,
              container: true,
              child: Text(feedback, textAlign: TextAlign.center, style: style),
            ),
          ),
        );
      },
    );
  }
}
