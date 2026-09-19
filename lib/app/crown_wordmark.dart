import 'package:flutter/material.dart';

/// Shared stacked logo and serif wordmark used by the main pages.
class CrownWordmark extends StatelessWidget {
  const CrownWordmark({
    required this.logo,
    required this.title,
    this.subtitle,
    super.key,
  });

  final Widget logo;
  final String title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      logo,
      const SizedBox(height: 8),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(title, style: Theme.of(context).textTheme.displayLarge),
      ),
      if (subtitle != null) ...[const SizedBox(height: 12), subtitle!],
    ],
  );
}
