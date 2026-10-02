import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/local_gateways.dart';
import '../data/exercise_catalog.dart';
import '../domain/workout_gateway.dart';

class WorkoutTemplate {
  const WorkoutTemplate(this.name, this.description, this.groups, this.days);
  final String name, description;
  final List<List<int>> groups;
  final List<int> days;
}

const workoutTemplates = [
  WorkoutTemplate(
    'ABC',
    'A • Peito e tríceps\nB • Costas e bíceps\nC • Pernas e ombros',
    [
      [0, 1, 2, 9],
      [3, 4, 8],
      [5, 6, 7, 10],
    ],
    [1, 3, 5],
  ),
  WorkoutTemplate(
    'Superior / Inferior',
    'Dois treinos para alternar membros superiores e inferiores.',
    [
      [0, 3, 4, 8, 9, 10],
      [5, 6, 7, 11],
    ],
    [2, 5],
  ),
  WorkoutTemplate(
    'Corpo inteiro',
    'Uma ficha com os principais grupos musculares.',
    [
      [0, 3, 5, 10, 11],
    ],
    [1],
  ),
];

class WorkoutTemplatesPage extends StatefulWidget {
  const WorkoutTemplatesPage({super.key, required this.gateway});
  final WorkoutGateway gateway;
  @override
  State<WorkoutTemplatesPage> createState() => _WorkoutTemplatesPageState();
}

class _WorkoutTemplatesPageState extends State<WorkoutTemplatesPage> {
  int selection = 0;
  late List<int> days = List.of(workoutTemplates.first.days);
  bool saving = false;
  String? error;
  List<WorkoutPlan>? pending;
  Future<void> add() async {
    final template = workoutTemplates[selection];
    setState(() => saving = true);
    try {
      final existing = await widget.gateway.loadWorkouts();
      if (existing.any(
            (w) => w.description.startsWith('Modelo ${template.name}.'),
          ) &&
          mounted &&
          pending == null) {
        final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Adicionar outra cópia?'),
            content: const Text(
              'Você já tem uma ficha deste modelo. Uma nova cópia terá seus próprios exercícios e dias.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Adicionar'),
              ),
            ],
          ),
        );
        if (yes != true) return;
      }
      final catalog = await widget.gateway.loadExercises();
      pending ??= [
        for (var n = 0; n < template.groups.length; n++)
          WorkoutPlan(
            id: const Uuid().v4(),
            name: '${template.name} • ${String.fromCharCode(65 + n)}',
            weekday: days[n],
            description:
                'Modelo ${template.name}. Ajuste as séries, cargas e repetições ao seu nível.',
            items: [
              for (final index in template.groups[n])
                WorkoutItem(
                  exercise: catalog.firstWhere(
                    (e) =>
                        e.id == exerciseCatalog[index].id ||
                        e.name == exerciseCatalog[index].name,
                  ),
                  sets: 3,
                  reps: 10,
                  weight: 0,
                  restSeconds: 60,
                ),
            ],
          ),
      ];
      if (widget.gateway case final LocalWorkoutGateway local) {
        await local.saveBatch(pending!);
      } else {
        for (final w in pending!) {
          await widget.gateway.saveWorkout(w);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Não foi possível adicionar. Tente novamente para concluir as mesmas fichas.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = workoutTemplates[selection];
    return Scaffold(
      appBar: AppBar(title: const Text('Treinos prontos')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Escolha um ponto de partida',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cada modelo é copiado para sua biblioteca. Depois você pode editar tudo. As cargas começam em zero para você definir.',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: selection,
                decoration: const InputDecoration(labelText: 'Modelo'),
                items: [
                  for (var i = 0; i < workoutTemplates.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        workoutTemplates[i].name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: saving || pending != null
                    ? null
                    : (value) => setState(() {
                        selection = value!;
                        days = List.of(workoutTemplates[selection].days);
                        error = null;
                      }),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(template.description),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < template.groups.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        key: ValueKey('$selection/$i'),
                        initialValue: days[i],
                        decoration: InputDecoration(
                          labelText:
                              'Treino ${String.fromCharCode(65 + i)} • dia da semana',
                        ),
                        items: [
                          for (var d = 1; d <= 7; d++)
                            DropdownMenuItem(
                              value: d,
                              child: Text(
                                weekdays[d - 1],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: saving || pending != null
                            ? null
                            : (d) => setState(() => days[i] = d!),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        template.groups[i]
                            .map((n) => exerciseCatalog[n].name)
                            .join(' · '),
                      ),
                      const Text('3 séries × 10 repetições · descanso de 60 s'),
                    ],
                  ),
                ),
              if (error != null) Text(error!),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: saving ? null : add,
                icon: const Icon(Icons.playlist_add),
                label: Text(
                  saving ? 'Adicionando…' : 'Adicionar à minha biblioteca',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
