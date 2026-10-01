import 'dart:io';

import 'package:moveupapp/features/workout/data/api_workout_gateway.dart';
import 'package:moveupapp/features/workout/domain/workout_gateway.dart';
import 'package:uuid/uuid.dart';

// Run against a development API; the temporary workout is deleted on completion.
Future<void> main(List<String> args) async {
  final gateway = ApiWorkoutGateway(
    baseUrl: args.isEmpty ? 'http://localhost:5013' : args.first,
  );
  final id = const Uuid().v4();
  var created = false;
  try {
    final catalog = await gateway.loadExercises();
    if (catalog.length < 2) {
      throw StateError('O catálogo precisa de dois exercícios.');
    }
    await gateway.saveWorkout(
      WorkoutPlan(
        id: id,
        name: 'Verificação de integração',
        weekday: 1,
        items: [
          WorkoutItem(exercise: catalog[0], sets: 4, weight: 72.5),
          WorkoutItem(exercise: catalog[1]),
        ],
      ),
    );
    created = true;
    final loaded = (await gateway.loadWorkouts()).singleWhere(
      (w) => w.id == id,
    );
    if (loaded.items.length != 2 || loaded.items.first.weight != 72.5) {
      throw StateError('Dados diferentes após a gravação.');
    }
    await gateway.saveWorkout(
      WorkoutPlan(
        id: id,
        name: 'Verificação editada',
        weekday: 5,
        items: [loaded.items.last],
      ),
    );
    final edited = (await gateway.loadWorkouts()).singleWhere(
      (w) => w.id == id,
    );
    if (edited.items.length != 1 || edited.weekday != 5) {
      throw StateError('Edição não persistiu.');
    }
    await gateway.deleteWorkout(id);
    created = false;
    if ((await gateway.loadWorkouts()).any((w) => w.id == id)) {
      throw StateError('Exclusão não persistiu.');
    }
    stdout.writeln(
      'Integração Flutter → API → SQLite validada: catálogo, criação, consulta, edição e exclusão.',
    );
  } finally {
    if (created) await gateway.deleteWorkout(id);
    gateway.close();
  }
}
