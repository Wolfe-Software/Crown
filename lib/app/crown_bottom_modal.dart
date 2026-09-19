import 'dart:ui';

import 'package:flutter/material.dart';

import 'crown_theme.dart';

Future<T?> showCrownBottomModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required bool reducedMotion,
  bool dismissible = true,
  Alignment alignment = Alignment.bottomCenter,
  Key blurKey = const ValueKey('crown-modal-background-blur'),
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: dismissible,
  barrierLabel: dismissible
      ? MaterialLocalizations.of(context).modalBarrierDismissLabel
      : null,
  barrierColor: Colors.black.withValues(alpha: .18),
  transitionDuration: reducedMotion
      ? Duration.zero
      : const Duration(milliseconds: 250),
  pageBuilder: (routeContext, _, _) => Stack(
    children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: dismissible ? () => Navigator.pop(routeContext) : null,
          child: BackdropFilter(
            key: blurKey,
            filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: ColoredBox(color: CrownColors.ink.withValues(alpha: .08)),
          ),
        ),
      ),
      Align(
        alignment: alignment,
        child: Material(
          type: MaterialType.transparency,
          child: builder(routeContext),
        ),
      ),
    ],
  ),
);

class CrownBottomSheet extends StatelessWidget {
  const CrownBottomSheet({
    required this.child,
    this.topFacing = false,
    super.key,
  });

  final Widget child;
  final bool topFacing;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: topFacing ? Radius.zero : const Radius.circular(32),
      bottom: topFacing ? const Radius.circular(32) : Radius.zero,
    );
    return DecoratedBox(
      key: const ValueKey('crown-sheet-frame'),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: CrownColors.obsidian.withValues(alpha: .2),
            blurRadius: 30,
            offset: Offset(0, topFacing ? 8 : -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          key: const ValueKey('crown-sheet-surface-blur'),
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            key: const ValueKey('crown-sheet-surface'),
            decoration: BoxDecoration(
              color: CrownColors.ivory.withValues(alpha: .42),
              border: Border(
                top: topFacing
                    ? BorderSide.none
                    : BorderSide(color: Colors.white.withValues(alpha: .92)),
                bottom: topFacing
                    ? BorderSide(color: Colors.white.withValues(alpha: .92))
                    : BorderSide.none,
              ),
            ),
            child: SafeArea(
              top: topFacing,
              bottom: !topFacing,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  topFacing ? 28 : 16,
                  24,
                  topFacing ? 16 : 28,
                ),
                child: Align(
                  alignment: topFacing
                      ? Alignment.bottomCenter
                      : Alignment.topCenter,
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CrownSheetHandle extends StatelessWidget {
  const CrownSheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 4,
    decoration: BoxDecoration(
      color: CrownColors.muted.withValues(alpha: .25),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}
