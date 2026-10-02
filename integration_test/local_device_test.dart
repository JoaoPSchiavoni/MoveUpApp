import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:moveupapp/core/app.dart';
import 'package:moveupapp/core/local_database.dart';
import 'package:moveupapp/core/local_gateways.dart';
import 'package:moveupapp/core/data_transfer.dart';
import 'package:moveupapp/features/workout/data/exercise_catalog.dart';
import 'package:moveupapp/features/workout/domain/workout_gateway.dart';
import 'package:moveupapp/features/session/domain/session.dart';
import 'package:moveupapp/features/progress/measurements.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native SQLite resumes session and restores portable backup in a fresh database',
    (tester) async {
      tzdata.initializeTimeZones();
      final name =
          'moveup_device_check_${DateTime.now().microsecondsSinceEpoch}';
      MoveUpDatabase open(String name) =>
          MoveUpDatabase(driftDatabase(name: name));
      var db = open(name), data = LocalData(db);
      addTearDown(() async {
        if (!data.disposed) {
          await data.db.customStatement('DELETE FROM records');
          data.dispose();
          await db.close();
        }
      });
      final plan = WorkoutPlan(
        id: 'device-plan',
        name: 'Treino no aparelho',
        weekday: DateTime.now().weekday,
        items: [
          WorkoutItem(
            exercise: exerciseCatalog.first,
            sets: 2,
            reps: 10,
            weight: 20,
            restSeconds: 0,
          ),
        ],
      );
      await LocalWorkoutGateway(data).loadExercises();
      await LocalWorkoutGateway(data).saveWorkout(plan);
      final sessions = LocalSessionGateway(data);
      final started = await sessions.start('device-session', plan);
      await sessions.record(
        started.id,
        started.sets.first.id,
        SetStatus.completed,
        reps: 8,
        weight: 25,
      );
      await data.db.put('preference', 'theme', {'mode': 'dark'});
      data.dispose();
      await db.close();
      db = open(name);
      data = LocalData(db);
      final resumed = await LocalSessionGateway(data).loadActive();
      expect(resumed!.volume, 200);
      expect(resumed.exercises.single.originId, exerciseCatalog.first.id);
      await tester.pumpWidget(MoveUpApp(gateway: LocalWorkoutGateway(data)));
      await tester.pumpAndSettle();
      expect(find.text('Continuar treino'), findsWidgets);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await LocalSessionGateway(data)
          .finish(resumed.id, 'Teste no dispositivo');
      final measures = MeasurementStore(data);
      await measures.save(monthKey(await measures.today()), {'weight': 80});
      final backup = await data.exportBackup();
      final restoredDb = open('${name}_restore'),
          restored = LocalData(restoredDb);
      try {
        await BackupService(restored).restore(backup);
        expect(
          (await LocalSessionGateway(restored).history()).items.single.volume,
          200,
        );
        expect(
          await LocalWorkoutGateway(restored).loadWorkouts(),
          hasLength(1),
        );
        expect(await MeasurementStore(restored).all(), hasLength(1));
        expect(
          (await restored.db.record('preference', 'theme'))!['mode'],
          'dark',
        );
      } finally {
        // Clear only these uniquely named verification databases, never the personal database.
        await data.db.customStatement('DELETE FROM records');
        await restoredDb.customStatement('DELETE FROM records');
        data.dispose();
        restored.dispose();
        await db.close();
        await restoredDb.close();
      }
    },
  );
}
