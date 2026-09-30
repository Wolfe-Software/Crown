import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game_engine/checkers_engine.dart';
import '../game_engine/crown_ai.dart';

enum MatchMode { ai, local }

class MatchSession {
  MatchSession._({
    required this.id,
    required this.mode,
    required this.humanSide,
    required this.bottomSide,
    required this.blackName,
    required this.whiteName,
    required this.startedAt,
    required this.initialState,
    required this.state,
  });

  factory MatchSession.newGame({
    required MatchMode mode,
    required String blackName,
    required String whiteName,
    Side? humanSide,
    Side? bottomSide,
    DateTime? startedAt,
    GameState? initialState,
  }) {
    final start = startedAt ?? DateTime.now();
    final state = initialState ?? GameState.initial();
    return MatchSession._(
      id: '${start.microsecondsSinceEpoch}-${mode.name}',
      mode: mode,
      humanSide: humanSide,
      bottomSide: bottomSide ?? humanSide ?? Side.white,
      blackName: blackName,
      whiteName: whiteName,
      startedAt: start,
      initialState: state,
      state: state,
    );
  }

  final String id;
  final MatchMode mode;
  final Side? humanSide;
  final Side bottomSide;
  final String blackName;
  final String whiteName;
  final DateTime startedAt;
  final GameState initialState;
  final GameState state;

  Side get perspectiveSide => mode == MatchMode.ai ? humanSide! : bottomSide;
  Side? get aiSide => mode == MatchMode.ai ? humanSide?.opponent : null;
  String nameForSide(Side side) => side == Side.black ? blackName : whiteName;
  String get opponentName => nameForSide(perspectiveSide.opponent);

  MatchSession copyWith({GameState? state}) => MatchSession._(
    id: id,
    mode: mode,
    humanSide: humanSide,
    bottomSide: bottomSide,
    blackName: blackName,
    whiteName: whiteName,
    startedAt: startedAt,
    initialState: initialState,
    state: state ?? this.state,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'id': id,
    'mode': mode.name,
    'humanSide': humanSide?.name,
    'bottomSide': bottomSide.name,
    'blackName': blackName,
    'whiteName': whiteName,
    'startedAt': startedAt.toIso8601String(),
    'initialState': initialState.toJson(),
    'state': state.toJson(),
  };

