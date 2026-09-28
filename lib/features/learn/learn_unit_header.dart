import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';
import 'learn_curriculum.dart';

class LearnUnitHeader extends StatelessWidget {
  const LearnUnitHeader({
    required this.curriculum,
    required this.unit,
    required this.highContrast,
    this.onTap,
    this.expanded = false,
    this.isSummary = false,
    super.key,
  });

  final LearnUnit unit;
  final List<LearnUnit> curriculum;
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
              for (final unit in curriculum)
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
