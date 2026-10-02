import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:moveupapp/core/app.dart';
import 'package:moveupapp/core/local_database.dart';
import 'package:moveupapp/core/local_gateways.dart';
import 'package:moveupapp/features/session/domain/session.dart';
import 'package:moveupapp/features/workout/data/exercise_catalog.dart';
import 'package:moveupapp/features/workout/domain/workout_gateway.dart';
import 'package:moveupapp/features/workout/presentation/workout_templates.dart';
import 'package:moveupapp/features/progress/progress_chart.dart';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_REVIEW')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('/tmp/moveup-review-$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  testWidgets(
    'Local mobile app shows OnFire, charts, details and persisted dark preferences',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (const bool.fromEnvironment('CAPTURE_REVIEW')) {
        await tester.runAsync(() async {
          final root = Platform.environment['FLUTTER_ROOT'];
          for (final family in ['Roboto', 'MaterialIcons']) {
            final file = File(
              '$root/bin/cache/artifacts/material_fonts/${family == 'Roboto' ? 'Roboto-Regular.ttf' : 'MaterialIcons-Regular.otf'}',
            );
            if (await file.exists()) {
              final loader = FontLoader(family)
                ..addFont(
                  Future.value(ByteData.sublistView(await file.readAsBytes())),
                );
              await loader.load();
            }
          }
        });
      }
      final db = MoveUpDatabase(NativeDatabase.memory()), data = LocalData(db);
      final workouts = LocalWorkoutGateway(data);
      var now = DateTime.utc(2026, 9, 21, 12);
      final sessions = LocalSessionGateway(data, now: () => now),
          consistency = LocalConsistencyGateway(data, now: () => now);
      final plan = WorkoutPlan(
        id: 'w',
        name: 'Peito',
        weekday: 5,
        items: [
          WorkoutItem(
            exercise: exerciseCatalog.first,
            sets: 1,
            reps: 10,
            weight: 20,
            restSeconds: 0,
          ),
        ],
      );
      await tester.runAsync(() async {
        await workouts.loadExercises();
        await workouts.saveWorkout(plan);
        await consistency.configure('UTC', [1, 3, 5], 3);
        for (final d in [21, 23, 25, 28, 30]) {
          now = DateTime.utc(2026, 9, d, 12);
          final s = await sessions.start('s$d', plan);
          await sessions.record(
            s.id,
            s.sets.first.id,
            SetStatus.completed,
            reps: 10,
            weight: d.toDouble(),
          );
          await sessions.finish(s.id, '');
        }
        now = DateTime.utc(2026, 10, 2, 12);
        await data.db.put('preference', 'theme', {'mode': 'dark'});
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MoveUpApp(
            gateway: workouts,
            sessionGateway: sessions,
            consistencyGateway: consistency,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      expect(find.text('Você está OnFire'), findsOneWidget);
      expect(find.text('Hoje'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'home-dark');
      await tester.ensureVisible(find.text('Evolução'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evolução'));
      await tester.pumpAndSettle();
      expect(find.byType(ProgressChart), findsNWidgets(2));
      await capture(tester, key, 'performance-dark');
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Medidas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medidas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar medidas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '80,5');
      await tester.scrollUntilVisible(
        find.text('Concluir'),
        180,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Medidas deste mês registradas'), findsOneWidget);
      expect(find.text('Corrigir registro deste mês'), findsOneWidget);
      expect(
        await tester.runAsync(() => data.db.records('measurement')),
        hasLength(1),
      );
      await capture(tester, key, 'measurements-dark');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preferências'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claro').last);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.light,
      );
      expect(
        (await tester.runAsync(
          () => data.db.record('preference', 'theme'),
        ))!['mode'],
        'light',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await capture(tester, key, 'home-light');
      await tester.tap(find.text('Meus treinos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Peito').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supino reto'));
      await tester.pumpAndSettle();
      expect(find.text('Como executar'), findsOneWidget);
      await capture(tester, key, 'exercise-light');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      data.dispose();
      await tester.runAsync(db.close);
    },
  );
  testWidgets(
    'ABC adds three independent editable workouts atomically on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = MoveUpDatabase(NativeDatabase.memory()),
          data = LocalData(db),
          gateway = LocalWorkoutGateway(data);
      await tester.runAsync(gateway.loadExercises);
      await tester.pumpWidget(
        MaterialApp(home: WorkoutTemplatesPage(gateway: gateway)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Adicionar à minha biblioteca'),
        200,
      );
      await tester.ensureVisible(find.text('Adicionar à minha biblioteca'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Adicionar à minha biblioteca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar à minha biblioteca'));
      await tester.pumpAndSettle();
      final plans = (await tester.runAsync(gateway.loadWorkouts))!;
      expect(plans, hasLength(3));
      expect(plans.map((p) => p.weekday).toSet(), {1, 3, 5});
      expect(plans.map((p) => p.id).toSet(), hasLength(3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      data.dispose();
      await tester.runAsync(db.close);
    },
  );
}
