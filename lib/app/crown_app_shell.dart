import 'package:flutter/material.dart';

import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/learn/learn_curriculum.dart';
import '../features/settings/settings_screen.dart';
import '../persistence/crown_repository.dart';
import 'crown_bottom_navigation.dart';

class CrownAppShell extends StatefulWidget {
  const CrownAppShell({required this.repository, this.learnCatalog, super.key});

  final CrownRepository repository;
  final LearnCatalog? learnCatalog;

  @override
  State<CrownAppShell> createState() => _CrownAppShellState();
}

class _CrownAppShellState extends State<CrownAppShell> {
  static const _destinations = [
    CrownNavigationDestination.crown(label: 'Play'),
    CrownNavigationDestination.asset(
      label: 'Learn',
      assetName: 'assets/LearnLogo.png',
    ),
    CrownNavigationDestination.asset(
      label: 'Feed',
      assetName: 'assets/FeedLogo.png',
    ),
    CrownNavigationDestination.asset(
      label: 'Profile',
      assetName: 'assets/ProfileLogo.png',
    ),
  ];

  int _selectedIndex = 0;
  CrownSettings _settings = const CrownSettings();
  LearnProgress _learnProgress = const LearnProgress();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLearnProgress();
  }

  Future<void> _loadSettings() async {
    final settings = await widget.repository.loadSettings();
    if (mounted) setState(() => _settings = settings);
  }

  Future<void> _loadLearnProgress() async {
    final progress = await widget.repository.loadLearnProgress();
    if (mounted) setState(() => _learnProgress = progress);
  }

  Future<void> _completeLesson(int lesson) async {
    final progress = LearnProgress(lastCompletedLesson: lesson);
    await widget.repository.saveLearnProgress(progress);
    final saved = await widget.repository.loadLearnProgress();
    if (mounted) setState(() => _learnProgress = saved);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        CrownBottomNavigation.height +
        MediaQuery.viewPaddingOf(context).bottom +
        40;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            repository: widget.repository,
            bottomPadding: bottomPadding,
          ),
          LearnScreen(
            catalog: widget.learnCatalog,
            bottomPadding: bottomPadding,
            highContrast: _settings.highContrast,
            reducedMotion: _settings.reducedMotion,
            sound: _settings.sound,
            showCoordinates: _settings.showCoordinates,
            lastCompletedLesson: _learnProgress.lastCompletedLesson,
            onLessonCompleted: _completeLesson,
          ),
          HistoryScreen(
            repository: widget.repository,
            active: _selectedIndex == 2,
            bottomPadding: bottomPadding,
          ),
          SettingsScreen(
            repository: widget.repository,
            bottomPadding: bottomPadding,
            onSettingsChanged: (settings) {
              if (mounted) setState(() => _settings = settings);
            },
          ),
        ],
      ),
      bottomNavigationBar: CrownBottomNavigation(
        destinations: _destinations,
        selectedIndex: _selectedIndex,
        highContrast: _settings.highContrast,
        onDestinationSelected: (index) {
          if (_selectedIndex != index) setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}
