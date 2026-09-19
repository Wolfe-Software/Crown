import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';
import '../../game_engine/checkers_engine.dart';
import 'checker_piece.dart';
import 'jump_animation.dart';
import 'move_hint.dart';
import 'square_highlight.dart';

class CheckersBoard extends StatelessWidget {
  const CheckersBoard({
    required this.pieces,
    required this.selected,
    required this.destinations,
    this.onSquareTap,
    this.showCoordinates = false,
    this.highContrast = false,
    this.reducedMotion = false,
    this.bottomSide = Side.white,
    this.ownerFacingCrowns = true,
    this.lastTurn,
    this.mandatoryOrigins = const {},
    this.mandatoryDestinations = const {},
    this.emphasizeRequiredAction = false,
    this.activeJump,
    super.key,
  });

  final Map<Square, Piece> pieces;
  final Square? selected;
  final Set<Square> destinations;
  final ValueChanged<Square>? onSquareTap;
  final bool showCoordinates;
  final bool highContrast;
  final bool reducedMotion;
  final Side bottomSide;

  /// Face-to-face games orient each crown to its owner; AI games face the viewer.
  final bool ownerFacingCrowns;
  final Turn? lastTurn;
  final Set<Square> mandatoryOrigins;
  final Set<Square> mandatoryDestinations;
  final bool emphasizeRequiredAction;
  final JumpAnimation? activeJump;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CrownColors.gold.withValues(alpha: .62),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: CrownColors.obsidian.withValues(alpha: .18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: ColoredBox(
            color: Colors.white.withValues(alpha: .1),
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                          ),
                      itemCount: 64,
                      itemBuilder: (context, index) {
                        final displayRow = index ~/ 8;
                        final displayColumn = index % 8;
                        final square = bottomSide == Side.white
                            ? Square(displayRow, displayColumn)
                            : Square(7 - displayRow, 7 - displayColumn);
                        final piece = pieces[square];
                        final isSelected = selected == square;
                        final isDestination = destinations.contains(square);
                        final isMandatoryOrigin = mandatoryOrigins.contains(
                          square,
                        );
                        final isMandatoryDestination = mandatoryDestinations
                            .contains(square);
                        final isLastMove =
                            lastTurn != null &&
                            (lastTurn!.origin == square ||
                                lastTurn!.destination == square ||
                                lastTurn!.captures.contains(square));
                        final label =
                            '${square.notation}. ${piece == null ? 'Empty' : '${piece.side.name} ${piece.rank.name}'}. ${isSelected ? 'Selected.' : ''} ${isDestination ? 'Legal destination.' : ''}';
                        return Semantics(
                          button: onSquareTap != null,
                          label: label,
                          child: GestureDetector(
                            key: ValueKey(
                              'board-square-${square.row}-${square.column}',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTap: onSquareTap == null
                                ? null
                                : () => onSquareTap!(square),
                            child: ColoredBox(
                              color: square.isPlayable
                                  ? (highContrast
                                        ? CrownColors.obsidian
                                        : CrownColors.obsidian.withValues(
                                            alpha: .28,
                                          ))
                                  : (highContrast
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: .12)),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (isLastMove)
                                    Positioned.fill(
                                      key: ValueKey(
                                        'last-move-${square.row}-${square.column}',
                                      ),
                                      child: const SquareHighlight(),
                                    ),
                                  if (isMandatoryOrigin)
                                    FractionallySizedBox(
                                      key: ValueKey(
                                        'mandatory-origin-${square.row}-${square.column}',
                                      ),
                                      widthFactor: .9,
                                      heightFactor: .9,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: CrownColors.paleGold,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: CrownColors.gold
                                                  .withValues(alpha: .35),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (isMandatoryOrigin &&
                                      emphasizeRequiredAction)
                                    FractionallySizedBox(
                                      key: ValueKey(
                                        'compelled-origin-${square.row}-${square.column}',
                                      ),
                                      widthFactor: .98,
                                      heightFactor: .98,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: highContrast
                                                ? Colors.yellow
                                                : CrownColors.gold,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (isMandatoryDestination)
                                    CaptureHint(
                                      key: ValueKey(
                                        'mandatory-destination-${square.row}-${square.column}',
                                      ),
                                      highContrast: highContrast,
                                      emphasized: emphasizeRequiredAction,
                                    ),
                                  if (isMandatoryDestination &&
                                      emphasizeRequiredAction)
                                    FractionallySizedBox(
                                      key: ValueKey(
                                        'compelled-destination-${square.row}-${square.column}',
                                      ),
                                      widthFactor: .62,
                                      heightFactor: .62,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: highContrast
                                                ? Colors.yellow
                                                : CrownColors.paleGold,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (isDestination)
                                    MoveHint(occupied: piece != null),
                                  if (piece != null)
                                    FractionallySizedBox(
                                      widthFactor: .76,
                                      heightFactor: .76,
                                      child: CheckerPiece(
                                        style: piece.side == Side.black
                                            ? CheckerPieceStyle.black
                                            : CheckerPieceStyle.white,
                                        isKing: piece.rank == PieceRank.king,
                                        crownQuarterTurns:
                                            !ownerFacingCrowns ||
                                                piece.side == bottomSide
                                            ? 0
                                            : 2,
                                        faceKey: ValueKey(
                                          'piece-face-${square.row}-${square.column}',
                                        ),
                                        selected: isSelected,
                                        reducedMotion: reducedMotion,
                                      ),
                                    ),
                                  if (showCoordinates)
                                    Positioned(
                                      key: ValueKey(
                                        'coordinate-${square.row}-${square.column}',
                                      ),
                                      left: 3,
                                      bottom: 1,
                                      child: Text(
                                        square.notation,
                                        style: TextStyle(
                                          fontSize: 8,
                                          height: 1,
                                          fontWeight: highContrast
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: square.isPlayable
                                              ? Colors.white
                                              : CrownColors.ink,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black45,
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (activeJump != null)
                    Positioned.fill(
                      child: _JumpingPieceOverlay(
                        key: ObjectKey(activeJump),
                        animation: activeJump!,
                        bottomSide: bottomSide,
                        ownerFacingCrowns: ownerFacingCrowns,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _JumpingPieceOverlay extends StatefulWidget {
  const _JumpingPieceOverlay({
    required this.animation,
    required this.bottomSide,
    required this.ownerFacingCrowns,
    super.key,
  });

  final JumpAnimation animation;
  final Side bottomSide;
  final bool ownerFacingCrowns;

  @override
  State<_JumpingPieceOverlay> createState() => _JumpingPieceOverlayState();
}

class _JumpingPieceOverlayState extends State<_JumpingPieceOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.animation.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final cell = constraints.maxWidth / 8;
        final from = _displayPosition(widget.animation.from, widget.bottomSide);
        final to = _displayPosition(widget.animation.to, widget.bottomSide);
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = Curves.easeInOutCubic.transform(_controller.value);
            final left = (from.$2 + (to.$2 - from.$2) * progress) * cell;
            final top = (from.$1 + (to.$1 - from.$1) * progress) * cell;
            final lift = 1 + .1 * (1 - (2 * progress - 1).abs());
            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: cell,
                  height: cell,
                  child: Center(
                    child: Transform.scale(
                      scale: lift,
                      child: SizedBox.square(
                        key: const ValueKey('jumping-piece'),
                        dimension: cell * .76,
                        child: CheckerPiece(
                          style: widget.animation.piece.side == Side.black
                              ? CheckerPieceStyle.black
                              : CheckerPieceStyle.white,
                          isKing: widget.animation.piece.rank == PieceRank.king,
                          crownQuarterTurns:
                              !widget.ownerFacingCrowns ||
                                  widget.animation.piece.side ==
                                      widget.bottomSide
                              ? 0
                              : 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

(int, int) _displayPosition(Square square, Side bottomSide) =>
    bottomSide == Side.white
    ? (square.row, square.column)
    : (7 - square.row, 7 - square.column);
