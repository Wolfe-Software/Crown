import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/crown_theme.dart';
import '../../app/crown_icon.dart';
import '../match/checker_piece.dart';
import '../match/move_hint.dart';
import '../match/square_highlight.dart';
import 'learn_curriculum.dart';

class LessonBoard extends StatelessWidget {
  const LessonBoard({
    required this.curriculum,
    required this.onLessonSelected,
    this.highContrast = false,
    this.lastCompletedLesson = 0,
    this.reducedMotion = false,
    super.key,
  }) : assert(lastCompletedLesson >= 0 && lastCompletedLesson <= 64);

  final void Function(LearnUnit unit, LearnLesson lesson) onLessonSelected;
  final List<LearnUnit> curriculum;
  final bool highContrast;

  /// Sequential progress supplied by lesson completion, never by browsing.
  /// Zero means no lessons have been completed yet.
  final int lastCompletedLesson;
  final bool reducedMotion;

  /// Keep the unit directory the same height as the board it replaces.
  static double sizeFor(BuildContext context, double width) => math.max(
    math.max(44.0, MediaQuery.textScalerOf(context).scale(13) * 2 + 8) * 8 + 4,
    math.min(620.0, width),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = sizeFor(context, constraints.maxWidth);
      return SingleChildScrollView(
        key: const ValueKey('lesson-board-horizontal-scroll'),
        scrollDirection: Axis.horizontal,
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CrownColors.gold.withValues(alpha: .62),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CrownColors.obsidian.withValues(alpha: .18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: Column(
                      children: [
                        for (var row = 0; row < curriculum.length; row++)
                          Expanded(
                            child: Row(
                              children: [
                                for (var column = 0; column < 8; column++)
                                  Expanded(
                                    child: _square(context, row, column),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _square(BuildContext context, int row, int column) {
    final unit = curriculum[row];
    final lesson = unit.lessons[column];
    return FocusTraversalOrder(
      order: NumericFocusOrder(lesson.number.toDouble()),
      child: _LessonSquare(
        unit: unit,
        lesson: lesson,
        dark: (row + column).isOdd,
        highContrast: highContrast,
        lastCompleted: lastCompletedLesson == lesson.number,
        nextLesson:
            lastCompletedLesson < 64 &&
            lesson.number == lastCompletedLesson + 1,
        reducedMotion: reducedMotion,
        onTap: () => onLessonSelected(unit, lesson),
      ),
    );
  }
}

class _LessonSquare extends StatefulWidget {
  const _LessonSquare({
    required this.unit,
    required this.lesson,
    required this.dark,
    required this.highContrast,
    required this.lastCompleted,
    required this.nextLesson,
    required this.reducedMotion,
    required this.onTap,
  });

  final LearnUnit unit;
  final LearnLesson lesson;
  final bool dark;
  final bool highContrast;
  final bool lastCompleted;
  final bool nextLesson;
  final bool reducedMotion;
  final VoidCallback onTap;

  @override
  State<_LessonSquare> createState() => _LessonSquareState();
}

class _LessonSquareState extends State<_LessonSquare> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final lesson = widget.lesson;
    final dark = widget.dark;
    final highContrast = widget.highContrast;
    final foreground = highContrast && dark ? Colors.white : CrownColors.ink;
    return Semantics(
      key: ValueKey('lesson-${lesson.number}'),
      sortKey: OrdinalSortKey(lesson.number.toDouble()),
      button: true,
      enabled: true,
      label:
          'Unit ${unit.number}, ${unit.name}. Lesson ${lesson.number}, ${lesson.name}.${lesson.isChallenge ? ' Unit challenge.' : ''}${widget.lastCompleted ? ' Last completed lesson.' : ''}${widget.nextLesson ? ' Next lesson.' : ''}',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Material(
        color: dark
            ? (highContrast
                  ? CrownColors.obsidian
                  : CrownColors.obsidian.withValues(alpha: .28))
            : (highContrast
                  ? Colors.white
                  : Colors.white.withValues(alpha: .12)),
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _focused = focused),
          excludeFromSemantics: true,
          focusColor: CrownColors.gold.withValues(alpha: .4),
          hoverColor: CrownColors.paleGold.withValues(alpha: .3),
          highlightColor: CrownColors.gold.withValues(alpha: .35),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.nextLesson)
                Positioned.fill(
                  child: SquareHighlight(
                    key: ValueKey('next-lesson-highlight-${lesson.number}'),
                  ),
                ),
              if (widget.nextLesson)
                Center(
                  child: CaptureHint(
                    key: ValueKey('next-lesson-${lesson.number}'),
                    highContrast: highContrast,
                  ),
                ),
              if (widget.lastCompleted)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Center(
                      child: SizedBox.square(
                        dimension:
                            math.min(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ) *
                            .62,
                        child: CheckerPiece(
                          key: ValueKey('completed-lesson-${lesson.number}'),
                          style: CheckerPieceStyle.black,
                          reducedMotion: widget.reducedMotion,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 4,
                bottom: 3,
                child: Text(
                  '${lesson.number}',
                  key: ValueKey('lesson-number-${lesson.number}'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Cormorant Garamond',
                    fontSize: 13,
                    height: 1,
                    fontWeight: highContrast
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
              if (lesson.isChallenge)
                Positioned(
                  top: 5,
                  right: 5,
                  child: LessonChallengeMark(
                    key: ValueKey('lesson-challenge-${lesson.number}'),
                    size: 14,
                  ),
                ),
              if (_focused)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: DecoratedBox(
                        key: ValueKey('lesson-focus-${lesson.number}'),
                        decoration: BoxDecoration(
                          border: Border.all(color: foreground, width: 2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class LessonChallengeMark extends StatelessWidget {
  const LessonChallengeMark({this.size = 16, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => CrownIcon(size: size);
}
