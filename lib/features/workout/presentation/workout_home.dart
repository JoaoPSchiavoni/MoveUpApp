import 'package:flutter/material.dart';

import '../domain/workout_gateway.dart';
import 'workout_editor.dart';

class WorkoutHome extends StatefulWidget {
  const WorkoutHome({super.key, required this.gateway});
  final WorkoutGateway gateway;
  @override
  State<WorkoutHome> createState() => _WorkoutHomeState();
}

class _WorkoutHomeState extends State<WorkoutHome> {
  List<WorkoutPlan> workouts = [];
  bool loading = true;
  String? error;
  int tab = 0;
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.gateway.loadWorkouts();
      result.sort((a, b) => a.weekday.compareTo(b.weekday));
      if (mounted) setState(() => workouts = result);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Não foi possível carregar os treinos.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([WorkoutPlan? workout]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            WorkoutEditor(gateway: widget.gateway, initial: workout),
      ),
    );
    if (saved == true && mounted) {
      await reload();
    }
  }

  Future<void> details(WorkoutPlan workout) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            WorkoutDetails(gateway: widget.gateway, workout: workout),
      ),
    );
    if (changed == true && mounted) await reload();
  }

  Widget card(WorkoutPlan workout) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
      title: Text(
        workout.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${weekdays[workout.weekday - 1]} · ${workout.items.length} exercícios',
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => details(workout),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final today = workouts
        .where((w) => w.weekday == DateTime.now().weekday)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MoveUp',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!),
                      TextButton(
                        onPressed: reload,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                    children: [
                      Text(
                        tab == 0
                            ? 'Seu próximo passo começa aqui.'
                            : 'Meus treinos',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tab == 0
                            ? 'Organize sua rotina. Treine no seu ritmo.'
                            : 'Suas fichas, organizadas por dia da semana.',
                      ),
                      const SizedBox(height: 28),
                      if (tab == 0) ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xff193f32),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TREINO DE HOJE',
                                style: TextStyle(
                                  color: Color(0xffb8e5c6),
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                weekdays[DateTime.now().weekday - 1],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (today.isEmpty)
                                const Text(
                                  'Nenhum treino definido para hoje.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              for (final workout in today)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: FilledButton.tonal(
                                    onPressed: () => details(workout),
                                    child: Text(workout.name),
                                  ),
                                ),
                              if (today.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: FilledButton.tonal(
                                    onPressed: () => edit(),
                                    child: const Text('Criar treino'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Seus treinos',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (workouts.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Sua rotina começa com o primeiro treino.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: () => edit(),
                                  child: const Text(
                                    'Criar meu primeiro treino',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ...workouts.map(card),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Novo treino'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Meus treinos',
          ),
        ],
      ),
    );
  }
}

class WorkoutDetails extends StatefulWidget {
  const WorkoutDetails({
    super.key,
    required this.gateway,
    required this.workout,
  });
  final WorkoutGateway gateway;
  final WorkoutPlan workout;
  @override
  State<WorkoutDetails> createState() => _WorkoutDetailsState();
}

class _WorkoutDetailsState extends State<WorkoutDetails> {
  bool deleting = false;
  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir treino?'),
        content: Text('Deseja excluir “${widget.workout.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => deleting = true);
    try {
      await widget.gateway.deleteWorkout(widget.workout.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível excluir. Tente novamente.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalhes do treino')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            WorkoutSummary(workout: widget.workout),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: deleting
                  ? null
                  : () async {
                      final saved = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => WorkoutEditor(
                            gateway: widget.gateway,
                            initial: widget.workout,
                          ),
                        ),
                      );
                      if (saved == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar treino'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: deleting ? null : delete,
              icon: const Icon(Icons.delete_outline),
              label: Text(deleting ? 'Excluindo...' : 'Excluir treino'),
            ),
          ],
        ),
      ),
    ),
  );
}

class WorkoutSummary extends StatelessWidget {
  const WorkoutSummary({super.key, required this.workout});
  final WorkoutPlan workout;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        workout.name,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(weekdays[workout.weekday - 1]),
      if (workout.description.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(workout.description),
        ),
      const SizedBox(height: 24),
      for (var index = 0; index < workout.items.length; index++)
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(workout.items[index].exercise.name),
            subtitle: Text(
              '${workout.items[index].sets} séries × ${workout.items[index].reps} repetições\n${workout.items[index].weight} kg · ${workout.items[index].restSeconds}s de descanso',
            ),
            isThreeLine: true,
          ),
        ),
    ],
  );
}
