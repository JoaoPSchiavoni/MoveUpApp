import '../../workout/domain/workout_gateway.dart';

enum SessionStatus { active, completed, cancelled }

enum SetStatus { pending, completed, skipped }

class SessionSet {
  const SessionSet({
    required this.id,
    required this.order,
    required this.plannedReps,
    required this.plannedWeight,
    this.reps,
    this.weight,
    this.status = SetStatus.pending,
  });
  final String id;
  final int order, plannedReps;
  final double plannedWeight;
  final int? reps;
  final double? weight;
  final SetStatus status;
  SessionSet recorded(SetStatus state, {int? reps, double? weight}) =>
      SessionSet(
        id: id,
        order: order,
        plannedReps: plannedReps,
        plannedWeight: plannedWeight,
        status: state,
        reps: reps,
        weight: weight,
      );
}

class SessionExercise {
  SessionExercise({
    required this.id,
    required this.name,
    required this.group,
    required this.order,
    required this.restSeconds,
    required List<SessionSet> sets,
  }) : sets = List.unmodifiable(sets);
  final String id, name, group;
  final int order, restSeconds;
  final List<SessionSet> sets;
  SessionExercise withSets(List<SessionSet> value) => SessionExercise(
    id: id,
    name: name,
    group: group,
    order: order,
    restSeconds: restSeconds,
    sets: value,
  );
}

class TrainingSession {
  TrainingSession({
    required this.id,
    required this.name,
    required this.startedAt,
    required List<SessionExercise> exercises,
    this.endedAt,
    this.status = SessionStatus.active,
    this.note = '',
  }) : exercises = List.unmodifiable(exercises);
  final String id, name, note;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SessionStatus status;
  final List<SessionExercise> exercises;
  Iterable<SessionSet> get sets => exercises.expand((e) => e.sets);
  int get completed =>
      sets.where((s) => s.status == SetStatus.completed).length;
  int get pending => sets.where((s) => s.status == SetStatus.pending).length;
  int get skipped => sets.where((s) => s.status == SetStatus.skipped).length;
  int get exercisesDone => exercises
      .where((e) => e.sets.any((s) => s.status == SetStatus.completed))
      .length;
  double get volume => sets
      .where((s) => s.status == SetStatus.completed)
      .fold(0, (sum, s) => sum + (s.weight ?? 0) * (s.reps ?? 0));
  TrainingSession copy({
    List<SessionExercise>? exercises,
    SessionStatus? status,
    DateTime? endedAt,
    String? note,
  }) => TrainingSession(
    id: id,
    name: name,
    startedAt: startedAt,
    exercises: exercises ?? this.exercises,
    status: status ?? this.status,
    endedAt: endedAt ?? this.endedAt,
    note: note ?? this.note,
  );
}

class SessionPage {
  const SessionPage(this.items, {required this.hasMore});
  final List<TrainingSession> items;
  final bool hasMore;
}

class SessionFailure implements Exception {
  const SessionFailure(this.message, {this.conflict = false});
  final String message;
  final bool conflict;
  @override
  String toString() => message;
}

abstract class SessionGateway {
  Future<TrainingSession?> loadActive();
  Future<TrainingSession> load(String id);
  Future<TrainingSession> start(String id, WorkoutPlan plan);
  Future<TrainingSession> record(
    String sessionId,
    String setId,
    SetStatus status, {
    int? reps,
    double? weight,
  });
  Future<TrainingSession> finish(String id, String note);
  Future<TrainingSession> cancel(String id);
  Future<SessionPage> history({int page = 1, int pageSize = 20});
}
