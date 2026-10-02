import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:timezone/timezone.dart' as tz;

import '../features/session/domain/session.dart';
import '../features/progress/measurements.dart';
import '../features/workout/data/api_workout_gateway.dart';
import '../features/session/data/api_session_gateway.dart';
import '../features/consistency/data/api_consistency_gateway.dart';
import '../features/consistency/domain/consistency.dart';
import 'local_database.dart';
import 'local_codec.dart';
import 'local_gateways.dart';

class BackupService {
  BackupService(this.data);
  final LocalData data;
  DateTime validDay(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('Data de calendário inválida.');
    }
    final day = DateTime.tryParse(value);
    if (day == null ||
        day.year < 1900 ||
        day.year > 2100 ||
        dateKey(day) != value) {
      throw const FormatException('Data de calendário inválida.');
    }
    return day;
  }

  List<Map<String, dynamic>> validate(String content) {
    if (content.length > 50 * 1024 * 1024) {
      throw const FormatException('Backup maior que 50 MB.');
    }
    final root = jsonDecode(content) as Map;
    if (root['format'] != 'moveup-backup' ||
        root['version'] != 1 ||
        root['records'] is! List) {
      throw const FormatException(
        'Este arquivo não é um backup compatível do MoveUp.',
      );
    }
    final rows = (root['records'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    if (rows.length > 100000) {
      throw const FormatException('Backup excede o limite de registros.');
    }
    final keys = <String>{};
    var active = 0;
    for (final r in rows) {
      final kind = r['kind'] as String;
      final id = r['id'] as String;
      final value = Map<String, dynamic>.from(r['value'] as Map);
      if (id.isEmpty || !keys.add('$kind/$id')) {
        throw const FormatException(
          'Registros duplicados ou sem identificação.',
        );
      }
      switch (kind) {
        case 'exercise':
          final e = exerciseFrom(value);
          if (e.id != id || e.name.trim().isEmpty) {
            throw const FormatException('Exercício inválido.');
          }
        case 'workout':
          final w = workoutFrom(value);
          if (w.id != id) {
            throw const FormatException('Identificação da ficha inválida.');
          }
          LocalWorkoutGateway(data).validate(w);
        case 'session':
          final s = sessionFrom(value);
          if (s.id != id ||
              s.name.trim().isEmpty ||
              s.exercises.isEmpty ||
              !s.volume.isFinite ||
              s.exercises.length > 1000 ||
              s.sets.length > 1000 ||
              s.note.length > 2000) {
            throw const FormatException('Sessão inválida.');
          }
          if (s.localDate != null) {
            validDay(s.localDate);
          }
          if (s.timeZone != null) tz.getLocation(s.timeZone!);
          if (s.status == SessionStatus.active) {
            active++;
            if (s.endedAt != null) {
              throw const FormatException('Sessão ativa com encerramento.');
            }
          } else if (s.endedAt == null ||
              s.endedAt!.isBefore(s.startedAt) ||
              (s.status == SessionStatus.completed &&
                  (s.completed == 0 || s.pending > 0))) {
            throw const FormatException('Encerramento inválido.');
          }
          final setIds = <String>{}, exerciseIds = <String>{};
          for (final e in s.exercises) {
            if (e.id.isEmpty ||
                !exerciseIds.add(e.id) ||
                e.name.isEmpty ||
                e.restSeconds < 0 ||
                e.sets.isEmpty ||
                e.sets.length > 1000) {
              throw const FormatException('Exercício da sessão inválido.');
            }
            for (final x in e.sets) {
              if (x.id.isEmpty ||
                  !setIds.add(x.id) ||
                  x.plannedReps <= 0 ||
                  !x.plannedWeight.isFinite ||
                  x.plannedWeight < 0 ||
                  (x.status == SetStatus.completed &&
                      (x.reps == null ||
                          x.reps! <= 0 ||
                          x.weight == null ||
                          !x.weight!.isFinite ||
                          x.weight! < 0)) ||
                  (x.status != SetStatus.completed &&
                      (x.reps != null || x.weight != null))) {
                throw const FormatException('Série inválida no backup.');
              }
            }
          }
        case 'measurement':
          MeasurementStore.validate(id, value);
        case 'preference':
          if (id == 'theme') {
            if (!['system', 'light', 'dark'].contains(value['mode'])) {
              throw const FormatException('Tema inválido.');
            }
          } else if (id == 'consistency') {
            final c = ConsistencyConfig({...value, 'hoje': '2026-01-01'});
            tz.getLocation(c.zone);
            if (c.enabled &&
                (value['inicio'] == null ||
                    c.routines.isEmpty ||
                    c.goals.isEmpty)) {
              throw const FormatException('Rotina sem início.');
            }
            if (value['inicio'] != null) {
              validDay(value['inicio']);
            }
            for (final revision in [
              ...value['rotinas'] as List,
              ...value['metas'] as List,
            ]) {
              validDay((revision as Map)['inicio']);
            }
            DateTime? previous;
            for (final r in c.routines) {
              if ((previous != null && !r.start.isAfter(previous)) ||
                  r.days.any((d) => d < 1 || d > 7) ||
                  r.days.toSet().length != r.days.length) {
                throw const FormatException('Versão de rotina inválida.');
              }
              previous = r.start;
            }
            previous = null;
            for (final g in c.goals) {
              if (g.start.weekday != 1 ||
                  g.days < 1 ||
                  g.days > 7 ||
                  (previous != null && !g.start.isAfter(previous))) {
                throw const FormatException('Versão de meta inválida.');
              }
              previous = g.start;
            }
          } else {
            throw const FormatException('Preferência não reconhecida.');
          }
        default:
          throw const FormatException('Tipo de registro não reconhecido.');
      }
    }
    if (active > 1) {
      throw const FormatException('Há mais de um treino ativo no backup.');
    }
    return rows;
  }

  Future<void> restore(String content) async {
    final rows = validate(content);
    await data.change(() async {
      await data.db.customStatement('DELETE FROM records');
      for (final r in rows) {
        await data.db.put(
          r['kind'] as String,
          r['id'] as String,
          Map<String, dynamic>.from(r['value'] as Map),
        );
      }
    });
  }

  Future<void> importApi(String url, {http.Client? client}) async {
    final workouts = ApiWorkoutGateway(baseUrl: url, client: client),
        sessions = ApiSessionGateway(baseUrl: url, client: client),
        consistency = ApiConsistencyGateway(baseUrl: url, client: client);
    try {
      final exercises = await workouts.loadExercises();
      final plans = await workouts.loadWorkouts();
      final history = <TrainingSession>[];
      for (var page = 1; ; page++) {
        final result = await sessions.history(page: page, pageSize: 100);
        history.addAll(result.items);
        if (!result.hasMore) break;
        if (page >= 1000) {
          throw const FormatException(
            'Histórico excede o limite de importação.',
          );
        }
      }
      final active = await sessions.loadActive();
      if (active != null) history.add(active);
      final c = await consistency.config();
      final rows = <Map<String, dynamic>>[
        for (final e in exercises)
          {'kind': 'exercise', 'id': e.id, 'value': exerciseJson(e)},
        for (final w in plans)
          {'kind': 'workout', 'id': w.id, 'value': workoutJson(w)},
        for (final s in history)
          {
            'kind': 'session',
            'id': s.id,
            'value': {
              ...sessionJson(s),
              'localDate':
                  s.localDate ?? dateKey(localDay(s.startedAt, c.zone)),
              'timeZone': s.timeZone ?? c.zone,
            },
          },
        {
          'kind': 'preference',
          'id': 'consistency',
          'value': {
            'ativado': c.enabled,
            'fuso': c.zone,
            'inicio': c.start == null ? null : dateKey(c.start!),
            'rotinas': [
              for (final r in c.routines)
                {'inicio': dateKey(r.start), 'diasSemana': r.days},
            ],
            'metas': [
              for (final g in c.goals)
                {'inicio': dateKey(g.start), 'dias': g.days},
            ],
          },
        },
      ];
      final checked = validate(
        jsonEncode({'format': 'moveup-backup', 'version': 1, 'records': rows}),
      );
      await data.change(() async {
        if ((await data.db.records('workout')).isNotEmpty ||
            (await data.db.records('session')).isNotEmpty) {
          throw const FormatException(
            'Importação da API requer uma biblioteca local vazia. Exporte um backup antes.',
          );
        }
        for (final r in checked) {
          await data.db.put(
            r['kind'] as String,
            r['id'] as String,
            Map<String, dynamic>.from(r['value'] as Map),
          );
        }
      });
    } finally {
      workouts.close();
      sessions.close();
      consistency.close();
    }
  }
}
