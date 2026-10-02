import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/consistency.dart';

class ApiConsistencyGateway implements ConsistencyGateway {
  ApiConsistencyGateway({required String baseUrl, http.Client? client})
    : base = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      client = client ?? http.Client();
  final String base;
  final http.Client client;
  void close() => client.close();
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    try {
      final response =
          await (method == 'GET'
                  ? client.get(
                      Uri.parse('$base/api/acompanhamento$path'),
                      headers: {'Accept': 'application/json'},
                    )
                  : client.put(
                      Uri.parse('$base/api/acompanhamento$path'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',
                      },
                      body: jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 15));
      Map<String, dynamic>? data;
      try {
        data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        data = null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ConsistencyFailure(
          data?['detail'] as String? ??
              'Não foi possível acessar o acompanhamento. Tente novamente.',
        );
      }
      if (data == null) {
        throw const ConsistencyFailure('Resposta inválida do acompanhamento.');
      }
      return data;
    } on TimeoutException {
      throw const ConsistencyFailure(
        'A conexão demorou demais. Tente novamente; uma configuração pode já ter sido salva.',
      );
    } on http.ClientException {
      throw const ConsistencyFailure(
        'Sem conexão com o servidor. Tente novamente.',
      );
    }
  }

  @override
  Future<ConsistencyConfig> config() async =>
      ConsistencyConfig(await request('GET', '/configuracao'));
  @override
  Future<ConsistencyConfig> configure(
    String zone,
    List<int> days,
    int goal,
  ) async => ConsistencyConfig(
    await request('PUT', '/configuracao', {
      'fuso': zone,
      'diasSemana': days,
      'metaSemanal': goal,
    }),
  );
  @override
  Future<ConsistencyPanel> panel() async =>
      ConsistencyPanel(await request('GET', '/painel'));
  @override
  Future<List<CalendarDay>> calendar(DateTime month) async {
    final data = await request(
      'GET',
      '/calendario?ano=${month.year}&mes=${month.month}',
    );
    return (data['dias'] as List)
        .map((d) => CalendarDay(Map<String, dynamic>.from(d as Map)))
        .toList();
  }

  @override
  Future<ConsistencyWeek> week(DateTime start) async => ConsistencyWeek(
    await request('GET', '/semanas?inicio=${dateKey(start)}'),
  );
}

/// Preview sessions are in memory; never present server metrics as preview data.
class UnavailableConsistencyGateway implements ConsistencyGateway {
  Never unavailable() => throw const ConsistencyFailure(
    'O calendário e as metas precisam do modo conectado à API. O modo de demonstração mantém apenas treinos e sessões em memória.',
  );
  @override
  Future<ConsistencyConfig> config() async => unavailable();
  @override
  Future<ConsistencyConfig> configure(
    String zone,
    List<int> days,
    int goal,
  ) async => unavailable();
  @override
  Future<ConsistencyPanel> panel() async => unavailable();
  @override
  Future<List<CalendarDay>> calendar(DateTime month) async => unavailable();
  @override
  Future<ConsistencyWeek> week(DateTime start) async => unavailable();
}
