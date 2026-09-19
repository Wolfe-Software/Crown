import 'package:flutter/material.dart';

enum CrownIconVariant { normal, broken, jeweled, draw }

class CrownIcon extends StatelessWidget {
  const CrownIcon({
    this.variant = CrownIconVariant.normal,
    this.size = 24,
    this.semanticLabel,
    super.key,
  });

  final CrownIconVariant variant;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipRect(
      child: Transform.scale(
        scale: variant == CrownIconVariant.jeweled ? 1 : 1.2,
        child: Image.asset(
          switch (variant) {
            CrownIconVariant.normal => 'assets/CrownLogo.png',
            CrownIconVariant.broken => 'assets/BrokenCrownLogo.png',
            CrownIconVariant.jeweled => 'assets/JeweledCrownLogo.png',
            CrownIconVariant.draw => 'assets/DrawLogo.png',
          },
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: semanticLabel,
          excludeFromSemantics: semanticLabel == null,
        ),
      ),
    ),
  );
}
