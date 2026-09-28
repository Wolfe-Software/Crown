import 'dart:async';

import 'package:crown/app/crown_bottom_modal.dart';
import 'package:crown/app/crown_theme.dart';
import 'package:crown/features/learn/guided_match_controller.dart';
import 'package:crown/features/learn/guided_match_screen.dart';
import 'package:crown/features/learn/lesson_asset_loader.dart';
import 'package:crown/features/learn/lesson_definition.dart';
import 'package:crown/features/match/checkers_board.dart';
import 'package:crown/features/match/match_controller.dart';
import 'package:crown/features/match/match_screen.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:crown/persistence/crown_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GuidedMatchDefinition definition;
  setUpAll(() async {
    final catalog = await LessonAssetLoader().loadCatalog(
      'assets/learn/catalog.json',
    );
    definition = catalog.definitions['lesson-008']! as GuidedMatchDefinition;
  });

  Future<GuidedMatchController> pumpLesson(
    WidgetTester tester, {
    GameState? state,
    double scale = 1,
    AiMoveChooser? ai,
    bool reducedMotion = true,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    final controller = GuidedMatchController(
      definition: definition,
      initialState: state,
      reducedMotion: reducedMotion,
      minimumAiTurnDuration: Duration.zero,
      aiMoveChooser:
          ai ??
          (state, _) async => const CheckersEngine().legalTurns(state).first,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: crownTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale), padding: padding),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => GuidedMatchScreen(
                    controller: controller,
                    highContrast: true,
                    reducedMotion: reducedMotion,
                    showCoordinates: true,
                  ),
                ),
              ),
              child: const Text('OPEN LESSON'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN LESSON'));
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Finder matchScrollable() => find
      .descendant(
        of: find.byKey(const ValueKey('singleplayer-match-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> revealGuidance(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        150,
        scrollable: matchScrollable(),
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> action(WidgetTester tester, String tooltip) async {
    await revealGuidance(tester, find.byTooltip(tooltip));
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  final winningPosition = GameState.custom(
    sideToMove: Side.black,
    pieces: {
      const Square(2, 1): const Piece.blackMan(),
      const Square(3, 2): const Piece.whiteMan(),
    },
  );

  testWidgets(
    'introduction is a bottom sheet over the inactive singleplayer board',
    (tester) async {
      final controller = await pumpLesson(tester);
      expect(
        find.byKey(const ValueKey('lesson-introduction-sheet')),
        findsOneWidget,
      );
      expect(find.byType(CrownBottomSheet), findsOneWidget);
      expect(find.text(definition.introduction), findsOneWidget);
      expect(find.text('CROWN'), findsOneWidget);
      final board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
      expect(board.pieces, hasLength(24));
      expect(board.onSquareTap, isNull);
      expect(board.highContrast, isTrue);
      expect(board.showCoordinates, isTrue);
      expect(board.reducedMotion, isTrue);
      expect(board.bottomSide, Side.black);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(controller.phase, GuidedMatchPhase.introduction);
      expect(
        find.byKey(const ValueKey('lesson-introduction-sheet')),
        findsOneWidget,
      );
      await tap(tester, 'BEGIN MATCH');
      expect(find.byType(CrownBottomSheet), findsNothing);
      expect(controller.phase, GuidedMatchPhase.match);
      expect(find.text('BLACK TO MOVE'), findsOneWidget);
      expect(find.byKey(const ValueKey('human-history')), findsOneWidget);
      await revealGuidance(
        tester,
        find.byKey(const ValueKey('guided-feedback')),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('guided-feedback'))).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const ValueKey('human-resign'))).dy,
        ),
      );
      tester.state<ScrollableState>(matchScrollable()).position.jumpTo(0);
      await tester.pumpAndSettle();
      final originalRect = tester.getRect(find.byType(CheckersBoard));
      await controller.tapSquare(const Square(2, 1));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(CheckersBoard)), originalRect);
      await action(tester, 'Unit 1 Rules');
      for (final item in definition.review) {
        expect(find.text(item.title), findsOneWidget);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CrownBottomSheet), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Lesson 8 matches singleplayer board and player-strip geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryCrownRepository();
    await repository.saveSettings(
      const CrownSettings(sound: false, haptics: false, reducedMotion: true),
    );
    final match = MatchController(
      repository: repository,
      session: MatchSession.newGame(
        mode: MatchMode.ai,
        humanSide: Side.black,
        blackName: 'You',
        whiteName: 'Crown AI',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: crownTheme(),
        home: MatchScreen(controller: match),
      ),
    );
    await tester.pumpAndSettle();
    final board = tester.getRect(find.byType(CheckersBoard));
    final top = tester.getRect(
      find.byKey(const ValueKey('player-strip-white')),
    );
    final bottom = tester.getRect(
      find.byKey(const ValueKey('player-strip-black')),
    );
    final controls = tester.getRect(
      find.byKey(const ValueKey('human-history')),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpLesson(tester);
    await tap(tester, 'BEGIN MATCH');
    expect(tester.getRect(find.byType(CheckersBoard)), board);
    expect(
      tester.getRect(find.byKey(const ValueKey('player-strip-white'))),
      top,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('player-strip-black'))),
      bottom,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('human-history'))),
      controls,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'victory sheet opens one scrollable recap with completion at its end',
    (tester) async {
      final controller = await pumpLesson(tester, state: winningPosition);
      await tap(tester, 'BEGIN MATCH');
      await controller.tapSquare(const Square(4, 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lesson-result-sheet')), findsOneWidget);
      expect(find.text('Victory'), findsOneWidget);
      expect(
        find.text('The final opposing piece was captured.'),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CrownBottomSheet), findsOneWidget);
      expect(controller.lessonComplete, isFalse);
      await tap(tester, 'REVIEW UNIT 1');
      expect(find.byType(CrownBottomSheet), findsNothing);
      expect(find.text('CONTINUE REVIEW'), findsNothing);
      for (final item in definition.review) {
        expect(find.text(item.title), findsOneWidget);
      }
      expect(find.text('COMPLETE LESSON').hitTestable(), findsNothing);
      await tester.ensureVisible(find.text('COMPLETE LESSON'));
      expect(
        tester.getTopLeft(find.text('COMPLETE LESSON')).dy,
        greaterThan(
          tester.getBottomLeft(find.text(definition.review.last.body)).dy,
        ),
      );
      expect(controller.lessonComplete, isFalse);
      await tap(tester, 'COMPLETE LESSON');
      expect(controller.lessonComplete, isTrue);
      expect(find.text('OPEN LESSON'), findsOneWidget);
    },
  );

  testWidgets(
    'resignation and defeat are sheets; retry opens a fresh introduction',
    (tester) async {
      final controller = await pumpLesson(tester);
      await tap(tester, 'BEGIN MATCH');
      await action(tester, 'Move history');
      expect(find.text('No moves yet.'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await action(tester, 'Resign');
      expect(find.byKey(const ValueKey('resign-sheet')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tap(tester, 'RESIGN');
      expect(find.byKey(const ValueKey('lesson-result-sheet')), findsOneWidget);
      expect(find.text('Defeat'), findsOneWidget);
      expect(controller.lessonComplete, isFalse);
      await tap(tester, 'TRY AGAIN');
      expect(
        find.byKey(const ValueKey('lesson-introduction-sheet')),
        findsOneWidget,
      );
      expect(controller.match.state.pieces, hasLength(24));
      expect(controller.match.state.turns, isEmpty);
      await tap(tester, 'RETURN TO LEARN');
      expect(find.text('OPEN LESSON'), findsOneWidget);
    },
  );

  testWidgets(
    'draw sheet explains the result and does not complete the lesson',
    (tester) async {
      final controller = await pumpLesson(
        tester,
        state: GameState.custom(
          sideToMove: Side.black,
          quietKingPlyCount: 79,
          pieces: {
            const Square(0, 1): const Piece(Side.black, PieceRank.king),
            const Square(7, 6): const Piece(Side.white, PieceRank.king),
          },
        ),
      );
      await tap(tester, 'BEGIN MATCH');
      await controller.tapSquare(const Square(0, 1));
      await controller.tapSquare(const Square(1, 0));
      await tester.pumpAndSettle();
      expect(find.text('Draw'), findsOneWidget);
      expect(
        find.text('Eighty quiet king turns were completed.'),
        findsOneWidget,
      );
      expect(controller.lessonComplete, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('OPEN LESSON'), findsOneWidget);
    },
  );

  testWidgets('result waits until an open rules reference closes', (
    tester,
  ) async {
    final answer = Completer<Turn>();
    final controller = await pumpLesson(
      tester,
      state: GameState.custom(
        sideToMove: Side.white,
        pieces: {
          const Square(2, 1): const Piece.blackMan(),
          const Square(3, 2): const Piece.whiteMan(),
        },
      ),
      ai: (_, _) => answer.future,
    );
    await tap(tester, 'BEGIN MATCH');
    await action(tester, 'Unit 1 Rules');
    answer.complete(
      const CheckersEngine().legalTurns(controller.match.state).single,
    );
    await tester.pumpAndSettle();
    expect(controller.phase, GuidedMatchPhase.result);
    expect(find.byKey(const ValueKey('lesson-result-sheet')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-result-sheet')), findsOneWidget);
    await tap(tester, 'RETURN TO LEARN');
  });

  testWidgets(
    'Back exits the introduction; gameplay Back opens the leave sheet',
    (tester) async {
      final controller = await pumpLesson(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('OPEN LESSON'), findsOneWidget);
      expect(controller.phase, GuidedMatchPhase.introduction);
      await tester.tap(find.text('OPEN LESSON'));
      await tester.pumpAndSettle();
      await tap(tester, 'BEGIN MATCH');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('leave-game-sheet')), findsOneWidget);
      expect(find.text('SAVE & LEAVE'), findsNothing);
      await tap(tester, 'KEEP PLAYING');
      expect(controller.phase, GuidedMatchPhase.match);
      await action(tester, 'Leave match');
      await tap(tester, 'LEAVE LESSON');
      expect(controller.lessonComplete, isFalse);
      expect(find.text('OPEN LESSON'), findsOneWidget);
    },
  );

  testWidgets(
    'compact enlarged-text sheets, guidance and recap remain accessible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await pumpLesson(
        tester,
        state: winningPosition,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      await tap(tester, 'BEGIN MATCH');
      await revealGuidance(
        tester,
        find.byKey(const ValueKey('guided-feedback')),
      );
      expect(tester.takeException(), isNull);
      await controller.tapSquare(const Square(4, 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tap(tester, 'REVIEW UNIT 1');
      await tap(tester, 'COMPLETE LESSON');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid sheet actions do not pop the lesson during a transition', (
    tester,
  ) async {
    final controller = await pumpLesson(tester, reducedMotion: false);
    final begin = find.text('BEGIN MATCH');
    final beginPoint = tester.getCenter(begin);
    await tester.tap(begin);
    await tester.tapAt(beginPoint);
    await tester.pumpAndSettle();
    expect(find.byType(GuidedMatchScreen), findsOneWidget);
    expect(controller.phase, GuidedMatchPhase.match);
    expect(find.byType(CrownBottomSheet), findsNothing);
    await action(tester, 'Resign');
    await tester.tap(find.text('RESIGN'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-result-sheet')), findsOneWidget);
    final retry = find.text('TRY AGAIN');
    final retryPoint = tester.getCenter(retry);
    await tester.tap(retry);
    await tester.tapAt(retryPoint);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('lesson-introduction-sheet')),
      findsOneWidget,
    );
    expect(find.byType(CrownBottomSheet), findsOneWidget);
    await tap(tester, 'RETURN TO LEARN');
  });

  testWidgets('guidance fills the lower space up to the bottom safe inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await pumpLesson(
      tester,
      padding: const EdgeInsets.only(top: 47, bottom: 34),
    );
    await tap(tester, 'BEGIN MATCH');
    final guidance = find.ancestor(
      of: find.byKey(const ValueKey('guided-feedback')),
      matching: find.byType(GlassPanel),
    );
    final controls = find.ancestor(
      of: find.byKey(const ValueKey('human-resign')),
      matching: find.byType(GlassPanel),
    );
    final plate = find.byKey(const ValueKey('player-strip-black'));
    final controlRect = tester.getRect(controls);
    final boardRect = tester.getRect(find.byType(CheckersBoard));
    final guidanceRect = tester.getRect(guidance);
    expect(controlRect.top - tester.getRect(plate).bottom, closeTo(8, .01));
    expect(guidanceRect.top - controlRect.bottom, closeTo(8, .01));
    expect(tester.getBottomLeft(guidance).dy, closeTo(966, 1));

    tester.view.physicalSize = const Size(390, 1160);
    await tester.pumpAndSettle();
    final tallerGuidanceRect = tester.getRect(guidance);
    expect(tallerGuidanceRect.top, guidanceRect.top);
    expect(tallerGuidanceRect.bottom, closeTo(1126, 1));
    expect(tallerGuidanceRect.height - guidanceRect.height, closeTo(160, .01));
    expect(tester.getRect(controls), controlRect);
    expect(tester.getRect(find.byType(CheckersBoard)), boardRect);

    await controller.tapSquare(const Square(0, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(guidance), tallerGuidanceRect);
    expect(tester.getRect(controls), controlRect);
    expect(tester.getRect(find.byType(CheckersBoard)), boardRect);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
