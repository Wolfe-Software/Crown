import 'package:crown/game_engine/checkers_engine.dart';
import 'package:crown/game_engine/crown_ai.dart';
import 'package:crown/persistence/crown_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('derives opponent identity from the saved perspective', () {
    final ai = MatchSession.newGame(
      mode: MatchMode.ai,
      humanSide: Side.white,
      bottomSide: Side.white,
      blackName: 'Crown AI',
      whiteName: 'You',
    );
    final local = MatchSession.newGame(
      mode: MatchMode.local,
      bottomSide: Side.black,
      blackName: 'Host',
      whiteName: 'Guest',
    );

    expect(ai.aiSide, Side.black);
    expect(ai.opponentName, 'Crown AI');
    expect(ai.nameForSide(Side.white), 'You');
    expect(local.aiSide, isNull);
    expect(local.opponentName, 'Guest');

    final completed = ai.copyWith(
      state: const CheckersEngine().resign(ai.state, Side.white),
    );
    final record = MatchRecord.fromSession(completed);
    expect(record.aiSide, Side.black);
    expect(record.opponentName, 'Crown AI');
  });

  test('persists an active match, settings, profile, and history', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesCrownRepository(
      await SharedPreferences.getInstance(),
    );
    final session = MatchSession.newGame(
      mode: MatchMode.ai,
      humanSide: Side.black,
      bottomSide: Side.black,
      blackName: 'You',
      whiteName: 'Crown AI',
    );
    const settings = CrownSettings(
      sound: false,
      haptics: false,
      showCoordinates: true,
      reducedMotion: true,
      highContrast: true,
    );

    await repository.saveActiveMatch(session);
    await repository.saveSettings(settings);
    await repository.saveAiProfile(const AiProfile(skill: 7, gamesPlayed: 8));
    final resigned = session.copyWith(
      state: const CheckersEngine().resign(session.state, Side.black),
    );
    await repository.addHistory(MatchRecord.fromSession(resigned));

    expect(await repository.loadActiveMatch(), session);
    expect((await repository.loadActiveMatch())?.bottomSide, Side.black);
    expect(await repository.loadSettings(), settings);
    expect((await repository.loadAiProfile()).skill, 7);
    expect(await repository.loadHistory(), hasLength(1));
    expect((await repository.loadHistory()).single.bottomSide, Side.black);
  });

  test('history is capped at fifty newest matches', () async {
    final repository = MemoryCrownRepository();
    for (var index = 0; index < 55; index++) {
      final session = MatchSession.newGame(
        mode: MatchMode.local,
        blackName: 'Black',
        whiteName: 'White',
        startedAt: DateTime(2026, 1, 1).add(Duration(minutes: index)),
      );
      await repository.addHistory(
        MatchRecord.fromSession(
          session.copyWith(
            state: const CheckersEngine().resign(session.state, Side.black),
          ),
        ),
      );
    }

    final history = await repository.loadHistory();
    expect(history, hasLength(50));
    expect(history.first.startedAt, DateTime(2026, 1, 1, 0, 54));
  });

  test('learn progress persists and never moves backward', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesCrownRepository(
      await SharedPreferences.getInstance(),
    );
    expect(await repository.loadLearnProgress(), const LearnProgress());

    await repository.saveLearnProgress(
      const LearnProgress(lastCompletedLesson: 3),
    );
    await repository.saveLearnProgress(
      const LearnProgress(lastCompletedLesson: 1),
    );
    expect(
      await repository.loadLearnProgress(),
      const LearnProgress(lastCompletedLesson: 3),
    );
  });
}
