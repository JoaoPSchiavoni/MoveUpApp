import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moveupapp/core/app.dart';
import 'package:moveupapp/features/consistency/domain/consistency.dart';
import 'package:moveupapp/features/workout/data/preview_workout_gateway.dart';
import 'package:moveupapp/features/session/data/preview_session_gateway.dart';

Finder get verticalScroll => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

void main() {
  testWidgets(
    'Configure routine, navigate calendar, inspect day and weekly goal on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final gateway = FixtureConsistency();
      await tester.pumpWidget(
        MoveUpApp(
          gateway: PreviewWorkoutGateway(),
          sessionGateway: PreviewSessionGateway(),
          consistencyGateway: gateway,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendário'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configurar minha rotina'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Segunda-feira'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Salvar rotina e meta'),
        300,
        scrollable: verticalScroll,
      );
      await tester.tap(find.text('Salvar rotina e meta'));
      await tester.pumpAndSettle();
      expect(gateway.enabled, isTrue);
      expect(gateway.days, [1]);
      expect(find.text('Outubro 2026'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.bySemanticsLabel('05/10/2026, Treinado, hoje'),
        200,
        scrollable: verticalScroll,
      );
      await tester.tap(find.bySemanticsLabel('05/10/2026, Treinado, hoje'));
      await tester.pumpAndSettle();
      expect(find.text('Treino A'), findsOneWidget);
      expect(find.text('05/10/2026'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.drag(verticalScroll, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Setembro 2026'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Meta: 1/2 dias'),
        250,
        scrollable: verticalScroll,
      );
      expect(find.text('Meta: 1/2 dias'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('Calendar failure shows retry without stale month cells', (
    tester,
  ) async {
    final gateway = FixtureConsistency()..enabled = true;
    await tester.pumpWidget(
      MoveUpApp(
        gateway: PreviewWorkoutGateway(),
        sessionGateway: PreviewSessionGateway(),
        consistencyGateway: gateway,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendário'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Outubro 2026'),
      150,
      scrollable: verticalScroll,
    );
    gateway.failCalendar = true;
    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Falha de calendário.'), findsOneWidget);
    expect(find.bySemanticsLabel('05/10/2026, Treinado, hoje'), findsNothing);
    gateway.failCalendar = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Falha de calendário.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class FixtureConsistency implements ConsistencyGateway {
  bool enabled = false, failCalendar = false;
  List<int> days = [1, 3, 5];
  Map<String, dynamic> get weekData => {
    'inicio': '2026-10-05',
    'fim': '2026-10-11',
    'diasTreinados': 1,
    'sessoes': 2,
    'meta': 2,
    'planejadosEncerrados': 0,
    'planejadosCumpridos': 0,
    'adesao': null,
    'duracaoSegundos': 3600,
    'volume': 400,
  };
  @override
  Future<ConsistencyConfig> config() async => ConsistencyConfig({
    'ativado': enabled,
    'fuso': 'America/Sao_Paulo',
    'hoje': '2026-10-05',
    'rotinas': enabled
        ? [
            {'inicio': '2026-10-05', 'diasSemana': days},
          ]
        : [],
    'metas': enabled
        ? [
            {'inicio': '2026-10-05', 'dias': 2},
          ]
        : [],
  });
  @override
  Future<ConsistencyConfig> configure(
    String zone,
    List<int> selected,
    int goal,
  ) async {
    enabled = true;
    days = selected;
    return config();
  }

  @override
  Future<ConsistencyPanel> panel() async => ConsistencyPanel({
    'hoje': '2026-10-05',
    'fuso': 'America/Sao_Paulo',
    'ativado': enabled,
    'sequenciaAtual': 1,
    'melhorSequencia': 3,
    'diasTreinadosMes': 1,
    'semana': weekData,
  });
  @override
  Future<List<CalendarDay>> calendar(DateTime month) async {
    if (failCalendar) throw const ConsistencyFailure('Falha de calendário.');
    return [
      for (var d = 1; d <= DateTime(month.year, month.month + 1, 0).day; d++)
        CalendarDay({
          'data': dateKey(DateTime(month.year, month.month, d)),
          'estado': d == 5 && month.month == 10 ? 'treinado' : 'descanso',
          'planejado': d == 5,
          'sessoes': d == 5 && month.month == 10
              ? [
                  {'id': 'session-id', 'nomeTreino': 'Treino A'},
                ]
              : [],
        }),
    ];
  }

  @override
  Future<ConsistencyWeek> week(DateTime start) async => ConsistencyWeek({
    ...weekData,
    'inicio': dateKey(start),
    'fim': dateKey(start.add(const Duration(days: 6))),
  });
}
