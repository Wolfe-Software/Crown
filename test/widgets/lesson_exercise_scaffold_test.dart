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

    expect(find.byType(SingleChildScrollView), findsOneWidget);
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
    final continueButton = find.widgetWithText(FilledButton, 'CONTINUE');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    expect(actionCount, 1);

    await tester.pumpWidget(lesson(complete: true, finalExercise: true));
    final completeButton = find.widgetWithText(FilledButton, 'COMPLETE LESSON');
    await tester.ensureVisible(completeButton);
    await tester.tap(completeButton);
    expect(actionCount, 2);
  });

  testWidgets('completion does not move or shrink the exercise board', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget lesson({required bool complete}) => MaterialApp(
      theme: crownTheme(),
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
        child: LessonExerciseScaffold(
          lessonNumber: 1,
          lessonName: 'THE FUNDAMENTALS',
          exerciseNumber: 1,
          exerciseCount: 2,
          exerciseTitle: 'Move a checker',
          instruction: 'Choose the checker, then choose its destination.',
          board: const AspectRatio(
            key: ValueKey('sized-lesson-board'),
            aspectRatio: 1,
          ),
          feedback: complete ? 'Excellent move.' : 'Your turn.',
          feedbackMessages: const ['Your turn.', 'Excellent move.'],
          feedbackKey: const ValueKey('lesson-feedback'),
          exerciseComplete: complete,
          isFinalExercise: false,
          onContinue: () {},
        ),
      ),
    );

    await tester.pumpWidget(lesson(complete: false));
    final initialBoard = tester.getRect(
      find.byKey(const ValueKey('sized-lesson-board')),
    );

    await tester.pumpWidget(lesson(complete: true));
    await tester.pump();
    final completedBoard = tester.getRect(
      find.byKey(const ValueKey('sized-lesson-board')),
    );

    expect(completedBoard, initialBoard);
    expect(completedBoard.width, 358);
  });

  testWidgets('compact completion keeps a full-width board and inline action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: crownTheme(),
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 21)),
          child: LessonExerciseScaffold(
            lessonNumber: 1,
            lessonName: 'THE FUNDAMENTALS',
            exerciseNumber: 1,
            exerciseCount: 2,
            exerciseTitle: 'Move a checker',
            instruction: 'Choose the checker, then choose its destination.',
            board: const AspectRatio(
              key: ValueKey('compact-lesson-board'),
              aspectRatio: 1,
            ),
            feedback: 'Excellent move.',
            feedbackMessages: const ['Your turn.', 'Excellent move.'],
            feedbackKey: const ValueKey('lesson-feedback'),
            exerciseComplete: true,
            isFinalExercise: false,
            onContinue: () {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('compact-lesson-board'))),
      const Size.square(288),
    );
    final feedback = tester.getRect(
      find.byKey(const ValueKey('lesson-feedback')),
    );
    final action = tester.getRect(
      find.byKey(const ValueKey('lesson-continue-compact')),
    );
    expect(action.width, action.height);
    expect(action.left, greaterThan(feedback.right));
    expect(action.center.dy, closeTo(feedback.center.dy, 1));
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
