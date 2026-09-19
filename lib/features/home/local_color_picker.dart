import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/crown_icon.dart';
import '../../app/crown_bottom_modal.dart';
import '../../app/crown_theme.dart';
import '../../game_engine/checkers_engine.dart';
import '../match/checker_piece.dart';

enum ColorPickerRole { host, player }

Future<Side?> showBlurredColorPicker({
  required BuildContext context,
  required ColorPickerRole role,
  required bool reducedMotion,
}) => showCrownBottomModal<Side>(
  context: context,
  reducedMotion: reducedMotion,
  blurKey: const ValueKey('color-picker-background-blur'),
  builder: (routeContext) => LocalColorPicker(
    role: role,
    reducedMotion: reducedMotion,
    onSelected: (side) => Navigator.pop(routeContext, side),
  ),
);

class LocalColorPicker extends StatefulWidget {
  const LocalColorPicker({
    required this.onSelected,
    this.role = ColorPickerRole.host,
    this.randomSideResolver,
    this.reducedMotion = false,
    this.flipDuration = const Duration(milliseconds: 1200),
    this.resultDuration = const Duration(milliseconds: 700),
    super.key,
  });

  final ValueChanged<Side> onSelected;
  final ColorPickerRole role;
  final Side Function()? randomSideResolver;
  final bool reducedMotion;
  final Duration flipDuration;
  final Duration resultDuration;

  @override
  State<LocalColorPicker> createState() => _LocalColorPickerState();
}

class _LocalColorPickerState extends State<LocalColorPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.flipDuration,
  );
  Side? _assignedSide;
  bool _isAssigning = false;
  bool _hasLanded = false;
  bool _didComplete = false;

  bool get _isPlayer => widget.role == ColorPickerRole.player;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(Side side) {
    if (_isAssigning || _didComplete) return;
    _didComplete = true;
    widget.onSelected(side);
  }

  Future<void> _selectRandom() async {
    if (_isAssigning || _didComplete) return;
    final side =
        widget.randomSideResolver?.call() ??
        (math.Random().nextBool() ? Side.black : Side.white);
    setState(() {
      _assignedSide = side;
      _isAssigning = true;
    });

    if (widget.reducedMotion) {
      await Future<void>.delayed(widget.flipDuration);
    } else {
      await _controller.forward(from: 0);
    }
    if (!mounted) return;
    setState(() => _hasLanded = true);

    await Future<void>.delayed(widget.resultDuration);
    if (!mounted || _didComplete) return;
    _didComplete = true;
    widget.onSelected(side);
  }

  @override
  Widget build(BuildContext context) => CrownBottomSheet(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CrownSheetHandle(),
        const SizedBox(height: 22),
        const CrownIcon(size: 30, semanticLabel: 'Crown'),
        const SizedBox(height: 10),
        Text(
          _isPlayer ? 'Choose your color' : 'Choose host color',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          _isAssigning
              ? 'The first move belongs to Black.'
              : _isPlayer
              ? 'Your pieces stay at the bottom of the board.'
              : 'The host stays at the bottom of the board.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: CrownColors.muted),
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: widget.reducedMotion
              ? const Duration(milliseconds: 150)
              : const Duration(milliseconds: 250),
          child: _isAssigning ? _randomStage() : _choices(),
        ),
      ],
    ),
  );

  Widget _choices() => Row(
    key: const ValueKey('color-choices'),
    children: [
      Expanded(
        child: _ColorChoice(
          label: 'BLACK',
          description: _isPlayer ? 'You play Black' : 'Host plays Black',
          style: CheckerPieceStyle.black,
          onTap: () => _select(Side.black),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ColorChoice(
          label: 'WHITE',
          description: _isPlayer ? 'You play White' : 'Host plays White',
          style: CheckerPieceStyle.white,
          onTap: () => _select(Side.white),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ColorChoice(
          label: 'RANDOM',
          description: 'Flip for a color',
          style: CheckerPieceStyle.split,
          onTap: _selectRandom,
        ),
      ),
    ],
  );

  Widget _randomStage() {
    final piece = SizedBox.square(
      dimension: 92,
      child: widget.reducedMotion
          ? AnimatedSwitcher(
              key: const ValueKey('random-piece-reduced-transition'),
              duration: const Duration(milliseconds: 150),
              child: CheckerPiece(
                key: ValueKey(_hasLanded ? _assignedSide : 'split'),
                style: _hasLanded
                    ? _styleFor(_assignedSide!)
                    : CheckerPieceStyle.split,
              ),
            )
          : AnimatedBuilder(
              key: const ValueKey('random-piece-flip'),
              animation: _controller,
              builder: (context, _) {
                final angle = _controller.value * math.pi * 6;
                final phase = (_controller.value * 6).floor();
                final style = _hasLanded
                    ? _styleFor(_assignedSide!)
                    : _controller.value < .06
                    ? CheckerPieceStyle.split
                    : phase.isEven
                    ? _styleFor(_assignedSide!)
                    : _styleFor(_assignedSide!.opponent);
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0018)
                    ..rotateY(angle),
                  child: CheckerPiece(style: style),
                );
              },
            ),
    );
    return Column(
      key: const ValueKey('random-stage'),
      children: [
        const SizedBox(height: 4),
        piece,
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            _hasLanded
                ? '${_isPlayer ? 'YOU PLAY' : 'HOST PLAYS'} ${_assignedSide!.name.toUpperCase()}'
                : 'CHOOSING YOUR COLOR',
            key: ValueKey(_hasLanded),
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: CrownColors.gold, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.label,
    required this.description,
    required this.style,
    required this.onTap,
  });

  final String label;
  final String description;
  final CheckerPieceStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: description,
    child: Material(
      color: Colors.white.withValues(alpha: .62),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.white.withValues(alpha: .9)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: 64, child: CheckerPiece(style: style)),
              const SizedBox(height: 15),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: CrownColors.ink, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

CheckerPieceStyle _styleFor(Side side) =>
    side == Side.black ? CheckerPieceStyle.black : CheckerPieceStyle.white;
