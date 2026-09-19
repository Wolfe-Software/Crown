import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';
import '../../app/crown_icon.dart';
import '../../app/crown_wordmark.dart';
import '../../game_engine/checkers_engine.dart';
import '../../persistence/crown_repository.dart';
import '../match/checker_piece.dart';
import '../match/match_controller.dart';
import '../match/match_screen.dart';
import 'local_color_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    this.bottomPadding = 48,
    super.key,
  });

  final CrownRepository repository;
  final double bottomPadding;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MatchSession? _active;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final active = await widget.repository.loadActiveMatch();
    if (mounted) {
      setState(() => _active = active);
    }
  }

  Future<void> _openMatch(MatchSession session) async {
    final controller = MatchController(
      session: session,
      repository: widget.repository,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchScreen(controller: controller),
      ),
    );
    await _refresh();
  }

  Future<void> _newAiGame() async {
    if (_active != null) {
      final replace = await _confirmReplace();
      if (!replace) return;
    }
    final humanSide = await _pickSide(ColorPickerRole.player);
    if (humanSide == null || !mounted) return;
    await _openMatch(
      MatchSession.newGame(
        mode: MatchMode.ai,
        humanSide: humanSide,
        bottomSide: humanSide,
        blackName: humanSide == Side.black ? 'You' : 'Crown AI',
        whiteName: humanSide == Side.white ? 'You' : 'Crown AI',
      ),
    );
  }

  Future<void> _newLocalGame() async {
    if (_active != null) {
      final replace = await _confirmReplace();
      if (!replace) return;
    }
    final hostSide = await _pickSide(ColorPickerRole.host);
    if (hostSide == null || !mounted) return;
    await _openMatch(
      MatchSession.newGame(
        mode: MatchMode.local,
        bottomSide: hostSide,
        blackName: hostSide == Side.black ? 'Host' : 'Guest',
        whiteName: hostSide == Side.white ? 'Host' : 'Guest',
      ),
    );
  }

  Future<Side?> _pickSide(ColorPickerRole role) async {
    if (!mounted) return null;
    final settings = await widget.repository.loadSettings();
    if (!mounted) return null;
    return showBlurredColorPicker(
      context: context,
      role: role,
      reducedMotion:
          settings.reducedMotion || MediaQuery.disableAnimationsOf(context),
    );
  }

  Future<bool> _confirmReplace() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Begin a new match?'),
          content: const Text('Your current match will be replaced.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Playing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('New Match'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      top: false,
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(floating: true, backgroundColor: Colors.transparent),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, widget.bottomPadding),
            sliver: SliverList.list(
              children: [
                const _Wordmark(),
                const SizedBox(height: 34),
                if (_active != null) ...[
                  GlassPanel(
                    onTap: () => _openMatch(_active!),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          color: CrownColors.gold,
                          size: 34,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Continue Match',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                _active!.mode == MatchMode.ai
                                    ? 'Against Crown AI'
                                    : 'Local multiplayer',
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _HeroPlayCard(onTap: _newAiGame),
                const SizedBox(height: 16),
                _ModeCard(
                  icon: const _MultiplayerCheckersIcon(),
                  title: 'Local Multiplayer',
                  subtitle: 'Share the board, face to face',
                  onTap: _newLocalGame,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => CrownWordmark(
    logo: const CrownIcon(size: 42, semanticLabel: 'Crown'),
    title: 'CROWN',
    subtitle: Text(
      '• CHECKERS •',
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: CrownColors.gold),
    ),
  );
}

class _HeroPlayCard extends StatelessWidget {
  const _HeroPlayCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassPanel(
    onTap: onTap,
    padding: EdgeInsets.zero,
    child: Container(
      constraints: const BoxConstraints(minHeight: 210),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .65),
            CrownColors.paleGold.withValues(alpha: .25),
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Play Crown AI',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('A thoughtful opponent that grows with your game.'),
                const SizedBox(height: 24),
                SizedBox(
                  width: 150,
                  child: GoldButton(
                    label: 'PLAY',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: onTap,
                  ),
                ),
              ],
            ),
          ),
          const CrownIcon(variant: CrownIconVariant.jeweled, size: 92),
        ],
      ),
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassPanel(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          key: const ValueKey('multiplayer-icon-badge'),
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CrownColors.gold.withValues(alpha: .12),
          ),
          child: icon,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              Text(subtitle),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward_rounded),
      ],
    ),
  );
}

class _MultiplayerCheckersIcon extends StatelessWidget {
  const _MultiplayerCheckersIcon();

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox.square(
      key: ValueKey('multiplayer-checkers-icon'),
      dimension: 46,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: 32,
            height: 32,
            child: CheckerPiece(style: CheckerPieceStyle.black),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            width: 32,
            height: 32,
            child: CheckerPiece(style: CheckerPieceStyle.white),
          ),
        ],
      ),
    ),
  );
}
