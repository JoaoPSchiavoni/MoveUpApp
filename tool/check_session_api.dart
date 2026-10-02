import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:moveupapp/features/workout/data/api_workout_gateway.dart';
import 'package:moveupapp/features/workout/domain/workout_gateway.dart';
import 'package:moveupapp/features/session/data/api_session_gateway.dart';
import 'package:moveupapp/features/session/domain/session.dart';

// Use an isolated development database: the completed session stays in history.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Uso: dart run tool/check_session_api.dart URL_DA_API_COM_BANCO_DE_TESTE',
    );
    exitCode = 1;
    return;
  }
  final workouts = ApiWorkoutGateway(baseUrl: args.first);
  final sessions = ApiSessionGateway(baseUrl: args.first);
  final workoutId = const Uuid().v4();
  final sessionId = const Uuid().v4();
  var workoutCreated = false;
  var sessionActive = false;
  try {
    if (await sessions.loadActive() != null) {
      throw StateError(
        'Existe uma sessão ativa. Use uma API com banco isolado para este teste.',
      );
    }
    final catalog = await workouts.loadExercises();
    final plan = WorkoutPlan(
      id: workoutId,
      name: 'Integração fase 2',
      weekday: 1,
      items: [
        WorkoutItem(exercise: catalog.first, sets: 2, reps: 10, weight: 70),
      ],
    );
    await workouts.saveWorkout(plan);
    workoutCreated = true;
    final started = await sessions.start(sessionId, plan);
    sessionActive = true;
    final repeated = await sessions.start(sessionId, plan);
    if (repeated.sets.first.id != started.sets.first.id) {
      throw StateError('Início duplicou as séries.');
    }
    final recorded = await sessions.record(
      sessionId,
      started.sets.first.id,
      SetStatus.completed,
      reps: 8,
      weight: 72.5,
    );
    if (recorded.volume != 580) throw StateError('Volume incorreto.');
    if ((await sessions.loadActive())?.completed != 1) {
      throw StateError('Retomada não recuperou o progresso.');
    }
    // Removing the original plan must leave its session snapshot intact.
    await workouts.deleteWorkout(workoutId);
    workoutCreated = false;
    final preserved = await sessions.load(sessionId);
    if (preserved.name != plan.name || preserved.sets.length != 2) {
      throw StateError('Histórico perdeu a cópia da ficha.');
    }
    final ended = await sessions.finish(
      sessionId,
      'Verificado pelo adapter Flutter.',
    );
    sessionActive = false;
    if (ended.status != SessionStatus.completed ||
        ended.skipped != 1 ||
        ended.volume != 580) {
      throw StateError('Conclusão inconsistente.');
    }
    if ((await sessions.finish(sessionId, 'Tentativa repetida')).endedAt !=
        ended.endedAt) {
      throw StateError('Conclusão não foi idempotente.');
    }
    if (await sessions.loadActive() != null) {
      throw StateError('Sessão finalizada continua ativa.');
    }
    if (!(await sessions.history()).items.any((s) => s.id == sessionId)) {
      throw StateError('Sessão não apareceu no histórico.');
    }
    stdout.writeln(
      'Fase 2 integrada: início, repetição, séries, retomada, preservação após exclusão, conclusão e histórico.',
    );
  } finally {
    try {
      if (sessionActive) await sessions.cancel(sessionId);
      if (workoutCreated) await workouts.deleteWorkout(workoutId);
    } finally {
      workouts.close();
      sessions.close();
    }
  }
}
