import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/crown_bottom_modal.dart';
import '../../app/crown_icon.dart';
import '../../app/crown_theme.dart';
import '../match/match_controller.dart';
import '../match/match_result_sheet.dart';
import '../match/singleplayer_match_layout.dart';
import 'guided_match_controller.dart';
import 'lesson_definition.dart';

enum _PhaseAction { proceed, leave }

class GuidedMatchScreen extends StatefulWidget {
  const GuidedMatchScreen({
    required this.controller,
    required this.highContrast,
    required this.reducedMotion,
    this.showCoordinates = false,
    super.key,
  });

  final GuidedMatchController controller;
  final bool highContrast;
  final bool reducedMotion;
  final bool showCoordinates;

  @override
  State<GuidedMatchScreen> createState() => _GuidedMatchScreenState();
}

class _GuidedMatchScreenState extends State<GuidedMatchScreen> {
  GuidedMatchController get controller => widget.controller;
  bool get _noMotion =>
      widget.reducedMotion || MediaQuery.disableAnimationsOf(context);
  MatchController? _introducedAttempt;
  MatchController? _resultAttempt;
  bool _overlayOpen = false;
  bool _presentationScheduled = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_changed);
    _schedulePhaseSheet();
  }

  @override
  void didUpdateWidget(covariant GuidedMatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_changed);
      controller.addListener(_changed);
      _introducedAttempt = null;
      _resultAttempt = null;
      _schedulePhaseSheet();
    }
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted || _leaving) return;
    setState(() {});
    _schedulePhaseSheet();
  }

  void _schedulePhaseSheet() {
    if (!mounted || _leaving || _presentationScheduled) return;
    _presentationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presentationScheduled = false;
      if (mounted &&
          !_leaving &&
          !_overlayOpen &&
          ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_presentPhaseSheet());
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Keep ownership until the reverse transition finishes, so a queued result
  /// never stacks on top of history, confirmation, or introduction sheets.
  Future<T?> _showSheet<T>(WidgetBuilder builder, {T? backResult}) async {
    if (_overlayOpen || _leaving || !mounted) return null;
    _overlayOpen = true;
    ModalRoute<dynamic>? route;
    try {
      final result = await showCrownBottomModal<T>(
        context: context,
        reducedMotion: _noMotion,
        dismissible: backResult == null,
        builder: (sheetContext) {
          route = ModalRoute.of(sheetContext);
          return PopScope<T>(
            canPop: backResult == null,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && backResult != null) {
                Navigator.pop(sheetContext, backResult);
              }
            },
            child: SafeArea(bottom: false, child: builder(sheetContext)),
          );
        },
      );
      await route?.completed;
      return result;
    } finally {
      _overlayOpen = false;
      _schedulePhaseSheet();
    }
  }

  Future<void> _presentPhaseSheet() async {
    final attempt = controller.match;
    final phase = controller.phase;
    if (phase == GuidedMatchPhase.introduction &&
        _introducedAttempt != attempt) {
      _introducedAttempt = attempt;
      final action = await _showSheet<_PhaseAction>(
        (sheetContext) => _LessonSheet(
          key: const ValueKey('lesson-introduction-sheet'),
          children: [
            Text(
              'LESSON ${controller.definition.number}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              controller.definition.name,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              controller.definition.introduction,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            GoldButton(
              label: 'BEGIN MATCH',
              onPressed: () =>
                  Navigator.pop(sheetContext, _PhaseAction.proceed),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, _PhaseAction.leave),
              child: const Text('RETURN TO LEARN'),
            ),
          ],
        ),
        backResult: _PhaseAction.leave,
      );
      if (!mounted ||
          _leaving ||
          controller.match != attempt ||
          controller.phase != phase) {
        return;
      }
      if (action == _PhaseAction.proceed) {
        await controller.begin();
      } else if (action == _PhaseAction.leave) {
        _exitLesson();
      }
    } else if (phase == GuidedMatchPhase.result && _resultAttempt != attempt) {
      _resultAttempt = attempt;
      final action = await _showSheet<_PhaseAction>(
        (sheetContext) => MatchResultSheet(
          key: const ValueKey('lesson-result-sheet'),
          result: attempt.state.result!,
          perspective: controller.definition.humanSide,
          message: controller.won
              ? 'Well played! Finish the Unit 1 recap to complete this lesson.'
              : 'Every game is practice. Try again, then win and finish the recap to complete this lesson.',
          actionLabel: controller.won ? 'REVIEW UNIT 1' : 'TRY AGAIN',
          onAction: () => Navigator.pop(sheetContext, _PhaseAction.proceed),
          onReturnToLearn: () =>
              Navigator.pop(sheetContext, _PhaseAction.leave),
        ),
        backResult: _PhaseAction.leave,
      );
      if (!mounted ||
          _leaving ||
          controller.match != attempt ||
          controller.phase != phase) {
        return;
      }
      if (action == _PhaseAction.leave) {
        _exitLesson();
      } else if (action == _PhaseAction.proceed) {
        if (controller.won) {
          controller.openReview();
        } else {
          controller.retry();
        }
      }
    }
  }

  void _exitLesson({bool completed = false}) {
    if (!mounted || _leaving) return;
    setState(() => _leaving = true);
    Navigator.of(context).pop(completed);
  }

  Future<void> _showRules() async {
    if (_overlayOpen || _leaving) return;
    _overlayOpen = true;
    final route = MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('UNIT 1 RULES')),
        body: _ReviewList(
          definition: controller.definition,
          highContrast: widget.highContrast,
        ),
      ),
    );
    try {
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      _overlayOpen = false;
      _schedulePhaseSheet();
    }
  }

  Future<void> _showMoves() => _showSheet<void>(
    (_) => _LessonSheet(
      key: const ValueKey('move-history-sheet'),
      children: [
        Text('Move history', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (controller.match.state.turns.isEmpty) const Text('No moves yet.'),
        for (final (index, turn) in controller.match.state.turns.indexed)
          ListTile(
            dense: true,
            leading: Text('${index + 1}'),
            title: Text(turn.toString()),
          ),
      ],
    ),
  );

  Future<void> _confirmResign() async {
    final attempt = controller.match;
    final confirmed = await _showSheet<bool>(
      (sheetContext) => _LessonSheet(
        key: const ValueKey('resign-sheet'),
        children: [
          const CrownIcon(
            variant: CrownIconVariant.broken,
            size: 34,
            semanticLabel: 'Defeat',
          ),
          const SizedBox(height: 12),
          Text(
            'Resign match?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Resigning ends this attempt as a loss. You can try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: CrownColors.error,
              ),
              onPressed: () => Navigator.pop(sheetContext, true),
              child: const Text('RESIGN'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(sheetContext, false),
            child: const Text('KEEP PLAYING'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        !_leaving &&
        controller.match == attempt) {
      await controller.resign();
    }
  }

  Future<void> _leave() async {
    final leave = await _showSheet<bool>(
      (sheetContext) => _LessonSheet(
        key: const ValueKey('leave-game-sheet'),
        children: [
          Text(
            'Leave lesson?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Leaving ends this attempt. Your next attempt starts a fresh game.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GoldButton(
            label: 'LEAVE LESSON',
            onPressed: () => Navigator.pop(sheetContext, true),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(sheetContext, false),
            child: const Text('KEEP PLAYING'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) _exitLesson();
  }

  @override
  Widget build(BuildContext context) {
    final phase = controller.phase;
    final reviewing =
        phase == GuidedMatchPhase.review || phase == GuidedMatchPhase.complete;
    final playing = phase == GuidedMatchPhase.match;
    final match = controller.match;
    match.animateJumps = !_noMotion;
    return PopScope<bool>(
      canPop: _leaving || reviewing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_overlayOpen && !_leaving) unawaited(_leave());
      },
      child: Scaffold(
        appBar: reviewing
            ? AppBar(title: const Text('UNIT 1 RECAP'))
            : const SingleplayerMatchHeader(),
        body: reviewing
            ? _ReviewList(
                definition: controller.definition,
                highContrast: widget.highContrast,
                encountered: controller.encountered,
                onComplete: () {
                  controller.complete();
                  if (controller.lessonComplete) _exitLesson(completed: true);
                },
              )
            : SingleplayerMatchLayout(
                controller: match,
                showCoordinates: widget.showCoordinates,
                highContrast: widget.highContrast,
                reducedMotion: _noMotion,
                playing: playing,
                onSquareTap: playing ? controller.tapSquare : null,
                onLeave: _leave,
                onHistory: _showMoves,
                onResign: playing && !match.isAnimatingJump
                    ? _confirmResign
                    : null,
                guidance: GlassPanel(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'LESSON ${controller.definition.number} · GUIDANCE',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: widget.highContrast
                                        ? CrownColors.obsidian
                                        : CrownColors.gold,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Unit 1 Rules',
                            onPressed: _showRules,
                            icon: const Icon(Icons.menu_book_outlined),
                          ),
                        ],
                      ),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          controller.feedback,
                          key: const ValueKey('guided-feedback'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(height: 1.4),
                        ),
                      ),
                      if (match.aiError != null) ...[
                        const SizedBox(height: 12),
                        GoldButton(
                          label: 'RETRY AI TURN',
                          onPressed: controller.retryAi,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _LessonSheet extends StatelessWidget {
  const _LessonSheet({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => CrownBottomSheet(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CrownSheetHandle(),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    ),
  );
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.definition,
    required this.highContrast,
    this.encountered,
    this.onComplete,
  });
  final GuidedMatchDefinition definition;
  final bool highContrast;
  final Set<ReviewConcept>? encountered;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      key: const ValueKey('unit-one-review-list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in definition.review) ...[
                GlassPanel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (encountered != null) ...[
                        Text(
                          encountered!.contains(item.concept)
                              ? 'ENCOUNTERED IN YOUR GAME'
                              : 'REFERENCE RECAP',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: highContrast
                                    ? CrownColors.obsidian
                                    : CrownColors.gold,
                              ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Semantics(
                        header: true,
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.body,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (onComplete != null) ...[
                const SizedBox(height: 8),
                GoldButton(label: 'COMPLETE LESSON', onPressed: onComplete!),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
