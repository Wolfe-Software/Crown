import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:crown/app/crown_app.dart';
import 'package:crown/app/crown_bottom_modal.dart';
import 'package:crown/app/crown_icon.dart';
import 'package:crown/app/crown_theme.dart';
import 'package:crown/features/home/local_color_picker.dart';
import 'package:crown/features/learn/lesson_board.dart';
import 'package:crown/features/match/checker_piece.dart';
import 'package:crown/features/match/checkers_board.dart';
import 'package:crown/features/match/match_controller.dart';
import 'package:crown/features/match/match_screen.dart';
import 'package:crown/features/match/jump_animation.dart';
import 'package:crown/features/settings/settings_screen.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:crown/persistence/crown_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell restores persisted learn progress', (tester) async {
    final repository = MemoryCrownRepository();
    await repository.saveLearnProgress(
      const LearnProgress(lastCompletedLesson: 1),
    );
    await tester.pumpWidget(CrownApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<LessonBoard>(find.byType(LessonBoard)).lastCompletedLesson,
      1,
    );
    expect(find.byKey(const ValueKey('next-lesson-2')), findsOneWidget);
  });

  testWidgets('crown icon renders the photographic logo asset', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: CrownIcon(semanticLabel: 'Victory')),
      ),
    );

    final logo = tester.widget<Image>(
      find.descendant(of: find.byType(CrownIcon), matching: find.byType(Image)),
    );
    expect((logo.image as AssetImage).assetName, 'assets/CrownLogo.png');
    expect(find.bySemanticsLabel('Victory'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('broken crown variant renders the defeat asset', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CrownIcon(
            variant: CrownIconVariant.broken,
            size: 32,
            semanticLabel: 'Defeat',
          ),
        ),
      ),
    );

    final logo = tester.widget<Image>(
      find.descendant(of: find.byType(CrownIcon), matching: find.byType(Image)),
    );
    expect((logo.image as AssetImage).assetName, 'assets/BrokenCrownLogo.png');
    expect(tester.getSize(find.byType(CrownIcon)), const Size.square(32));
    expect(find.bySemanticsLabel('Defeat'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('jeweled crown variant preserves its full artwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CrownIcon(variant: CrownIconVariant.jeweled, size: 92),
        ),
      ),
    );

    final logo = tester.widget<Image>(
      find.descendant(of: find.byType(CrownIcon), matching: find.byType(Image)),
    );
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(CrownIcon),
        matching: find.byType(Transform),
      ),
    );
    expect((logo.image as AssetImage).assetName, 'assets/JeweledCrownLogo.png');
    expect(logo.excludeFromSemantics, isTrue);
    expect(tester.getSize(find.byType(CrownIcon)), const Size.square(92));
    expect(transform.transform.getMaxScaleOnAxis(), 1);
  });

  testWidgets('draw crown variant renders balanced scales', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CrownIcon(
            variant: CrownIconVariant.draw,
            semanticLabel: 'Draw',
          ),
        ),
      ),
    );

    final logo = tester.widget<Image>(find.byType(Image));
    expect((logo.image as AssetImage).assetName, 'assets/DrawLogo.png');
    expect(find.bySemanticsLabel('Draw'), findsOneWidget);
  });

  testWidgets('marble background covers the navigator with the texture', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: 32)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(
            child: MarbleBackground(
              child: ColoredBox(
                key: ValueKey('navigator-content'),
                color: Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getRect(find.byKey(const ValueKey('navigator-content'))).bottom,
      600,
    );
    final background = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(MarbleBackground),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = background.decoration as BoxDecoration;
    final image = decoration.image!;
    expect(decoration.color, CrownColors.ivory);
    expect(
      (image.image as AssetImage).assetName,
      'assets/MarbleBackground.png',
    );
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.center);
  });

  testWidgets('screen content extends through the bottom system inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 32)),
          child: SettingsScreen(repository: MemoryCrownRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(ListView)).bottom, 600);
  });

  testWidgets('home exposes both offline play modes', (tester) async {
    await tester.pumpWidget(CrownApp(repository: MemoryCrownRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('CROWN'), findsOneWidget);
    expect(find.byType(CrownIcon), findsNWidgets(3));
    expect(
      tester
          .widgetList<CrownIcon>(find.byType(CrownIcon))
          .where((icon) => icon.variant == CrownIconVariant.jeweled),
      hasLength(1),
    );
    expect(find.byIcon(Icons.workspace_premium_outlined), findsNothing);
    expect(find.text('Play Crown AI'), findsOneWidget);
    expect(find.text('Local Multiplayer'), findsOneWidget);
    expect(
      find.text('No account. No connection. Just checkers.'),
      findsNothing,
    );
    expect(find.byTooltip('Match history'), findsNothing);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(find.text('Recent matches'), findsNothing);
  });

  testWidgets('local multiplayer uses overlapping opposite-color checkers', (
    tester,
  ) async {
    await tester.pumpWidget(CrownApp(repository: MemoryCrownRepository()));
    await tester.pumpAndSettle();

    final badge = find.byKey(const ValueKey('multiplayer-icon-badge'));
    final artwork = find.byKey(const ValueKey('multiplayer-checkers-icon'));
    final checkers = find.descendant(
      of: artwork,
      matching: find.byType(CheckerPiece),
    );
    expect(badge, findsOneWidget);
    expect(artwork, findsOneWidget);
    expect(checkers, findsNWidgets(2));
    expect(
      tester.widgetList<CheckerPiece>(checkers).map((piece) => piece.style),
      [CheckerPieceStyle.black, CheckerPieceStyle.white],
    );
    expect(find.byIcon(Icons.people_alt_outlined), findsNothing);

    final badgeRect = tester.getRect(badge);
    final checkerRects = CheckerPieceStyle.values
        .where((style) => style != CheckerPieceStyle.split)
        .map(
          (style) => tester.getRect(
            find.descendant(
              of: artwork,
              matching: find.byWidgetPredicate(
                (widget) => widget is CheckerPiece && widget.style == style,
              ),
            ),
          ),
        )
        .toList();
    expect(checkerRects.first.overlaps(checkerRects.last), isTrue);
    for (final checkerRect in checkerRects) {
      expect(badgeRect.contains(checkerRect.topLeft), isTrue);
      expect(badgeRect.contains(checkerRect.bottomRight), isTrue);
    }
  });

  testWidgets('bottom navigation switches between all four destinations', (
    tester,
  ) async {
    await tester.pumpWidget(CrownApp(repository: MemoryCrownRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-1')), findsOneWidget);

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();
    expect(
      find.text('Completed matches will appear here, ready to replay.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Sound'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Play Crown AI'), findsOneWidget);
  });

  testWidgets('bottom navigation uses a clipped blurred glass surface', (
    tester,
  ) async {
    await tester.pumpWidget(CrownApp(repository: MemoryCrownRepository()));
    await tester.pumpAndSettle();

    final blur = tester.widget<BackdropFilter>(
      find.byKey(const ValueKey('crown-bottom-nav-blur')),
    );
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('crown-bottom-nav-surface')),
    );
    final material = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('crown-bottom-nav-material')),
    );
    final decoration = surface.decoration as BoxDecoration;
    final materialDecoration = material.decoration as BoxDecoration;

    expect(blur.filter.toString(), contains('24.0'));
    expect(decoration.boxShadow, isNotEmpty);
    expect(materialDecoration.gradient, isNotNull);
    expect(materialDecoration.border, isNotNull);
  });

  testWidgets('compact Play button keeps a bright yellow-gold finish', (
    tester,
  ) async {
    await tester.pumpWidget(CrownApp(repository: MemoryCrownRepository()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'PLAY'), findsOneWidget);
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('metal-surface-gold')),
    );
    final gradient =
        (surface.decoration as BoxDecoration).gradient! as RadialGradient;
    expect(gradient.radius, greaterThanOrEqualTo(5));
    expect(gradient.colors.last.g, greaterThan(.58));
    expect(gradient.colors.last.b, greaterThan(.2));
  });

  testWidgets('bottom navigation uses image assets and color-only selection', (
    tester,
  ) async {
    await tester.pumpWidget(CrownApp(repository: MemoryCrownRepository()));
    await tester.pumpAndSettle();

    final navigation = find.byKey(const ValueKey('crown-bottom-nav'));
    final playCrown = find.descendant(
      of: navigation,
      matching: find.byType(CrownIcon),
    );
    expect(playCrown, findsOneWidget);
    expect(
      tester.widget<CrownIcon>(playCrown).variant,
      CrownIconVariant.normal,
    );
    expect(tester.getSize(playCrown), const Size.square(28));
    final navAssets = tester
        .widgetList<Image>(
          find.descendant(of: navigation, matching: find.byType(Image)),
        )
        .map((image) => (image.image as AssetImage).assetName)
        .toSet();
    expect(navAssets, {
      'assets/CrownLogo.png',
      'assets/LearnLogo.png',
      'assets/FeedLogo.png',
      'assets/ProfileLogo.png',
    });
    for (final assetName in [
      'assets/LearnLogo.png',
      'assets/FeedLogo.png',
      'assets/ProfileLogo.png',
    ]) {
      final image = find.descendant(
        of: navigation,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == assetName,
        ),
      );
      expect(tester.getSize(image), const Size.square(28));
    }
    expect(find.byIcon(Icons.sports_esports_rounded), findsNothing);
    expect(find.byIcon(Icons.sports_esports_outlined), findsNothing);
    expect(find.byIcon(Icons.school_rounded), findsNothing);
    expect(find.byIcon(Icons.school_outlined), findsNothing);
    expect(find.byIcon(Icons.view_agenda_rounded), findsNothing);
    expect(find.byIcon(Icons.view_agenda_outlined), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsNothing);
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    expect(
      find.descendant(of: navigation, matching: find.byType(AnimatedContainer)),
      findsNothing,
    );
    final initialFilteredAssets = tester
        .widgetList<Image>(
          find.descendant(
            of: find.descendant(
              of: navigation,
              matching: find.byType(ColorFiltered),
            ),
            matching: find.byType(Image),
          ),
        )
        .map((image) => (image.image as AssetImage).assetName)
        .toSet();
    expect(initialFilteredAssets, {
      'assets/LearnLogo.png',
      'assets/FeedLogo.png',
      'assets/ProfileLogo.png',
    });

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    final learnSelectedFilteredAssets = tester
        .widgetList<Image>(
          find.descendant(
            of: find.descendant(
              of: navigation,
              matching: find.byType(ColorFiltered),
            ),
            matching: find.byType(Image),
          ),
        )
        .map((image) => (image.image as AssetImage).assetName)
        .toSet();
    expect(learnSelectedFilteredAssets, {
      'assets/CrownLogo.png',
      'assets/FeedLogo.png',
      'assets/ProfileLogo.png',
    });
    expect(
      tester
          .widget<Text>(
            find.descendant(of: navigation, matching: find.text('Learn')),
          )
          .style
          ?.color,
      CrownColors.gold,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(of: navigation, matching: find.text('Play')),
          )
          .style
          ?.color,
      CrownColors.muted,
    );
  });

  testWidgets('bottom navigation exposes selection and tap semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(CrownApp(repository: MemoryCrownRepository()));
    await tester.pumpAndSettle();

    final play = tester.getSemantics(find.bySemanticsLabel('Play'));
    final learn = tester.getSemantics(find.bySemanticsLabel('Learn'));
    expect(play.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    expect(learn.flagsCollection.isSelected.toBoolOrNull(), isFalse);
    expect(play.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    semantics.dispose();
  });

  testWidgets('Learn wordmark aligns with the Home wordmark', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(CrownApp(repository: MemoryCrownRepository()));
    await tester.pumpAndSettle();

    final homeLogo = find.byWidgetPredicate(
      (widget) =>
          widget is CrownIcon &&
          widget.semanticLabel == 'Crown' &&
          widget.size == 42,
    );
    final homeLogoRect = tester.getRect(homeLogo);
    final homeTitleRect = tester.getRect(find.text('CROWN'));

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    final hero = find.byKey(const ValueKey('learn-header-logo'));
    expect(hero, findsOneWidget);
    expect(
      (tester.widget<Image>(hero).image as AssetImage).assetName,
      'assets/LearnLogo.png',
    );
    expect(tester.getSize(hero), const Size.square(42));
    expect(tester.getRect(hero).topLeft, homeLogoRect.topLeft);
    expect(tester.getRect(find.text('LEARN')).top, homeTitleRect.top);
    expect(tester.getCenter(find.text('LEARN')).dx, homeTitleRect.center.dx);
    expect(
      tester.getRect(hero).bottom,
      lessThan(tester.getRect(find.text('LEARN')).top),
    );
    expect(find.byKey(const ValueKey('learn-hero-logo')), findsNothing);
    expect(
      tester
          .widgetList<CrownIcon>(find.byType(CrownIcon))
          .where((icon) => icon.variant == CrownIconVariant.jeweled),
      isEmpty,
    );

    semantics.dispose();
  });

  testWidgets('jeweled AI card artwork fits a compact phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(CrownApp(repository: MemoryCrownRepository()));
    await tester.pumpAndSettle();

    final jeweledCrown = find.byWidgetPredicate(
      (widget) =>
          widget is CrownIcon && widget.variant == CrownIconVariant.jeweled,
    );
    final artwork = tester.getRect(jeweledCrown);
    expect(artwork.size, const Size.square(92));
    expect(artwork.left, greaterThanOrEqualTo(24));
    expect(artwork.right, lessThanOrEqualTo(366));
    expect(tester.takeException(), isNull);
  });

  testWidgets('feed marks perspective losses as defeats', (tester) async {
    final scenarios =
        <({MatchSession session, Side resigning, bool defeat, String row})>[
          (
            session: MatchSession.newGame(
              mode: MatchMode.ai,
              humanSide: Side.black,
              bottomSide: Side.black,
              blackName: 'You',
              whiteName: 'Crown AI',
            ),
            resigning: Side.black,
            defeat: true,
            row: 'Crown AI',
          ),
          (
            session: MatchSession.newGame(
              mode: MatchMode.local,
              bottomSide: Side.white,
              blackName: 'Guest',
              whiteName: 'Host',
            ),
            resigning: Side.black,
            defeat: false,
            row: 'Guest',
          ),
        ];

    for (final scenario in scenarios) {
      final repository = MemoryCrownRepository();
      final completed = scenario.session.copyWith(
        state: const CheckersEngine().resign(
          scenario.session.state,
          scenario.resigning,
        ),
      );
      await repository.addHistory(MatchRecord.fromSession(completed));
      await tester.pumpWidget(CrownApp(repository: repository));
      await tester.pumpAndSettle();
      expect(find.text(scenario.row), findsNothing);
      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();

      final assets = tester
          .widgetList<Image>(find.byType(Image))
          .map((widget) => (widget.image as AssetImage).assetName);
      expect(assets.contains('assets/BrokenCrownLogo.png'), scenario.defeat);
      expect(
        find.bySemanticsLabel(scenario.defeat ? 'Defeat' : 'Victory'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('feed reloads history whenever it becomes active', (
    tester,
  ) async {
    final repository = MemoryCrownRepository();
    await tester.pumpWidget(CrownApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();
    expect(find.text('Guest'), findsNothing);

    final session = MatchSession.newGame(
      mode: MatchMode.local,
      blackName: 'Guest',
      whiteName: 'Host',
    );
    final completed = session.copyWith(
      state: const CheckersEngine().resign(session.state, Side.black),
    );
    await repository.addHistory(MatchRecord.fromSession(completed));

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();

    expect(find.text('Guest'), findsOneWidget);
  });

  testWidgets('local match gives both seats the same mirrored HUD', (
    tester,
  ) async {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        bottomSide: Side.white,
        blackName: 'Guest',
        whiteName: 'Host',
      ),
      repository: MemoryCrownRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    final topHud = find.byKey(const ValueKey('local-top-hud'));
    final bottomHud = find.byKey(const ValueKey('local-bottom-hud'));
    expect(topHud, findsOneWidget);
    expect(bottomHud, findsOneWidget);
    expect(tester.widget<RotatedBox>(topHud).quarterTurns, 2);
    expect(find.text('BLACK TO MOVE'), findsNWidgets(2));
    expect(find.byTooltip('Leave match'), findsNWidgets(2));
    expect(find.byTooltip('Move history'), findsNWidgets(2));
    expect(find.byTooltip('Resign'), findsNWidgets(2));
    expect(find.byType(AppBar), findsNothing);

    final board = tester.getRect(find.byType(CheckersBoard));
    expect(tester.getRect(topHud).bottom, lessThan(board.top));
    expect(tester.getRect(bottomHud).top, greaterThan(board.bottom));
    expect(
      board.top - tester.getRect(topHud).bottom,
      tester.getRect(bottomHud).top - board.bottom,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('local face-to-face layout handles compact landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(667, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        bottomSide: Side.white,
        blackName: 'Guest',
        whiteName: 'Host',
      ),
      repository: MemoryCrownRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(667, 320),
            padding: EdgeInsets.only(top: 24, bottom: 8),
          ),
          child: MatchScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byType(CheckersBoard));
    expect(board.size, const Size.square(180));
    expect(board.top, greaterThanOrEqualTo(0));
    expect(board.bottom, lessThanOrEqualTo(320));
    expect(board.center.dy, closeTo(160, 1));
    expect(
      tester.getRect(find.byKey(const ValueKey('board-square-0-0'))).topLeft,
      board.topLeft,
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('board-square-7-7')))
          .bottomRight,
      board.bottomRight,
    );
    expect(find.byKey(const ValueKey('local-top-hud')), findsOneWidget);
    expect(find.byKey(const ValueKey('local-bottom-hud')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final scrollController = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    scrollController.jumpTo(0);
    await controller.tapSquare(const Square(2, 1));
    await tester.pump();
    expect(scrollController.offset, 0);

    await controller.resign(Side.black);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('local-result-overlay')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('top local controls open a rotated top-edge sheet', (
    tester,
  ) async {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        bottomSide: Side.white,
        blackName: 'Guest',
        whiteName: 'Host',
      ),
      repository: MemoryCrownRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('top-history')));
    await tester.pumpAndSettle();

    final topSheet = find.byKey(const ValueKey('crown-top-sheet'));
    expect(topSheet, findsOneWidget);
    expect(tester.getRect(topSheet).top, 0);
    expect(
      tester
          .widget<RotatedBox>(
            find.byKey(const ValueKey('crown-top-sheet-content')),
          )
          .quarterTurns,
      2,
    );
    expect(find.text('Move history'), findsOneWidget);
  });

  testWidgets('each local resign button resigns its own seat', (tester) async {
    for (final scenario in [
      (button: 'top-resign', loser: Side.black, winner: Side.white),
      (button: 'bottom-resign', loser: Side.white, winner: Side.black),
    ]) {
      final controller = MatchController(
        session: MatchSession.newGame(
          mode: MatchMode.local,
          bottomSide: Side.white,
          blackName: 'Guest',
          whiteName: 'Host',
        ),
        repository: MemoryCrownRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(home: MatchScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey(scenario.button)));
      await tester.pumpAndSettle();
      expect(find.text('Resign?'), findsOneWidget);
      expect(find.text('Resign BLACK?'), findsNothing);
      expect(find.text('Resign WHITE?'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'RESIGN'));
      await tester.pumpAndSettle();

      expect(controller.state.result?.winner, scenario.winner);
      expect(
        find.byKey(const ValueKey('local-result-overlay')),
        findsOneWidget,
      );
      expect(find.text('RETURN HOME'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('local-top-result')),
          matching: find.text(
            scenario.loser == Side.black ? 'Defeat' : 'Victory',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('local-bottom-result')),
          matching: find.text(
            scenario.loser == Side.white ? 'Defeat' : 'Victory',
          ),
        ),
        findsOneWidget,
      );
      String resultAsset(Key key) {
        final image = tester.widget<Image>(
          find.descendant(of: find.byKey(key), matching: find.byType(Image)),
        );
        return (image.image as AssetImage).assetName;
      }

      expect(
        resultAsset(const ValueKey('local-top-result')),
        scenario.loser == Side.black
            ? 'assets/BrokenCrownLogo.png'
            : 'assets/CrownLogo.png',
      );
      expect(
        resultAsset(const ValueKey('local-bottom-result')),
        scenario.loser == Side.white
            ? 'assets/BrokenCrownLogo.png'
            : 'assets/CrownLogo.png',
      );
      expect(find.bySemanticsLabel('Victory'), findsOneWidget);
      expect(find.bySemanticsLabel('Defeat'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('local multiplayer opens a complete board', (tester) async {
    await tester.pumpWidget(CrownApp(repository: MemoryCrownRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Multiplayer'));
    await tester.pumpAndSettle();

    expect(find.text('Choose host color'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('color-picker-background-blur')),
      findsOneWidget,
    );
    expect(find.text('CROWN'), findsOneWidget);
    final picker = tester.getRect(find.byType(LocalColorPicker));
    expect(picker.top, greaterThan(0));
    expect(picker.bottom, closeTo(600, 1));
    await tester.tap(find.text('WHITE'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('crown-bottom-nav')), findsNothing);
    expect(find.text('BLACK TO MOVE'), findsNWidgets(2));
    expect(find.text('• CHECKERS •'), findsNothing);
    expect(find.text('LOCAL MATCH'), findsNothing);
    expect(find.byKey(const ValueKey('board-square-0-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-square-7-7')), findsOneWidget);
    final board = tester.getRect(find.byType(CheckersBoard));
    expect(tester.getCenter(find.text('Guest')).dy, lessThan(board.top));
    expect(tester.getCenter(find.text('Host')).dy, greaterThan(board.bottom));
  });

  testWidgets('singleplayer opens the same picker with player copy', (
    tester,
  ) async {
    await tester.pumpWidget(CrownApp(repository: MemoryCrownRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play Crown AI'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your color'), findsOneWidget);
    expect(find.text('BLACK'), findsOneWidget);
    expect(find.text('WHITE'), findsOneWidget);
    expect(find.text('RANDOM'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('color-picker-background-blur')),
      findsOneWidget,
    );

    await tester.tap(find.text('BLACK'));
    await tester.pumpAndSettle();
    expect(find.text('BLACK TO MOVE'), findsOneWidget);
    expect(find.text('• CHECKERS •'), findsOneWidget);
    expect(find.text('CROWN AI'), findsNothing);
    final board = tester.getRect(find.byType(CheckersBoard));
    expect(tester.getCenter(find.text('You')).dy, greaterThan(board.bottom));
    expect(find.byTooltip('Leave match'), findsOneWidget);
    expect(
      tester.getCenter(find.byTooltip('Leave match')).dy,
      greaterThan(board.bottom),
    );
    expect(
      tester.getCenter(find.byTooltip('Resign')).dy,
      tester.getCenter(find.byTooltip('Move history')).dy,
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      ),
      findsNothing,
    );
  });

  testWidgets('tapping the blurred backdrop dismisses without starting', (
    tester,
  ) async {
    final repository = MemoryCrownRepository();
    await tester.pumpWidget(CrownApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Multiplayer'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();

    expect(find.byType(LocalColorPicker), findsNothing);
    expect(find.text('CROWN'), findsOneWidget);
    expect(await repository.loadActiveMatch(), isNull);
  });

  testWidgets(
    'black-bottom board rotates display but preserves canonical taps',
    (tester) async {
      Square? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 320,
              child: CheckersBoard(
                pieces: const {},
                selected: null,
                destinations: const {},
                bottomSide: Side.black,
                onSquareTap: (square) => tapped = square,
              ),
            ),
          ),
        ),
      );

      final topLeft = tester.getCenter(
        find.byKey(const ValueKey('board-square-7-7')),
      );
      final bottomRight = tester.getCenter(
        find.byKey(const ValueKey('board-square-0-0')),
      );
      expect(topLeft.dy, lessThan(bottomRight.dy));
      expect(topLeft.dx, lessThan(bottomRight.dx));

      await tester.tap(find.byKey(const ValueKey('board-square-7-7')));
      expect(tapped, const Square(7, 7));
    },
  );

  testWidgets('singleplayer keeps You below the board when playing white', (
    tester,
  ) async {
    final session = MatchSession.newGame(
      mode: MatchMode.ai,
      humanSide: Side.white,
      bottomSide: Side.white,
      blackName: 'Crown AI',
      whiteName: 'You',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MatchScreen(
          controller: MatchController(
            session: session,
            repository: MemoryCrownRepository(),
            aiMoveChooser: (state, profile) async =>
                const CheckersEngine().legalTurns(state).first,
            minimumAiTurnDuration: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byType(CheckersBoard));
    expect(tester.getCenter(find.text('Crown AI')).dy, lessThan(board.top));
    expect(tester.getCenter(find.text('You')).dy, greaterThan(board.bottom));
  });

  testWidgets('turn highlight does not move the board', (tester) async {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Guest',
        whiteName: 'Host',
      ),
      repository: MemoryCrownRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    final initialBoard = tester.getRect(find.byType(CheckersBoard));

    await controller.tapSquare(const Square(2, 1));
    await controller.tapSquare(const Square(3, 0));
    await tester.pump();
    expect(controller.state.sideToMove, Side.white);

    await tester.pump(const Duration(milliseconds: 100));
    final animatedBoard = tester.getRect(find.byType(CheckersBoard));
    expect(animatedBoard.top, initialBoard.top);
    expect(animatedBoard.bottom, initialBoard.bottom);

    await tester.pumpAndSettle();
    final settledBoard = tester.getRect(find.byType(CheckersBoard));
    expect(settledBoard.top, initialBoard.top);
    expect(settledBoard.bottom, initialBoard.bottom);
  });

  testWidgets('result crown reflects AI human outcomes', (tester) async {
    final scenarios = <({MatchSession session, Side resigning, String asset})>[
      for (final human in Side.values)
        for (final resigning in Side.values)
          (
            session: MatchSession.newGame(
              mode: MatchMode.ai,
              humanSide: human,
              bottomSide: human,
              blackName: 'Black',
              whiteName: 'White',
            ),
            resigning: resigning,
            asset: resigning == human
                ? 'assets/BrokenCrownLogo.png'
                : 'assets/CrownLogo.png',
          ),
    ];

    for (final scenario in scenarios) {
      final controller = MatchController(
        session: scenario.session,
        repository: MemoryCrownRepository(),
        aiMoveChooser: (state, profile) async =>
            const CheckersEngine().legalTurns(state).first,
        aiDelay: (_) async {},
      );
      await tester.pumpWidget(
        MaterialApp(home: MatchScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await controller.resign(scenario.resigning);
      await tester.pumpAndSettle();

      final logo = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey('result-sheet')),
          matching: find.byType(Image),
        ),
      );
      expect((logo.image as AssetImage).assetName, scenario.asset);
      expect(
        find.text(scenario.asset.contains('Broken') ? 'Defeat' : 'Victory'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CrownIcon),
          matching: find.bySemanticsLabel(
            scenario.asset.contains('Broken') ? 'Defeat' : 'Victory',
          ),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('draw result uses the balanced scales', (tester) async {
    for (final mode in MatchMode.values) {
      final state = GameState.custom(
        sideToMove: Side.black,
        quietKingPlyCount: 79,
        pieces: {
          const Square(2, 1): const Piece(Side.black, PieceRank.king),
          const Square(5, 6): const Piece(Side.white, PieceRank.king),
        },
      );
      final controller = MatchController(
        session: MatchSession.newGame(
          mode: mode,
          humanSide: mode == MatchMode.ai ? Side.black : null,
          bottomSide: Side.white,
          blackName: 'Guest',
          whiteName: 'Host',
          initialState: state,
        ),
        repository: MemoryCrownRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(home: MatchScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await controller.tapSquare(const Square(2, 1));
      await controller.tapSquare(const Square(3, 0));
      await tester.pumpAndSettle();

      final logos = tester.widgetList<Image>(
        find.descendant(
          of: find.byKey(
            ValueKey(
              mode == MatchMode.local ? 'local-result-overlay' : 'result-sheet',
            ),
          ),
          matching: find.byType(Image),
        ),
      );
      expect(
        logos.map((logo) => (logo.image as AssetImage).assetName),
        everyElement('assets/DrawLogo.png'),
      );
      final count = mode == MatchMode.local ? 2 : 1;
      expect(logos, hasLength(count));
      expect(find.text('Draw'), findsNWidgets(count));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('board grid ignores surrounding system padding', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.fromLTRB(12, 32, 18, 24)),
          child: Center(
            child: SizedBox.square(
              dimension: 320,
              child: CheckersBoard(
                pieces: {},
                selected: null,
                destinations: {},
              ),
            ),
          ),
        ),
      ),
    );

    final board = tester.getRect(find.byType(CheckersBoard));
    final firstSquare = tester.getRect(
      find.byKey(const ValueKey('board-square-0-0')),
    );
    final lastSquare = tester.getRect(
      find.byKey(const ValueKey('board-square-7-7')),
    );

    expect(firstSquare.topLeft, board.topLeft);
    expect(lastSquare.bottomRight, board.bottomRight);
    expect(firstSquare.size, const Size.square(40));
    expect(lastSquare.size, const Size.square(40));
  });

  testWidgets('board uses neutral frosted glass squares', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 320,
            child: CheckersBoard(pieces: {}, selected: null, destinations: {}),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    final lightSquare = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(const ValueKey('board-square-0-0')),
        matching: find.byType(ColoredBox),
      ),
    );
    final darkSquare = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(const ValueKey('board-square-0-1')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(lightSquare.color, Colors.white.withValues(alpha: .12));
    expect(darkSquare.color, CrownColors.obsidian.withValues(alpha: .28));
    expect(lightSquare.color.a, lessThan(.3));
    expect(darkSquare.color.a, lessThan(.3));

    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(filter.filter.toString(), contains('20.0'));
  });

  testWidgets('high contrast board squares remain opaque', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 320,
            child: CheckersBoard(
              pieces: {},
              selected: null,
              destinations: {},
              highContrast: true,
            ),
          ),
        ),
      ),
    );

    final squares = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(GridView),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(squares.every((square) => square.color.a == 1), isTrue);
    expect(squares.elementAt(1).color, CrownColors.obsidian);
  });

  testWidgets('resign confirmation is a blurred bottom sheet', (tester) async {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Host',
        whiteName: 'Guest',
      ),
      repository: MemoryCrownRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-resign')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('resign-sheet')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const ValueKey('crown-modal-background-blur')),
      findsOneWidget,
    );
    final backgroundBlur = tester.widget<BackdropFilter>(
      find.byKey(const ValueKey('crown-modal-background-blur')),
    );
    final surfaceBlur = tester.widget<BackdropFilter>(
      find.byKey(const ValueKey('crown-sheet-surface-blur')),
    );
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('crown-sheet-surface')),
    );
    final frame = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('crown-sheet-frame')),
    );
    final surfaceDecoration = surface.decoration as BoxDecoration;
    final frameDecoration = frame.decoration as BoxDecoration;
    expect(backgroundBlur.filter.toString(), contains('9.0'));
    expect(surfaceBlur.filter.toString(), contains('24.0'));
    expect(surfaceDecoration.color!.a, lessThan(.5));
    expect(frameDecoration.boxShadow, isNotEmpty);
    final logo = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('resign-sheet')),
        matching: find.byType(Image),
      ),
    );
    expect((logo.image as AssetImage).assetName, 'assets/BrokenCrownLogo.png');
    expect(find.bySemanticsLabel('Defeat'), findsOneWidget);
  });

  testWidgets('resigning during the AI turn defeats the human', (tester) async {
    final aiDelay = Completer<void>();
    final controller = MatchController(
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
      aiDelay: (_) => aiDelay.future,
    );
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(controller: controller)),
    );
    await tester.pump();
    await tester.pump();
    expect(controller.isAiThinking, isTrue);

    await tester.tap(find.byTooltip('Resign'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'RESIGN'));
    await tester.pumpAndSettle();

    expect(controller.state.result?.winner, Side.black);
    expect(controller.state.result?.reason, ResultReason.resignation);
    expect(find.text('Defeat'), findsOneWidget);

    aiDelay.complete();
    await tester.pumpAndSettle();
    expect(controller.state.result?.winner, Side.black);
  });

  testWidgets('leave confirmation uses the same bottom sheet', (tester) async {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Host',
        whiteName: 'Guest',
      ),
      repository: MemoryCrownRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-leave')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('leave-game-sheet')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('move history uses the shared frosted bottom sheet', (
    tester,
  ) async {
    final controller = MatchController(
      session: MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Host',
        whiteName: 'Guest',
      ),
      repository: MemoryCrownRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('move-history-sheet')), findsOneWidget);
    expect(find.byType(CrownBottomSheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey('crown-sheet-surface-blur')),
      findsOneWidget,
    );
  });

  testWidgets('settings changes are persisted', (tester) async {
    final repository = MemoryCrownRepository();
    await tester.pumpWidget(CrownApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Sound'));
    await tester.pumpAndSettle();

    expect((await repository.loadSettings()).sound, isFalse);
  });

  testWidgets('reduced motion removes checker scaling animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CheckersBoard(
          pieces: {const Square(2, 1): const Piece.blackMan()},
          selected: const Square(2, 1),
          destinations: const {},
          reducedMotion: true,
        ),
      ),
    );

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
      Duration.zero,
    );
  });

  testWidgets('last move highlights its origin and destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CheckersBoard(
          pieces: {const Square(3, 0): const Piece.blackMan()},
          selected: null,
          destinations: const {},
          lastTurn: Turn.step(const Square(2, 1), const Square(3, 0)),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('last-move-2-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('last-move-3-0')), findsOneWidget);
  });

  testWidgets('a king carries a golden crown on its face', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CheckersBoard(
          pieces: {const Square(3, 2): const Piece(Side.black, PieceRank.king)},
          selected: null,
          destinations: const {},
        ),
      ),
    );

    final logo = tester.widget<Image>(
      find.descendant(of: find.byType(CrownIcon), matching: find.byType(Image)),
    );
    expect((logo.image as AssetImage).assetName, 'assets/CrownLogo.png');
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
  });

  testWidgets('non-king pieces have plain faces', (tester) async {
    for (final style in CheckerPieceStyle.values) {
      final faceKey = ValueKey('plain-${style.name}');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 64,
              child: CheckerPiece(style: style, faceKey: faceKey),
            ),
          ),
        ),
      );

      final face = tester.widget<DecoratedBox>(find.byKey(faceKey));
      expect(
        face.child,
        isNull,
        reason: '${style.name} should have a plain face.',
      );
    }
  });

  testWidgets('stationary and jumping kings follow the crown perspective', (
    tester,
  ) async {
    for (final ownerFacing in [true, false]) {
      for (final bottom in Side.values) {
        for (final owner in Side.values) {
          for (final jumping in [false, true]) {
            await tester.pumpWidget(
              MaterialApp(
                home: CheckersBoard(
                  bottomSide: bottom,
                  ownerFacingCrowns: ownerFacing,
                  pieces: jumping
                      ? {}
                      : {const Square(3, 2): Piece(owner, PieceRank.king)},
                  selected: null,
                  destinations: const {},
                  activeJump: jumping
                      ? JumpAnimation(
                          piece: Piece(owner, PieceRank.king),
                          from: const Square(2, 1),
                          to: const Square(4, 3),
                          captured: const Square(3, 2),
                          duration: const Duration(milliseconds: 300),
                        )
                      : null,
                ),
              ),
            );
            final facing = find.ancestor(
              of: find.byType(CrownIcon),
              matching: find.byType(RotatedBox),
            );
            expect(facing, findsOneWidget);
            expect(
              tester.widget<RotatedBox>(facing).quarterTurns,
              !ownerFacing || owner == bottom ? 0 : 2,
            );
            await tester.pumpAndSettle();
          }
        }
      }
    }
  });

  testWidgets('AI matches keep both king crowns facing the human', (
    tester,
  ) async {
    for (final human in Side.values) {
      final controller = MatchController(
        session: MatchSession.newGame(
          mode: MatchMode.ai,
          humanSide: human,
          bottomSide: human,
          blackName: 'Black',
          whiteName: 'White',
          initialState: GameState.custom(
            sideToMove: human,
            pieces: {
              const Square(2, 1): const Piece(Side.black, PieceRank.king),
              const Square(5, 6): const Piece(Side.white, PieceRank.king),
            },
          ),
        ),
        repository: MemoryCrownRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(home: MatchScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      final crowns = find.descendant(
        of: find.byType(CheckerPiece),
        matching: find.byType(RotatedBox),
      );
      expect(crowns, findsNWidgets(2));
      expect(
        tester
            .widgetList<RotatedBox>(crowns)
            .map((crown) => crown.quarterTurns),
        everyElement(0),
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a king crown remains contained within the checker face', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 160,
            child: CheckersBoard(
              pieces: {
                const Square(3, 2): const Piece(Side.black, PieceRank.king),
              },
              selected: null,
              destinations: const {},
            ),
          ),
        ),
      ),
    );

    final face = tester.getRect(find.byKey(const ValueKey('piece-face-3-2')));
    final crown = tester.getRect(find.byType(CrownIcon));
    expect(crown.width, lessThanOrEqualTo(face.width * .56));
    expect(crown.height, lessThanOrEqualTo(face.height * .56));
    expect(face.contains(crown.topLeft), isTrue);
    expect(face.contains(crown.bottomRight), isTrue);
  });

  testWidgets('mandatory and uniquely compelled moves use distinct markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CheckersBoard(
          pieces: {const Square(2, 1): const Piece.blackMan()},
          selected: null,
          destinations: const {},
          mandatoryOrigins: {const Square(2, 1)},
          mandatoryDestinations: {const Square(4, 3)},
          emphasizeRequiredAction: true,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('mandatory-origin-2-1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mandatory-destination-4-3')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('compelled-origin-2-1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('compelled-destination-4-3')),
      findsOneWidget,
    );
  });

  testWidgets('coordinate setting labels every board space', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 320,
            child: CheckersBoard(
              pieces: {},
              selected: null,
              destinations: {},
              showCoordinates: true,
            ),
          ),
        ),
      ),
    );

    final coordinates = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('coordinate-'),
    );
    expect(coordinates, findsNWidgets(64));
    expect(find.byKey(const ValueKey('coordinate-0-0')), findsOneWidget);
    expect(find.text('a8'), findsOneWidget);
    expect(find.byKey(const ValueKey('coordinate-7-7')), findsOneWidget);
    expect(find.text('h1'), findsOneWidget);
  });

  testWidgets('jump overlay travels between board squares', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 320,
            child: CheckersBoard(
              pieces: {const Square(3, 2): const Piece.whiteMan()},
              selected: null,
              destinations: const {},
              activeJump: const JumpAnimation(
                piece: Piece.blackMan(),
                from: Square(2, 1),
                to: Square(4, 3),
                captured: Square(3, 2),
                duration: Duration(milliseconds: 300),
              ),
            ),
          ),
        ),
      ),
    );

    final start = tester.getCenter(find.byKey(const ValueKey('jumping-piece')));
    await tester.pump(const Duration(milliseconds: 150));
    final middle = tester.getCenter(
      find.byKey(const ValueKey('jumping-piece')),
    );
    await tester.pump(const Duration(milliseconds: 150));
    final end = tester.getCenter(find.byKey(const ValueKey('jumping-piece')));

    expect(middle.dx, greaterThan(start.dx));
    expect(middle.dy, greaterThan(start.dy));
    expect(end.dx, greaterThan(middle.dx));
    expect(end.dy, greaterThan(middle.dy));
    expect(find.byKey(const ValueKey('piece-face-3-2')), findsOneWidget);
  });
}