  factory MatchSession.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) throw const FormatException('Unsupported match');
    final humanSide = json['humanSide'] == null
        ? null
        : Side.values.byName(json['humanSide']! as String);
    return MatchSession._(
      id: json['id']! as String,
      mode: MatchMode.values.byName(json['mode']! as String),
      humanSide: humanSide,
      bottomSide: json['bottomSide'] == null
          ? humanSide ?? Side.white
          : Side.values.byName(json['bottomSide']! as String),
      blackName: json['blackName']! as String,
      whiteName: json['whiteName']! as String,
      startedAt: DateTime.parse(json['startedAt']! as String),
      initialState: GameState.fromJson(
        (json['initialState']! as Map).cast<String, Object?>(),
      ),
      state: GameState.fromJson(
        (json['state']! as Map).cast<String, Object?>(),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MatchSession &&
      id == other.id &&
      mode == other.mode &&
      humanSide == other.humanSide &&
      bottomSide == other.bottomSide &&
      blackName == other.blackName &&
      whiteName == other.whiteName &&
      startedAt == other.startedAt &&
      initialState == other.initialState &&
      state == other.state;

  @override
  int get hashCode => Object.hash(
    id,
    mode,
    humanSide,
    bottomSide,
    blackName,
    whiteName,
    startedAt,
    initialState,
    state,
  );
}

class MatchRecord {
  const MatchRecord._({
    required this.id,
    required this.mode,
    required this.humanSide,
    required this.bottomSide,
    required this.blackName,
    required this.whiteName,
    required this.startedAt,
    required this.completedAt,
    required this.initialState,
    required this.finalState,
  });

  factory MatchRecord.fromSession(
    MatchSession session, {
    DateTime? completedAt,
  }) {
    if (session.state.result == null) {
      throw StateError('Only completed matches can be added to history');
    }
    return MatchRecord._(
      id: session.id,
      mode: session.mode,
      humanSide: session.humanSide,
      bottomSide: session.bottomSide,
      blackName: session.blackName,
      whiteName: session.whiteName,
      startedAt: session.startedAt,
      completedAt: completedAt ?? DateTime.now(),
      initialState: session.initialState,
      finalState: session.state,
    );
  }

  final String id;
  final MatchMode mode;
  final Side? humanSide;
  final Side bottomSide;
  final String blackName;
  final String whiteName;
  final DateTime startedAt;
  final DateTime completedAt;
  final GameState initialState;
  final GameState finalState;

  Duration get duration => completedAt.difference(startedAt);
  GameResult get result => finalState.result!;
  Side get perspectiveSide => mode == MatchMode.ai ? humanSide! : bottomSide;
  Side? get aiSide => mode == MatchMode.ai ? humanSide?.opponent : null;
  String nameForSide(Side side) => side == Side.black ? blackName : whiteName;
  String get opponentName => nameForSide(perspectiveSide.opponent);
  PerspectiveOutcome get perspectiveOutcome =>
      result.outcomeFor(perspectiveSide);

  List<GameState> replayStates() {
    final states = <GameState>[initialState];
    var state = initialState;
    const engine = CheckersEngine();
    for (final turn in finalState.turns) {
      state = engine.applyTurn(state, turn);
      states.add(state);
    }
    return states;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'mode': mode.name,
    'humanSide': humanSide?.name,
    'bottomSide': bottomSide.name,
    'blackName': blackName,
    'whiteName': whiteName,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'initialState': initialState.toJson(),
    'finalState': finalState.toJson(),
  };

  factory MatchRecord.fromJson(Map<String, Object?> json) => MatchRecord._(
    id: json['id']! as String,
    mode: MatchMode.values.byName(json['mode']! as String),
    humanSide: json['humanSide'] == null
        ? null
        : Side.values.byName(json['humanSide']! as String),
    bottomSide: json['bottomSide'] == null
        ? (json['humanSide'] == null
              ? Side.white
              : Side.values.byName(json['humanSide']! as String))
        : Side.values.byName(json['bottomSide']! as String),
    blackName: json['blackName']! as String,
    whiteName: json['whiteName']! as String,
    startedAt: DateTime.parse(json['startedAt']! as String),
    completedAt: DateTime.parse(json['completedAt']! as String),
    initialState: GameState.fromJson(
      (json['initialState']! as Map).cast<String, Object?>(),
    ),
    finalState: GameState.fromJson(
      (json['finalState']! as Map).cast<String, Object?>(),
    ),
  );
}

sealed class FeedEntry {
  const FeedEntry();

  String get id;
  DateTime get occurredAt;
  Map<String, Object?> toJson();

  factory FeedEntry.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported feed entry');
    }
    return switch (json['type']) {
      'match' => MatchFeedEntry.fromJson(json),
      'lessonCompletion' => LessonCompletionFeedEntry.fromJson(json),
      'challengeAttempt' => ChallengeAttemptFeedEntry.fromJson(json),
      _ => throw const FormatException('Unknown feed entry type'),
    };
  }
}

final class MatchFeedEntry extends FeedEntry {
  const MatchFeedEntry(this.record);

  final MatchRecord record;

  @override
  String get id => 'match:${record.id}';
  @override
  DateTime get occurredAt => record.completedAt;

  @override
  Map<String, Object?> toJson() => {
    'version': 1,
    'type': 'match',
    'record': record.toJson(),
  };

  factory MatchFeedEntry.fromJson(Map<String, Object?> json) => MatchFeedEntry(
    MatchRecord.fromJson((json['record']! as Map).cast<String, Object?>()),
  );
}

final class LessonCompletionFeedEntry extends FeedEntry {
  const LessonCompletionFeedEntry({
    required this.lessonId,
    required this.lessonNumber,
    required this.completedAt,
  });

  final String lessonId;
  final int lessonNumber;
  final DateTime completedAt;

  @override
  String get id => 'lesson:$lessonId';
  @override
  DateTime get occurredAt => completedAt;

  @override
  Map<String, Object?> toJson() => {
    'version': 1,
    'type': 'lessonCompletion',
    'lessonId': lessonId,
    'lessonNumber': lessonNumber,
    'completedAt': completedAt.toIso8601String(),
  };

  factory LessonCompletionFeedEntry.fromJson(Map<String, Object?> json) =>
      LessonCompletionFeedEntry(
        lessonId: json['lessonId']! as String,
        lessonNumber: json['lessonNumber']! as int,
        completedAt: DateTime.parse(json['completedAt']! as String),
      );
}

final class ChallengeAttemptFeedEntry extends FeedEntry {
  const ChallengeAttemptFeedEntry({
    required this.lessonId,
    required this.lessonNumber,
    required this.record,
  });

  final String lessonId;
  final int lessonNumber;
  final MatchRecord record;

  @override
  String get id => 'challenge:${record.id}';
  @override
  DateTime get occurredAt => record.completedAt;

  @override
  Map<String, Object?> toJson() => {
    'version': 1,
    'type': 'challengeAttempt',
    'lessonId': lessonId,
    'lessonNumber': lessonNumber,
    'record': record.toJson(),
  };

