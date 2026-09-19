import 'dart:ui';

import 'package:flutter/material.dart';

abstract final class CrownColors {
  static const ivory = Color(0xFFF5F0E8);
  static const parchment = Color(0xFFE6DCCB);
  static const ink = Color(0xFF1D1A17);
  static const muted = Color(0xFF6D6964);
  static const gold = Color(0xFFB8842E);
  static const error = Color(0xFFB65454);
  static const paleGold = Color(0xFFE4C985);
  static const obsidian = Color(0xFF211F1D);
  static const marble = Color(0xFFF9F7F2);
}

ThemeData crownTheme({bool highContrast = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: CrownColors.gold,
    brightness: Brightness.light,
    surface: CrownColors.ivory,
    onSurface: CrownColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: 'Cormorant Garamond',
    fontFamilyFallback: const ['Times New Roman', 'serif'],
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 48, height: .95, letterSpacing: 7),
      headlineLarge: TextStyle(fontSize: 36, height: 1.05),
      headlineMedium: TextStyle(fontSize: 28, height: 1.1),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontFamily: '.SF Pro Text', fontSize: 17),
      bodyMedium: TextStyle(fontFamily: '.SF Pro Text', fontSize: 15),
      labelLarge: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: CrownColors.ink,
      elevation: 0,
      centerTitle: true,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? CrownColors.gold
            : CrownColors.marble,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? CrownColors.paleGold.withValues(alpha: .65)
            : CrownColors.muted.withValues(alpha: .25),
      ),
    ),
    dividerColor: highContrast
        ? CrownColors.ink
        : CrownColors.ink.withValues(alpha: .1),
  );
}

class MarbleBackground extends StatelessWidget {
  const MarbleBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: CrownColors.ivory,
      image: DecorationImage(
        image: AssetImage('assets/MarbleBackground.png'),
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    ),
    child: child,
  );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Material(
        color: Colors.white.withValues(alpha: .56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: Colors.white.withValues(alpha: .78)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    ),
  );
}

class GoldButton extends StatelessWidget {
  const GoldButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) =>
      MetalButton(label: label, onPressed: onPressed, icon: icon);
}

enum MetalFinish { gold, silver }

class MetalButton extends StatelessWidget {
  const MetalButton({
    required this.label,
    required this.onPressed,
    this.finish = MetalFinish.gold,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final MetalFinish finish;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: ValueKey('metal-surface-${finish.name}'),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      // A single top-left highlight keeps the light source unambiguous.
      gradient: RadialGradient(
        center: Alignment.topLeft,
        radius: finish == MetalFinish.gold ? 5.5 : 1.55,
        stops: const [0, .34, .62, 1],
        colors: finish == MetalFinish.gold
            ? const [
                Color(0xFFE5C85E),
                Color(0xFFDDB53F),
                Color(0xFFD2A62F),
                Color(0xFFC2983A),
              ]
            : const [
                Color(0xFFD5D4CE),
                Color(0xFFC4C4BE),
                Color(0xFFAEB0AD),
                Color(0xFF929795),
              ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: .42)),
      boxShadow: [
        BoxShadow(
          color:
              (finish == MetalFinish.gold
                      ? CrownColors.gold
                      : CrownColors.obsidian)
                  .withValues(alpha: onPressed == null ? .08 : .16),
          blurRadius: onPressed == null ? 7 : 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              key: ValueKey('metal-brush-${finish.name}'),
              painter: _MetalBrushPainter(finish),
            ),
          ),
          FilledButton.icon(
            onPressed: onPressed,
            icon: icon == null ? const SizedBox.shrink() : Icon(icon),
            label: Text(label),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: CrownColors.ink,
              disabledForegroundColor: CrownColors.ink,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MetalBrushPainter extends CustomPainter {
  const _MetalBrushPainter(this.finish);

  final MetalFinish finish;

  @override
  void paint(Canvas canvas, Size size) {
    final bright = Paint()
      ..color = Colors.white.withValues(
        alpha: finish == MetalFinish.gold ? .022 : .024,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = .5;
    final shadow = Paint()
      ..color = CrownColors.ink.withValues(alpha: .01)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .4;

    final maximumRadius = Offset(size.width, size.height).distance;
    var radius = 5.0;
    var index = 0;
    while (radius < maximumRadius) {
      canvas.drawCircle(Offset.zero, radius, bright);
      canvas.drawCircle(Offset.zero, radius + .8, shadow);
      radius += index.isEven ? 5.0 : 5.75;
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant _MetalBrushPainter oldDelegate) =>
      finish != oldDelegate.finish;
}
