import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';
import '../../game_engine/checkers_engine.dart';

/// Read-only annotations. Board taps always pass through to the actual pieces.
class ThreatRouteOverlay extends StatelessWidget {
  const ThreatRouteOverlay({
    required this.routes,
    required this.bottomSide,
    required this.highContrast,
    required this.occupiedSquares,
    required this.destinations,
    super.key,
  });

  final List<Turn> routes;
  final Side bottomSide;
  final bool highContrast;
  final Set<Square> occupiedSquares;
  final Set<Square> destinations;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label:
          'Opponent capture routes. ${routes.map((route) => 'From ${route.origin.notation}, land on ${route.landings.map((square) => square.notation).join(', then ')}; threatened pieces on ${route.captures.map((square) => square.notation).join(', ')}.').join(' ')}',
      child: CustomPaint(
        painter: _ThreatRoutePainter(
          routes,
          bottomSide,
          highContrast,
          occupiedSquares,
          destinations,
        ),
      ),
    ),
  );
}

class _ThreatRoutePainter extends CustomPainter {
  _ThreatRoutePainter(
    this.routes,
    this.bottomSide,
    this.highContrast,
    this.occupiedSquares,
    this.destinations,
  );
  final List<Turn> routes;
  final Side bottomSide;
  final bool highContrast;
  final Set<Square> occupiedSquares;
  final Set<Square> destinations;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    Offset center(Square square) => bottomSide == Side.white
        ? Offset((square.column + .5) * cell, (square.row + .5) * cell)
        : Offset((7.5 - square.column) * cell, (7.5 - square.row) * cell);
    final ink = Paint()
      ..color = highContrast ? Colors.yellow : CrownColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = highContrast ? 2.5 : 2;
    final outline = Paint()
      ..color = CrownColors.obsidian
      ..style = PaintingStyle.stroke
      ..strokeWidth = ink.strokeWidth + 2;
    void line(Offset start, Offset end) {
      canvas.drawLine(start, end, outline);
      canvas.drawLine(start, end, ink);
    }

    void ring(Offset point, double radius) {
      canvas.drawCircle(point, radius, outline);
      canvas.drawCircle(point, radius, ink);
    }

    final markedPieces = <Square>{};
    for (final route in routes) {
      for (final square in [route.origin, ...route.captures]) {
        if (markedPieces.add(square)) ring(center(square), cell * .43);
      }
      var from = route.origin;
      for (var index = 0; index < route.landings.length; index++) {
        final to = route.landings[index];
        final start = center(from);
        final end = center(to);
        final direction = (end - start) / (end - start).distance;
        final target = center(route.captures[index]);
        final tip = end - direction * cell * .25;
        // Leave the checker faces unobscured, including the jumped target.
        line(start + direction * cell * .45, target - direction * cell * .43);
        line(target + direction * cell * .43, tip);
        final perpendicular = Offset(-direction.dy, direction.dx);
        line(tip, tip - direction * cell * .16 + perpendicular * cell * .1);
        line(tip, tip - direction * cell * .16 - perpendicular * cell * .1);
        final cornerLabel =
            occupiedSquares.contains(to) || destinations.contains(to);
        final labelPosition = cornerLabel
            ? end + Offset(cell * .34, -cell * .34)
            : end;
        if (!cornerLabel) ring(end, cell * .21);
        final number = TextPainter(
          text: TextSpan(
            text: '${index + 1}',
            style: TextStyle(
              color: ink.color,
              fontSize: cell * (cornerLabel ? .2 : .27),
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        number.paint(
          canvas,
          labelPosition - Offset(number.width / 2, number.height / 2),
        );
        from = to;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThreatRoutePainter oldDelegate) =>
      oldDelegate.routes != routes ||
      oldDelegate.bottomSide != bottomSide ||
      oldDelegate.highContrast != highContrast ||
      oldDelegate.occupiedSquares != occupiedSquares ||
      oldDelegate.destinations != destinations;
}
