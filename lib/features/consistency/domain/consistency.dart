String dateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
String shortDate(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';

class RoutineRevision {
  RoutineRevision(Map<String, dynamic> json)
    : start = DateTime.parse(json['inicio'] as String),
      days = List<int>.from(json['diasSemana'] as List);
  final DateTime start;
  final List<int> days;
}

class GoalRevision {
  GoalRevision(Map<String, dynamic> json)
    : start = DateTime.parse(json['inicio'] as String),
      days = json['dias'] as int;
  final DateTime start;
  final int days;
}

class ConsistencyConfig {
  ConsistencyConfig(Map<String, dynamic> json)
    : enabled = json['ativado'] as bool,
      zone = json['fuso'] as String,
      today = DateTime.parse(json['hoje'] as String),
      routines = (json['rotinas'] as List)
          .map((r) => RoutineRevision(Map<String, dynamic>.from(r as Map)))
          .toList(),
      goals = (json['metas'] as List)
          .map((g) => GoalRevision(Map<String, dynamic>.from(g as Map)))
          .toList();
  final bool enabled;
  final String zone;
  final DateTime today;
  final List<RoutineRevision> routines;
  final List<GoalRevision> goals;
}

class ConsistencyWeek {
  ConsistencyWeek(Map<String, dynamic> json)
    : start = DateTime.parse(json['inicio'] as String),
      end = DateTime.parse(json['fim'] as String),
      days = json['diasTreinados'] as int,
      sessions = json['sessoes'] as int,
      goal = json['meta'] as int?,
      planned = json['planejadosEncerrados'] as int,
      fulfilled = json['planejadosCumpridos'] as int,
      adherence = (json['adesao'] as num?)?.toDouble(),
      seconds = (json['duracaoSegundos'] as num).toDouble(),
      volume = (json['volume'] as num).toDouble();
  final DateTime start, end;
  final int days, sessions, planned, fulfilled;
  final int? goal;
  final double? adherence;
  final double seconds, volume;
}

class ConsistencyPanel {
  ConsistencyPanel(Map<String, dynamic> json)
    : today = DateTime.parse(json['hoje'] as String),
      zone = json['fuso'] as String,
      enabled = json['ativado'] as bool,
      streak = json['sequenciaAtual'] as int,
      best = json['melhorSequencia'] as int,
      monthDays = json['diasTreinadosMes'] as int,
      week = ConsistencyWeek(Map<String, dynamic>.from(json['semana'] as Map));
  final DateTime today;
  final String zone;
  final bool enabled;
  final int streak, best, monthDays;
  final ConsistencyWeek week;
}

class DaySession {
  DaySession(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['nomeTreino'] as String;
  final String id, name;
}

class CalendarDay {
  CalendarDay(Map<String, dynamic> json)
    : date = DateTime.parse(json['data'] as String),
      state = json['estado'] as String,
      planned = json['planejado'] as bool,
      sessions = (json['sessoes'] as List)
          .map((s) => DaySession(Map<String, dynamic>.from(s as Map)))
          .toList();
  final DateTime date;
  final String state;
  final bool planned;
  final List<DaySession> sessions;
  String get label => switch (state) {
    'treinado' => 'Treinado',
    'falta' => 'Falta',
    'descanso' => 'Descanso',
    'planejadoHoje' => 'Planejado para hoje',
    'planejadoFuturo' => 'Planejado',
    _ => 'Sem planejamento histórico',
  };
}

class ConsistencyFailure implements Exception {
  const ConsistencyFailure(this.message);
  final String message;
}

abstract class ConsistencyGateway {
  Future<ConsistencyConfig> config();
  Future<ConsistencyConfig> configure(String zone, List<int> days, int goal);
  Future<ConsistencyPanel> panel();
  Future<List<CalendarDay>> calendar(DateTime month);
  Future<ConsistencyWeek> week(DateTime start);
}
