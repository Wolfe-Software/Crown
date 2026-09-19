import 'dart:ui';

import 'package:flutter/material.dart';

import 'crown_icon.dart';
import 'crown_theme.dart';

class CrownNavigationDestination {
  const CrownNavigationDestination.asset({
    required this.label,
    required this.assetName,
  }) : usesCrownIcon = false;

  const CrownNavigationDestination.crown({required this.label})
    : assetName = null,
      usesCrownIcon = true;

  final String label;
  final String? assetName;
  final bool usesCrownIcon;
}

class CrownBottomNavigation extends StatelessWidget {
  const CrownBottomNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.highContrast = false,
    super.key,
  });

  static const double height = 68;

  final List<CrownNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool highContrast;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 8),
    child: Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: DecoratedBox(
            key: const ValueKey('crown-bottom-nav-surface'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: CrownColors.obsidian.withValues(alpha: .16),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: .7),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                key: const ValueKey('crown-bottom-nav-blur'),
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  key: const ValueKey('crown-bottom-nav-material'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: highContrast
                          ? const [Color(0xFFFDFBF7), CrownColors.ivory]
                          : [
                              Colors.white.withValues(alpha: .72),
                              CrownColors.ivory.withValues(alpha: .48),
                              Colors.white.withValues(alpha: .34),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: highContrast
                          ? CrownColors.ink.withValues(alpha: .45)
                          : Colors.white.withValues(alpha: .9),
                    ),
                  ),
                  child: SizedBox(
                    key: const ValueKey('crown-bottom-nav'),
                    height: height,
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < destinations.length;
                          index++
                        )
                          Expanded(
                            child: _Destination(
                              destination: destinations[index],
                              selected: selectedIndex == index,
                              highContrast: highContrast,
                              onTap: () => onDestinationSelected(index),
                            ),
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
  );
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.destination,
    required this.selected,
    required this.highContrast,
    required this.onTap,
  });

  final CrownNavigationDestination destination;
  final bool selected;
  final bool highContrast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unselectedColor = highContrast ? CrownColors.ink : CrownColors.muted;
    Widget icon = destination.usesCrownIcon
        ? const CrownIcon(size: 28)
        : SizedBox.square(
            dimension: 28,
            child: Image.asset(
              destination.assetName!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
            ),
          );
    if (!selected) {
      icon = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: Opacity(opacity: highContrast ? .78 : .56, child: icon),
      );
    }

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(height: 1),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 10,
                      letterSpacing: .4,
                      color: selected ? CrownColors.gold : unselectedColor,
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
}
