import 'package:flutter/material.dart';

import '../../app/crown_bottom_modal.dart';
import '../../app/crown_theme.dart';
import 'learn_curriculum.dart';
import 'learn_unit_header.dart';

enum LessonDetailsAction { start }

Future<LessonDetailsAction?> showLessonDetails({
  required BuildContext context,
  required LearnUnit unit,
  required LearnLesson lesson,
  required bool locked,
  required bool reducedMotion,
  required bool highContrast,
}) => showCrownBottomModal<LessonDetailsAction>(
  context: context,
  reducedMotion: reducedMotion || MediaQuery.disableAnimationsOf(context),
  builder: (sheetContext) => SafeArea(
    bottom: false,
    child: SingleChildScrollView(
      child: CrownBottomSheet(
        key: const ValueKey('lesson-details-sheet'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 48),
                const Expanded(child: Center(child: CrownSheetHandle())),
                IconButton(
                  tooltip: 'Close lesson details',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LearnUnitHeader(unit: unit, highContrast: highContrast),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),
            Text(
              'LESSON ${lesson.number}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: CrownColors.gold),
            ),
            const SizedBox(height: 10),
            Semantics(
              header: true,
              child: Text(
                lesson.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              lesson.objective,
              key: const ValueKey('lesson-objective'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: CrownColors.muted, height: 1.45),
            ),
            const SizedBox(height: 28),
            if (locked)
              const MetalButton(
                label: 'LOCKED',
                finish: MetalFinish.silver,
                onPressed: null,
              )
            else if (lesson.status == LessonStatus.available)
              GoldButton(
                label: 'START',
                onPressed: () =>
                    Navigator.pop(sheetContext, LessonDetailsAction.start),
              ),
            if (!locked && lesson.status == LessonStatus.planned)
              const MetalButton(
                label: 'COMING SOON',
                finish: MetalFinish.silver,
                onPressed: null,
              ),
          ],
        ),
      ),
    ),
  ),
);
