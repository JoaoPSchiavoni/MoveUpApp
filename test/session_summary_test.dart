import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moveupapp/core/appearance.dart';
import 'package:moveupapp/features/session/domain/session.dart';
import 'package:moveupapp/features/session/presentation/session_summary.dart';

void main() {
  for (final width in [320.0, 393.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Summary fits width $width with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: moveUpTheme(Brightness.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: SessionSummaryPage(
              session: TrainingSession(
                id: 'summary',
                name: 'Peito',
                startedAt: DateTime(2026, 10, 2, 14, 32),
                endedAt: DateTime(2026, 10, 2, 14, 32, 30),
                status: SessionStatus.completed,
                note: 'Treino registrado',
                exercises: [
                  SessionExercise(
                    id: 'exercise',
                    name: 'Supino',
                    group: 'Peito',
                    order: 0,
                    restSeconds: 60,
                    sets: [
                      const SessionSet(
                        id: 'set',
                        order: 0,
                        plannedReps: 10,
                        plannedWeight: 40,
                        status: SetStatus.completed,
                        reps: 10,
                        weight: 40,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final duration = tester.getRect(
          find.byKey(const ValueKey('summary-Duração')),
        );
        // A short workout must use the available width, without the old empty half-screen.
        expect(duration.width, closeTo((width < 850 ? width : 850) - 48, 1));
        for (final label in [
          'Exercícios realizados',
          'Séries concluídas',
          'Séries puladas',
          'Volume registrado',
        ]) {
          final finder = find.byKey(ValueKey('summary-$label'));
          await tester.scrollUntilVisible(finder, 200);
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
        await tester.scrollUntilVisible(find.text('Treino registrado'), 200);
        expect(find.text('Treino registrado'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Série 1 · 10 reps × 40 kg'),
          200,
        );
        expect(find.text('Série 1 · 10 reps × 40 kg'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