  factory ChallengeAttemptFeedEntry.fromJson(Map<String, Object?> json) =>
      ChallengeAttemptFeedEntry(
        lessonId: json['lessonId']! as String,
        lessonNumber: json['lessonNumber']! as int,
        record: MatchRecord.fromJson(
          (json['record']! as Map).cast<String, Object?>(),
        ),
      );
}

class CrownSettings {
  const CrownSettings({
    this.sound = true,
    this.haptics = true,
    this.showCoordinates = false,
    this.reducedMotion = false,
    this.highContrast = false,
  });

  final bool sound;
  final bool haptics;
  final bool showCoordinates;
  final bool reducedMotion;
  final bool highContrast;

  CrownSettings copyWith({
    bool? sound,
    bool? haptics,
    bool? showCoordinates,
    bool? reducedMotion,
    bool? highContrast,
  }) => CrownSettings(
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    showCoordinates: showCoordinates ?? this.showCoordinates,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    highContrast: highContrast ?? this.highContrast,
  );

  Map<String, Object> toJson() => {
    'sound': sound,
    'haptics': haptics,
    'showCoordinates': showCoordinates,
    'reducedMotion': reducedMotion,
    'highContrast': highContrast,
  };

  factory CrownSettings.fromJson(Map<String, Object?> json) => CrownSettings(
    sound: json['sound'] as bool? ?? true,
    haptics: json['haptics'] as bool? ?? true,
    showCoordinates: json['showCoordinates'] as bool? ?? false,
    reducedMotion: json['reducedMotion'] as bool? ?? false,
    highContrast: json['highContrast'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is CrownSettings &&
      sound == other.sound &&
      haptics == other.haptics &&
      showCoordinates == other.showCoordinates &&
      reducedMotion == other.reducedMotion &&
      highContrast == other.highContrast;

  @override
  int get hashCode =>
      Object.hash(sound, haptics, showCoordinates, reducedMotion, highContrast);
}

class LearnProgress {
  const LearnProgress({this.lastCompletedLesson = 0})
    : assert(lastCompletedLesson >= 0 && lastCompletedLesson <= 64);

  final int lastCompletedLesson;

  Map<String, Object> toJson() => {
    'version': 1,
    'lastCompletedLesson': lastCompletedLesson,
  };

  factory LearnProgress.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported progress');
    }
    final lesson = json['lastCompletedLesson'];
    if (lesson is! int || lesson < 0 || lesson > 64) {
      throw const FormatException('Invalid lesson progress');
    }
    return LearnProgress(lastCompletedLesson: lesson);
  }

  @override
  bool operator ==(Object other) =>
      other is LearnProgress &&
      lastCompletedLesson == other.lastCompletedLesson;

  @override
  int get hashCode => lastCompletedLesson.hashCode;
}

abstract class CrownRepository {
  Future<MatchSession?> loadActiveMatch();
  Future<void> saveActiveMatch(MatchSession session);
  Future<void> clearActiveMatch();
  Future<List<MatchRecord>> loadHistory();
  Future<void> addHistory(MatchRecord record);
  Future<List<FeedEntry>> loadFeed();
  Future<void> addFeedEntry(FeedEntry entry);
  Future<CrownSettings> loadSettings();
  Future<void> saveSettings(CrownSettings settings);
  Future<AiProfile> loadAiProfile();
  Future<void> saveAiProfile(AiProfile profile);
  Future<LearnProgress> loadLearnProgress();
  Future<void> saveLearnProgress(LearnProgress progress);
}

class MemoryCrownRepository implements CrownRepository {
  MatchSession? _active;
  final List<FeedEntry> _feed = [];
  CrownSettings _settings = const CrownSettings();
  AiProfile _profile = const AiProfile();
  LearnProgress _learnProgress = const LearnProgress();

  @override
  Future<MatchSession?> loadActiveMatch() async => _active;
  @override
  Future<void> saveActiveMatch(MatchSession session) async => _active = session;
  @override
  Future<void> clearActiveMatch() async => _active = null;
  @override
  Future<List<MatchRecord>> loadHistory() async => List.unmodifiable(
    _feed.whereType<MatchFeedEntry>().map((entry) => entry.record),
  );
  @override
  Future<void> addHistory(MatchRecord record) =>
      addFeedEntry(MatchFeedEntry(record));

  @override
  Future<List<FeedEntry>> loadFeed() async => List.unmodifiable(_feed);
  @override
  Future<void> addFeedEntry(FeedEntry entry) async {
    _feed.removeWhere((item) => item.id == entry.id);
    _feed.add(entry);
    _feed.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (_feed.length > 50) _feed.removeRange(50, _feed.length);
  }

