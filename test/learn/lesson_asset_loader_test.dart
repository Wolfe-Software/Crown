import 'dart:convert';

import 'package:crown/features/learn/lesson_asset_loader.dart';
import 'package:crown/features/learn/learn_curriculum.dart';
import 'package:crown/features/learn/lesson_definition.dart';
import 'package:crown/game_engine/checkers_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) throw StateError('Missing asset: $key');
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('requires five exercises in Unit 2 standard lessons', () async {
    const path = 'lesson-009.json';
    final json = (jsonDecode(
      await rootBundle.loadString('assets/learn/lessons/lesson-009.json'),
    ) as Map).cast<String, Object?>();
    (json['exercises']! as List).removeLast();
    final loader = LessonAssetLoader(
      bundle: _MemoryAssetBundle({path: jsonEncode(json)}),
    );
    final lesson = LearnLesson.fromJson({
      'id': 'lesson-009',
      'number': 9,
      'name': 'Spot the Threat',
      'objective': 'Find threats.',
      'overview': 'Find threats.',
      'status': 'available',
      'definitionAsset': path,
    });

    await expectLater(
      loader.loadDefinition(lesson),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('exactly five exercises'),
        ),
      ),
    );
  });

  for (final (field, value) in <(String, Object?)>[
    ('type', 'unknown'),
    ('startingPosition', 'custom'),
    ('completion', 'finishOnly'),
    ('aiSkill', -1),
    ('aiSkill', 11),
    ('humanSide', 'red'),
    ('introduction', ''),
    ('coaching', <String, Object?>{}),
    ('review', <Object?>[]),
    ('exercises', <Object?>[]),
    ('name', 'Mismatched name'),
  ]) {
    test('rejects invalid guided-match $field: $value', () async {
      const path = 'assets/learn/lessons/lesson-008.json';
      final json = (jsonDecode(await rootBundle.loadString(path)) as Map)
          .cast<String, Object?>();
      json[field] = value;
      final loader = LessonAssetLoader(
        bundle: _MemoryAssetBundle({path: jsonEncode(json)}),
      );
      final lesson = LearnLesson.fromJson({
        'id': 'lesson-008',
        'number': 8,
        'name': 'Challenge: Your First Game',
        'objective': 'Win and review.',
        'overview': 'A full guided match.',
        'status': 'available',
        'definitionAsset': path,
      });
      await expectLater(
        loader.loadDefinition(lesson),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'asset path',
            contains(path),
          ),
        ),
      );
    });
  }

  test('loads a versioned catalog and its executable lesson', () async {
    final bundle = _MemoryAssetBundle({
      'catalog.json': jsonEncode({
        'schemaVersion': 1,
        'units': [
          {
            'number': 1,
            'name': 'The Fundamentals',
            'lessons': [
              {
                'id': 'lesson-001',
                'number': 1,
                'name': 'Meet the Board',
                'objective': 'Restore the starting position.',
                'overview': 'Place pieces and make moves.',
                'status': 'available',
                'definitionAsset': 'lesson-001.json',
              },
            ],
          },
        ],
      }),
      'lesson-001.json': jsonEncode({
        'schemaVersion': 2,
        'id': 'lesson-001',
        'number': 1,
        'name': 'Meet the Board',
        'exercises': [
          {
            'id': 'place-black',
            'title': 'Set up the black pieces',
            'instruction': 'Place the missing pieces.',
            'perspective': 'black',
            'board': {
              'source': 'initialWithRemovedPieces',
              'removed': [
                {'row': 0, 'column': 1},
              ],
            },
            'interaction': {
              'type': 'placement',
              'piece': {'side': 'black', 'rank': 'man'},
              'targets': [
                {'row': 0, 'column': 1},
              ],
            },
            'feedback': {
              'initial': 'Find the gap.',
              'progress': 'Correct. Place {remaining} more.',
              'success': 'Black is complete.',
              'invalidPiece': 'That square already has a piece.',
              'invalidDestination': 'That is not a gap.',
            },
          },
        ],
      }),
    });
    final loader = LessonAssetLoader(bundle: bundle);

    final catalog = await loader.loadCatalog('catalog.json');
    final definition = await loader.loadDefinition(
      catalog.units.single.lessons.single,
    );

    expect(catalog.units.single.name, 'The Fundamentals');
    expect(definition.id, 'lesson-001');
    expect(definition.exercises.single.id, 'place-black');
    expect(definition.exercises.single.initialPieces, hasLength(23));
  });

  test('rejects an unsupported schema with the asset path', () async {
    final loader = LessonAssetLoader(
      bundle: _MemoryAssetBundle({
        'catalog.json': jsonEncode({'schemaVersion': 2, 'units': []}),
      }),
    );

    await expectLater(
      loader.loadCatalog('catalog.json'),
      throwsA(
        isA<FormatException>()
            .having(
              (error) => error.message,
              'message',
              contains('catalog.json'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('schemaVersion'),
            ),
      ),
    );
  });

  test(
    'rejects a multi-jump authored turn truncated after its first landing',
    () async {
      final catalogLesson = {
        'id': 'lesson-002',
        'number': 2,
        'name': 'Making Captures',
        'objective': 'Capture.',
        'overview': 'Capture.',
        'status': 'available',
        'definitionAsset': 'lesson-002.json',
      };
      final loader = LessonAssetLoader(
        bundle: _MemoryAssetBundle({
          'catalog.json': jsonEncode({
            'schemaVersion': 1,
            'units': [
              {
                'number': 1,
                'name': 'Unit',
                'lessons': [catalogLesson],
              },
            ],
          }),
          'lesson-002.json': jsonEncode({
            'schemaVersion': 2,
            'id': 'lesson-002',
            'number': 2,
            'name': 'Making Captures',
            'exercises': [
              {
                'id': 'bad-turn',
                'title': 'Bad turn',
                'instruction': 'Move.',
                'perspective': 'black',
                'board': {
                  'source': 'custom',
                  'sideToMove': 'black',
                  'pieces': [
                    {
                      'square': {'row': 1, 'column': 0},
                      'side': 'black',
                      'rank': 'man',
                    },
                    {
                      'square': {'row': 2, 'column': 1},
                      'side': 'white',
                      'rank': 'man',
                    },
                    {
                      'square': {'row': 4, 'column': 3},
                      'side': 'white',
                      'rank': 'man',
                    },
                  ],
                },
                'interaction': {
                  'type': 'turn',
                  'acceptance': 'exactLegalSet',
                  'turns': [
                    {
                      'origin': {'row': 1, 'column': 0},
                      'landings': [
                        {'row': 3, 'column': 2},
                      ],
                      'captures': [
                        {'row': 2, 'column': 1},
                      ],
                    },
                  ],
                },
                'feedback': {
                  'initial': 'Move.',
                  'success': 'Done.',
                  'invalidPiece': 'Wrong.',
                  'invalidDestination': 'Wrong.',
                },
              },
            ],
          }),
        }),
      );
      await expectLater(
        loader.loadCatalog('catalog.json'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('engine legal turns'),
          ),
        ),
      );
    },
  );

  test('requires definitions only for available lessons', () async {
    final loader = LessonAssetLoader(
      bundle: _MemoryAssetBundle({
        'catalog.json': jsonEncode({
          'schemaVersion': 1,
          'units': [
            {
              'number': 1,
              'name': 'Unit',
              'lessons': [
                {
                  'id': 'lesson-001',
                  'number': 1,
                  'name': 'Missing Definition',
                  'objective': 'Objective.',
                  'overview': 'Overview.',
                  'status': 'available',
                },
              ],
            },
          ],
        }),
      }),
    );

    await expectLater(
      loader.loadCatalog('catalog.json'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('available lesson requires definitionAsset'),
        ),
      ),
    );
  });

  test('loads a schema v2 choice interaction and typed outcome', () async {
    final loader = LessonAssetLoader(
      bundle: _lessonBundle(
        exercise: {
          'id': 'classify-resignation',
          'title': 'Resignation',
          'instruction': 'White resigned. Classify the result.',
          'perspective': 'black',
          'board': {
            'source': 'custom',
            'sideToMove': 'black',
            'pieces': [
              {
                'square': {'row': 2, 'column': 1},
                'side': 'black',
                'rank': 'man',
              },
              {
                'square': {'row': 5, 'column': 0},
                'side': 'white',
                'rank': 'man',
              },
            ],
          },
          'outcome': {'winner': 'black', 'reason': 'resignation'},
          'interaction': {
            'type': 'choice',
            'correctOptionId': 'black-wins',
            'options': [
              {
                'id': 'black-wins',
                'label': 'Black wins',
                'icon': 'blackChecker',
                'feedback': 'Correct.',
              },
              {
                'id': 'draw',
                'label': 'Draw',
                'icon': 'draw',
                'feedback': 'Resignation awards a win.',
              },
            ],
          },
          'feedback': {
            'initial': 'Choose the result.',
            'success': 'Black wins when White resigns.',
          },
        },
      ),
    );

    final catalog = await loader.loadCatalog('catalog.json');
    final exercise = catalog.definitions.values.single.exercises.single;

    expect(exercise.interactionType, LessonInteractionType.choice);
    expect(exercise.choiceOptions.map((option) => option.id), [
      'black-wins',
      'draw',
    ]);
    expect(exercise.choiceOptions.map((option) => option.icon), [
      LessonChoiceIcon.blackChecker,
      LessonChoiceIcon.draw,
    ]);
    expect(exercise.correctChoiceId, 'black-wins');
    expect(
      exercise.outcome,
      const GameResult.win(Side.black, ResultReason.resignation),
    );
  });

  test('rejects a choice whose correct option does not exist', () async {
    final loader = LessonAssetLoader(
      bundle: _lessonBundle(
        exercise: {
          'id': 'bad-choice',
          'title': 'Bad choice',
          'instruction': 'Choose.',
          'perspective': 'black',
          'board': {
            'source': 'custom',
            'pieces': [
              {
                'square': {'row': 2, 'column': 1},
                'side': 'black',
                'rank': 'man',
              },
            ],
          },
          'interaction': {
            'type': 'choice',
            'correctOptionId': 'missing',
            'options': [
              {'id': 'win', 'label': 'Win', 'feedback': 'Try again.'},
              {'id': 'draw', 'label': 'Draw', 'feedback': 'Try again.'},
            ],
          },
          'feedback': {'initial': 'Choose.', 'success': 'Correct.'},
        },
      ),
    );

    await expectLater(
      loader.loadCatalog('catalog.json'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('correctOptionId'),
        ),
      ),
    );
  });

  test('rejects a turn outcome that disagrees with the engine', () async {
    final loader = LessonAssetLoader(
      bundle: _lessonBundle(
        exercise: {
          'id': 'bad-outcome',
          'title': 'Finish',
          'instruction': 'Capture.',
          'perspective': 'black',
          'board': {
            'source': 'custom',
            'sideToMove': 'black',
            'pieces': [
              {
                'square': {'row': 2, 'column': 1},
                'side': 'black',
                'rank': 'man',
              },
              {
                'square': {'row': 3, 'column': 2},
                'side': 'white',
                'rank': 'man',
              },
            ],
          },
          'outcome': {'winner': null, 'reason': 'repetition'},
          'interaction': {
            'type': 'turn',
            'acceptance': 'exactLegalSet',
            'turns': [
              {
                'origin': {'row': 2, 'column': 1},
                'landings': [
                  {'row': 4, 'column': 3},
                ],
                'captures': [
                  {'row': 3, 'column': 2},
                ],
              },
            ],
          },
          'feedback': {
            'initial': 'Capture.',
            'success': 'Done.',
            'invalidPiece': 'Wrong piece.',
            'invalidDestination': 'Wrong square.',
          },
        },
      ),
    );

    await expectLater(
      loader.loadCatalog('catalog.json'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('outcome does not match'),
        ),
      ),
    );
  });
}

_MemoryAssetBundle _lessonBundle({required Map<String, Object?> exercise}) =>
    _MemoryAssetBundle({
      'catalog.json': jsonEncode({
        'schemaVersion': 1,
        'units': [
          {
            'number': 1,
            'name': 'Unit',
            'lessons': [
              {
                'id': 'lesson-007',
                'number': 7,
                'name': 'How Games End',
                'objective': 'Recognize results.',
                'overview': 'Classify completed games.',
                'status': 'available',
                'definitionAsset': 'lesson-007.json',
              },
            ],
          },
        ],
      }),
      'lesson-007.json': jsonEncode({
        'schemaVersion': 2,
        'id': 'lesson-007',
        'number': 7,
        'name': 'How Games End',
        'exercises': [exercise],
      }),
    });
