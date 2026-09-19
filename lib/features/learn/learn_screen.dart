import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';
import '../../app/crown_wordmark.dart';
import 'learn_curriculum.dart';
import 'lesson_board.dart';
import 'lesson_details_sheet.dart';
import 'lesson_one_controller.dart';
import 'lesson_one_screen.dart';

enum _UnitDirectoryPhase { board, opening, list, closing }

class LearnScreen extends StatefulWidget {
  const LearnScreen({
    required this.bottomPadding,
    this.highContrast = false,
    this.reducedMotion = false,
    this.showCoordinates = false,
    this.lastCompletedLesson = 0,
    this.onLessonCompleted,
    super.key,
  }) : assert(lastCompletedLesson >= 0 && lastCompletedLesson <= 64);

  final double bottomPadding;
  final bool highContrast;
  final bool reducedMotion;
  final bool showCoordinates;

  /// Sequential completion supplied by the lesson runner. The MVP starts at zero.
  final int lastCompletedLesson;
  final Future<void> Function(int lesson)? onLessonCompleted;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  static const _directoryMotionDuration = Duration(milliseconds: 250);

  _UnitDirectoryPhase _directoryPhase = _UnitDirectoryPhase.board;
  late int _lastCompletedLesson;
  final ScrollController _unitScrollController = ScrollController();
  final GlobalKey _unitSummaryAnchorKey = GlobalKey();
  final GlobalKey _unitListPaneKey = GlobalKey();
  final GlobalKey _unitListContentKey = GlobalKey();
  final Map<int, GlobalKey> _unitListHeaderKeys = {
    for (final unit in learnCurriculum) unit.number: GlobalKey(),
  };
  int _transitionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _lastCompletedLesson = widget.lastCompletedLesson;
  }

  @override
  void didUpdateWidget(covariant LearnScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastCompletedLesson != oldWidget.lastCompletedLesson) {
      _lastCompletedLesson = widget.lastCompletedLesson;
    }
  }

  @override
  void dispose() {
    _unitScrollController.dispose();
    super.dispose();
  }

  bool get _directoryVisible => _directoryPhase != _UnitDirectoryPhase.board;
  bool get _directoryInteractive => _directoryPhase == _UnitDirectoryPhase.list;

  LearnUnit get _currentUnit {
    final next = _lastCompletedLesson < 64 ? _lastCompletedLesson + 1 : 64;
    return learnCurriculum[(next - 1) ~/ 8];
  }

  bool get _reduceDirectoryMotion =>
      widget.reducedMotion || MediaQuery.disableAnimationsOf(context);

  Rect? _rectFor(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  double _clampDirectoryOffset(double value) {
    final position = _unitScrollController.position;
    return value.clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  double? _summaryAlignedOffset() {
    if (!_unitScrollController.hasClients) return null;
    final summary = _rectFor(_unitSummaryAnchorKey);
    final current = _rectFor(_unitListHeaderKeys[_currentUnit.number]!);
    if (summary == null || current == null) return null;
    return _clampDirectoryOffset(
      _unitScrollController.offset + current.top - summary.top,
    );
  }

  double? _naturalDirectoryOffset() {
    if (!_unitScrollController.hasClients) return null;
    final pane = _rectFor(_unitListPaneKey);
    final content = _rectFor(_unitListContentKey);
    final current = _rectFor(_unitListHeaderKeys[_currentUnit.number]!);
    if (pane == null || content == null || current == null) return null;
    final offset = _unitScrollController.offset;
    final naturalStart = offset + content.top - pane.top;
    final naturalEnd = naturalStart + content.height - pane.height;
    final centered = offset + current.center.dy - pane.center.dy;
    return _clampDirectoryOffset(
      centered.clamp(
        naturalStart,
        naturalEnd < naturalStart ? naturalStart : naturalEnd,
      ),
    );
  }

  Future<void> _openUnitList() async {
    if (_directoryPhase != _UnitDirectoryPhase.board) return;
    final summaryOffset = _summaryAlignedOffset();
    final naturalOffset = _naturalDirectoryOffset();
    if (summaryOffset == null || naturalOffset == null) return;
    final generation = ++_transitionGeneration;
    _unitScrollController.jumpTo(summaryOffset);
    setState(() => _directoryPhase = _UnitDirectoryPhase.opening);
    if (_reduceDirectoryMotion) {
      _unitScrollController.jumpTo(naturalOffset);
    } else {
      await _unitScrollController.animateTo(
        naturalOffset,
        duration: _directoryMotionDuration,
        curve: Curves.easeOutCubic,
      );
    }
    if (mounted && generation == _transitionGeneration) {
      setState(() => _directoryPhase = _UnitDirectoryPhase.list);
    }
  }

  Future<void> _closeUnitList() async {
    if (_directoryPhase != _UnitDirectoryPhase.list) return;
    final summaryOffset = _summaryAlignedOffset();
    if (summaryOffset == null) return;
    final generation = ++_transitionGeneration;
    setState(() => _directoryPhase = _UnitDirectoryPhase.closing);
    if (_reduceDirectoryMotion) {
      _unitScrollController.jumpTo(summaryOffset);
    } else {
      await _unitScrollController.animateTo(
        summaryOffset,
        duration: _directoryMotionDuration,
        curve: Curves.easeInOutCubic,
      );
    }
    if (mounted && generation == _transitionGeneration) {
      setState(() => _directoryPhase = _UnitDirectoryPhase.board);
    }
  }

  Future<void> _selectLesson(LearnUnit unit, LearnLesson lesson) async {
    final action = await showLessonDetails(
      context: context,
      unit: unit,
      lesson: lesson,
      locked: lesson.number > _lastCompletedLesson + 1,
      reducedMotion: widget.reducedMotion,
    );
    if (action != LessonDetailsAction.start || lesson.number != 1 || !mounted) {
      return;
    }
    final controller = LessonOneController();
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LessonOneScreen(
          controller: controller,
          highContrast: widget.highContrast,
          reducedMotion: widget.reducedMotion,
          showCoordinates: widget.showCoordinates,
        ),
      ),
    );
    controller.dispose();
    if (completed == true && mounted) {
      setState(
        () => _lastCompletedLesson = _lastCompletedLesson < 1
            ? 1
            : _lastCompletedLesson,
      );
      await widget.onLessonCompleted?.call(1);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sidePadding = constraints.maxWidth >= 388 ? 16.0 : 8.0;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _directoryInteractive ? () => _closeUnitList() : null,
            child: CustomScrollView(
              key: const ValueKey('learn-scroll'),
              physics: _directoryVisible
                  ? const NeverScrollableScrollPhysics()
                  : null,
              slivers: [
                SliverAppBar(
                  floating: true,
                  backgroundColor: Colors.transparent,
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: CrownWordmark(
                      title: 'LEARN',
                      logo: Image.asset(
                        'assets/LearnLogo.png',
                        key: const ValueKey('learn-header-logo'),
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 34)),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    sidePadding,
                    0,
                    sidePadding,
                    widget.bottomPadding + 8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              key: const ValueKey('learn-panel-clip'),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                                bottom: Radius.circular(24),
                              ),
                              child: BackdropFilter(
                                key: const ValueKey('learn-panel-blur'),
                                filter: ImageFilter.blur(
                                  sigmaX: 14,
                                  sigmaY: 14,
                                ),
                                child: DecoratedBox(
                                  key: const ValueKey('learn-board-panel'),
                                  decoration: BoxDecoration(
                                    color: widget.highContrast
                                        ? CrownColors.ivory
                                        : CrownColors.ivory.withValues(
                                            alpha: .56,
                                          ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                      bottom: Radius.circular(24),
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: .78,
                                      ),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Visibility(
                                            key: const ValueKey(
                                              'learn-board-slot',
                                            ),
                                            visible: !_directoryVisible,
                                            maintainState: true,
                                            maintainAnimation: true,
                                            maintainSize: true,
                                            child: LessonBoard(
                                              highContrast: widget.highContrast,
                                              reducedMotion:
                                                  widget.reducedMotion ||
                                                  MediaQuery.disableAnimationsOf(
                                                    context,
                                                  ),
                                              lastCompletedLesson:
                                                  _lastCompletedLesson,
                                              onLessonSelected: _selectLesson,
                                            ),
                                          ),
                                          Padding(
                                            key: const ValueKey(
                                              'learn-unit-summary-slot',
                                            ),
                                            padding: const EdgeInsets.fromLTRB(
                                              18,
                                              18,
                                              18,
                                              20,
                                            ),
                                            child: Visibility(
                                              visible: !_directoryVisible,
                                              maintainState: true,
                                              maintainAnimation: true,
                                              maintainSize: true,
                                              child: KeyedSubtree(
                                                key: _unitSummaryAnchorKey,
                                                child: _UnitHeader(
                                                  unit: _currentUnit,
                                                  highContrast:
                                                      widget.highContrast,
                                                  expanded: false,
                                                  isSummary: true,
                                                  onTap: () => _openUnitList(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        bottom: 20,
                                        child: KeyedSubtree(
                                          key: _unitListPaneKey,
                                          child: SizedBox.expand(
                                            key: const ValueKey(
                                              'learn-unit-list-pane',
                                            ),
                                            child: IgnorePointer(
                                              ignoring: !_directoryInteractive,
                                              child: ExcludeSemantics(
                                                excluding: !_directoryVisible,
                                                child: Opacity(
                                                  opacity: _directoryVisible
                                                      ? 1
                                                      : 0,
                                                  child: LayoutBuilder(
                                                    builder: (context, pane) => SingleChildScrollView(
                                                      key: const ValueKey(
                                                        'learn-unit-list',
                                                      ),
                                                      controller:
                                                          _unitScrollController,
                                                      primary: false,
                                                      physics:
                                                          _directoryInteractive
                                                          ? const ClampingScrollPhysics()
                                                          : const NeverScrollableScrollPhysics(),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 18,
                                                          ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          SizedBox(
                                                            height:
                                                                pane.maxHeight,
                                                          ),
                                                          KeyedSubtree(
                                                            key:
                                                                _unitListContentKey,
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .stretch,
                                                              children: [
                                                                for (final unit
                                                                    in learnCurriculum)
                                                                  Padding(
                                                                    key: ValueKey(
                                                                      'unit-list-label-${unit.number}',
                                                                    ),
                                                                    padding:
                                                                        const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              16,
                                                                        ),
                                                                    child: KeyedSubtree(
                                                                      key:
                                                                          _unitListHeaderKeys[unit
                                                                              .number],
                                                                      child: Container(
                                                                        key: ValueKey(
                                                                          'unit-list-header-${unit.number}',
                                                                        ),
                                                                        child: _UnitHeader(
                                                                          unit:
                                                                              unit,
                                                                          highContrast:
                                                                              widget.highContrast,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            height:
                                                                pane.maxHeight,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _BoardFooter(directoryVisible: _directoryVisible),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _UnitHeader extends StatelessWidget {
  const _UnitHeader({
    required this.unit,
    required this.highContrast,
    this.onTap,
    this.expanded = false,
    this.isSummary = false,
  });

  final LearnUnit unit;
  final bool highContrast;
  final VoidCallback? onTap;
  final bool expanded;
  final bool isSummary;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: isSummary,
    button: onTap != null,
    expanded: onTap != null ? expanded : null,
    onTap: onTap,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          key: isSummary ? const ValueKey('learn-unit-summary') : null,
          padding: const EdgeInsets.only(left: 14),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: CrownColors.gold, width: 2)),
          ),
          // Keep the board still when browsing unit titles of different lengths.
          child: IndexedStack(
            index: unit.number - 1,
            alignment: Alignment.topLeft,
            children: [
              for (final unit in learnCurriculum)
                _UnitLabel(unit: unit, highContrast: highContrast),
            ],
          ),
        ),
      ),
    ),
  );
}

class _UnitLabel extends StatelessWidget {
  const _UnitLabel({required this.unit, required this.highContrast});
  final LearnUnit unit;
  final bool highContrast;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'UNIT ${unit.number} · LESSONS ${unit.lessons.first.number}–${unit.lessons.last.number}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: highContrast ? CrownColors.ink : CrownColors.gold,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        unit.name,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontSize: 26, height: 1.15),
      ),
    ],
  );
}

class _BoardFooter extends StatelessWidget {
  const _BoardFooter({required this.directoryVisible});

  final bool directoryVisible;

  @override
  Widget build(BuildContext context) {
    final instruction = directoryVisible
        ? 'Tap anywhere to return to the board.'
        : 'Tap a square to explore a lesson.';
    const label = 'Challenge';
    final style = Theme.of(context).textTheme.bodyMedium!
        .copyWith(fontSize: 13, height: 1.3, color: CrownColors.muted);
    final legend = Row(
      key: const ValueKey('learn-challenge-legend'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const ExcludeSemantics(child: LessonChallengeMark()),
        const SizedBox(width: 8),
        Text(label, style: style),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        double textWidth(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }

        final fits =
            textWidth(instruction) + textWidth(label) + 24 + 12 <=
            constraints.maxWidth;
        if (fits) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                instruction,
                key: const ValueKey('learn-board-hint'),
                style: style,
              ),
              legend,
            ],
          );
        }
        // Preserve the complete instruction at large accessibility text scales.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              instruction,
              key: const ValueKey('learn-board-hint'),
              style: style,
            ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: legend),
          ],
        );
      },
    );
  }
}
