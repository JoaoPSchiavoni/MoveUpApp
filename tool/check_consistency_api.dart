import 'dart:io';

import 'package:moveupapp/features/consistency/data/api_consistency_gateway.dart';
import 'package:moveupapp/features/consistency/domain/consistency.dart';
import 'package:moveupapp/features/session/data/api_session_gateway.dart';
import 'package:moveupapp/features/session/domain/session.dart';
import 'package:moveupapp/features/workout/data/api_workout_gateway.dart';
import 'package:moveupapp/features/workout/domain/workout_gateway.dart';
import 'package:uuid/uuid.dart';

// Run only against an isolated temporary API database. Configuration and history persist.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError(
      'Informe a URL de uma API com banco temporário isolado.',
    );
  }
  final url = args.single;
  final workouts = ApiWorkoutGateway(baseUrl: url);
  final sessions = ApiSessionGateway(baseUrl: url);
  final consistency = ApiConsistencyGateway(baseUrl: url);
  void require(bool value, String message) {
    if (!value) throw StateError(message);
  }

  try {
    final initial = await consistency.config();
    require(
      !initial.enabled &&
          (await workouts.loadWorkouts()).isEmpty &&
          (await sessions.history()).items.isEmpty &&
          await sessions.loadActive() == null,
      'Use somente um banco temporário vazio; não execute contra dados pessoais.',
    );
    final configured = await consistency.configure('UTC', [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ], 1);
    require(
      configured.enabled && configured.goals.single.days == 1,
      'Configuração não persistiu.',
    );
    final catalog = await workouts.loadExercises();
    final plan = WorkoutPlan(
      id: const Uuid().v4(),
      name: 'Integração Fase 3',
      weekday: configured.today.weekday,
      items: [
        WorkoutItem(
          exercise: catalog.first,
          sets: 2,
          reps: 10,
          weight: 20,
          restSeconds: 0,
        ),
      ],
    );
    await workouts.saveWorkout(plan);
    for (var i = 0; i < 2; i++) {
      final session = await sessions.start(const Uuid().v4(), plan);
      await sessions.record(
        session.id,
        session.sets.first.id,
        SetStatus.completed,
        reps: 8,
        weight: 25,
      );
      await sessions.finish(session.id, 'Conclusão parcial válida');
    }
    var panel = await consistency.panel();
    require(
      panel.week.days == 1 &&
          panel.week.sessions == 2 &&
          panel.week.volume == 400 &&
          panel.streak == 1,
      'Presença ou métricas incorretas.',
    );
    final calendar = await consistency.calendar(
      DateTime(panel.today.year, panel.today.month),
    );
    final day = calendar.singleWhere(
      (d) => dateKey(d.date) == dateKey(panel.today),
    );
    require(
      day.sessions.length == 2 && day.state == 'treinado',
      'Calendário perdeu sessões do mesmo dia.',
    );
    var changed = await consistency.configure('UTC', [], 2);
    changed = await consistency.configure('UTC', [], 2);
    require(
      changed.routines.length == 2 &&
          changed.goals.length == 2 &&
          dateKey(changed.routines.last.start) ==
              dateKey(panel.today.add(const Duration(days: 1))),
      'Vigência ou repetição inválida.',
    );
    require(
      (await consistency.week(panel.week.start)).goal == 1,
      'Meta atual foi alterada retroativamente.',
    );
    try {
      await consistency.configure('Invalid/Zone', [1], 3);
      throw StateError('Fuso inválido foi aceito.');
    } on ConsistencyFailure catch (e) {
      require(
        e.message.contains('Fuso'),
        'Mensagem de validação não chegou ao Front.',
      );
    }
    await workouts.deleteWorkout(plan.id);
    panel = await consistency.panel();
    require(
      panel.week.days == 1 && panel.week.sessions == 2,
      'Excluir ficha alterou o histórico.',
    );
    stdout.writeln(
      'Integração da Fase 3 validada: configuração, sessões reais, calendário, painel, resumo, revisões, validação e preservação do histórico.',
    );
  } finally {
    workouts.close();
    sessions.close();
    consistency.close();
  }
}
