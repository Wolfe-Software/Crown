import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';

/// The ordinary legal destination marker used in gameplay.
class MoveHint extends StatelessWidget {
  const MoveHint({this.occupied = false, super.key});

  final bool occupied;

  @override
  Widget build(BuildContext context) => Container(
    width: occupied ? 42 : 15,
    height: occupied ? 42 : 15,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: occupied ? Colors.transparent : CrownColors.paleGold,
      border: occupied
          ? Border.all(color: CrownColors.paleGold, width: 4)
          : null,
    ),
  );
}

/// The forced-capture destination marker shared by gameplay and Learn.
class CaptureHint extends StatelessWidget {
  const CaptureHint({
    this.highContrast = false,
    this.emphasized = false,
    super.key,
  });

  final bool highContrast;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    width: emphasized ? 22 : 16,
    height: emphasized ? 22 : 16,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: CrownColors.paleGold.withValues(alpha: .85),
      border: Border.all(
        color: highContrast ? Colors.black : CrownColors.gold,
        width: emphasized ? 3 : 1.5,
      ),
    ),
  );
}
