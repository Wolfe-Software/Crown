import 'dart:async';

import 'package:crown/features/match/match_controller.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:crown/persistence/crown_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects a piece and commits a legal local turn', () async {
    final repository = MemoryCrownRepository();
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Black',
        whiteName: 'White',
      ),
      repository: repository,
    );

    await controller.tapSquare(const Square(2, 1));
    expect(controller.selectedSquare, const Square(2, 1));
    expect(
      controller.legalDestinations,
      containsAll(const [Square(3, 0), Square(3, 2)]),
    );

    await controller.tapSquare(const Square(3, 0));
    expect(controller.state.sideToMove, Side.white);
    expect(controller.state.pieces[const Square(3, 0)], const Piece.blackMan());
    expect((await repository.loadActiveMatch())?.state, controller.state);
  });

  test('requires every landing in a multi-capture turn', () async {
    final state = GameState.custom(
      sideToMove: Side.black,
      pieces: {
        const Square(1, 0): const Piece.blackMan(),
        const Square(2, 1): const Piece.whiteMan(),
        const Square(4, 3): const Piece.whiteMan(),
      },
    );
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Black',
        whiteName: 'White',
        initialState: state,
      ),
      repository: MemoryCrownRepository(),
    );

    await controller.tapSquare(const Square(1, 0));
    await controller.tapSquare(const Square(3, 2));
    expect(controller.state.sideToMove, Side.black);
    expect(controller.legalDestinations, {const Square(5, 4)});
    expect(controller.previewPieces[const Square(2, 1)], isNull);

    await controller.tapSquare(const Square(5, 4));
    expect(controller.state.sideToMove, Side.white);
    expect(controller.state.pieces[const Square(5, 4)], const Piece.blackMan());
  });

  test('resignation closes the active match and adds history', () async {
    final repository = MemoryCrownRepository();
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Black',
        whiteName: 'White',
      ),
      repository: repository,
    );

    await controller.resign(Side.black);

    expect(controller.state.result?.winner, Side.white);
    expect(await repository.loadActiveMatch(), isNull);
    expect(await repository.loadHistory(), hasLength(1));
  });

  test('AI move waits for the minimum visible turn duration', () async {
    final delayGate = Completer<void>();
    Duration? requestedDelay;
    late MatchController controller;
    controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.ai,
        humanSide: Side.white,
        bottomSide: Side.white,
        blackName: 'Crown AI',
        whiteName: 'You',
      ),
      repository: MemoryCrownRepository(),
      aiMoveChooser: (state, profile) async =>
          const CheckersEngine().legalTurns(state).first,
      minimumAiTurnDuration: const Duration(milliseconds: 800),
      aiDelay: (duration) {
        requestedDelay = duration;
        return delayGate.future;
      },
    );

    final start = controller.start();
    await Future<void>.delayed(Duration.zero);

    expect(requestedDelay, const Duration(milliseconds: 800));
    expect(controller.isAiThinking, isTrue);
    expect(controller.state.turns, isEmpty);

    delayGate.complete();
    await start;
    expect(controller.state.turns, hasLength(1));
    expect(controller.isAiThinking, isFalse);
  });

  test('exposes every mandatory capture origin and first landing', () {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Host',
        whiteName: 'Guest',
        initialState: GameState.custom(
          sideToMove: Side.black,
          pieces: {
            const Square(2, 1): const Piece.blackMan(),
            const Square(2, 5): const Piece.blackMan(),
            const Square(3, 2): const Piece.whiteMan(),
            const Square(3, 6): const Piece.whiteMan(),
          },
        ),
      ),
      repository: MemoryCrownRepository(),
    );

    expect(controller.mandatoryOrigins, {
      const Square(2, 1),
      const Square(2, 5),
    });
    expect(controller.mandatoryDestinations, {
      const Square(4, 3),
      const Square(4, 7),
    });
    expect(controller.hasSingleRequiredAction, isFalse);
  });

  test('identifies a single compelled capture action', () {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Host',
        whiteName: 'Guest',
        initialState: GameState.custom(
          sideToMove: Side.black,
          pieces: {
            const Square(2, 1): const Piece.blackMan(),
            const Square(3, 2): const Piece.whiteMan(),
          },
        ),
      ),
      repository: MemoryCrownRepository(),
    );

    expect(controller.mandatoryOrigins, {const Square(2, 1)});
    expect(controller.mandatoryDestinations, {const Square(4, 3)});
    expect(controller.hasSingleRequiredAction, isTrue);
  });

  test('identifies a forced continuation during a multi-capture', () async {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Host',
        whiteName: 'Guest',
        initialState: GameState.custom(
          sideToMove: Side.black,
          pieces: {
            const Square(1, 0): const Piece.blackMan(),
            const Square(2, 1): const Piece.whiteMan(),
            const Square(4, 3): const Piece.whiteMan(),
          },
        ),
      ),
      repository: MemoryCrownRepository(),
    );

    await controller.tapSquare(const Square(1, 0));
    await controller.tapSquare(const Square(3, 2));

    expect(controller.mandatoryOrigins, {const Square(3, 2)});
    expect(controller.mandatoryDestinations, {const Square(5, 4)});
    expect(controller.hasSingleRequiredAction, isTrue);
  });

  test('tapping an unambiguous mandatory destination makes the move', () async {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Host',
        whiteName: 'Guest',
        initialState: GameState.custom(
          sideToMove: Side.black,
          pieces: {
            const Square(2, 1): const Piece.blackMan(),
            const Square(3, 2): const Piece.whiteMan(),
            const Square(7, 6): const Piece.whiteMan(),
          },
        ),
      ),
      repository: MemoryCrownRepository(),
    );

    await controller.tapSquare(const Square(4, 3));

    expect(controller.state.turns, hasLength(1));
    expect(controller.state.pieces[const Square(4, 3)], const Piece.blackMan());
    expect(controller.state.sideToMove, Side.white);
  });

  test('does not infer a source when two pieces share a destination', () async {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Host',
        whiteName: 'Guest',
        initialState: GameState.custom(
          sideToMove: Side.black,
          pieces: {
            const Square(2, 1): const Piece.blackMan(),
            const Square(2, 5): const Piece.blackMan(),
            const Square(3, 2): const Piece.whiteMan(),
            const Square(3, 4): const Piece.whiteMan(),
          },
        ),
      ),
      repository: MemoryCrownRepository(),
    );

    await controller.tapSquare(const Square(4, 3));

    expect(controller.state.turns, isEmpty);
    expect(controller.selectedSquare, isNull);
    expect(controller.state.pieces[const Square(2, 1)], isNotNull);
    expect(controller.state.pieces[const Square(2, 5)], isNotNull);
  });

  test(
    'destination-first capture continues when later branches remain',
    () async {
      final controller = MatchController(
        session: MatchSession.newGame(
          mode: MatchMode.local,
          blackName: 'Host',
          whiteName: 'Guest',
          initialState: GameState.custom(
            sideToMove: Side.black,
            pieces: {
              const Square(1, 2): const Piece.blackMan(),
              const Square(2, 3): const Piece.whiteMan(),
              const Square(4, 3): const Piece.whiteMan(),
              const Square(4, 5): const Piece.whiteMan(),
            },
          ),
        ),
        repository: MemoryCrownRepository(),
      );

      await controller.tapSquare(const Square(3, 4));

      expect(controller.state.turns, isEmpty);
      expect(controller.selectedSquare, const Square(3, 4));
      expect(controller.legalDestinations, {
        const Square(5, 2),
        const Square(5, 6),
      });
    },
  );

  test('ordinary destinations still require selecting a piece first', () async {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Host',
        whiteName: 'Guest',
      ),
      repository: MemoryCrownRepository(),
    );

    await controller.tapSquare(const Square(3, 0));

    expect(controller.state.turns, isEmpty);
    expect(controller.selectedSquare, isNull);
  });

  test('human capture waits for its jump animation before mutation', () async {
    final gate = Completer<void>();
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Host',
        whiteName: 'Guest',
        initialState: GameState.custom(
          sideToMove: Side.black,
          pieces: {
            const Square(2, 1): const Piece.blackMan(),
            const Square(3, 2): const Piece.whiteMan(),
            const Square(7, 6): const Piece.whiteMan(),
          },
        ),
      ),
      repository: MemoryCrownRepository(),
      animateJumps: true,
      jumpDelay: (_) => gate.future,
    );

    await controller.tapSquare(const Square(2, 1));
    final move = controller.tapSquare(const Square(4, 3));
    await Future<void>.delayed(Duration.zero);

    expect(controller.isAnimatingJump, isTrue);
    expect(controller.activeJump?.from, const Square(2, 1));
    expect(controller.activeJump?.to, const Square(4, 3));
    expect(controller.displayPieces[const Square(2, 1)], isNull);
    expect(controller.displayPieces[const Square(3, 2)], isNotNull);
    expect(controller.state.turns, isEmpty);

    gate.complete();
    await move;
    expect(controller.isAnimatingJump, isFalse);
    expect(controller.activeJump, isNull);
    expect(controller.state.pieces[const Square(4, 3)], const Piece.blackMan());
    expect(controller.state.pieces[const Square(3, 2)], isNull);
  });

  test('AI multi-capture animates every jump in order', () async {
    final jumps = <String>[];
    final state = GameState.custom(
      sideToMove: Side.black,
      pieces: {
        const Square(1, 0): const Piece.blackMan(),
        const Square(2, 1): const Piece.whiteMan(),
        const Square(4, 3): const Piece.whiteMan(),
        const Square(7, 6): const Piece.whiteMan(),
      },
    );
    late MatchController controller;
    controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.ai,
        humanSide: Side.white,
        blackName: 'Crown AI',
        whiteName: 'You',
        initialState: state,
      ),
      repository: MemoryCrownRepository(),
      aiMoveChooser: (state, profile) async =>
          const CheckersEngine().legalTurns(state).single,
      minimumAiTurnDuration: Duration.zero,
      animateJumps: true,
      jumpDelay: (_) async {
        final jump = controller.activeJump!;
        jumps.add('${jump.from}-${jump.to}');
      },
    );

    await controller.start();

    expect(jumps, ['a7-c5', 'c5-e3']);
    expect(controller.state.turns, hasLength(1));
  });
}
