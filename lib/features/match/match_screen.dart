import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/crown_theme.dart';
import '../../app/crown_icon.dart';
import '../../app/crown_bottom_modal.dart';
import '../../game_engine/checkers_engine.dart';
import '../../persistence/crown_repository.dart';
import 'checkers_board.dart';
import 'game_result_summary.dart';
import 'match_controller.dart';
import 'match_result_sheet.dart';
import 'move_audio.dart';
import 'player_strip.dart';
import 'singleplayer_match_layout.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({
    required this.controller,
    this.createMoveAudio,
    super.key,
  });
  final MatchController controller;
  final MoveAudio Function()? createMoveAudio;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  CrownSettings _settings = const CrownSettings();
  bool _resultShown = false;
  MoveAudio? _moveAudio;
  late int _lastTurnCount = controller.state.turns.length;
  final ScrollController _localScrollController = ScrollController();
  Size? _lastLocalViewportSize;
  bool _localRecenterScheduled = false;

  MatchController get controller => widget.controller;
  Side get _resigningSide => controller.session.mode == MatchMode.ai
      ? controller.session.humanSide!
      : controller.state.sideToMove;

  @override
  void initState() {
    super.initState();
    controller.addListener(_changed);
    controller.landings.addListener(_landed);
    _load();
  }

  Future<void> _load() async {
    _settings = await controller.repository.loadSettings();
    if (!mounted) return;
    controller.animateJumps =
        !_settings.reducedMotion && !MediaQuery.disableAnimationsOf(context);
    if (_settings.sound) {
      _moveAudio = widget.createMoveAudio?.call() ?? MoveAudio();
      unawaited(_moveAudio!.prepare());
    }
    setState(() {});
    await controller.start();
  }

  void _changed() {
    if (!mounted) return;
    if (controller.state.turns.length != _lastTurnCount) {
      _lastTurnCount = controller.state.turns.length;
      if (_settings.haptics) HapticFeedback.selectionClick();
    }
    setState(() {});
    if (controller.state.result != null && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  @override
  void dispose() {
    controller.landings.removeListener(_landed);
    controller.removeListener(_changed);
    unawaited(_moveAudio?.dispose());
    controller.dispose();
    _localScrollController.dispose();
    super.dispose();
  }

  void _landed() {
    if (mounted && _settings.sound) unawaited(_moveAudio?.play());
  }

  void _scheduleLocalBoardCenter(Size viewportSize) {
    if (_lastLocalViewportSize == viewportSize) return;
    _lastLocalViewportSize = viewportSize;
    if (_localRecenterScheduled) return;
    _localRecenterScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _localRecenterScheduled = false;
      if (!mounted || !_localScrollController.hasClients) return;
      final position = _localScrollController.position;
      _localScrollController.jumpTo(position.maxScrollExtent / 2);
    });
  }

  Future<void> _showResult() async {
    final result = controller.state.result!;
    if (controller.session.mode == MatchMode.local) {
      await _showLocalResult(result);
      return;
    }
    await showCrownBottomModal<void>(
      context: context,
      reducedMotion:
          _settings.reducedMotion || MediaQuery.disableAnimationsOf(context),
      dismissible: false,
      builder: (sheetContext) => MatchResultSheet(
        key: const ValueKey('result-sheet'),
        result: result,
        perspective: controller.session.perspectiveSide,
        actionLabel: 'RETURN HOME',
        onAction: () {
          Navigator.pop(sheetContext);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _showLocalResult(GameResult result) async {
    void returnHome(BuildContext dialogContext) {
      Navigator.pop(dialogContext);
      Navigator.pop(context);
    }

    await showCrownBottomModal<void>(
      context: context,
      reducedMotion:
          _settings.reducedMotion || MediaQuery.disableAnimationsOf(context),
      dismissible: false,
      alignment: Alignment.center,
      builder: (dialogContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GlassPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              key: const ValueKey('local-result-overlay'),
              mainAxisSize: MainAxisSize.min,
              children: [
                RotatedBox(
                  quarterTurns: 2,
                  child: _LocalResultSummary(
                    key: const ValueKey('local-top-result'),
                    result: result,
                    side: controller.session.bottomSide.opponent,
                    onReturnHome: () => returnHome(dialogContext),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(),
                ),
                _LocalResultSummary(
                  key: const ValueKey('local-bottom-result'),
                  result: result,
                  side: controller.session.bottomSide,
                  onReturnHome: () => returnHome(dialogContext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _leave({Side? resigningSide, bool topFacing = false}) async {
    if (controller.state.result != null) return true;
    final choice = await showCrownBottomModal<_LeaveChoice>(
      context: context,
      reducedMotion:
          _settings.reducedMotion || MediaQuery.disableAnimationsOf(context),
      alignment: topFacing ? Alignment.topCenter : Alignment.bottomCenter,
      builder: (sheetContext) => _seatSheet(
        contentKey: const ValueKey('leave-game-sheet'),
        topFacing: topFacing,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CrownSheetHandle(),
            const SizedBox(height: 24),
            Text(
              'Leave game?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your position is saved after every complete turn.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GoldButton(
              label: 'SAVE & LEAVE',
              onPressed: () =>
                  Navigator.pop(sheetContext, _LeaveChoice.saveAndLeave),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () =>
                    Navigator.pop(sheetContext, _LeaveChoice.resign),
                style: TextButton.styleFrom(foregroundColor: CrownColors.error),
                child: const Text('RESIGN'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () =>
                    Navigator.pop(sheetContext, _LeaveChoice.keepPlaying),
                child: const Text('KEEP PLAYING'),
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == _LeaveChoice.resign) {
      await controller.resign(resigningSide ?? _resigningSide);
      return false;
    }
    return choice == _LeaveChoice.saveAndLeave;
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final isLocal = controller.session.mode == MatchMode.local;
    final captureRequired = const CheckersEngine()
        .legalTurns(state)
        .any((turn) => turn.isCapture);
    final width = MediaQuery.sizeOf(context).width;
    final widthBoardMax = width > 700 ? 590.0 : width - 32;
    final bottomSide = controller.session.bottomSide;
    final topSide = bottomSide.opponent;
    final statusTitle = controller.isAiThinking
        ? 'CROWN AI IS THINKING'
        : '${state.sideToMove.name.toUpperCase()} TO MOVE';
    final statusDetail = captureRequired
        ? (controller.selectedSquare == null
              ? 'Capture required'
              : 'Continue the capture')
        : 'Choose a piece, then its destination';
    return PopScope(
      canPop: state.result != null,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop &&
            await _leave(resigningSide: isLocal ? bottomSide : null) &&
            context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: isLocal ? null : const SingleplayerMatchHeader(),
        body: !isLocal
            ? SingleplayerMatchLayout(
                controller: controller,
                showCoordinates: _settings.showCoordinates,
                highContrast: _settings.highContrast,
                reducedMotion:
                    _settings.reducedMotion ||
                    MediaQuery.disableAnimationsOf(context),
                onSquareTap: controller.tapSquare,
                onLeave: () async {
                  if (await _leave() && context.mounted) Navigator.pop(context);
                },
                onHistory: () => _showMoves(),
                onResign: () => _confirmResign(),
              )
            : SafeArea(
                top: false,
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final padding = MediaQuery.paddingOf(context);
                    final symmetricInset = padding.top > padding.bottom
                        ? padding.top
                        : padding.bottom;
                    final availableHeight =
                        constraints.maxHeight - (symmetricInset * 2) - 292;
                    final minimumBoard = widthBoardMax < 180
                        ? widthBoardMax
                        : 180.0;
                    final boardSize = availableHeight.clamp(
                      minimumBoard,
                      widthBoardMax,
                    );
                    final board = SizedBox.square(
                      dimension: boardSize,
                      child: CheckersBoard(
                        pieces: controller.displayPieces,
                        selected: controller.selectedSquare,
                        destinations: controller.legalDestinations,
                        showCoordinates: _settings.showCoordinates,
                        highContrast: _settings.highContrast,
                        reducedMotion: _settings.reducedMotion,
                        bottomSide: bottomSide,
                        ownerFacingCrowns: isLocal,
                        lastTurn: state.turns.isEmpty ? null : state.turns.last,
                        mandatoryOrigins: controller.mandatoryOrigins,
                        mandatoryDestinations: controller.mandatoryDestinations,
                        emphasizeRequiredAction:
                            controller.hasSingleRequiredAction,
                        activeJump: controller.activeJump,
                        onSquareTap: controller.tapSquare,
                      ),
                    );
                    final children = _localMatchChildren(
                      context: context,
                      state: state,
                      topSide: topSide,
                      bottomSide: bottomSide,
                      statusTitle: statusTitle,
                      statusDetail: statusDetail,
                      board: board,
                    );
                    final verticalPadding = symmetricInset + 8;
                    _scheduleLocalBoardCenter(constraints.biggest);
                    return SingleChildScrollView(
                      controller: _localScrollController,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        verticalPadding,
                        16,
                        verticalPadding,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 620,
                            minHeight:
                                constraints.maxHeight - (verticalPadding * 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: children,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  List<Widget> _localMatchChildren({
    required BuildContext context,
    required GameState state,
    required Side topSide,
    required Side bottomSide,
    required String statusTitle,
    required String statusDetail,
    required Widget board,
  }) => [
    RotatedBox(
      key: const ValueKey('local-top-hud'),
      quarterTurns: 2,
      child: _LocalPlayerHud(
        seat: 'top',
        name: _nameForSide(topSide),
        side: topSide,
        active: state.sideToMove == topSide,
        pieces: state.pieces.values
            .where((piece) => piece.side == topSide)
            .length,
        statusTitle: statusTitle,
        statusDetail: statusDetail,
        onLeave: () async {
          if (await _leave(resigningSide: topSide, topFacing: true) &&
              context.mounted) {
            Navigator.pop(context);
          }
        },
        onHistory: () => _showMoves(topFacing: true),
        onResign: () => _confirmResign(side: topSide, topFacing: true),
      ),
    ),
    const SizedBox(height: 12),
    board,
    const SizedBox(height: 12),
    KeyedSubtree(
      key: const ValueKey('local-bottom-hud'),
      child: _LocalPlayerHud(
        seat: 'bottom',
        name: _nameForSide(bottomSide),
        side: bottomSide,
        active: state.sideToMove == bottomSide,
        pieces: state.pieces.values
            .where((piece) => piece.side == bottomSide)
            .length,
        statusTitle: statusTitle,
        statusDetail: statusDetail,
        onLeave: () async {
          if (await _leave(resigningSide: bottomSide) && context.mounted) {
            Navigator.pop(context);
          }
        },
        onHistory: () => _showMoves(),
        onResign: () => _confirmResign(side: bottomSide),
      ),
    ),
  ];

  Future<void> _confirmResign({Side? side, bool topFacing = false}) async {
    final resigningSide = side ?? _resigningSide;
    final resign = await showCrownBottomModal<bool>(
      context: context,
      reducedMotion:
          _settings.reducedMotion || MediaQuery.disableAnimationsOf(context),
      alignment: topFacing ? Alignment.topCenter : Alignment.bottomCenter,
      builder: (sheetContext) => _seatSheet(
        contentKey: const ValueKey('resign-sheet'),
        topFacing: topFacing,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CrownSheetHandle(),
            const SizedBox(height: 24),
            const CrownIcon(
              variant: CrownIconVariant.broken,
              size: 34,
              semanticLabel: 'Defeat',
            ),
            const SizedBox(height: 12),
            Text(
              controller.session.mode == MatchMode.local
                  ? 'Resign?'
                  : 'Resign match?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Resigning ends this match as a loss.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: CrownColors.error,
                ),
                child: const Text('RESIGN'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: const Text('KEEP PLAYING'),
              ),
            ),
          ],
        ),
      ),
    );
    if (resign == true) await controller.resign(resigningSide);
  }

  String _nameForSide(Side side) => side == Side.black
      ? controller.session.blackName
      : controller.session.whiteName;

  void _showMoves({bool topFacing = false}) => showCrownBottomModal<void>(
    context: context,
    reducedMotion:
        _settings.reducedMotion || MediaQuery.disableAnimationsOf(context),
    alignment: topFacing ? Alignment.topCenter : Alignment.bottomCenter,
    builder: (sheetContext) => _seatSheet(
      contentKey: const ValueKey('move-history-sheet'),
      topFacing: topFacing,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(child: CrownSheetHandle()),
          const SizedBox(height: 24),
          Text(
            'Move history',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          if (controller.state.turns.isEmpty)
            const Text('No moves yet.')
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: controller.state.turns.length,
                itemBuilder: (_, index) => ListTile(
                  dense: true,
                  leading: Text('${index + 1}'),
                  title: Text(controller.state.turns[index].toString()),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _seatSheet({
    required Key contentKey,
    required bool topFacing,
    required Widget child,
  }) {
    final keyedContent = KeyedSubtree(key: contentKey, child: child);
    return CrownBottomSheet(
      key: topFacing ? const ValueKey('crown-top-sheet') : null,
      topFacing: topFacing,
      child: topFacing
          ? RotatedBox(
              key: const ValueKey('crown-top-sheet-content'),
              quarterTurns: 2,
              child: keyedContent,
            )
          : keyedContent,
    );
  }
}

enum _LeaveChoice { keepPlaying, saveAndLeave, resign }

class _LocalPlayerHud extends StatelessWidget {
  const _LocalPlayerHud({
    required this.seat,
    required this.name,
    required this.side,
    required this.active,
    required this.pieces,
    required this.statusTitle,
    required this.statusDetail,
    required this.onLeave,
    required this.onHistory,
    required this.onResign,
  });

  final String seat;
  final String name;
  final Side side;
  final bool active;
  final int pieces;
  final String statusTitle;
  final String statusDetail;
  final VoidCallback onLeave;
  final VoidCallback onHistory;
  final VoidCallback onResign;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      PlayerStrip(
        name: name,
        side: side,
        isCrownAi: false,
        active: active,
        pieces: pieces,
      ),
      const SizedBox(height: 8),
      MatchActionRow(
        seat: seat,
        statusTitle: statusTitle,
        statusDetail: statusDetail,
        onLeave: onLeave,
        onHistory: onHistory,
        onResign: onResign,
      ),
    ],
  );
}

class _LocalResultSummary extends StatelessWidget {
  const _LocalResultSummary({
    required this.result,
    required this.side,
    required this.onReturnHome,
    super.key,
  });

  final GameResult result;
  final Side side;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameResultSummary(result: result, perspective: side),
        const SizedBox(height: 12),
        GoldButton(label: 'RETURN HOME', onPressed: onReturnHome),
      ],
    );
  }
}
