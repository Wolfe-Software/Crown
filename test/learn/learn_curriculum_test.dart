import 'package:crown/features/learn/learn_curriculum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'curriculum has eight ordered units and 64 complete, consecutive lessons',
    () {
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
      expect(learnCurriculum.first.lessons.first.name, 'Meet the Board');
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
