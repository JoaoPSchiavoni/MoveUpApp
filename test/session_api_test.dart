import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moveupapp/features/session/data/api_session_gateway.dart';
import 'package:moveupapp/features/session/domain/session.dart';

import 'session_store_test.dart' show plan;

Map<String, dynamic> response() => {
  'id': 's1',
  'nomeTreino': 'Peito',
  'inicio': '2026-10-02T12:00:00Z',
  'fim': null,
  'status': 'emAndamento',
  'observacao': null,
  'exercicios': [
    {
      'id': 'e1',
      'nome': 'Supino',
      'grupoMuscular': 'Peito',
      'ordem': 0,
      'tempoDescanso': 90,
      'series': [
        {
          'id': 'set1',
          'ordem': 0,
          'repeticoesPlanejadas': 10,
          'cargaPlanejada': 70,
          'repeticoes': 8,
          'carga': 72.5,
          'status': 'concluida',
        },
      ],
    },
  ],
};
void main() {
  test('Session requests preserve ID and map confirmed results', () async {
    final requests = <http.Request>[];
    final gateway = ApiSessionGateway(
      baseUrl: 'http://localhost:5013/',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(response()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(gateway.close);
    final session = await gateway.start('s1', plan());
    expect(requests.last.method, 'PUT');
    expect(requests.last.url.path, '/api/sessoes/s1');
    expect(jsonDecode(requests.last.body)['treinoId'], 'plan');
    expect(session.volume, 580);
    expect(session.startedAt.isUtc, isTrue);
    await gateway.record(
      's1',
      'set1',
      SetStatus.completed,
      reps: 8,
      weight: 72.5,
    );
    expect(requests.last.url.path, '/api/sessoes/s1/series/set1');
    expect(jsonDecode(requests.last.body), {
      'status': 'concluida',
      'repeticoes': 8,
      'carga': 72.5,
    });
    await gateway.record('s1', 'set1', SetStatus.pending);
    expect(jsonDecode(requests.last.body)['carga'], isNull);
    await gateway.finish('s1', 'Bom treino');
    expect(requests.last.url.path, '/api/sessoes/s1/conclusao');
    await gateway.cancel('s1');
    expect(requests.last.url.path, '/api/sessoes/s1/cancelamento');
  });
  test(
    '204 means no active session, 404 remains an actionable error',
    () async {
      var status = 204;
      final gateway = ApiSessionGateway(
        baseUrl: 'http://localhost',
        client: MockClient((_) async => http.Response('', status)),
      );
      addTearDown(gateway.close);
      expect(await gateway.loadActive(), isNull);
      status = 404;
      await expectLater(gateway.loadActive(), throwsA(isA<SessionFailure>()));
    },
  );
  test(
    'History sends pagination and handles problem details and non-JSON errors',
    () async {
      var fail = false;
      final gateway = ApiSessionGateway(
        baseUrl: 'http://localhost',
        client: MockClient((request) async {
          if (fail) return http.Response('<html>Unavailable</html>', 503);
          expect(request.url.queryParameters['pagina'], '2');
          expect(request.url.queryParameters['tamanhoPagina'], '20');
          return http.Response(
            jsonEncode({
              'items': [response()],
              'hasMore': false,
            }),
            200,
          );
        }),
      );
      addTearDown(gateway.close);
      expect((await gateway.history(page: 2)).items, hasLength(1));
      fail = true;
      await expectLater(gateway.loadActive(), throwsA(isA<SessionFailure>()));
    },
  );
}
