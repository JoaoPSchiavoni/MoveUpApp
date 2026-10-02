import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moveupapp/core/app.dart';
import 'package:moveupapp/features/workout/data/preview_workout_gateway.dart';
import 'package:moveupapp/features/session/data/preview_session_gateway.dart';
import 'package:moveupapp/features/session/presentation/session_page.dart';
import 'package:moveupapp/features/session/presentation/session_store.dart';

import 'session_store_test.dart' show plan, FailingGateway;

Future<void> reveal(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
    await tester.drag(
      find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
  }
  expect(finder, findsAtLeastNWidgets(1));
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Start, record, resume, partially finish and open history on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workouts = PreviewWorkoutGateway();
      final sessions = PreviewSessionGateway();
      await workouts.saveWorkout(plan());
      await tester.pumpWidget(
        MoveUpApp(gateway: workouts, sessionGateway: sessions),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Treino A'));
      await tester.tap(find.text('Treino A').last);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Iniciar treino'));
      await tester.tap(find.text('Iniciar treino'));
      await tester.pumpAndSettle();
      expect(find.text('Treino em andamento'), findsOneWidget);
      final id = (await sessions.loadActive())!.sets.first.id;
      await reveal(tester, find.byKey(ValueKey('weight-$id')));
      await tester.enterText(find.byKey(ValueKey('weight-$id')), '72,5');
      await tester.enterText(find.byKey(ValueKey('reps-$id')), '8');
      await reveal(tester, find.text('Concluir série'));
      await tester.tap(find.text('Concluir série').first);
      await tester.pumpAndSettle();
      expect((await sessions.loadActive())!.completed, 1);
      expect(find.textContaining('Salva · 8 reps'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Continuar treino'));
      await tester.tap(find.text('Continuar treino').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('1 concluídas'), findsOneWidget);
      await reveal(tester, find.text('Finalizar treino'));
      await tester.tap(find.text('Finalizar treino'));
      await tester.pumpAndSettle();
      expect(
        find.text('1 séries pendentes serão marcadas como puladas.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Treino concluído',
      );
      await tester.tap(find.text('Confirmar conclusão'));
      await tester.pumpAndSettle();
      expect(find.text('Resumo do treino'), findsOneWidget);
      expect(find.text('580 kg'), findsOneWidget);
      expect(await sessions.loadActive(), isNull);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      expect(find.text('Histórico de treinos'), findsOneWidget);
      await tester.tap(find.text('Treino A'));
      await tester.pumpAndSettle();
      expect(find.text('Resumo do treino'), findsOneWidget);
    },
  );

  testWidgets(
    'Save failure retains inputs; correction and cancellation require explicit actions',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = FailingGateway()..failRecord = true;
      final store = SessionStore(gateway);
      addTearDown(store.dispose);
      await store.start(plan());
      final setId = store.active!.sets.first.id;
      await tester.pumpWidget(MaterialApp(home: SessionPageView(store: store)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ValueKey('weight-$setId')), '80');
      await tester.tap(find.text('Concluir série').first);
      await tester.pumpAndSettle();
      expect(find.text('Falha ao salvar.'), findsOneWidget);
      expect(store.active!.completed, 0);
      expect(
        tester
            .widget<TextField>(find.byKey(ValueKey('weight-$setId')))
            .controller!
            .text,
        '80',
      );
      await tester.tap(find.text('Concluir série').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Corrigir série'));
      await tester.pumpAndSettle();
      expect(store.active!.completed, 0);
      await tester.enterText(find.byKey(ValueKey('reps-$setId')), '6');
      await tester.tap(find.text('Concluir série').first);
      await tester.pumpAndSettle();
      expect(store.active!.sets.first.reps, 6);
      await reveal(tester, find.text('Cancelar treino'));
      await tester.tap(find.text('Cancelar treino'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar treinando'));
      await tester.pumpAndSettle();
      expect(store.active, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
