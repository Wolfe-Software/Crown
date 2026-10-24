import 'package:flutter/material.dart';

import '../../app/crown_icon.dart';
import '../../app/crown_theme.dart';
import '../match/checker_piece.dart';
import 'lesson_definition.dart';

class LessonChoiceRow extends StatelessWidget {
  const LessonChoiceRow({
    required this.options,
    required this.enabled,
    required this.highContrast,
    required this.reducedMotion,
    required this.onSelected,
    super.key,
  });

  final List<LessonChoiceOptionDefinition> options;
  final bool enabled;
  final bool highContrast;
  final bool reducedMotion;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final iconSize = constraints.maxWidth < 340 ? 48.0 : 60.0;
      return Row(
        key: const ValueKey('lesson-choice-row'),
        children: [
          for (var index = 0; index < options.length; index++) ...[
            Expanded(
              child: _LessonChoiceCard(
                option: options[index],
                iconSize: iconSize,
                enabled: enabled,
                highContrast: highContrast,
                reducedMotion: reducedMotion,
                onTap: () => onSelected(options[index].id),
              ),
            ),
            if (index != options.length - 1) const SizedBox(width: 8),
          ],
        ],
      );
    },
  );
}

class _LessonChoiceCard extends StatelessWidget {
  const _LessonChoiceCard({
    required this.option,
    required this.iconSize,
    required this.enabled,
    required this.highContrast,
    required this.reducedMotion,
    required this.onTap,
  });

  final LessonChoiceOptionDefinition option;
  final double iconSize;
  final bool enabled;
  final bool highContrast;
  final bool reducedMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: option.label,
    excludeSemantics: true,
    child: Material(
      key: ValueKey('lesson-choice-${option.id}'),
      color: Colors.white.withValues(alpha: enabled ? .62 : .36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: highContrast
              ? CrownColors.ink
              : Colors.white.withValues(alpha: .9),
          width: highContrast ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: option.icon == null ? 64 : 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (option.icon != null) ...[
                  SizedBox.square(
                    dimension: iconSize,
                    child: switch (option.icon!) {
                      LessonChoiceIcon.blackChecker => CheckerPiece(
                        style: CheckerPieceStyle.black,
                        isKing: true,
                        reducedMotion: reducedMotion,
                      ),
                      LessonChoiceIcon.whiteChecker => CheckerPiece(
                        style: CheckerPieceStyle.white,
                        isKing: true,
                        reducedMotion: reducedMotion,
                      ),
                      LessonChoiceIcon.draw => CrownIcon(
                        variant: CrownIconVariant.draw,
                        size: iconSize,
                      ),
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  option.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: CrownColors.ink,
                    fontSize: option.icon == null ? 13 : 10,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
