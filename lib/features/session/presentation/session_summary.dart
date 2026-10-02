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
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.task_alt, size: 56, color: Color(0xff236b50)),
            const SizedBox(height: 16),
            Text(
              session.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(sessionDate(session.startedAt)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Duração', sessionDuration(session)),
                _metric('Exercícios realizados', '${session.exercisesDone}'),
                _metric('Séries concluídas', '${session.completed}'),
                _metric('Séries puladas', '${session.skipped}'),
                _metric('Volume registrado', '${number(session.volume)} kg'),
              ],
            ),
            if (session.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Observação: ${session.note}'),
              ),
            const SizedBox(height: 24),
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
  );
  Widget _metric(String label, String value) => Container(
    width: 190,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xffe1eee4),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    ),
  );
}
