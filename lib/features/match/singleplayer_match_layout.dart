import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';
import '../../game_engine/checkers_engine.dart';
import 'checkers_board.dart';
import 'match_controller.dart';
import 'player_strip.dart';

/// The same header and play surface for singleplayer and guided AI matches.
class SingleplayerMatchHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const SingleplayerMatchHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    title: Column(
      children: [
        const Text('CROWN', style: TextStyle(letterSpacing: 4, fontSize: 19)),
        Text(
          '• CHECKERS •',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: CrownColors.gold, fontSize: 9),
        ),
      ],
    ),
    automaticallyImplyLeading: false,
  );
}

class SingleplayerMatchLayout extends StatelessWidget {
  static const _controlGap = 8.0;

  const SingleplayerMatchLayout({
    required this.controller,
    required this.onSquareTap,
    required this.onLeave,
    required this.onHistory,
    required this.onResign,
    this.showCoordinates = false,
    this.highContrast = false,
    this.reducedMotion = false,
    this.playing = true,
    this.guidance,
    super.key,
  });

  final MatchController controller;
  final ValueChanged<Square>? onSquareTap;
  final VoidCallback? onLeave;
  final VoidCallback? onHistory;
  final VoidCallback? onResign;
  final bool showCoordinates;
  final bool highContrast;
  final bool reducedMotion;
  final bool playing;
  final Widget? guidance;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final session = controller.session;
    final bottom = session.bottomSide;
    final top = bottom.opponent;
    final captureRequired = const CheckersEngine()
        .legalTurns(state)
        .any((turn) => turn.isCapture);
    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = MediaQuery.sizeOf(context).width;
          final widthBoardMax = width > 700 ? 590.0 : width - 32;
          final boardSize = (constraints.maxHeight - 240).clamp(
            math.min(widthBoardMax, 180.0),
            widthBoardMax,
          );
          final bottomPadding = guidance == null
              ? 28.0
              : math.max(28.0, MediaQuery.paddingOf(context).bottom);
          final matchContent = Column(
            children: [
              PlayerStrip(
                name: session.nameForSide(top),
                side: top,
                isCrownAi: session.aiSide == top,
                active: playing && state.sideToMove == top,
                pieces: state.pieces.values
                    .where((piece) => piece.side == top)
                    .length,
                reducedMotion: reducedMotion,
              ),
              const SizedBox(height: 12),
              SizedBox.square(
                dimension: boardSize.toDouble(),
                child: CheckersBoard(
                  pieces: controller.displayPieces,
                  selected: controller.selectedSquare,
                  destinations: playing
                      ? controller.legalDestinations
                      : const {},
                  showCoordinates: showCoordinates,
                  highContrast: highContrast,
                  reducedMotion: reducedMotion,
                  bottomSide: bottom,
                  ownerFacingCrowns: false,
                  lastTurn: state.turns.lastOrNull,
                  mandatoryOrigins: playing
                      ? controller.mandatoryOrigins
                      : const {},
                  mandatoryDestinations: playing
                      ? controller.mandatoryDestinations
                      : const {},
                  emphasizeRequiredAction:
                      playing && controller.hasSingleRequiredAction,
                  activeJump: controller.activeJump,
                  onSquareTap: onSquareTap,
                ),
              ),
              const SizedBox(height: 12),
              PlayerStrip(
                name: session.nameForSide(bottom),
                side: bottom,
                isCrownAi: session.aiSide == bottom,
                active: playing && state.sideToMove == bottom,
                pieces: state.pieces.values
                    .where((piece) => piece.side == bottom)
                    .length,
                reducedMotion: reducedMotion,
              ),
              const SizedBox(height: _controlGap),
              MatchActionRow(
                seat: 'human',
                statusTitle: controller.aiError != null
                    ? 'AI TURN PAUSED'
                    : controller.isAiThinking
                    ? 'CROWN AI IS THINKING'
                    : '${state.sideToMove.name.toUpperCase()} TO MOVE',
                statusDetail: captureRequired
                    ? (controller.selectedSquare == null
                          ? 'Capture required'
                          : 'Continue the capture')
                    : 'Choose a piece, then its destination',
                onLeave: onLeave,
                onHistory: onHistory,
                onResign: onResign,
              ),
            ],
          );
          if (guidance != null) {
            final sidePadding = math.max(
              16.0,
              (constraints.maxWidth - 620) / 2,
            );
            // Fill the remaining height above the existing bottom inset. Keep
            // that inset inside the scroll content so a taller panel can scroll
            // naturally on compact screens instead of clipping at the safe area.
            return CustomScrollView(
              key: const ValueKey('singleplayer-match-scroll'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    sidePadding,
                    8,
                    sidePadding,
                    _controlGap,
                  ),
                  sliver: SliverToBoxAdapter(child: matchContent),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      child: guidance!,
                    ),
                  ),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            key: const ValueKey('singleplayer-match-scroll'),
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: matchContent,
              ),
            ),
          );
        },
      ),
    );
  }
}

class MatchActionRow extends StatelessWidget {
  const MatchActionRow({
    required this.seat,
    required this.statusTitle,
    required this.statusDetail,
    required this.onLeave,
    required this.onHistory,
    required this.onResign,
    super.key,
  });

  final String seat;
  final String statusTitle;
  final String statusDetail;
  final VoidCallback? onLeave;
  final VoidCallback? onHistory;
  final VoidCallback? onResign;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: Row(
      children: [
        IconButton(
          key: ValueKey('$seat-leave'),
          tooltip: 'Leave match',
          onPressed: onLeave,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: CrownColors.gold),
              ),
              const SizedBox(height: 2),
              Text(
                statusDetail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton(
          key: ValueKey('$seat-history'),
          tooltip: 'Move history',
          onPressed: onHistory,
          icon: const Icon(Icons.format_list_numbered_rounded),
        ),
        IconButton(
          key: ValueKey('$seat-resign'),
          tooltip: 'Resign',
          onPressed: onResign,
          icon: const Icon(Icons.flag_outlined),
        ),
      ],
    ),
  );
}
