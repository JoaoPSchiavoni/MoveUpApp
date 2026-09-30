import '../domain/workout_gateway.dart';

/// Temporary preview adapter: data is lost when the application restarts.
class PreviewWorkoutGateway implements WorkoutGateway {
  final _workouts = <String, WorkoutPlan>{};
  @override
  Future<List<WorkoutPlan>> loadWorkouts() async => _workouts.values.toList();
  @override
  Future<void> saveWorkout(WorkoutPlan workout) async {
    _workouts[workout.id] = workout;
  }

  @override
  Future<void> deleteWorkout(String id) async {
    _workouts.remove(id);
  }

  @override
  Future<List<ExerciseOption>> loadExercises() async => const [
    ExerciseOption('supino-reto', 'Supino reto', 'Peito'),
    ExerciseOption('supino-inclinado', 'Supino inclinado', 'Peito'),
    ExerciseOption('crucifixo', 'Crucifixo', 'Peito'),
    ExerciseOption('puxada', 'Puxada frontal', 'Costas'),
    ExerciseOption('remada', 'Remada baixa', 'Costas'),
    ExerciseOption('agachamento', 'Agachamento', 'Pernas'),
    ExerciseOption('leg-press', 'Leg press', 'Pernas'),
    ExerciseOption('extensora', 'Cadeira extensora', 'Pernas'),
    ExerciseOption('rosca', 'Rosca direta', 'Bíceps'),
    ExerciseOption('pulley', 'Tríceps pulley', 'Tríceps'),
    ExerciseOption('desenvolvimento', 'Desenvolvimento', 'Ombros'),
    ExerciseOption('abdominal', 'Abdominal', 'Abdômen'),
  ];
}
