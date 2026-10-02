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
          color: Theme.of(context).colorScheme.primaryContainer,
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
      final resting = store.restEndsAt != null && store.remainingRest > 0;
      if (store.restEndsAt != null && store.remainingRest == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && store.restEndsAt != null && store.remainingRest == 0) {
            store.skipRest();
          }
        });
      }
      final exercise = session.exercises.isEmpty
          ? null
          : session.exercises[store.currentExerciseIndex.clamp(
              0,
              session.exercises.length - 1,
            )];
      final resolved = session.completed + session.skipped;
      return PopScope(
        canPop: !resting,
        child: Scaffold(
          appBar: resting
              ? null
              : AppBar(title: const Text('Treino em andamento')),
          body: resting
              ? RestFullscreen(store: store)
              : Center(
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
                        if (exercise != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Exercício ${store.currentExerciseIndex + 1} de ${session.exercises.length}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
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
                              locked:
                                  set.status == SetStatus.pending &&
                                  exercise.sets.any(
                                    (previous) =>
                                        previous.order < set.order &&
                                        previous.status == SetStatus.pending,
                                  ),
                            ),
                          if (store.currentExerciseIndex <
                                  session.exercises.length - 1 &&
                              store.canAdvanceFrom(exercise))
                            OutlinedButton.icon(
                              onPressed: store.busy
                                  ? null
                                  : store.advanceToNextExercise,
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(
                                'Próximo exercício · ${session.exercises[store.currentExerciseIndex + 1].name}',
                              ),
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
    required this.locked,
  });
  final SessionSet set;
  final SessionStore store;
  final int restSeconds;
  final bool locked;
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
            if (set.status == SetStatus.pending && widget.locked) ...[
              const SizedBox(height: 8),
              const Text('Disponível após concluir ou pular a série anterior.'),
            ] else if (set.status == SetStatus.pending) ...[
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
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.store.busy
                          ? null
                          : () => record(SetStatus.completed),
                      icon: const Icon(Icons.check),
                      label: const Text('Concluir série'),
                    ),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: widget.store.busy
                      ? null
                      : () => record(SetStatus.skipped),
                  child: const Text('Pular série'),
                ),
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

class RestFullscreen extends StatefulWidget {
  const RestFullscreen({super.key, required this.store});
  final SessionStore store;
  @override
  State<RestFullscreen> createState() => _RestFullscreenState();
}

class _RestFullscreenState extends State<RestFullscreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? ticker;
  late final AnimationController ring;

  void syncRing() {
    final deadline = widget.store.restEndsAt;
    final total = widget.store.lastRestSeconds * Duration.microsecondsPerSecond;
    if (deadline == null || total <= 0) return;
    final remaining = deadline.difference(widget.store.now()).inMicroseconds;
    ring.stop();
    ring.value = (1 - remaining / total).clamp(0.0, 1.0);
    if (remaining > 0) {
      ring.animateTo(
        1,
        duration: Duration(microseconds: remaining),
        curve: Curves.linear,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    ring = AnimationController(vsync: this);
    syncRing();
    WidgetsBinding.instance.addObserver(this);
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.store.remainingRest == 0) {
        widget.store.skipRest();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    if (widget.store.remainingRest == 0) {
      widget.store.skipRest();
    } else {
      syncRing();
      setState(() {});
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    ring.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String get clockText {
    final remaining = widget.store.remainingRest;
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    if (remaining >= 3600) {
      return '${(remaining ~/ 3600).toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final diameter = (MediaQuery.sizeOf(context).shortestSide * .82).clamp(
      220.0,
      340.0,
    );
    return SizedBox.expand(
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'DESCANSO',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox.square(
                dimension: diameter,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(diameter),
                      painter: _RestRingPainter(
                        progress: ring,
                        color: colors.primary,
                        trackColor: colors.outlineVariant,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          clockText,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: diameter * .17,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'até a próxima série',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    onPressed: widget.store.skipRest,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                    ),
                    child: const Text(
                      'Pular descanso',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestRingPainter extends CustomPainter {
  _RestRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  }) : super(repaint: progress);
  final Animation<double> progress;
  final Color color;
  final Color trackColor;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.shortestSide * .035;
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, rect.width / 2, track);
    if (progress.value > 0) {
      canvas.drawArc(
        rect,
        -1.5707963267948966,
        6.283185307179586 * progress.value,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RestRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
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
