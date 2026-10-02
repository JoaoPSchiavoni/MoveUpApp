import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moveupapp/features/session/data/preview_session_gateway.dart';
import 'package:moveupapp/features/session/domain/session.dart';
import 'package:moveupapp/features/session/presentation/session_store.dart';
import 'package:moveupapp/features/workout/domain/workout_gateway.dart';

WorkoutPlan plan() => WorkoutPlan(
  id: 'plan',
  name: 'Treino A',
  weekday: 1,
  items: const [
    WorkoutItem(
      exercise: ExerciseOption('e1', 'Supino', 'Peito'),
      sets: 2,
      reps: 10,
      weight: 70,
      restSeconds: 90,
    ),
  ],
);

class FailingGateway extends PreviewSessionGateway {
  bool failStart = false, failRecord = false, failFinish = false;
  final starts = <String>[];
  @override
  Future<TrainingSession> start(String id, WorkoutPlan plan) async {
    starts.add(id);
    if (failStart) {
      failStart = false;
      throw const SessionFailure('Conexão interrompida.');
    }
    return super.start(id, plan);
  }

  @override
  Future<TrainingSession> record(
    String sessionId,
    String setId,
    SetStatus status, {
    int? reps,
    double? weight,
  }) async {
    if (failRecord) {
      failRecord = false;
      throw const SessionFailure('Falha ao salvar.');
    }
    return super.record(sessionId, setId, status, reps: reps, weight: weight);
  }

  @override
  Future<TrainingSession> finish(String id, String note) async {
    if (failFinish) {
      failFinish = false;
      throw const SessionFailure('Falha ao finalizar.');
    }
    return super.finish(id, note);
  }
}

