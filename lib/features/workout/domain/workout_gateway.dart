class ExerciseOption {
  const ExerciseOption(this.id, this.name, this.group);
  final String id;
  final String name;
  final String group;
}

class WorkoutItem {
  const WorkoutItem({
    required this.exercise,
    this.sets = 3,
    this.reps = 10,
    this.weight = 0,
    this.restSeconds = 90,
  });
  final ExerciseOption exercise;
  final int sets;
  final int reps;
  final double weight;
  final int restSeconds;
}

class WorkoutPlan {
  WorkoutPlan({
    required this.id,
    required this.name,
    required this.weekday,
    this.description = '',
    this.active = true,
    required List<WorkoutItem> items,
  }) : items = List.unmodifiable(items);
  final String id;
  final String name;
  final int weekday;
  final String description;
  final bool active;
  final List<WorkoutItem> items;
}

/// Front-end boundary. Implement using the local database repositories.
abstract class WorkoutGateway {
  Future<List<WorkoutPlan>> loadWorkouts();
  Future<List<ExerciseOption>> loadExercises();
  Future<void> saveWorkout(WorkoutPlan workout);
  Future<void> deleteWorkout(String id);
}

const weekdays = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];
