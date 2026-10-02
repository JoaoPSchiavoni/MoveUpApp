import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../workout/domain/workout_gateway.dart';
import '../domain/session.dart';

/// Phase 2 API contract; see docs/phase-2-session-api.md.
class ApiSessionGateway implements SessionGateway {
  ApiSessionGateway({required String baseUrl, http.Client? client})
    : _base = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();
  final String _base;
  final http.Client _client;
  void close() => _client.close();
  Future<dynamic> _request(String method, String path, [Object? body]) async {
    try {
      final request = http.Request(
        method,
        Uri.parse('$_base/api/sessoes$path'),
      );
      request.headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 15));
      dynamic json;
      if (response.bodyBytes.isNotEmpty) {
        try {
          json = jsonDecode(utf8.decode(response.bodyBytes));
        } on FormatException {
          json = null;
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SessionFailure(
          json is Map && json['detail'] is String
              ? json['detail'] as String
              : response.statusCode == 404
              ? 'Não foi possível acessar as sessões de treino. Tente novamente mais tarde.'
              : 'Não foi possível salvar ou carregar o treino. Tente novamente.',
          conflict: response.statusCode == 409,
        );
      }
      if (response.statusCode == 204) return null;
      if (json == null) {
        throw const SessionFailure('Resposta inválida ao carregar o treino.');
      }
      return json;
    } on TimeoutException {
      throw const SessionFailure(
        'A conexão demorou demais. Tente novamente; a operação pode já ter sido salva.',
      );
    } on http.ClientException {
      throw const SessionFailure(
        'Sem conexão com o servidor. Seus valores continuam nesta tela. Tente novamente.',
      );
    }
  }

  TrainingSession _session(dynamic value) {
    final json = value as Map<String, dynamic>;
    final exercises = (json['exercicios'] as List).map((raw) {
      final e = raw as Map<String, dynamic>;
      final sets = (e['series'] as List).map((raw) {
        final s = raw as Map<String, dynamic>;
        return SessionSet(
          id: s['id'] as String,
          order: s['ordem'] as int,
          plannedReps: s['repeticoesPlanejadas'] as int,
          plannedWeight: (s['cargaPlanejada'] as num).toDouble(),
          reps: s['repeticoes'] as int?,
          weight: (s['carga'] as num?)?.toDouble(),
          status: switch (s['status']) {
            'pendente' => SetStatus.pending,
            'concluida' => SetStatus.completed,
            'pulada' => SetStatus.skipped,
            _ => throw const FormatException('Status da série inválido'),
          },
        );
      }).toList()..sort((a, b) => a.order.compareTo(b.order));
      return SessionExercise(
        id: e['id'] as String,
        name: e['nome'] as String,
        group: e['grupoMuscular'] as String,
        order: e['ordem'] as int,
        restSeconds: e['tempoDescanso'] as int,
        sets: sets,
      );
    }).toList()..sort((a, b) => a.order.compareTo(b.order));
    return TrainingSession(
      id: json['id'] as String,
      name: json['nomeTreino'] as String,
      startedAt: DateTime.parse(json['inicio'] as String),
      endedAt: json['fim'] == null
          ? null
          : DateTime.parse(json['fim'] as String),
      note: json['observacao'] as String? ?? '',
      exercises: exercises,
      status: switch (json['status']) {
        'emAndamento' => SessionStatus.active,
        'concluida' => SessionStatus.completed,
        'cancelada' => SessionStatus.cancelled,
        _ => throw const FormatException('Status da sessão inválido'),
      },
    );
  }

  String _id(String id) => Uri.encodeComponent(id);
  @override
  Future<TrainingSession?> loadActive() async {
    final json = await _request('GET', '/ativa');
    return json == null ? null : _session(json);
  }

  @override
  Future<TrainingSession> load(String id) async =>
      _session(await _request('GET', '/${_id(id)}'));
  @override
  Future<TrainingSession> start(String id, WorkoutPlan plan) async =>
      _session(await _request('PUT', '/${_id(id)}', {'treinoId': plan.id}));
  @override
  Future<TrainingSession> record(
    String sessionId,
    String setId,
    SetStatus status, {
    int? reps,
    double? weight,
  }) async => _session(
    await _request('PUT', '/${_id(sessionId)}/series/${_id(setId)}', {
      'status': switch (status) {
        SetStatus.pending => 'pendente',
        SetStatus.completed => 'concluida',
        SetStatus.skipped => 'pulada',
      },
      'repeticoes': status == SetStatus.completed ? reps : null,
      'carga': status == SetStatus.completed ? weight : null,
    }),
  );
  @override
  Future<TrainingSession> finish(String id, String note) async => _session(
    await _request('PUT', '/${_id(id)}/conclusao', {'observacao': note}),
  );
  @override
  Future<TrainingSession> cancel(String id) async =>
      _session(await _request('PUT', '/${_id(id)}/cancelamento', {}));
  @override
  Future<SessionPage> history({int page = 1, int pageSize = 20}) async {
    final json = await _request(
      'GET',
      '?pagina=$page&tamanhoPagina=$pageSize&status=concluida',
    ) as Map;
    return SessionPage(
      (json['items'] as List).map(_session).toList(),
      hasMore: json['hasMore'] as bool,
    );
  }
}
