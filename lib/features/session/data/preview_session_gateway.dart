import 'package:uuid/uuid.dart';

import '../../workout/domain/workout_gateway.dart';
import '../domain/session.dart';

/// In-memory sessions for explicit preview mode and tests only.
class PreviewSessionGateway implements SessionGateway {
  final Map<String, TrainingSession> _sessions = {};
  @override
  Future<TrainingSession?> loadActive() async => _sessions.values
      .where((s) => s.status == SessionStatus.active)
      .firstOrNull;
  @override
  Future<TrainingSession> load(String id) async =>
      _sessions[id] ?? (throw const SessionFailure('Sessão não encontrada.'));
  @override
  Future<TrainingSession> start(String id, WorkoutPlan plan) async {
    if (_sessions.containsKey(id)) return _sessions[id]!;
    if (await loadActive() != null) {
      throw const SessionFailure(
        'Já existe um treino em andamento.',
        conflict: true,
      );
    }
    if (plan.items.isEmpty) {
      throw const SessionFailure('A ficha não possui exercícios.');
    }
    final session = TrainingSession(
      id: id,
      name: plan.name,
      workoutId: plan.id,
      startedAt: DateTime.now().toUtc(),
      exercises: [
        for (var i = 0; i < plan.items.length; i++)
          SessionExercise(
            id: const Uuid().v4(),
            name: plan.items[i].exercise.name,
            originId: plan.items[i].exercise.id,
            group: plan.items[i].exercise.group,
            order: i,
            restSeconds: plan.items[i].restSeconds,
            sets: List.generate(
              plan.items[i].sets,
              (n) => SessionSet(
                id: const Uuid().v4(),
                order: n,
                plannedReps: plan.items[i].reps,
                plannedWeight: plan.items[i].weight,
              ),
            ),
          ),
      ],
    );
    _sessions[id] = session;
    return session;
  }

  Future<TrainingSession> _active(String id) async {
    final session = await load(id);
    if (session.status != SessionStatus.active) {
      throw const SessionFailure('Esta sessão já foi encerrada.');
    }
    return session;
  }

  @override
  Future<TrainingSession> record(
    String sessionId,
    String setId,
    SetStatus status, {
    int? reps,
    double? weight,
  }) async {
    final session = await _active(sessionId);
    if (!session.sets.any((s) => s.id == setId)) {
      throw const SessionFailure('Série não encontrada.');
    }
    if (status == SetStatus.completed &&
        (reps == null ||
            reps <= 0 ||
            weight == null ||
            !weight.isFinite ||
            weight < 0)) {
      throw const SessionFailure('Informe carga e repetições válidas.');
    }
    final updated = session.copy(
      exercises: session.exercises
          .map(
            (e) => e.withSets(
              e.sets
                  .map(
                    (s) => s.id == setId
                        ? s.recorded(
                            status,
                            reps: status == SetStatus.completed ? reps : null,
                            weight: status == SetStatus.completed
                                ? weight
                                : null,
                          )
                        : s,
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
    _sessions[sessionId] = updated;
    return updated;
  }

  @override
  Future<TrainingSession> finish(String id, String note) async {
    final previous = await load(id);
    if (previous.status == SessionStatus.completed) return previous;
    final session = await _active(id);
    if (session.completed == 0) {
      throw const SessionFailure(
        'Conclua pelo menos uma série antes de finalizar.',
      );
    }
    final result = session.copy(
      status: SessionStatus.completed,
      endedAt: DateTime.now().toUtc(),
      note: note.trim(),
      exercises: session.exercises
          .map(
            (e) => e.withSets(
              e.sets
                  .map(
                    (s) => s.status == SetStatus.pending
                        ? s.recorded(SetStatus.skipped)
                        : s,
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
    _sessions[id] = result;
    return result;
  }

  @override
  Future<TrainingSession> cancel(String id) async {
    final previous = await load(id);
    if (previous.status == SessionStatus.cancelled) return previous;
    final session = await _active(id);
    final result = session.copy(
      status: SessionStatus.cancelled,
      endedAt: DateTime.now().toUtc(),
    );
    _sessions[id] = result;
    return result;
  }

  @override
  Future<SessionPage> history({int page = 1, int pageSize = 20}) async {
    final items =
        _sessions.values
            .where((s) => s.status == SessionStatus.completed)
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return SessionPage(
      items.skip((page - 1) * pageSize).take(pageSize).toList(),
      hasMore: page * pageSize < items.length,
    );
  }
}
