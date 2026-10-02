import 'dart:async';

import 'package:flutter/material.dart';

import '../../workout/domain/workout_gateway.dart';
import '../domain/session.dart';
import 'session_store.dart';
import 'session_summary.dart';

Future<void> openActiveSession(BuildContext context, SessionStore store) async {
  if (store.active == null) return;
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => SessionPageView(store: store)));
}

class StartSessionButton extends StatelessWidget {
  const StartSessionButton({
    super.key,
    required this.store,
    required this.plan,
  });
  final SessionStore store;
  final WorkoutPlan plan;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => FilledButton.icon(
      onPressed: store.busy || store.loading
          ? null
          : () async {
              final session = await store.start(plan);
              if (!context.mounted) return;
              if (session != null && session.status == SessionStatus.active) {
                await openActiveSession(context, store);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      store.error ?? 'Esta sessão já foi encerrada. Tente iniciar novamente.',
                    ),
                  ),
                );
              }
            },
      icon: const Icon(Icons.play_arrow),
      label: Text(
        store.busy
            ? 'Aguarde...'
            : store.active == null
            ? 'Iniciar treino'
            : 'Continuar treino',
      ),
    ),
  );
}

class ActiveSessionBanner extends StatelessWidget {
  const ActiveSessionBanner({super.key, required this.store});
  final SessionStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      if (store.loading) return const LinearProgressIndicator();
      if (store.active != null) {
        return Card(
          color: const Color(0xffe1eee4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TREINO EM ANDAMENTO'),
                Text(
                  store.active!.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${store.active!.completed} de ${store.active!.sets.length} séries concluídas',
                ),
                FilledButton.icon(
                  onPressed: store.busy
                      ? null
                      : () => openActiveSession(context, store),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Continuar treino'),
                ),
              ],
            ),
          ),
        );
      }
      if (store.error != null) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.error!),
                TextButton(
                  onPressed: store.refresh,
                  child: const Text('Verificar treino em andamento'),
                ),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    },
  );
}

class SessionPageView extends StatefulWidget {
  const SessionPageView({super.key, required this.store});
  final SessionStore store;
  @override
  State<SessionPageView> createState() => _SessionPageViewState();
}

