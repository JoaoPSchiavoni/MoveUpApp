import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;

import '../features/workout/domain/workout_gateway.dart';
import '../features/workout/data/exercise_catalog.dart';
import '../features/session/domain/session.dart';
import '../features/consistency/domain/consistency.dart';
import 'local_database.dart';
import 'local_codec.dart';

DateTime localDay(DateTime instant, String zone) {
  final date = tz.TZDateTime.from(instant, tz.getLocation(zone));
  return DateTime(date.year, date.month, date.day);
}

DateTime monday(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);

class LocalWorkoutGateway implements WorkoutGateway {
  LocalWorkoutGateway(this.data);
  final LocalData data;
  @override
  Future<List<ExerciseOption>> loadExercises() async {
    final stored = await data.db.records('exercise');
    if (stored.isEmpty) {
      await data.change(() async {
        for (final e in exerciseCatalog) {
          await data.db.put('exercise', e.id, exerciseJson(e));
        }
      });
    }
    return (await data.db.records('exercise'))
        .map(exerciseFrom)
        .map(exerciseDetails)
        .toList();
  }

  @override
  Future<List<WorkoutPlan>> loadWorkouts() async =>
      (await data.db.records('workout')).map(workoutFrom).toList();
  void validate(WorkoutPlan w) {
    if (w.id.isEmpty ||
        w.name.trim().isEmpty ||
        w.name.length > 120 ||
        w.description.length > 2000 ||
        w.weekday < 1 ||
        w.weekday > 7 ||
        w.items.isEmpty ||
        w.items.map((i) => i.exercise.id).toSet().length != w.items.length ||
        w.items.fold<int>(0, (s, i) => s + i.sets) > 1000) {
      throw const FormatException(
        'Ficha inválida. Confira nome, dia e exercícios.',
      );
    }
    for (final i in w.items) {
      if (i.sets <= 0 ||
          i.reps <= 0 ||
          i.restSeconds < 0 ||
          !i.weight.isFinite ||
          i.weight < 0 ||
          !(i.weight * i.reps * i.sets).isFinite) {
        throw const FormatException('Valores inválidos no exercício.');
      }
    }
  }

  @override
  Future<void> saveWorkout(WorkoutPlan w) async {
    validate(w);
    await data.change(() => data.db.put('workout', w.id, workoutJson(w)));
  }

  Future<void> saveBatch(List<WorkoutPlan> plans) async {
    plans.forEach(validate);
    await data.change(() async {
      for (final w in plans) {
        await data.db.put('workout', w.id, workoutJson(w));
      }
    });
  }

  @override
  Future<void> deleteWorkout(String id) =>
      data.change(() => data.db.remove('workout', id));
}

