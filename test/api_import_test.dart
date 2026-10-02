import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:moveupapp/core/data_transfer.dart';
import 'package:moveupapp/core/local_database.dart';
import 'package:moveupapp/core/local_gateways.dart';

final exercise = {'id': 'e', 'nome': 'Supino', 'grupoMuscular': 'Peito'};
Map<String, dynamic> session(String id, {bool legacy = false}) => {
  'id': id,
  'nomeTreino': 'A',
  'treinoId': 'w',
  'treinoOrigemId': 'w',
  'inicio': '2026-10-02T02:00:00Z',
  'fim': '2026-10-02T03:00:00Z',
  'status': 'concluida',
  'observacao': '',
  if (!legacy) 'dataPresenca': '2026-10-01',
  if (!legacy) 'fusoPresenca': 'America/Sao_Paulo',
  'exercicios': [
    {
      'id': 'ex$id',
      'nome': 'Supino',
      'grupoMuscular': 'Peito',
      'ordem': 0,
      'tempoDescanso': 60,
      if (!legacy) 'exercicioOrigemId': 'e',
      'series': [
        {
          'id': 'set$id',
          'ordem': 0,
          'repeticoesPlanejadas': 10,
          'cargaPlanejada': 20,
          'repeticoes': 8,
          'carga': 25,
          'status': 'concluida',
        },
      ],
    },
  ],
};
MockClient api({bool fail = false}) => MockClient((request) async {
  final path = request.url.path;
  Object? body;
  if (path == '/api/exercicios') {
    body = [exercise];
  } else if (path == '/api/treinos') {
    body = [
      {
        'id': 'w',
        'nome': 'A',
        'diaSemana': 1,
        'ativo': true,
        'descricao': '',
        'exercicios': [
          {
            'ordem': 0,
            'exercicio': exercise,
            'series': 2,
            'repeticoes': 10,
            'cargaInicial': 20,
            'tempoDescanso': 60,
          },
        ],
      },
    ];
  } else if (path == '/api/sessoes/ativa') {
    return http.Response('', 204);
  } else if (path == '/api/sessoes') {
    if (request.url.queryParameters['pagina'] == '1') {
      body = {
        'items': [session('s1')],
        'hasMore': true,
      };
    } else if (fail) {
      return http.Response('failed', 500);
    } else {
      body = {
        'items': [session('s2', legacy: true)],
        'hasMore': false,
      };
    }
  } else if (path == '/api/acompanhamento/configuracao') {
    body = {
      'ativado': true,
      'fuso': 'America/Sao_Paulo',
      'hoje': '2026-10-02',
      'inicio': '2026-09-21',
      'rotinas': [
        {
          'inicio': '2026-09-21',
          'diasSemana': [1, 3, 5],
        },
      ],
      'metas': [
        {'inicio': '2026-09-21', 'dias': 3},
      ],
    };
  } else {
    return http.Response('Not found: $path', 404);
  }
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
});
void main() {
  setUpAll(tzdata.initializeTimeZones);
  test('API import reads every page, preserves original identity and freezes legacy dates', () async {
    final db = MoveUpDatabase(NativeDatabase.memory()), data = LocalData(db);
    try {
      await BackupService(data).importApi('http://test', client: api());
      expect(await LocalWorkoutGateway(data).loadWorkouts(), hasLength(1));
      final sessions = await LocalSessionGateway(data).all();
      expect(sessions, hasLength(2));
      expect(sessions.first.exercises.single.originId, 'e');
      expect(sessions.last.exercises.single.originId, isNull);
      expect(sessions.map((s) => s.localDate).toSet(), {'2026-10-01'});
      expect(
        (await LocalConsistencyGateway(data).config()).start,
        DateTime(2026, 9, 21),
      );
      await expectLater(
        BackupService(data).importApi('http://test', client: api()),
        throwsFormatException,
      );
      expect(await LocalSessionGateway(data).all(), hasLength(2));
    } finally {
      data.dispose();
      await db.close();
    }
  });
  test(
    'Failed API read does not partially import workouts or catalog',
    () async {
      final db = MoveUpDatabase(NativeDatabase.memory()), data = LocalData(db);
      try {
        await expectLater(
          BackupService(data).importApi('http://test', client: api(fail: true)),
          throwsA(anything),
        );
        expect(await db.records('workout'), isEmpty);
        expect(await db.records('exercise'), isEmpty);
        expect(await db.records('session'), isEmpty);
      } finally {
        data.dispose();
        await db.close();
      }
    },
  );
}
