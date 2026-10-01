import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/workout_gateway.dart';

class WorkoutApiException implements Exception {
  const WorkoutApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Maps the Portuguese API contract to the presentation models.
class ApiWorkoutGateway implements WorkoutGateway {
  ApiWorkoutGateway({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  void close() => _client.close();

  Future<dynamic> _request(String method, String path, [Object? data]) async {
    final request = http.Request(method, Uri.parse('$_baseUrl/api/$path'));
    request.headers['Accept'] = 'application/json';
    if (data != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(data);
    }
    final response = await (() async {
      final stream = await _client.send(request);
      return http.Response.fromStream(stream);
    })().timeout(const Duration(seconds: 15));
    final body = response.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WorkoutApiException(
        body is Map
            ? (body['detail'] ??
                      body['title'] ??
                      'Não foi possível concluir a operação.')
                  .toString()
            : 'Não foi possível concluir a operação.',
      );
    }
    return body;
  }

  ExerciseOption _exercise(Map<String, dynamic> json) => ExerciseOption(
    json['id'] as String,
    json['nome'] as String,
    json['grupoMuscular'] as String,
  );
  WorkoutPlan _workout(Map<String, dynamic> json) {
    final items = List<Map<String, dynamic>>.from(json['exercicios'] as List)
      ..sort((a, b) => (a['ordem'] as int).compareTo(b['ordem'] as int));
    return WorkoutPlan(
      id: json['id'] as String,
      name: json['nome'] as String,
      weekday: json['diaSemana'] as int,
      description: json['descricao'] as String? ?? '',
      items: items
          .map(
            (item) => WorkoutItem(
              exercise: _exercise(item['exercicio'] as Map<String, dynamic>),
              sets: item['series'] as int,
              reps: item['repeticoes'] as int,
              weight: (item['cargaInicial'] as num).toDouble(),
              restSeconds: item['tempoDescanso'] as int,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<List<WorkoutPlan>> loadWorkouts() async =>
      (await _request('GET', 'treinos') as List)
          .map((item) => _workout(item as Map<String, dynamic>))
          .toList();
  @override
  Future<List<ExerciseOption>> loadExercises() async =>
      (await _request('GET', 'exercicios') as List)
          .map((item) => _exercise(item as Map<String, dynamic>))
          .toList();
  @override
  Future<void> saveWorkout(WorkoutPlan workout) async {
    await _request('PUT', 'treinos/${Uri.encodeComponent(workout.id)}', {
      'nome': workout.name,
      'diaSemana': workout.weekday,
      'descricao': workout.description,
      'exercicios': workout.items
          .map(
            (item) => {
              'exercicioId': item.exercise.id,
              'series': item.sets,
              'repeticoes': item.reps,
              'cargaInicial': item.weight,
              'tempoDescanso': item.restSeconds,
            },
          )
          .toList(),
    });
  }

  @override
  Future<void> deleteWorkout(String id) async {
    await _request('DELETE', 'treinos/${Uri.encodeComponent(id)}');
  }
}
