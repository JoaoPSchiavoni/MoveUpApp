import 'exercise_details.dart';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../domain/workout_gateway.dart';
import 'workout_home.dart' show WorkoutSummary;

class WorkoutEditor extends StatefulWidget {
  const WorkoutEditor({super.key, required this.gateway, this.initial});
  final WorkoutGateway gateway;
  final WorkoutPlan? initial;
  @override
  State<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends State<WorkoutEditor> {
  final form = GlobalKey<FormState>();
  final configuration = GlobalKey<FormState>();
  late final TextEditingController name = TextEditingController(
    text: widget.initial?.name,
  );
  late final TextEditingController description = TextEditingController(
    text: widget.initial?.description,
  );
  late int? weekday = widget.initial?.weekday;
  late final String id = widget.initial?.id ?? const Uuid().v4();
  final selected = <ExerciseDraft>[];
  List<ExerciseOption> exercises = [];
  bool selectionInvalid = false;
  String query = '';
  String group = 'Todos';
  int step = 0;
  bool loading = true;
  bool saving = false;
  bool changed = false;
  String? error;
  @override
  void initState() {
    super.initState();
    for (final item in widget.initial?.items ?? <WorkoutItem>[]) {
      selected.add(ExerciseDraft(item.exercise, item));
    }
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.gateway.loadExercises();
      if (mounted) setState(() => exercises = result);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Não foi possível carregar os exercícios.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    for (final item in selected) {
      item.dispose();
    }
    super.dispose();
  }

  WorkoutPlan get plan => WorkoutPlan(
    id: id,
    name: name.text.trim(),
    weekday: weekday!,
    description: description.text.trim(),
    active: widget.initial?.active ?? true,
    items: selected.map((item) => item.toItem()).toList(),
  );
  Future<void> next() async {
    if (step == 0 && !form.currentState!.validate()) return;
    if (step == 1 && selected.isEmpty) {
      setState(() => selectionInvalid = true);
      return;
    }
    if (step == 2 && !configuration.currentState!.validate()) return;
    if (step < 3) {
      setState(() => step++);
      return;
    }
    setState(() => saving = true);
    try {
      await widget.gateway.saveWorkout(plan);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar. Seus dados continuam aqui.',
            ),
          ),
        );
      }
    }
  }

  Future<void> leave() async {
    if (saving) return;
    if (step > 0) {
      setState(() => step--);
      return;
    }
    if (changed) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Descartar alterações?'),
          content: const Text(
            'As alterações deste treino ainda não foram salvas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Widget metadata() => Form(
    key: form,
    onChanged: () => changed = true,
    child: Column(
      children: [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Nome do treino',
            hintText: 'Ex.: Peito + Tríceps',
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Informe o nome do treino.'
              : null,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<int>(
          initialValue: weekday,
          decoration: const InputDecoration(labelText: 'Dia da semana'),
          items: List.generate(
            7,
            (i) => DropdownMenuItem(value: i + 1, child: Text(weekdays[i])),
          ),
          onChanged: (value) {
            changed = true;
            setState(() => weekday = value);
          },
          validator: (value) =>
              value == null ? 'Escolha um dia da semana.' : null,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: description,
          decoration: const InputDecoration(
            labelText: 'Descrição (opcional)',
            hintText: 'Observações sobre sua ficha',
          ),
          minLines: 3,
          maxLines: 5,
        ),
      ],
    ),
  );
  Widget selection() {
    final groups = {'Todos', ...exercises.map((e) => e.group)};
    final filtered = exercises
        .where(
          (e) =>
              (group == 'Todos' || e.group == group) &&
              e.name.toLowerCase().contains(query.toLowerCase().trim()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar exercício',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: groups
              .map(
                (g) => ChoiceChip(
                  label: Text(g),
                  selected: group == g,
                  onSelected: (_) => setState(() => group = g),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Text('${selected.length} exercícios selecionados'),
        if (selectionInvalid && selected.isEmpty)
          Text(
            'Selecione pelo menos um exercício.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nenhum exercício encontrado. Tente outra busca.'),
          ),
        for (final exercise in filtered)
          Card(
            child: CheckboxListTile(
              title: InkWell(
                onTap: () => openExercise(context, exercise),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(exercise.name),
                ),
              ),
              secondary: IconButton(
                tooltip: 'Detalhes do exercício',
                icon: const Icon(Icons.info_outline),
                onPressed: () => openExercise(context, exercise),
              ),
              subtitle: Text(exercise.group),
              value: selected.any((e) => e.exercise.id == exercise.id),
              onChanged: (value) => setState(() {
                changed = true;
                if (value == true) {
                  selected.add(ExerciseDraft(exercise));
                } else {
                  final index = selected.indexWhere(
                    (e) => e.exercise.id == exercise.id,
                  );
                  selected.removeAt(index).dispose();
                }
              }),
            ),
          ),
      ],
    );
  }

  Widget numeric(
    TextEditingController controller,
    String label, {
    bool decimal = false,
    bool positive = false,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    onChanged: (_) => changed = true,
    validator: (value) {
      final normalized = (value ?? '').trim().replaceAll(',', '.');
      final number = decimal
          ? double.tryParse(normalized)
          : int.tryParse(normalized);
      if (number == null ||
          !number.isFinite ||
          (positive ? number <= 0 : number < 0)) {
        return positive
            ? 'Informe um valor maior que zero.'
            : 'Informe um valor válido (zero ou mais).';
      }
      return null;
    },
  );
  Widget configure() => Form(
    key: configuration,
    child: Column(
      children: [
        for (var i = 0; i < selected.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${i + 1}. ${selected[i].exercise.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Detalhes do exercício',
                        icon: const Icon(Icons.info_outline),
                        onPressed: () =>
                            openExercise(context, selected[i].exercise),
                      ),
                      IconButton(
                        tooltip: 'Mover para cima',
                        onPressed: i == 0
                            ? null
                            : () => setState(() {
                                changed = true;
                                final item = selected.removeAt(i);
                                selected.insert(i - 1, item);
                              }),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: 'Mover para baixo',
                        onPressed: i == selected.length - 1
                            ? null
                            : () => setState(() {
                                changed = true;
                                final item = selected.removeAt(i);
                                selected.insert(i + 1, item);
                              }),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      IconButton(
                        tooltip: 'Remover exercício',
                        onPressed: () => setState(() {
                          changed = true;
                          selected.removeAt(i).dispose();
                          if (selected.isEmpty) step = 1;
                        }),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth > 520
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: width,
                            child: numeric(
                              selected[i].sets,
                              'Séries',
                              positive: true,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: numeric(
                              selected[i].reps,
                              'Repetições',
                              positive: true,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: numeric(
                              selected[i].weight,
                              'Carga inicial (kg)',
                              decimal: true,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: numeric(
                              selected[i].rest,
                              'Descanso (segundos)',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    const labels = [
      'Dados do treino',
      'Selecionar exercícios',
      'Configurar exercícios',
      'Revisar e salvar',
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: saving ? null : leave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(widget.initial == null ? 'Novo treino' : 'Editar treino'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PASSO ${step + 1} DE 4',
                        style: const TextStyle(letterSpacing: 2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[step],
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: (step + 1) / 4),
                    ],
                  ),
                ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(error!),
                              TextButton(
                                onPressed: load,
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            if (step == 0) metadata(),
                            if (step == 1) selection(),
                            if (step == 2) configure(),
                            if (step == 3) WorkoutSummary(workout: plan),
                          ],
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        if (step > 0)
                          TextButton(
                            onPressed: saving ? null : leave,
                            child: const Text('Voltar'),
                          ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: saving || loading || error != null
                              ? null
                              : next,
                          icon: Icon(
                            step == 3 ? Icons.check : Icons.arrow_forward,
                          ),
                          label: Text(
                            saving
                                ? 'Salvando...'
                                : step == 3
                                ? 'Salvar treino'
                                : 'Continuar',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExerciseDraft {
  ExerciseDraft(this.exercise, [WorkoutItem? item])
    : sets = TextEditingController(text: '${item?.sets ?? 3}'),
      reps = TextEditingController(text: '${item?.reps ?? 10}'),
      weight = TextEditingController(text: '${item?.weight ?? 0}'),
      rest = TextEditingController(text: '${item?.restSeconds ?? 90}');
  final ExerciseOption exercise;
  final TextEditingController sets, reps, weight, rest;
  WorkoutItem toItem() => WorkoutItem(
    exercise: exercise,
    sets: int.parse(sets.text.trim()),
    reps: int.parse(reps.text.trim()),
    weight: double.parse(weight.text.trim().replaceAll(',', '.')),
    restSeconds: int.parse(rest.text.trim()),
  );
  void dispose() {
    sets.dispose();
    reps.dispose();
    weight.dispose();
    rest.dispose();
  }
}