  @override
  Future<CrownSettings> loadSettings() async => _settings;
  @override
  Future<void> saveSettings(CrownSettings settings) async =>
      _settings = settings;
  @override
  Future<AiProfile> loadAiProfile() async => _profile;
  @override
  Future<void> saveAiProfile(AiProfile profile) async => _profile = profile;
  @override
  Future<LearnProgress> loadLearnProgress() async => _learnProgress;
  @override
  Future<void> saveLearnProgress(LearnProgress progress) async {
    if (progress.lastCompletedLesson > _learnProgress.lastCompletedLesson) {
      _learnProgress = progress;
    }
  }
}

class SharedPreferencesCrownRepository implements CrownRepository {
  SharedPreferencesCrownRepository(this._preferences);

  final SharedPreferences _preferences;
  static const _activeKey = 'active_match_v1';
  static const _historyKey = 'match_history_v1';
  static const _feedKey = 'feed_history_v1';
  static const _settingsKey = 'settings_v1';
  static const _aiKey = 'ai_profile_v1';
  static const _learnProgressKey = 'learn_progress_v1';

  @override
  Future<MatchSession?> loadActiveMatch() async {
    final value = _preferences.getString(_activeKey);
    if (value == null) return null;
    try {
      return MatchSession.fromJson(
        (jsonDecode(value) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      await clearActiveMatch();
      return null;
    }
  }

  @override
  Future<void> saveActiveMatch(MatchSession session) =>
      _preferences.setString(_activeKey, jsonEncode(session.toJson()));

  @override
  Future<void> clearActiveMatch() => _preferences.remove(_activeKey);

  @override
  Future<List<MatchRecord>> loadHistory() async {
    final feed = await loadFeed();
    return feed
        .whereType<MatchFeedEntry>()
        .map((entry) => entry.record)
        .toList();
  }

  @override
  Future<void> addHistory(MatchRecord record) =>
      addFeedEntry(MatchFeedEntry(record));

  @override
  Future<List<FeedEntry>> loadFeed() async {
    final value = _preferences.getString(_feedKey);
    if (value != null) {
      try {
        return (jsonDecode(value) as List)
            .map(
              (item) =>
                  FeedEntry.fromJson((item as Map).cast<String, Object?>()),
            )
            .toList();
      } on Object {
        await _discardCorruptFeed();
        return const [];
      }
    }

    final legacy = _preferences.getString(_historyKey);
    if (legacy == null) return const [];
    try {
      final feed = (jsonDecode(legacy) as List)
          .map(
            (item) => MatchFeedEntry(
              MatchRecord.fromJson((item as Map).cast<String, Object?>()),
            ),
          )
          .toList();
      await _saveFeed(feed);
      return feed;
    } on Object {
      await _discardCorruptFeed();
      return const [];
    }
  }

  @override
  Future<void> addFeedEntry(FeedEntry entry) async {
    final feed = [...await loadFeed()];
    feed.removeWhere((item) => item.id == entry.id);
    feed.add(entry);
    feed.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (feed.length > 50) feed.removeRange(50, feed.length);
    await _saveFeed(feed);
  }

  Future<void> _saveFeed(List<FeedEntry> feed) async {
    await _preferences.setString(
      _feedKey,
      jsonEncode(feed.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _discardCorruptFeed() async {
    await _preferences.remove(_feedKey);
    await _preferences.remove(_historyKey);
  }

  @override
  Future<CrownSettings> loadSettings() async {
    final value = _preferences.getString(_settingsKey);
    if (value == null) return const CrownSettings();
    return CrownSettings.fromJson(
      (jsonDecode(value) as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<void> saveSettings(CrownSettings settings) =>
      _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));

  @override
  Future<AiProfile> loadAiProfile() async {
    final value = _preferences.getString(_aiKey);
    if (value == null) return const AiProfile();
    return AiProfile.fromJson(
      (jsonDecode(value) as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<void> saveAiProfile(AiProfile profile) =>
      _preferences.setString(_aiKey, jsonEncode(profile.toJson()));

  @override
  Future<LearnProgress> loadLearnProgress() async {
    final value = _preferences.getString(_learnProgressKey);
    if (value == null) return const LearnProgress();
    try {
      return LearnProgress.fromJson(
        (jsonDecode(value) as Map).cast<String, Object?>(),
      );
    } on Object {
      await _preferences.remove(_learnProgressKey);
      return const LearnProgress();
    }
  }

  @override
  Future<void> saveLearnProgress(LearnProgress progress) async {
    final current = await loadLearnProgress();
    if (progress.lastCompletedLesson <= current.lastCompletedLesson) return;
    await _preferences.setString(
      _learnProgressKey,
      jsonEncode(progress.toJson()),
    );
  }
}
