import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:moveupapp/core/local_database.dart';
import 'package:moveupapp/core/local_gateways.dart';
import 'package:moveupapp/core/local_codec.dart';
import 'package:moveupapp/core/data_transfer.dart';
import 'package:moveupapp/features/workout/data/exercise_catalog.dart';
import 'package:moveupapp/features/workout/domain/workout_gateway.dart';
import 'package:moveupapp/features/session/domain/session.dart';
import 'package:moveupapp/features/progress/measurements.dart';

WorkoutPlan plan(String id) => WorkoutPlan(
  id: id,
  name: 'A',
  weekday: 1,
  items: [
    WorkoutItem(
      exercise: exerciseCatalog.first,
      sets: 2,
      reps: 10,
      weight: 20,
      restSeconds: 60,
    ),
  ],
);
void main() {
  setUpAll(tzdata.initializeTimeZones);
  test(
    'Disk database survives reopening with session snapshot and presence',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'moveup-persistence-',
      );
      final file = File('${directory.path}/personal.sqlite');
      var db = MoveUpDatabase(NativeDatabase(file));
      var data = LocalData(db);
      final workouts = LocalWorkoutGateway(data);
      await workouts.saveWorkout(plan('w'));
      final sessions = LocalSessionGateway(
        data,
        now: () => DateTime.utc(2026, 10, 2, 2),
      );
      final started = await sessions.start('s', plan('w'));
      await sessions.record(
        's',
        started.sets.first.id,
        SetStatus.completed,
        reps: 8,
        weight: 25,
      );
      data.dispose();
      await db.close();
      db = MoveUpDatabase(NativeDatabase(file));
      data = LocalData(db);
      try {
        final resumed = await LocalSessionGateway(data).loadActive();
        expect(resumed!.localDate, '2026-10-01');
        expect(resumed.volume, 200);
        expect(resumed.exercises.single.originId, exerciseCatalog.first.id);
        await LocalWorkoutGateway(data).deleteWorkout('w');
        final finished = await LocalSessionGateway(data).finish('s', 'feito');
        expect(finished.pending, 0);
        expect(finished.skipped, 1);
        expect(finished.name, 'A');
        expect((await LocalSessionGateway(data).history()).items, hasLength(1));
      } finally {
        data.dispose();
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test('Transactions roll back batches and unique index blocks two active sessions', () async {
    final db = MoveUpDatabase(NativeDatabase.memory());
    final local = LocalData(db);
    try {
      final workouts = LocalWorkoutGateway(local);
      await expectLater(
        workouts.saveBatch([
          plan('w'),
          WorkoutPlan(id: 'bad', name: '', weekday: 0, items: []),
        ]),
        throwsFormatException,
      );
      expect(await workouts.loadWorkouts(), isEmpty);
      await workouts.saveWorkout(plan('w'));
      final sessions = LocalSessionGateway(local);
      final s = await sessions.start('s', plan('w'));
      await expectLater(
        sessions.start('other', plan('w')),
        throwsA(isA<SessionFailure>()),
      );
      await expectLater(
        db.put(
          'session',
          'raw',
          sessionJson(
            TrainingSession(
              id: 'raw',
              name: s.name,
              startedAt: s.startedAt,
              exercises: s.exercises,
            ),
          ),
        ),
        throwsA(anything),
      );
      expect(await sessions.all(), hasLength(1));
      await expectLater(
        local.change(() async {
          await db.remove('workout', 'w');
          throw StateError('interrupted');
        }),
        throwsStateError,
      );
      expect(await workouts.loadWorkouts(), hasLength(1));
    } finally {
      local.dispose();
      await db.close();
    }
  });
  test('Backup restores atomically and rejects malformed data before replacing library', () async {
    final db = MoveUpDatabase(NativeDatabase.memory()), local = LocalData(db);
    try {
      final workouts = LocalWorkoutGateway(local);
      await workouts.saveWorkout(plan('original'));
      final backup = await local.exportBackup();
      final root = jsonDecode(backup) as Map;
      final invalid = jsonDecode(backup) as Map;
      (invalid['records'] as List).add({
        'kind': 'session',
        'id': 'bad',
        'value': {'status': 'invalid'},
      });
      await expectLater(
        BackupService(local).restore(jsonEncode(invalid)),
        throwsA(anything),
      );
      expect((await workouts.loadWorkouts()).single.id, 'original');
      final badDate = jsonDecode(backup) as Map;
      (badDate['records'] as List).add({
        'kind': 'preference',
        'id': 'consistency',
        'value': {
          'ativado': true,
          'fuso': 'UTC',
          'inicio': '2026-02-31',
          'rotinas': [
            {
              'inicio': '2026-02-31',
              'diasSemana': [1],
            },
          ],
          'metas': [
            {'inicio': '2026-03-02', 'dias': 3},
          ],
        },
      });
      await expectLater(
        BackupService(local).restore(jsonEncode(badDate)),
        throwsFormatException,
      );
      expect((await workouts.loadWorkouts()).single.id, 'original');
      await workouts.saveWorkout(plan('new'));
      await BackupService(local).restore(jsonEncode(root));
      expect((await workouts.loadWorkouts()).single.id, 'original');
    } finally {
      local.dispose();
      await db.close();
    }
  });
  test('OnFire counts planned days, preserves rests, ignores duplicate sessions and keeps historical fire', () async {
    final db = MoveUpDatabase(NativeDatabase.memory()), local = LocalData(db);
    var now = DateTime.utc(2026, 9, 21, 12);
    final consistency = LocalConsistencyGateway(local, now: () => now);
    try {
      await consistency.configure('UTC', [1, 3, 5], 3);
      final workouts = LocalWorkoutGateway(local);
      await workouts.saveWorkout(plan('w'));
      final sessions = LocalSessionGateway(local, now: () => now);
      Future<void> finish(String id) async {
        final s = await sessions.start(id, plan('w'));
        await sessions.record(
          id,
          s.sets.first.id,
          SetStatus.completed,
          reps: 10,
          weight: 20,
        );
        await sessions.finish(id, '');
      }

      for (final day in [21, 23, 25, 28, 30]) {
        now = DateTime.utc(2026, 9, day, 12);
        await finish('s$day');
      }
      await finish('duplicate');
      expect((await consistency.panel()).streak, 5);
      expect(
        (await consistency.calendar(DateTime(2026, 9))).where((d) => d.onFire),
        hasLength(5),
      );
      now = DateTime.utc(2026, 10, 1, 12);
      expect((await consistency.panel()).streak, 5);
      now = DateTime.utc(2026, 10, 2, 12);
      expect((await consistency.panel()).streak, 5); // today not a miss yet
      now = DateTime.utc(2026, 10, 3, 12);
      expect((await consistency.panel()).streak, 0);
      expect(
        (await consistency.calendar(DateTime(2026, 9))).where((d) => d.onFire),
        hasLength(5),
      );
      await consistency.configure('UTC', [2, 4], 2);
      final config = await consistency.config();
      expect(config.routines.last.start, DateTime(2026, 10, 4));
      expect(config.goals.last.start, DateTime(2026, 10, 5));
    } finally {
      local.dispose();
      await db.close();
    }
  });
  test('Monthly measurements correct same record and unlock at local calendar boundary', () async {
    final db = MoveUpDatabase(NativeDatabase.memory()), local = LocalData(db);
    var now = DateTime.utc(2026, 11, 1, 2); // still October in Sao Paulo
    final measures = MeasurementStore(local, now: () => now);
    try {
      await measures.save('2026-10', {'weight': 80, 'waist': 90});
      await measures.save('2026-10', {'weight': 79});
      expect(await measures.all(), hasLength(1));
      await expectLater(
        measures.save('2026-11', {'weight': 78}),
        throwsFormatException,
      );
      now = DateTime.utc(2026, 11, 1, 3);
      await measures.save('2026-11', {'weight': 78});
      await expectLater(
        measures.save('2026-10', {'weight': 77}),
        throwsFormatException,
      );
      await expectLater(
        measures.save('2026-11', {'weight': double.nan}),
        throwsFormatException,
      );
      expect(await measures.all(), hasLength(2));
    } finally {
      local.dispose();
      await db.close();
    }
  });
}