class _SessionPageViewState extends State<SessionPageView> {
  int exerciseIndex = 0;
  SessionStore get store => widget.store;
  Future<void> finish() async {
    final session = store.active!;
    if (session.completed == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _FinishDialog(store: store, session: session),
    );
    if (confirmed != true || !mounted) return;
    final ended = await store.end(cancel: false);
    if (ended != null && mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SessionSummaryPage(session: ended)),
      );
    }
  }

  Future<void> cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar este treino?'),
        content: const Text(
          'A sessão será encerrada como cancelada e não aparecerá no histórico de treinos concluídos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar treinando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar treino'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ended = await store.end(cancel: true);
    if (ended != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final session = store.active;
      if (session == null) {
        return const Scaffold(body: Center(child: Text('Sessão encerrada.')));
      }
      final exercise = session.exercises.isEmpty
          ? null
          : session.exercises[exerciseIndex.clamp(
              0,
              session.exercises.length - 1,
            )];
      final resolved = session.completed + session.skipped;
      return Scaffold(
        appBar: AppBar(title: const Text('Treino em andamento')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  session.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${session.completed} concluídas · ${session.skipped} puladas · ${session.pending} pendentes',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: session.sets.isEmpty
                      ? 0
                      : resolved / session.sets.length,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Você pode sair desta tela e continuar o treino depois.',
                ),
                const SizedBox(height: 16),
                RestPanel(store: store),
                if (store.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        store.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (store.busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < session.exercises.length; i++)
                      ChoiceChip(
                        label: Text('${i + 1}. ${session.exercises[i].name}'),
                        selected: exerciseIndex == i,
                        onSelected: store.busy
                            ? null
                            : (_) => setState(() => exerciseIndex = i),
                      ),
                  ],
                ),
                if (exercise != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${exercise.group} · Descanso: ${exercise.restSeconds}s',
                  ),
                  const SizedBox(height: 12),
                  for (final set in exercise.sets)
                    _SetCard(
                      key: ValueKey(set.id),
                      set: set,
                      store: store,
                      restSeconds: exercise.restSeconds,
                    ),
                  if (exerciseIndex < session.exercises.length - 1)
                    OutlinedButton.icon(
                      onPressed: store.busy
                          ? null
                          : () => setState(() => exerciseIndex++),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Próximo exercício'),
                    ),
                ],
                const SizedBox(height: 24),
                if (session.completed == 0)
                  const Text(
                    'Conclua pelo menos uma série para finalizar o treino.',
                  ),
                FilledButton.icon(
                  onPressed: store.busy || session.completed == 0
                      ? null
                      : finish,
                  icon: const Icon(Icons.check),
                  label: const Text('Finalizar treino'),
                ),
                TextButton(
                  onPressed: store.busy ? null : cancel,
                  child: const Text('Cancelar treino'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SetCard extends StatefulWidget {
  const _SetCard({
    super.key,
    required this.set,
    required this.store,
    required this.restSeconds,
  });
  final SessionSet set;
  final SessionStore store;
  final int restSeconds;
  @override
  State<_SetCard> createState() => _SetCardState();
}

class _SetCardState extends State<_SetCard> {
  late final TextEditingController weight = TextEditingController(
    text: widget.store.draft(widget.set).weight,
  );
  late final TextEditingController reps = TextEditingController(
    text: widget.store.draft(widget.set).reps,
  );
  void changed(String _) {
    final draft = widget.store.draft(widget.set);
    draft.weight = weight.text;
    draft.reps = reps.text;
    draft.dirty = true;
  }

  Future<void> record(SetStatus status) async {
    // Copy the visible inputs before every retry; no optimistic completion.
    if (status == SetStatus.completed) changed('');
    await widget.store.record(widget.set, status, widget.restSeconds);
  }

  @override
  void dispose() {
    weight.dispose();
    reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Série ${set.order + 1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Planejado: ${set.plannedReps} repetições · ${number(set.plannedWeight)} kg',
            ),
            const SizedBox(height: 12),
            if (set.status == SetStatus.pending) ...[
              LayoutBuilder(
                builder: (context, box) {
                  final width = box.maxWidth >= 320
                      ? (box.maxWidth - 12) / 2
                      : box.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: TextField(
                          key: ValueKey('weight-${set.id}'),
                          controller: weight,
                          enabled: !widget.store.busy,
                          onChanged: changed,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Carga realizada (kg)',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: TextField(
                          key: ValueKey('reps-${set.id}'),
                          controller: reps,
                          enabled: !widget.store.busy,
                          onChanged: changed,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Repetições realizadas',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: widget.store.busy
                        ? null
                        : () => record(SetStatus.completed),
                    icon: const Icon(Icons.check),
                    label: const Text('Concluir série'),
                  ),
                  TextButton(
                    onPressed: widget.store.busy
                        ? null
                        : () => record(SetStatus.skipped),
                    child: const Text('Pular série'),
                  ),
                ],
              ),
            ] else ...[
              Text(
                set.status == SetStatus.completed
                    ? 'Salva · ${set.reps} reps × ${number(set.weight ?? 0)} kg'
                    : 'Série pulada',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: widget.store.busy
                    ? null
                    : () => record(SetStatus.pending),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Corrigir série'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RestPanel extends StatefulWidget {
  const RestPanel({super.key, required this.store});
  final SessionStore store;
  @override
  State<RestPanel> createState() => _RestPanelState();
}

class _RestPanelState extends State<RestPanel> with WidgetsBindingObserver {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.store.restEndsAt != null) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.store.lastRestSeconds == 0) return const SizedBox.shrink();
    final remaining = widget.store.remainingRest;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffe1eee4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            remaining == 0
                ? 'Pronto para a próxima série'
                : 'Descanso · ${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Wrap(
            spacing: 12,
            children: [
              if (remaining > 0)
                TextButton(
                  onPressed: widget.store.skipRest,
                  child: const Text('Pular descanso'),
                ),
              TextButton(
                onPressed: () =>
                    widget.store.startRest(widget.store.lastRestSeconds),
                child: const Text('Reiniciar descanso'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinishDialog extends StatefulWidget {
  const _FinishDialog({required this.store, required this.session});
  final SessionStore store;
  final TrainingSession session;
  @override
  State<_FinishDialog> createState() => _FinishDialogState();
}

class _FinishDialogState extends State<_FinishDialog> {
  late final controller = TextEditingController(text: widget.store.noteDraft);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Finalizar este treino?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.session.pending == 0
                ? 'Seu treino será salvo no histórico.'
                : '${widget.session.pending} séries pendentes serão marcadas como puladas.',
          ),
          if (widget.store.hasUnsaved)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Há valores digitados que ainda não foram salvos. Apenas séries confirmadas entrarão no resumo.',
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLength: 2000,
            maxLines: 3,
            onChanged: (value) => widget.store.noteDraft = value,
            decoration: const InputDecoration(
              labelText: 'Observação (opcional)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Voltar ao treino'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Confirmar conclusão'),
      ),
    ],
  );
}
