import 'lesson_definition.dart';

class LearnLesson {
  const LearnLesson({
    required this.id,
    required this.number,
    required this.name,
    required this.objective,
    required this.contentAndExercise,
    required this.status,
    this.definitionAsset,
  });

  factory LearnLesson.fromJson(Map<String, Object?> json) => LearnLesson(
    id: json['id']! as String,
    number: json['number']! as int,
    name: json['name']! as String,
    objective: json['objective']! as String,
    contentAndExercise: json['overview']! as String,
    status: LessonStatus.values.byName(json['status']! as String),
    definitionAsset: json['definitionAsset'] as String?,
  );

  final String id;
  final int number;
  final String name;
  final String objective;
  final String contentAndExercise;
  final LessonStatus status;
  final String? definitionAsset;

  bool get isChallenge => number % 8 == 0;
}

enum LessonStatus { planned, available }

class LearnUnit {
  const LearnUnit(this.number, this.name, this.lessons);

  factory LearnUnit.fromJson(Map<String, Object?> json) => LearnUnit(
    json['number']! as int,
    json['name']! as String,
    List.unmodifiable(
      (json['lessons']! as List).map(
        (value) => LearnLesson.fromJson((value as Map).cast<String, Object?>()),
      ),
    ),
  );

  final int number;
  final String name;
  final List<LearnLesson> lessons;
}

class LearnCatalog {
  const LearnCatalog(this.units, {this.definitions = const {}});

  final List<LearnUnit> units;
  final Map<String, LessonDefinition> definitions;
}