void main() {
  test('A lost start response is recovered without reusing the finished session ID', () async {
    final gateway = LostStartGateway();
    final store = SessionStore(gateway);
    addTearDown(store.dispose);
    expect(await store.start(plan()), isNull);
    final recovered = await store.start(plan());
    expect(recovered, isNotNull);
    await store.end(cancel: true);
    final next = await store.start(plan());
    expect(next!.status, SessionStatus.active);
    expect(next.id, isNot(recovered!.id));
  });
  test(
    'Start retries reuse UUID and an existing active session is resumed',
    () async {
      final gateway = FailingGateway()..failStart = true;
      final store = SessionStore(gateway);
      addTearDown(store.dispose);
      expect(await store.start(plan()), isNull);
      final session = await store.start(plan());
      expect(session, isNotNull);
      expect(gateway.starts[0], gateway.starts[1]);
      expect((await store.start(plan()))!.id, session!.id);
      expect(gateway.starts, hasLength(2));
    },
  );
  test(
    'Failed saves keep draft values and do not mark a set completed',
    () async {
      final gateway = FailingGateway()..failRecord = true;
      final store = SessionStore(gateway);
      addTearDown(store.dispose);
      await store.start(plan());
      final set = store.active!.sets.first;
      final draft = store.draft(set)
        ..weight = '72,5'
        ..reps = '8'
        ..dirty = true;
      expect(await store.record(set, SetStatus.completed, 90), isFalse);
      expect(store.active!.completed, 0);
      expect(store.draft(set), same(draft));
      expect(store.remainingRest, 0);
      expect(await store.record(set, SetStatus.completed, 90), isTrue);
      expect(store.active!.sets.first.weight, 72.5);
      expect(store.active!.volume, 580);
      expect(store.hasUnsaved, isFalse);
    },
  );
  test(
    'Numeric validation, skip and reopen do not count false volume',
    () async {
      final store = SessionStore(PreviewSessionGateway());
      addTearDown(store.dispose);
      await store.start(plan());
      final set = store.active!.sets.first;
      store.draft(set).reps = '1.5';
      expect(await store.record(set, SetStatus.completed, 90), isFalse);
      store.draft(set).reps = '10';
      store.draft(set).weight = 'NaN';
      expect(await store.record(set, SetStatus.completed, 90), isFalse);
      store.draft(set).weight = '0';
      expect(await store.record(set, SetStatus.completed, 90), isTrue);
      expect(store.active!.completed, 1);
      expect(store.active!.volume, 0);
      await store.record(set, SetStatus.pending, 90);
      expect(store.active!.completed, 0);
      await store.record(set, SetStatus.skipped, 90);
      expect(store.active!.skipped, 1);
    },
  );
  test(
    'Resume confirmed progress, finish partially and preserve note on failure',
    () async {
      final gateway = FailingGateway();
      final first = SessionStore(gateway);
      await first.start(plan());
      await first.record(first.active!.sets.first, SetStatus.completed, 90);
      first.dispose();
      final resumed = SessionStore(gateway);
      addTearDown(resumed.dispose);
      await resumed.refresh();
      expect(resumed.active!.completed, 1);
      resumed.noteDraft = 'Bom treino';
      gateway.failFinish = true;
      expect(await resumed.end(cancel: false), isNull);
      expect(resumed.noteDraft, 'Bom treino');
      expect(resumed.active, isNotNull);
      final finished = await resumed.end(cancel: false);
      expect(finished!.skipped, 1);
      expect(finished.note, 'Bom treino');
      expect(resumed.active, isNull);
      expect((await gateway.history()).items, hasLength(1));
    },
  );
  test(
    'Cancelled sessions stay out of history; completed sessions are immutable',
    () async {
      final gateway = PreviewSessionGateway();
      final store = SessionStore(gateway);
      addTearDown(store.dispose);
      await store.start(plan());
      expect((await store.end(cancel: true))!.status, SessionStatus.cancelled);
      expect((await gateway.history()).items, isEmpty);
      await store.start(plan());
      await store.record(store.active!.sets.first, SetStatus.completed, 0);
      final finished = await store.end(cancel: false);
      await expectLater(
        gateway.record(finished!.id, finished.sets.first.id, SetStatus.pending),
        throwsA(isA<SessionFailure>()),
      );
    },
  );
  test('Rest uses an absolute deadline and survives delayed ticks', () {
    var now = DateTime(2026, 10, 2, 10);
    final store = SessionStore(PreviewSessionGateway(), now: () => now);
    addTearDown(store.dispose);
    store.startRest(90);
    now = now.add(const Duration(seconds: 65));
    expect(store.remainingRest, 25);
    now = now.add(const Duration(minutes: 5));
    expect(store.remainingRest, 0);
    store.startRest(store.lastRestSeconds);
    expect(store.remainingRest, 90);
    store.skipRest();
    expect(store.remainingRest, 0);
  });
  test(
    'History pagination is bounded and does not duplicate sessions',
    () async {
      final gateway = PreviewSessionGateway();
      for (var i = 0; i < 3; i++) {
        final session = await gateway.start('$i', plan());
        await gateway.record(
          session.id,
          session.sets.first.id,
          SetStatus.completed,
          reps: 10,
          weight: 1,
        );
        await gateway.finish(session.id, '');
      }
      final first = await gateway.history(page: 1, pageSize: 2);
      final second = await gateway.history(page: 2, pageSize: 2);
      expect(first.hasMore, isTrue);
      expect(second.hasMore, isFalse);
      expect({
        ...first.items.map((s) => s.id),
        ...second.items.map((s) => s.id),
      }, hasLength(3));
    },
  );
  test('Rapid start taps trigger only one request', () async {
    final gateway = SlowGateway();
    final store = SessionStore(gateway);
    addTearDown(store.dispose);
    final first = store.start(plan());
    final second = await store.start(plan());
    expect(second, isNull);
    gateway.ready.complete();
    await first;
    expect(gateway.calls, 1);
  });
}

class SlowGateway extends PreviewSessionGateway {
  final ready = Completer<void>();
  int calls = 0;
  @override
  Future<TrainingSession> start(String id, WorkoutPlan plan) async {
    calls++;
    await ready.future;
    return super.start(id, plan);
  }
}

class LostStartGateway extends PreviewSessionGateway {
  bool fail = true;
  @override
  Future<TrainingSession> start(String id, WorkoutPlan plan) async {
    final session = await super.start(id, plan);
    if (fail) {
      fail = false;
      throw const SessionFailure('Resposta perdida.');
    }
    return session;
  }
}
