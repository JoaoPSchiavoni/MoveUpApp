import 'package:flutter/material.dart';

import '../domain/session.dart';

String sessionDate(DateTime time) {
  final date = time.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(date.day)}/${pad(date.month)}/${date.year} às ${pad(date.hour)}:${pad(date.minute)}';
}

String sessionDuration(TrainingSession session) {
  final duration = (session.endedAt ?? session.startedAt).difference(
    session.startedAt,
  );
  final minutes = duration.inMinutes.clamp(0, 999999);
  return minutes < 1
      ? 'Menos de 1 min'
      : minutes < 60
      ? '$minutes min'
      : '${minutes ~/ 60}h ${minutes % 60}min';
}

String number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1).replaceAll('.', ',');

class SessionSummaryPage extends StatelessWidget {
  const SessionSummaryPage({super.key, required this.session});
  final TrainingSession session;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Resumo do treino')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.task_alt,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                session.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(sessionDate(session.startedAt)),
              const SizedBox(height: 24),
              _SummaryMetrics(session: session),
              if (session.note.isNotEmpty) ...[
                const SizedBox(height: 20),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Observação',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(session.note),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Detalhes dos exercícios',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final exercise in session.exercises)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(exercise.group),
                        for (final set in exercise.sets)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              set.status == SetStatus.completed
                                  ? Icons.check_circle_outline
                                  : Icons.skip_next_outlined,
                            ),
                            title: Text(
                              'Série ${set.order + 1} · ${set.status == SetStatus.completed ? '${set.reps} reps × ${number(set.weight ?? 0)} kg' : 'Pulada'}',
                            ),
                            subtitle: Text(
                              'Planejado: ${set.plannedReps} reps × ${number(set.plannedWeight)} kg',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SummaryMetrics extends StatelessWidget {
  const _SummaryMetrics({required this.session});
  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _SummaryMetric(
        label: 'Exercícios realizados',
        value: '${session.exercisesDone}',
        icon: Icons.fitness_center,
      ),
      _SummaryMetric(
        label: 'Séries concluídas',
        value: '${session.completed}',
        icon: Icons.check_circle_outline,
      ),
      _SummaryMetric(
        label: 'Séries puladas',
        value: '${session.skipped}',
        icon: Icons.skip_next_outlined,
      ),
      _SummaryMetric(
        label: 'Volume registrado',
        value: '${number(session.volume)} kg',
        icon: Icons.monitor_weight_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final twoColumns = constraints.maxWidth >= 312 * textScale;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryMetric(
              label: 'Duração',
              value: sessionDuration(session),
              icon: Icons.timer_outlined,
            ),
            const SizedBox(height: 12),
            if (twoColumns)
              for (var i = 0; i < metrics.length; i += 2) ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: metrics[i]),
                      const SizedBox(width: 12),
                      Expanded(child: metrics[i + 1]),
                    ],
                  ),
                ),
                if (i + 2 < metrics.length) const SizedBox(height: 12),
              ]
            else
              for (var i = 0; i < metrics.length; i++) ...[
                metrics[i],
                if (i + 1 < metrics.length) const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('summary-$label'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 22,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    ),
  );
}
