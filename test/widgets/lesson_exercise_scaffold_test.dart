import 'package:crown/app/crown_theme.dart';
import 'package:crown/features/learn/lesson_exercise_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('enforces the standard lesson presentation and action labels', (
    tester,
  ) async {
    var actionCount = 0;

    Widget lesson({required bool complete, required bool finalExercise}) =>
        MaterialApp(
          theme: crownTheme(),
          home: LessonExerciseScaffold(
            lessonNumber: 9,
            lessonName: 'STANDARD LESSON',
            exerciseNumber: 2,
            exerciseCount: 4,
            exerciseTitle: 'Exercise title',
            instruction: 'Exercise instruction',
            board: const SizedBox(key: ValueKey('lesson-board')),
            feedback: 'Exercise feedback',
            feedbackMessages: const ['Exercise feedback'],
            feedbackKey: const ValueKey('lesson-feedback'),
            exerciseComplete: complete,
            isFinalExercise: finalExercise,
            onContinue: () => actionCount++,
          ),
        );

    await tester.pumpWidget(lesson(complete: false, finalExercise: false));

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('LESSON 9'), findsOneWidget);
    expect(find.text('STANDARD LESSON'), findsOneWidget);
    expect(find.text('EXERCISE 2 OF 4'), findsOneWidget);
    expect(find.text('Exercise title'), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-board')), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('lesson-feedback')))
          .properties
          .liveRegion,
      isTrue,
    );

    await tester.pumpWidget(lesson(complete: true, finalExercise: false));
    await tester.tap(find.widgetWithText(FilledButton, 'CONTINUE'));
    expect(actionCount, 1);

    await tester.pumpWidget(lesson(complete: true, finalExercise: true));
    await tester.tap(find.widgetWithText(FilledButton, 'COMPLETE LESSON'));
    expect(actionCount, 2);
  });
}
