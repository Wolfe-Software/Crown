import 'package:crown/features/learn/learn_curriculum.dart';
import 'package:crown/features/learn/lesson_asset_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'curriculum has eight ordered units and 64 complete, consecutive lessons',
    () async {
      final learnCurriculum = (await LessonAssetLoader().loadCatalog(
        'assets/learn/catalog.json',
      )).units;
      expect(learnCurriculum, hasLength(8));
      final numbers = <int>[];
      for (var row = 0; row < 8; row++) {
        final unit = learnCurriculum[row];
        expect(unit.number, row + 1);
        expect(unit.name, isNotEmpty);
        expect(unit.lessons, hasLength(8));
        for (var column = 0; column < 8; column++) {
          final lesson = unit.lessons[column];
          expect(lesson.number, row * 8 + column + 1);
          expect(lesson.name, isNotEmpty);
          expect(lesson.contentAndExercise, isNotEmpty);
          expect(lesson.objective, isNotEmpty);
          expect(lesson.objective.length, lessThan(120));
          expect(lesson.isChallenge, column == 7);
          numbers.add(lesson.number);
        }
      }
      expect(numbers.toSet(), hasLength(64));
      final lessons = learnCurriculum.expand((unit) => unit.lessons).toList();
      expect(lessons.map((lesson) => lesson.id).toSet(), hasLength(64));
      expect(
        lessons
            .where((lesson) => lesson.definitionAsset != null)
            .map((lesson) => lesson.number),
        List.generate(16, (index) => index + 1),
      );
      expect(
        lessons.where((lesson) => lesson.status == LessonStatus.available),
        everyElement(
          isA<LearnLesson>().having(
            (lesson) => lesson.definitionAsset,
            'definitionAsset',
            isNotNull,
          ),
        ),
      );
      expect(learnCurriculum.first.lessons.first.name, 'Meet the Board');
      expect(learnCurriculum.first.lessons[1].name, 'Making Captures');
      expect(learnCurriculum.first.lessons[2].name, 'Capture Is Compulsory');
      expect(
        learnCurriculum.first.lessons[2].contentAndExercise,
        contains('free choice among legal single captures'),
      );
      expect(
        learnCurriculum.first.lessons[2].contentAndExercise,
        isNot(contains('blocked jumps')),
      );
      expect(learnCurriculum[2].lessons[2].name, 'Build a Multiple Jump');
      expect(
        learnCurriculum.last.lessons.last.name,
        'Final Challenge: A Complete Game',
      );
      expect(
        learnCurriculum[0].lessons[4].contentAndExercise,
        'Explain the promotion row and that reaching it ends the turn, including during a capture. Guide pieces to promotion through ordinary moves and jumps.',
      );
    },
  );
}
