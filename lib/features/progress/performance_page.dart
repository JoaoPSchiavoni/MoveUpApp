import 'package:flutter/material.dart';

import '../session/domain/session.dart';
import '../consistency/domain/consistency.dart';
import 'progress_chart.dart';

class ExercisePerformance {
  ExercisePerformance(this.session, this.exercise);
  final TrainingSession session;
  final SessionExercise exercise;
  List<SessionSet> get sets =>
      exercise.sets.where((s) => s.status == SetStatus.completed).toList();
  double get volume => sets.fold(0, (v, s) => v + s.weight! * s.reps!);
  double get peak => sets.map((s) => s.weight!).reduce((a, b) => a > b ? a : b);
}

class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key, required this.gateway});
  final SessionGateway gateway;
  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  late final Future<List<TrainingSession>> history = load();
  String? selected;
  String metric = 'peak';
  Future<List<TrainingSession>> load() async {
    final all = <TrainingSession>[];
    for (var p = 1; ; p++) {
      final result = await widget.gateway.history(page: p, pageSize: 100);
      all.addAll(result.items);
      if (!result.hasMore) break;
    }
    return all..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sua evolução')),
    body: FutureBuilder(
      future: history,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Não foi possível carregar os gráficos.'),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PerformancePage(gateway: widget.gateway),
                    ),
                  ),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = <String, List<ExercisePerformance>>{};
        for (final s in snapshot.data!) {
          for (final e in s.exercises) {
            if (e.sets.any((x) => x.status == SetStatus.completed)) {
              groups
                  .putIfAbsent(e.originId ?? 'snapshot:${e.id}', () => [])
                  .add(ExercisePerformance(s, e));
            }
          }
        }
        if (groups.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Conclua seu primeiro treino para acompanhar carga, repetições e volume.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        selected ??= groups.keys.first;
        final records = groups[selected]!,
            recent = records
                .skip((records.length - 4).clamp(0, records.length))
                .toList();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Compare seus últimos 4 treinos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Exercício'),
                  items: [
                    for (final entry in groups.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          '${entry.value.last.exercise.name}${entry.key.startsWith('snapshot:') ? ' • registro histórico ${shortDate(entry.value.last.session.startedAt.toLocal())}' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => selected = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: metric,
                  decoration: const InputDecoration(labelText: 'Comparar'),
                  items: const [
                    DropdownMenuItem(
                      value: 'peak',
                      child: Text(
                        'Maior carga realizada (kg)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'volume',
                      child: Text(
                        'Volume realizado (kg × repetições)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => metric = v!),
                ),
                const SizedBox(height: 16),
                ProgressChart(
                  points: [
                    for (var i = 0; i < recent.length; i++)
                      ChartPoint(
                        (i + 1).toDouble(),
                        metric == 'peak' ? recent[i].peak : recent[i].volume,
                        'Treino ${i + 1} • ${recent[i].session.localDate ?? shortDate(recent[i].session.startedAt.toLocal())}',
                      ),
                  ],
                  xLabel: 'Treino em ordem cronológica',
                  yLabel: metric == 'peak'
                      ? 'Maior carga (kg)'
                      : 'Volume (kg × repetições)',
                ),
                const SizedBox(height: 12),
                ProgressChart(
                  connect: false,
                  points: [
                    for (var i = 0; i < recent.length; i++)
                      for (final s in recent[i].sets)
                        ChartPoint(
                          s.reps!.toDouble(),
                          s.weight!,
                          'Treino ${i + 1} • série ${s.order + 1}',
                        ),
                  ],
                  xLabel: 'Repetições',
                  yLabel: 'Carga (kg)',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mais carga com menos repetições não significa, por si só, melhora. Compare também repetições, número de séries e volume. Os pontos do gráfico mostram as séries realmente concluídas.',
                ),
                if (selected!.startsWith('snapshot:'))
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Este registro antigo não tem a identificação do exercício original. Ele é exibido separadamente para evitar misturar exercícios apenas pelo nome.',
                    ),
                  ),
                const SizedBox(height: 16),
                for (var i = 0; i < recent.length; i++)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(
                        recent[i].session.localDate ??
                            shortDate(recent[i].session.startedAt.toLocal()),
                      ),
                      subtitle: Text(
                        recent[i].sets
                            .map((s) => '${s.reps} × ${s.weight} kg')
                            .join(' • '),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
