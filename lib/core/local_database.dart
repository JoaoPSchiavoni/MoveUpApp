import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

class MoveUpDatabase extends GeneratedDatabase {
  MoveUpDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'moveup_personal',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE records (kind TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL CHECK(json_valid(payload)), PRIMARY KEY(kind,id))',
      );
      await customStatement(
        "CREATE UNIQUE INDEX one_active_session ON records(kind) WHERE kind='session' AND json_extract(payload,'\$.status')='active'",
      );
    },
    onUpgrade: (_, from, to) async {
      throw StateError(
        'Migração de banco $from → $to não suportada. Os dados foram preservados.',
      );
    },
  );
  Future<List<Map<String, dynamic>>> records(String kind) async =>
      (await customSelect(
            'SELECT payload FROM records WHERE kind=? ORDER BY id',
            variables: [Variable(kind)],
          ).get())
          .map(
            (r) => Map<String, dynamic>.from(
              jsonDecode(r.read<String>('payload')) as Map,
            ),
          )
          .toList();
  Future<Map<String, dynamic>?> record(String kind, String id) async {
    final row = await customSelect(
      'SELECT payload FROM records WHERE kind=? AND id=?',
      variables: [Variable(kind), Variable(id)],
    ).getSingleOrNull();
    return row == null
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(row.read<String>('payload')) as Map,
          );
  }

  Future<void> put(String kind, String id, Map<String, dynamic> value) =>
      customStatement(
        'INSERT INTO records(kind,id,payload) VALUES (?,?,?) ON CONFLICT(kind,id) DO UPDATE SET payload=excluded.payload',
        [kind, id, jsonEncode(value)],
      );
  Future<void> remove(String kind, String id) =>
      customStatement('DELETE FROM records WHERE kind=? AND id=?', [kind, id]);
}

class LocalData extends ChangeNotifier {
  LocalData(this.db);
  final MoveUpDatabase db;
  bool disposed = false;
  Future<T> change<T>(Future<T> Function() action) async {
    final result = await db.transaction(action);
    if (!disposed) notifyListeners();
    return result;
  }

  Future<String> exportBackup() async => db.transaction(() async {
    final rows = await db
        .customSelect('SELECT kind,id,payload FROM records ORDER BY kind,id')
        .get();
    return jsonEncode({
      'format': 'moveup-backup',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'records': rows
          .map(
            (r) => {
              'kind': r.read<String>('kind'),
              'id': r.read<String>('id'),
              'value': jsonDecode(r.read<String>('payload')),
            },
          )
          .toList(),
    });
  });
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
