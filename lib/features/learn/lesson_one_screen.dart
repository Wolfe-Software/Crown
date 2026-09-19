import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';
import '../match/checkers_board.dart';
import 'lesson_one_controller.dart';

class LessonOneScreen extends StatefulWidget {
  const LessonOneScreen({
    required this.controller,
    required this.highContrast,
    required this.reducedMotion,
    this.showCoordinates = false,
    super.key,
  });

  final LessonOneController controller;
  final bool highContrast;
  final bool reducedMotion;
  final bool showCoordinates;

  @override
  State<LessonOneScreen> createState() => _LessonOneScreenState();
}

class _LessonOneScreenState extends State<LessonOneScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant LessonOneScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _continue() {
    widget.controller.continueExercise();
    if (widget.controller.lessonComplete && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('LESSON 1'),
            Text(
              'MEET THE BOARD',
              style: TextStyle(
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
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'EXERCISE ${controller.exerciseNumber} OF ${controller.exerciseCount}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: CrownColors.gold),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: LinearProgressIndicator(
                            value:
                                controller.exerciseNumber /
                                controller.exerciseCount,
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
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              controller.title,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            controller.instruction,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(height: 1.45),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckersBoard(
                      pieces: controller.pieces,
                      selected: controller.selectedSquare,
                      destinations: controller.destinations,
                      onSquareTap: controller.tapSquare,
                      showCoordinates: widget.showCoordinates,
                      highContrast: widget.highContrast,
                      reducedMotion:
                          widget.reducedMotion ||
                          MediaQuery.disableAnimationsOf(context),
                      bottomSide: controller.perspectiveSide,
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      key: const ValueKey('lesson-one-feedback'),
                      liveRegion: true,
                      container: true,
                      child: Text(
                        controller.feedback,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: controller.exerciseComplete
                              ? CrownColors.gold
                              : CrownColors.muted,
                          fontWeight: controller.exerciseComplete
                              ? FontWeight.w700
                              : null,
                        ),
                      ),
                    ),
                    if (controller.exerciseComplete) ...[
                      const SizedBox(height: 16),
                      GoldButton(
                        label: controller.isFinalExercise
                            ? 'COMPLETE LESSON'
                            : 'CONTINUE',
                        onPressed: _continue,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
