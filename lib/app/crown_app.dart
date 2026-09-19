import 'package:flutter/material.dart';

import '../persistence/crown_repository.dart';
import 'crown_app_shell.dart';
import 'crown_theme.dart';

class CrownApp extends StatelessWidget {
  const CrownApp({required this.repository, super.key});

  final CrownRepository repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Crown',
    debugShowCheckedModeBanner: false,
    theme: crownTheme(),
    builder: (context, child) =>
        MarbleBackground(child: child ?? const SizedBox()),
    home: CrownAppShell(repository: repository),
  );
}
