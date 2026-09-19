import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';

/// The translucent full-square wash used by gameplay and Learn.
class SquareHighlight extends StatelessWidget {
  const SquareHighlight({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ColoredBox(color: CrownColors.paleGold.withValues(alpha: .28)),
  );
}
