import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../workout/domain/workout_gateway.dart';
import '../domain/session.dart';

class SetDraft {
  SetDraft(SessionSet set)
    : reps = '${set.reps ?? set.plannedReps}',
      weight = '${set.weight ?? set.plannedWeight}';
  String reps, weight;
  bool dirty = false;
}

/// Owns session state across routes. Confirmed values only change after a reply.
class SessionStore extends ChangeNotifier {
  SessionStore(this.gateway, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final SessionGateway gateway;
  final DateTime Function() now;
  TrainingSession? active;
  bool busy = false, loading = false;
  String? error;
  final Map<String, String> _startIds = {};
  final Map<String, SetDraft> drafts = {};
  DateTime? restEndsAt;
  int lastRestSeconds = 0;
  String noteDraft = '';
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String message(Object error) => error is SessionFailure
      ? error.message
      : 'Não foi possível concluir a operação. Tente novamente.';
  SetDraft draft(SessionSet set) =>
      drafts.putIfAbsent(set.id, () => SetDraft(set));
  bool get hasUnsaved => drafts.values.any((d) => d.dirty);
  int get remainingRest {
    if (restEndsAt == null) return 0;
    final milliseconds = restEndsAt!.difference(now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  void startRest(int seconds) {
    lastRestSeconds = seconds;
    restEndsAt = seconds > 0 ? now().add(Duration(seconds: seconds)) : null;
    _notify();
  }

  void skipRest() {
    restEndsAt = null;
    _notify();
  }

  void _accept(TrainingSession? value) {
    if (value != null) {
      _startIds.removeWhere((_, id) => id == value.id);
    }
    if (active?.id != value?.id) {
      drafts.clear();
      restEndsAt = null;
      lastRestSeconds = 0;
      noteDraft = '';
    }
    active = value?.status == SessionStatus.active ? value : null;
  }

  Future<void> refresh() async {
    if (loading || busy) return;
    loading = true;
    error = null;
    _notify();
    try {
      _accept(await gateway.loadActive());
    } catch (e) {
      error = message(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<TrainingSession?> start(WorkoutPlan plan) async {
    if (busy || loading) return null;
    busy = true;
    error = null;
    _notify();
    try {
      final existing = await gateway.loadActive();
      if (existing != null) {
        _accept(existing);
        return existing;
      }
      final id = _startIds.putIfAbsent(plan.id, () => const Uuid().v4());
      try {
        final value = await gateway.start(id, plan);
        _startIds.remove(plan.id);
        _accept(value);
        return value;
      } on SessionFailure catch (e) {
        if (!e.conflict) rethrow;
        final existing = await gateway.loadActive();
        if (existing == null) rethrow;
        _accept(existing);
        return existing;
      }
    } catch (e) {
      error = message(e);
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> record(SessionSet set, SetStatus status, int restSeconds) async {
    if (busy || active == null) return false;
    final draftValue = draft(set);
    int? reps;
    double? weight;
    if (status == SetStatus.completed) {
      reps = int.tryParse(draftValue.reps.trim());
      weight = double.tryParse(draftValue.weight.trim().replaceAll(',', '.'));
      if (reps == null ||
          reps <= 0 ||
          weight == null ||
          !weight.isFinite ||
          weight < 0) {
        error = 'Informe repetições inteiras maiores que zero e carga válida, zero ou mais.';
        _notify();
        return false;
      }
    }
    busy = true;
    error = null;
    _notify();
    try {
      final updated = await gateway.record(
        active!.id,
        set.id,
        status,
        reps: reps,
        weight: weight,
      );
      _accept(updated);
      drafts.remove(set.id);
      if (status == SetStatus.pending) {
        drafts[set.id] = SetDraft(set);
      }
      if (status == SetStatus.completed) startRest(restSeconds);
      return true;
    } catch (e) {
      error = message(e);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<TrainingSession?> end({required bool cancel}) async {
    if (busy || active == null) return null;
    busy = true;
    error = null;
    _notify();
    try {
      final value = cancel
          ? await gateway.cancel(active!.id)
          : await gateway.finish(active!.id, noteDraft.trim());
      _accept(null);
      return value;
    } catch (e) {
      error = message(e);
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
