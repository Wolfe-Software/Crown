import 'package:crown/features/learn/lesson_exercise_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void expectStandardLessonPresentation({
  required WidgetTester tester,
  required Key feedbackKey,
}) {
  expect(find.byType(LessonExerciseScaffold), findsOneWidget);
  expect(find.byType(LinearProgressIndicator), findsOneWidget);
  expect(
    tester.widget<Semantics>(find.byKey(feedbackKey)).properties.liveRegion,
    isTrue,
  );
}