class LocalSessionGateway implements SessionGateway {
  LocalSessionGateway(this.data, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final LocalData data;
  final DateTime Function() now;
  Future<List<TrainingSession>> all() async =>
      (await data.db.records('session')).map(sessionFrom).toList();
  @override
  Future<TrainingSession?> loadActive() async =>
      (await all()).where((s) => s.status == SessionStatus.active).firstOrNull;
  @override
  Future<TrainingSession> load(String id) async {
    final j = await data.db.record('session', id);
    if (j == null) throw const SessionFailure('Sessão não encontrada.');
    return sessionFrom(j);
  }

  Future<TrainingSession> active(String id) async {
    final s = await load(id);
    if (s.status != SessionStatus.active) {
      throw const SessionFailure('Esta sessão já foi encerrada.');
    }
    return s;
  }

  @override
  Future<TrainingSession> start(String id, WorkoutPlan plan) => data.change(
    () async {
      if (id.trim().isEmpty) {
        throw const SessionFailure('ID da sessão é obrigatório.');
      }
      final previous = await data.db.record('session', id);
      if (previous != null) {
        final old = sessionFrom(previous);
        if (old.workoutId != plan.id) {
          throw const SessionFailure(
            'Este ID pertence a outra ficha.',
            conflict: true,
          );
        }
        return old;
      }
      if (await loadActive() != null) {
        throw const SessionFailure(
          'Já existe um treino em andamento.',
          conflict: true,
        );
      }
      final saved = await data.db.record('workout', plan.id);
      if (saved == null) throw const SessionFailure('Ficha não encontrada.');
      final w = workoutFrom(saved);
      if (!w.active) throw const SessionFailure('Esta ficha está desativada.');
      LocalWorkoutGateway(data).validate(w);
      final config = await data.db.record('preference', 'consistency');
      final zone = config?['fuso'] as String? ?? 'America/Sao_Paulo';
      final instant = now().toUtc();
      final s = TrainingSession(
        id: id,
        name: w.name,
        workoutId: w.id,
        startedAt: instant,
        localDate: dateKey(localDay(instant, zone)),
        timeZone: zone,
        exercises: [
          for (var i = 0; i < w.items.length; i++)
            SessionExercise(
              id: const Uuid().v4(),
              originId: w.items[i].exercise.id,
              name: w.items[i].exercise.name,
              group: w.items[i].exercise.group,
              order: i,
              restSeconds: w.items[i].restSeconds,
              sets: List.generate(
                w.items[i].sets,
                (n) => SessionSet(
                  id: const Uuid().v4(),
                  order: n,
                  plannedReps: w.items[i].reps,
                  plannedWeight: w.items[i].weight,
                ),
              ),
            ),
        ],
      );
      await data.db.put('session', id, sessionJson(s));
      return s;
    },
  );
  @override
  Future<TrainingSession> record(
    String sessionId,
    String setId,
    SetStatus status, {
    int? reps,
    double? weight,
  }) => data.change(() async {
    final s = await active(sessionId);
    if (!s.sets.any((x) => x.id == setId)) {
      throw const SessionFailure('Série não encontrada nesta sessão.');
    }
    if (status == SetStatus.completed &&
        (reps == null ||
            reps <= 0 ||
            weight == null ||
            !weight.isFinite ||
            weight < 0)) {
      throw const SessionFailure('Informe carga e repetições válidas.');
    }
    if (status != SetStatus.completed && (reps != null || weight != null)) {
      throw const SessionFailure(
        'Séries pendentes ou puladas não devem conter resultados.',
      );
    }
    final updated = s.copy(
      exercises: s.exercises
          .map(
            (e) => e.withSets(
              e.sets
                  .map(
                    (x) => x.id == setId
                        ? x.recorded(
                            status,
                            reps: status == SetStatus.completed ? reps : null,
                            weight: status == SetStatus.completed
                                ? weight
                                : null,
                          )
                        : x,
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
    if (!updated.volume.isFinite) {
      throw const SessionFailure('Volume registrado excede o limite numérico.');
    }
    await data.db.put('session', sessionId, sessionJson(updated));
    return updated;
  });
  @override
  Future<TrainingSession> finish(String id, String note) =>
      end(id, false, note);
  @override
  Future<TrainingSession> cancel(String id) => end(id, true, '');
  Future<TrainingSession> end(
    String id,
    bool cancel,
    String note,
  ) => data.change(() async {
    final previous = await load(id);
    final status = cancel ? SessionStatus.cancelled : SessionStatus.completed;
    if (previous.status == status) return previous;
    final s = await active(id);
    if (!cancel && s.completed == 0) {
      throw const SessionFailure('Conclua pelo menos uma série.');
    }
    if (note.length > 2000) {
      throw const SessionFailure('Observação deve ter até 2000 caracteres.');
    }
    final end = now().toUtc();
    final updated = s.copy(
      status: status,
      endedAt: end.isBefore(s.startedAt) ? s.startedAt : end,
      note: note.trim(),
      exercises: cancel
          ? s.exercises
          : s.exercises
                .map(
                  (e) => e.withSets(
                    e.sets
                        .map(
                          (x) => x.status == SetStatus.pending
                              ? x.recorded(SetStatus.skipped)
                              : x,
                        )
                        .toList(),
                  ),
                )
                .toList(),
    );
    await data.db.put('session', id, sessionJson(updated));
    return updated;
  });
  @override
  Future<SessionPage> history({int page = 1, int pageSize = 20}) async {
    if (page < 1 || pageSize < 1 || pageSize > 100) {
      throw const SessionFailure('Página inválida.');
    }
    final sessions =
        (await all()).where((s) => s.status == SessionStatus.completed).toList()
          ..sort((a, b) {
            final c = b.startedAt.compareTo(a.startedAt);
            return c == 0 ? b.id.compareTo(a.id) : c;
          });
    return SessionPage(
      sessions.skip((page - 1) * pageSize).take(pageSize).toList(),
      hasMore: page * pageSize < sessions.length,
    );
  }
}

class LocalConsistencyGateway implements ConsistencyGateway {
  LocalConsistencyGateway(this.data, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final LocalData data;
  final DateTime Function() now;
  Future<Map<String, dynamic>> raw() async =>
      await data.db.record('preference', 'consistency') ??
      {
        'ativado': false,
        'fuso': 'America/Sao_Paulo',
        'rotinas': <dynamic>[],
        'metas': <dynamic>[],
      };
  @override
  Future<ConsistencyConfig> config() async {
    final j = await raw();
    return ConsistencyConfig({
      ...j,
      'hoje': dateKey(localDay(now(), j['fuso'] as String)),
    });
  }

  @override
  Future<ConsistencyConfig> configure(
    String zone,
    List<int> days,
    int goal,
  ) async {
    try {
      tz.getLocation(zone);
    } catch (_) {
      throw const ConsistencyFailure('Fuso IANA não encontrado.');
    }
    if (goal < 1 ||
        goal > 7 ||
        days.any((d) => d < 1 || d > 7) ||
        days.toSet().length != days.length) {
      throw const ConsistencyFailure('Confira os dias e a meta entre 1 e 7.');
    }
    await data.change(() async {
      final j = await raw();
      final first = j['ativado'] != true;
      final today = localDay(now(), zone);
      final week = monday(today);
      final routines = List<Map<String, dynamic>>.from(
        (j['rotinas'] as List).map((x) => Map<String, dynamic>.from(x as Map)),
      );
      final goals = List<Map<String, dynamic>>.from(
        (j['metas'] as List).map((x) => Map<String, dynamic>.from(x as Map)),
      );
      final selected = days.toList()..sort();
      void revise(
        List<Map<String, dynamic>> versions,
        DateTime current,
        DateTime effective,
        Map<String, dynamic> value,
        String field,
      ) {
        final currentRevision =
            versions
                .where(
                  (v) =>
                      !DateTime.parse(v['inicio'] as String).isAfter(current),
                )
                .lastOrNull ??
            versions.firstOrNull;
        final future = versions
            .skip(1)
            .where(
              (v) => DateTime.parse(v['inicio'] as String).isAfter(current),
            )
            .lastOrNull;
        final equal =
            currentRevision != null &&
            currentRevision[field].toString() == value[field].toString();
        if (equal) {
          if (future != null) versions.remove(future);
          return;
        }
        if (future != null) {
          final old = DateTime.parse(future['inicio'] as String);
          future.addAll({
            ...value,
            'inicio': dateKey(old.isAfter(effective) ? old : effective),
          });
        } else {
          versions.add({...value, 'inicio': dateKey(effective)});
        }
      }

      revise(
        routines,
        today,
        first ? today : DateTime(today.year, today.month, today.day + 1),
        {'diasSemana': selected},
        'diasSemana',
      );
      revise(
        goals,
        week,
        first ? week : DateTime(week.year, week.month, week.day + 7),
        {'dias': goal},
        'dias',
      );
      await data.db.put('preference', 'consistency', {
        'ativado': true,
        'fuso': zone,
        'inicio': j['inicio'] ?? dateKey(today),
        'rotinas': routines,
        'metas': goals,
      });
    });
    return config();
  }

  bool planned(DateTime day, ConsistencyConfig c) =>
      c.routines
          .where((r) => !r.start.isAfter(day))
          .lastOrNull
          ?.days
          .contains(day.weekday) ==
      true;
  Future<List<TrainingSession>> completed() async =>
      (await LocalSessionGateway(data).all())
          .where((s) => s.status == SessionStatus.completed && s.completed > 0)
          .toList();
  String date(TrainingSession s, ConsistencyConfig c) =>
      s.localDate ?? dateKey(localDay(s.startedAt, c.zone));
  @override
  Future<List<CalendarDay>> calendar(DateTime month) async {
    final c = await config();
    final sessions = await completed();
    final today = c.today;
    final j = await raw();
    final start = j['inicio'] == null
        ? null
        : DateTime.parse(j['inicio'] as String);
    final presence = sessions.map((s) => date(s, c)).toSet();
    final fire = <String>{};
    final segment = <String>[];
    if (c.enabled && start != null) {
      for (
        var day = start;
        !day.isAfter(today);
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        if (!planned(day, c)) continue;
        if (presence.contains(dateKey(day))) {
          segment.add(dateKey(day));
          if (segment.length >= 5) fire.addAll(segment);
        } else if (day.isBefore(today)) {
          segment.clear();
        }
      }
    }
    return [
      for (var n = 1; n <= DateTime(month.year, month.month + 1, 0).day; n++)
        (() {
          final day = DateTime(month.year, month.month, n);
          final items = sessions
              .where((s) => date(s, c) == dateKey(day))
              .toList();
          final p = planned(day, c);
          return CalendarDay({
            'data': dateKey(day),
            'onFire': fire.contains(dateKey(day)),
            'planejado': p,
            'estado': items.isNotEmpty
                ? 'treinado'
                : !c.enabled || start == null || day.isBefore(start)
                ? 'semPlanejamento'
                : !p
                ? 'descanso'
                : day.isBefore(today)
                ? 'falta'
                : day == today
                ? 'planejadoHoje'
                : 'planejadoFuturo',
            'sessoes': items
                .map((s) => {'id': s.id, 'nomeTreino': s.name})
                .toList(),
          });
        })(),
    ];
  }

  @override
  Future<ConsistencyWeek> week(DateTime start) async {
    if (start.weekday != 1) {
      throw const ConsistencyFailure('Informe uma segunda-feira.');
    }
    final c = await config();
    final end = DateTime(start.year, start.month, start.day + 6);
    final sessions = (await completed()).where((s) {
      final d = DateTime.parse(date(s, c));
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
    final presence = sessions.map((s) => date(s, c)).toSet();
    final closed = [
      for (var n = 0; n < 7; n++)
        DateTime(start.year, start.month, start.day + n),
    ].where((d) => d.isBefore(c.today) && planned(d, c)).toList();
    final fulfilled = closed.where((d) => presence.contains(dateKey(d))).length;
    return ConsistencyWeek({
      'inicio': dateKey(start),
      'fim': dateKey(end),
      'diasTreinados': presence.length,
      'sessoes': sessions.length,
      'meta': c.goals.where((g) => !g.start.isAfter(start)).lastOrNull?.days,
      'planejadosEncerrados': closed.length,
      'planejadosCumpridos': fulfilled,
      'adesao': closed.isEmpty ? null : fulfilled / closed.length,
      'duracaoSegundos': sessions.fold<double>(
        0,
        (total, s) =>
            total + (s.endedAt!.difference(s.startedAt).inMilliseconds / 1000),
      ),
      'volume': sessions.fold<double>(0, (total, s) => total + s.volume),
    });
  }

  @override
  Future<ConsistencyPanel> panel() async {
    final c = await config();
    final j = await raw();
    final today = c.today;
    final sessions = await completed();
    final presence = sessions.map((s) => date(s, c)).toSet();
    int current = 0, best = 0;
    if (c.enabled) {
      final start = DateTime.parse(j['inicio'] as String);
      for (
        var day = start;
        !day.isAfter(today);
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        if (!planned(day, c)) continue;
        if (presence.contains(dateKey(day))) {
          current++;
          if (current > best) best = current;
        } else if (day.isBefore(today)) {
          current = 0;
        }
      }
    }
    final w = await week(monday(today));
    return ConsistencyPanel({
      'hoje': dateKey(today),
      'fuso': c.zone,
      'ativado': c.enabled,
      'sequenciaAtual': current,
      'melhorSequencia': best,
      'diasTreinadosMes': presence
          .where((d) => d.startsWith(dateKey(today).substring(0, 7)))
          .length,
      'semana': {
        'inicio': dateKey(w.start),
        'fim': dateKey(w.end),
        'diasTreinados': w.days,
        'sessoes': w.sessions,
        'meta': w.goal,
        'planejadosEncerrados': w.planned,
        'planejadosCumpridos': w.fulfilled,
        'adesao': w.adherence,
        'duracaoSegundos': w.seconds,
        'volume': w.volume,
      },
    });
  }
}
