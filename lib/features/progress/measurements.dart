import '../../core/local_database.dart';
import '../../core/local_gateways.dart';
import '../consistency/domain/consistency.dart';

const measurementFields = {
  'weight': 'Peso (kg)',
  'waist': 'Cintura (cm)',
  'hips': 'Quadril (cm)',
  'chest': 'Peitoral (cm)',
  'arm': 'Braço (cm)',
  'thigh': 'Coxa (cm)',
  'calf': 'Panturrilha (cm)',
};
String monthKey(DateTime day) => dateKey(day).substring(0, 7);

class MeasurementStore {
  MeasurementStore(this.data, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final LocalData data;
  final DateTime Function() now;
  Future<DateTime> today() async => localDay(
    now(),
    (await data.db.record('preference', 'consistency'))?['fuso'] as String? ??
        'America/Sao_Paulo',
  );
  Future<List<Map<String, dynamic>>> all() => data.db.records('measurement');
  static void validate(String id, Map<String, dynamic> record) {
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(id) ||
        record['month'] != id ||
        record['values'] is! Map) {
      throw const FormatException('Registro mensal inválido.');
    }
    DateTime.parse(record['updatedAt'] as String);
    final values = record['values'] as Map;
    if (values.isEmpty ||
        values.keys.any((k) => !measurementFields.containsKey(k)) ||
        values.values.any(
          (v) => v is! num || !v.isFinite || v <= 0 || v > 1000,
        )) {
      throw const FormatException(
        'Informe pelo menos uma medida entre 0 e 1000.',
      );
    }
  }

  Future<void> save(String month, Map<String, double> values) async {
    if (month != monthKey(await today())) {
      throw const FormatException(
        'Novas medidas só podem ser registradas no mês atual.',
      );
    }
    final record = {
      'month': month,
      'values': values,
      'updatedAt': now().toUtc().toIso8601String(),
    };
    validate(month, record);
    await data.change(() => data.db.put('measurement', month, record));
  }
}
