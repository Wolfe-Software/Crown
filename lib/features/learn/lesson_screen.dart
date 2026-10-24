import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/crown_bottom_modal.dart';
import '../../app/crown_theme.dart';
import '../../game_engine/checkers_engine.dart';
import '../match/checkers_board.dart';
import '../match/game_result_summary.dart';
import '../match/move_audio.dart';
import 'lesson_choice_row.dart';
import 'lesson_definition.dart';
import 'lesson_exercise_scaffold.dart';
import 'lesson_session_controller.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({
    required this.controller,
    required this.highContrast,
    required this.reducedMotion,
    this.sound = true,
    this.createMoveAudio,
    this.showCoordinates = false,
    super.key,
  });

  final LessonSessionController controller;
  final bool highContrast;
  final bool reducedMotion;
  final bool sound;
  final MoveAudio Function()? createMoveAudio;
  final bool showCoordinates;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  String? _presentedOutcomeExerciseId;
  MoveAudio? _moveAudio;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.controller.landings.addListener(_landed);
    _syncAudio();
  }

  @override
  void didUpdateWidget(covariant LessonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      oldWidget.controller.landings.removeListener(_landed);
      widget.controller.addListener(_refresh);
      widget.controller.landings.addListener(_landed);
      _presentedOutcomeExerciseId = null;
    }
    if (oldWidget.sound != widget.sound) _syncAudio();
  }

  @override
  void dispose() {
    widget.controller.landings.removeListener(_landed);
    widget.controller.removeListener(_refresh);
    unawaited(_moveAudio?.dispose());
    super.dispose();
  }

  void _syncAudio() {
    if (widget.sound) {
      _moveAudio ??= widget.createMoveAudio?.call() ?? MoveAudio();
      unawaited(_moveAudio!.prepare());
    } else {
      final audio = _moveAudio;
      _moveAudio = null;
      unawaited(audio?.dispose());
    }
  }

  void _landed() {
    if (mounted && widget.sound) unawaited(_moveAudio?.play());
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    _scheduleOutcomeSheet();
  }

  void _scheduleOutcomeSheet() {
    final outcome = widget.controller.visibleOutcome;
    final exerciseId = widget.controller.exerciseId;
    if (outcome == null || _presentedOutcomeExerciseId == exerciseId) return;
    _presentedOutcomeExerciseId = exerciseId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showOutcomeSheet(outcome, exerciseId);
    });
  }

  Future<void> _showOutcomeSheet(GameResult result, String exerciseId) async {
    if (!mounted || widget.controller.exerciseId != exerciseId) return;
    final advance = await showCrownBottomModal<bool>(
      context: context,
      reducedMotion:
          widget.reducedMotion || MediaQuery.disableAnimationsOf(context),
      dismissible: false,
      builder: (sheetContext) => CrownBottomSheet(
        key: const ValueKey('lesson-result-sheet'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CrownSheetHandle(),
            const SizedBox(height: 24),
            GameResultSummary(
              result: result,
              perspective: widget.controller.perspectiveSide,
              iconSize: 44,
            ),
            const SizedBox(height: 24),
            GoldButton(
              label: widget.controller.isFinalExercise
                  ? 'COMPLETE LESSON'
                  : 'CONTINUE',
              onPressed: () => Navigator.pop(sheetContext, true),
            ),
          ],
        ),
      ),
    );
    if (advance == true &&
        mounted &&
        widget.controller.exerciseId == exerciseId) {
      _continue();
    }
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
    final definition = controller.definition;
    return LessonExerciseScaffold(
      lessonNumber: definition.number,
      lessonName: definition.name.toUpperCase(),
      exerciseNumber: controller.exerciseNumber,
      exerciseCount: controller.exerciseCount,
      exerciseTitle: controller.title,
      instruction: controller.instruction,
      boardLabel: controller.previewLabel,
      board: CheckersBoard(
        pieces: controller.displayedPieces,
        threatRoutes: controller.visibleThreat?.routes ?? const [],
        selected: controller.selectedSquare,
        destinations: controller.destinations,
        onSquareTap: controller.acceptsInput ? controller.tapSquare : null,
        activeJump: controller.activeJump,
        lastTurn: controller.lastTurn,
        showCoordinates: widget.showCoordinates,
        highContrast: widget.highContrast,
        reducedMotion:
            widget.reducedMotion || MediaQuery.disableAnimationsOf(context),
        bottomSide: controller.perspectiveSide,
      ),
      interaction: controller.interactionType == LessonInteractionType.choice
          ? LessonChoiceRow(
              options: controller.choiceOptions,
              enabled: controller.acceptsInput,
              highContrast: widget.highContrast,
              reducedMotion: widget.reducedMotion,
              onSelected: controller.selectChoice,
            )
          : null,
      feedback: controller.feedback,
      feedbackMessages: controller.exercise.feedbackMessages,
      feedbackKey: const ValueKey('lesson-feedback'),
      exerciseComplete:
          controller.exerciseComplete || controller.canContinuePreparation,
      isFinalExercise:
          controller.isFinalExercise && !controller.canContinuePreparation,
      showCompletionAction: controller.visibleOutcome == null,
      onContinue: _continue,
    );
  }
}
