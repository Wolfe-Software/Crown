import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';
import '../../game_engine/crown_ai.dart';
import '../../persistence/crown_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.repository,
    this.bottomPadding = 24,
    this.onSettingsChanged,
    super.key,
  });
  final CrownRepository repository;
  final double bottomPadding;
  final ValueChanged<CrownSettings>? onSettingsChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  CrownSettings _settings = const CrownSettings();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await widget.repository.loadSettings();
    if (mounted) setState(() => _settings = value);
  }

  Future<void> _save(CrownSettings value) async {
    setState(() => _settings = value);
    widget.onSettingsChanged?.call(value);
    await widget.repository.saveSettings(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile')),
    body: SafeArea(
      top: false,
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, widget.bottomPadding),
        children: [
          GlassPanel(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Sound'),
                  subtitle: const Text('Play sounds when pieces move'),
                  value: _settings.sound,
                  onChanged: (value) => _save(_settings.copyWith(sound: value)),
                ),
                SwitchListTile(
                  title: const Text('Haptics'),
                  subtitle: const Text('Tactile move feedback'),
                  value: _settings.haptics,
                  onChanged: (value) =>
                      _save(_settings.copyWith(haptics: value)),
                ),
                SwitchListTile(
                  title: const Text('Board coordinates'),
                  value: _settings.showCoordinates,
                  onChanged: (value) =>
                      _save(_settings.copyWith(showCoordinates: value)),
                ),
                SwitchListTile(
                  title: const Text('Reduced motion'),
                  value: _settings.reducedMotion,
                  onChanged: (value) =>
                      _save(_settings.copyWith(reducedMotion: value)),
                ),
                SwitchListTile(
                  title: const Text('Increased contrast'),
                  value: _settings.highContrast,
                  onChanged: (value) =>
                      _save(_settings.copyWith(highContrast: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GlassPanel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.psychology_alt_outlined,
                color: CrownColors.gold,
              ),
              title: const Text('Reset Crown AI'),
              subtitle: const Text(
                'Return adaptive strength to its starting point.',
              ),
              onTap: () async {
                await widget.repository.saveAiProfile(const AiProfile());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Crown AI has been reset.')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    ),
  );
}
