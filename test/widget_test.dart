import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moveupapp/core/app.dart';
import 'package:moveupapp/features/workout/data/preview_workout_gateway.dart';

void main() {
  testWidgets('Create, edit and delete a workout through the UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = PreviewWorkoutGateway();
    await tester.pumpWidget(MoveUpApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo treino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome do treino.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Peito');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segunda-feira').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Selecione pelo menos um exercício.'), findsOneWidget);
    await tester.tap(find.text('Supino reto'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '4');
    await tester.enterText(find.byType(TextFormField).at(2), '72,5');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar treino'));
    await tester.pumpAndSettle();
    expect((await gateway.loadWorkouts()).single.items.single.weight, 72.5);
    await tester.tap(find.text('Peito').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar treino'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Peito e tríceps');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Salvar treino'));
    await tester.pumpAndSettle();
    expect((await gateway.loadWorkouts()).single.name, 'Peito e tríceps');
    await tester.tap(find.text('Peito e tríceps').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir treino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await gateway.loadWorkouts(), hasLength(1));
    await tester.tap(find.text('Excluir treino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(await gateway.loadWorkouts(), isEmpty);
  });

  testWidgets('Mobile layout has no overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MoveUpApp(gateway: PreviewWorkoutGateway()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Novo treino'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
