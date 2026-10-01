import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moveupapp/features/workout/data/api_workout_gateway.dart';
import 'package:moveupapp/features/workout/domain/workout_gateway.dart';

void main() {
  const exercise = {
    'id': 'e1',
    'nome': 'Supino reto',
    'grupoMuscular': 'Peito',
  };
  test('Maps the API catalog and ordered workout items', () async {
    final gateway = ApiWorkoutGateway(
      baseUrl: 'http://localhost:5013/',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        if (request.url.path == '/api/exercicios') {
          return http.Response(jsonEncode([exercise]), 200);
        }
        expect(request.url.path, '/api/treinos');
        return http.Response(
          jsonEncode([
            {
              'id': 'w1',
              'nome': 'Peito',
              'diaSemana': 1,
              'descricao': null,
              'exercicios': [
                {
                  'ordem': 1,
                  'exercicio': exercise,
                  'series': 4,
                  'repeticoes': 8,
                  'cargaInicial': 72.5,
                  'tempoDescanso': 90,
                },
                {
                  'ordem': 0,
                  'exercicio': exercise,
                  'series': 3,
                  'repeticoes': 10,
                  'cargaInicial': 0,
                  'tempoDescanso': 0,
                },
              ],
            },
          ]),
          200,
        );
      }),
    );
    addTearDown(gateway.close);
    expect((await gateway.loadExercises()).single.name, 'Supino reto');
    final plan = (await gateway.loadWorkouts()).single;
    expect(plan.description, '');
    expect(plan.items.first.sets, 3);
    expect(plan.items.last.weight, 72.5);
  });
  test('Saves with stable ID and sends fields expected by API', () async {
    var writes = 0;
    final gateway = ApiWorkoutGateway(
      baseUrl: 'http://localhost:5013',
      client: MockClient((request) async {
        expect(request.url.path, '/api/treinos/w1');
        if (request.method == 'DELETE') return http.Response('', 204);
        expect(request.method, 'PUT');
        final body = jsonDecode(request.body) as Map;
        expect(body['nome'], 'Peito');
        expect(body['diaSemana'], 1);
        expect(body['exercicios'][0]['exercicioId'], 'e1');
        expect(body['exercicios'][0]['cargaInicial'], 72.5);
        writes++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(gateway.close);
    final plan = WorkoutPlan(
      id: 'w1',
      name: 'Peito',
      weekday: 1,
      items: const [
        WorkoutItem(
          exercise: ExerciseOption('e1', 'Supino reto', 'Peito'),
          weight: 72.5,
        ),
      ],
    );
    await gateway.saveWorkout(plan);
    await gateway.saveWorkout(plan);
    expect(writes, 2);
    await gateway.deleteWorkout('w1');
  });
  test('Propagates server validation failures', () async {
    final gateway = ApiWorkoutGateway(
      baseUrl: 'http://localhost:5013',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Treino inválido.'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(gateway.close);
    await expectLater(
      gateway.loadWorkouts(),
      throwsA(
        isA<WorkoutApiException>().having(
          (e) => e.message,
          'message',
          'Treino inválido.',
        ),
      ),
    );
  });
}
