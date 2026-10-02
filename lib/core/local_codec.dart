import '../features/workout/domain/workout_gateway.dart';
import '../features/session/domain/session.dart';

Map<String, dynamic> exerciseJson(ExerciseOption e) => {
  'id': e.id,
  'name': e.name,
  'group': e.group,
  'description': e.description,
  'equipment': e.equipment,
  'instructions': e.instructions,
};
ExerciseOption exerciseFrom(Map<String, dynamic> j) => ExerciseOption(
  j['id'] as String,
  j['name'] as String,
  j['group'] as String,
  description: j['description'] as String? ?? '',
  equipment: j['equipment'] as String? ?? '',
  instructions: List<String>.from(j['instructions'] as List? ?? []),
);
Map<String, dynamic> workoutJson(WorkoutPlan w) => {
  'id': w.id,
  'name': w.name,
  'weekday': w.weekday,
  'description': w.description,
  'active': w.active,
  'items': w.items
      .map(
        (i) => {
          'exercise': exerciseJson(i.exercise),
          'sets': i.sets,
          'reps': i.reps,
          'weight': i.weight,
          'rest': i.restSeconds,
        },
      )
      .toList(),
};
WorkoutPlan workoutFrom(Map<String, dynamic> j) => WorkoutPlan(
  id: j['id'] as String,
  name: j['name'] as String,
  weekday: j['weekday'] as int,
  description: j['description'] as String? ?? '',
  active: j['active'] as bool? ?? true,
  items: (j['items'] as List).map((r) {
    final i = Map<String, dynamic>.from(r as Map);
    return WorkoutItem(
      exercise: exerciseFrom(Map<String, dynamic>.from(i['exercise'] as Map)),
      sets: i['sets'] as int,
      reps: i['reps'] as int,
      weight: (i['weight'] as num).toDouble(),
      restSeconds: i['rest'] as int,
    );
  }).toList(),
);
Map<String, dynamic> sessionJson(TrainingSession s) => {
  'id': s.id,
  'name': s.name,
  'startedAt': s.startedAt.toIso8601String(),
  'endedAt': s.endedAt?.toIso8601String(),
  'status': s.status.name,
  'note': s.note,
  'workoutId': s.workoutId,
  'localDate': s.localDate,
  'timeZone': s.timeZone,
  'exercises': s.exercises
      .map(
        (e) => {
          'id': e.id,
          'originId': e.originId,
          'name': e.name,
          'group': e.group,
          'order': e.order,
          'rest': e.restSeconds,
          'sets': e.sets
              .map(
                (x) => {
                  'id': x.id,
                  'order': x.order,
                  'plannedReps': x.plannedReps,
                  'plannedWeight': x.plannedWeight,
                  'reps': x.reps,
                  'weight': x.weight,
                  'status': x.status.name,
                },
              )
              .toList(),
        },
      )
      .toList(),
};
TrainingSession sessionFrom(Map<String, dynamic> j) => TrainingSession(
  id: j['id'] as String,
  name: j['name'] as String,
  startedAt: DateTime.parse(j['startedAt'] as String),
  endedAt: j['endedAt'] == null ? null : DateTime.parse(j['endedAt'] as String),
  status: SessionStatus.values.byName(j['status'] as String),
  note: j['note'] as String? ?? '',
  workoutId: j['workoutId'] as String?,
  localDate: j['localDate'] as String?,
  timeZone: j['timeZone'] as String?,
  exercises: (j['exercises'] as List).map((r) {
    final e = Map<String, dynamic>.from(r as Map);
    return SessionExercise(
      id: e['id'] as String,
      originId: e['originId'] as String?,
      name: e['name'] as String,
      group: e['group'] as String,
      order: e['order'] as int,
      restSeconds: e['rest'] as int,
      sets: (e['sets'] as List).map((r) {
        final x = Map<String, dynamic>.from(r as Map);
        return SessionSet(
          id: x['id'] as String,
          order: x['order'] as int,
          plannedReps: x['plannedReps'] as int,
          plannedWeight: (x['plannedWeight'] as num).toDouble(),
          reps: x['reps'] as int?,
          weight: (x['weight'] as num?)?.toDouble(),
          status: SetStatus.values.byName(x['status'] as String),
        );
      }).toList(),
    );
  }).toList(),
);
