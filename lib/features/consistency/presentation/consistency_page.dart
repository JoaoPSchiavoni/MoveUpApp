import 'package:flutter/material.dart';

import '../../session/domain/session.dart';
import '../../session/presentation/session_history.dart';
import '../../workout/domain/workout_gateway.dart';
import '../domain/consistency.dart';
import 'consistency_store.dart';

const monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

Future<void> configureConsistency(
  BuildContext context,
  ConsistencyStore store,
  List<int> suggested,
) async {
  if (store.config == null) {
    await store.refresh();
  }
  if (!context.mounted || store.config == null) return;
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ConsistencySettings(store: store, suggested: suggested),
    ),
  );
  if (saved == true) await store.refresh();
}

class ConsistencyOverview extends StatelessWidget {
  const ConsistencyOverview({
    super.key,
    required this.store,
    required this.suggested,
  });
  final ConsistencyStore store;
  final List<int> suggested;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final panel = store.panel;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sua constância',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (store.loading) const LinearProgressIndicator(),
              if (store.error != null) ...[
                Text(store.error!),
                TextButton(
                  onPressed: store.loading ? null : store.refresh,
                  child: const Text('Tentar novamente'),
                ),
              ] else if (panel != null && !panel.enabled) ...[
                const Text(
                  'Defina sua rotina para acompanhar presença, sequência e meta semanal.',
                ),
                FilledButton.tonal(
                  onPressed: () =>
                      configureConsistency(context, store, suggested),
                  child: const Text('Configurar minha rotina'),
                ),
              ] else if (panel != null) ...[
                Text(
                  '${panel.week.days} dias treinados nesta semana · ${panel.monthDays} neste mês',
                ),
                const SizedBox(height: 8),
                Text(
                  'Sequência: ${panel.streak} dias planejados · Melhor: ${panel.best}',
                ),
                if (panel.week.goal != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Meta semanal: ${panel.week.days}/${panel.week.goal} dias',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (panel.week.days / panel.week.goal!).clamp(0, 1),
                  ),
                  if (panel.week.days >= panel.week.goal!)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Meta alcançada! Continue no seu ritmo.'),
                    ),
                ],
                TextButton(
                  onPressed: () =>
                      configureConsistency(context, store, suggested),
                  child: const Text('Editar rotina e meta'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class ConsistencyPage extends StatefulWidget {
  const ConsistencyPage({
    super.key,
    required this.store,
    required this.sessions,
    required this.suggested,
  });
  final ConsistencyStore store;
  final SessionGateway sessions;
  final List<int> suggested;
  @override
  State<ConsistencyPage> createState() => _ConsistencyPageState();
}

class _ConsistencyPageState extends State<ConsistencyPage> {
  DateTime? selectedWeek;
  Future<ConsistencyWeek>? weekFuture;
  void changeWeek(int offset) {
    final start = (selectedWeek ?? widget.store.panel!.week.start).add(
      Duration(days: 7 * offset),
    );
    setState(() {
      selectedWeek = start;
      weekFuture = widget.store.gateway.week(start);
    });
  }

  Future<void> reload() async {
    await widget.store.refresh();
    if (mounted && selectedWeek != null) {
      setState(() => weekFuture = widget.store.gateway.week(selectedWeek!));
    }
  }

  Future<void> openDay(CalendarDay day) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .65,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  shortDate(day.date),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(day.onFire ? '${day.label} • OnFire' : day.label),
                if (day.state == 'treinado' && !day.planned)
                  const Text('Treino extra: conta para a meta semanal.'),
                if (day.state == 'falta')
                  const Text(
                    'Este dia estava planejado e terminou sem um treino concluído.',
                  ),
                if (day.state == 'descanso')
                  const Text('Dias de descanso preservam sua sequência.'),
                if (day.state == 'semPlanejamento')
                  const Text(
                    'Não há rotina registrada para esta data; não presumimos faltas.',
                  ),
                if (day.state == 'planejadoHoje')
                  const Text('Você ainda pode cumprir o treino de hoje.'),
                for (final session in day.sessions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(session.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, session.id),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (id != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              SessionHistoryDetail(gateway: widget.sessions, id: id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final panel = store.panel;
      final month = store.month;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Seu calendário',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(
                  'Cada presença conta. O descanso faz parte da rotina.',
                ),
                const SizedBox(height: 16),
                ConsistencyOverview(store: store, suggested: widget.suggested),
                if (panel != null && panel.enabled && month != null) ...[
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Mês anterior',
                        onPressed: month.year == 1900 && month.month == 1
                            ? null
                            : () => store.loadMonth(
                                DateTime(month.year, month.month - 1),
                              ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '${monthNames[month.month - 1]} ${month.year}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Próximo mês',
                        onPressed: month.year == 2100 && month.month == 12
                            ? null
                            : () => store.loadMonth(
                                DateTime(month.year, month.month + 1),
                              ),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Text('Datas em ${panel.zone}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (store.calendarLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (store.calendarError != null) ...[
                    Text(store.calendarError!),
                    TextButton(
                      onPressed: () => store.loadMonth(month),
                      child: const Text('Tentar novamente'),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        for (final label in [
                          'Seg',
                          'Ter',
                          'Qua',
                          'Qui',
                          'Sex',
                          'Sáb',
                          'Dom',
                        ])
                          Expanded(
                            child: Text(label, textAlign: TextAlign.center),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                      itemCount: month.weekday - 1 + store.days.length,
                      itemBuilder: (context, index) {
                        if (index < month.weekday - 1) {
                          return const SizedBox.shrink();
                        }
                        final day = store.days[index - (month.weekday - 1)];
                        final colors = Theme.of(context).colorScheme;
                        final (
                          background,
                          foreground,
                          icon,
                        ) = switch (day.state) {
                          'treinado' => (
                            colors.primaryContainer,
                            colors.onPrimaryContainer,
                            Icons.check,
                          ),
                          'falta' => (
                            colors.errorContainer,
                            colors.onErrorContainer,
                            Icons.close,
                          ),
                          'planejadoHoje' || 'planejadoFuturo' => (
                            colors.tertiaryContainer,
                            colors.onTertiaryContainer,
                            Icons.fitness_center,
                          ),
                          'descanso' => (
                            colors.surfaceContainerHighest,
                            colors.onSurfaceVariant,
                            Icons.remove,
                          ),
                          _ => (
                            colors.surface,
                            colors.onSurfaceVariant,
                            Icons.more_horiz,
                          ),
                        };
                        final isToday =
                            dateKey(day.date) == dateKey(panel.today);
                        return Semantics(
                          label:
                              '${shortDate(day.date)}, ${day.label}${day.onFire ? ', OnFire' : ''}${isToday ? ', hoje' : ''}',
                          button: true,
                          child: Material(
                            color: day.onFire
                                ? const Color(0xffffa34d)
                                : background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isToday
                                  ? BorderSide(color: colors.primary, width: 2)
                                  : BorderSide.none,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => openDay(day),
                              child: ExcludeSemantics(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${day.date.day}',
                                      style: TextStyle(
                                        color: day.onFire
                                            ? const Color(0xff441700)
                                            : foreground,
                                        fontWeight: isToday
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    Icon(
                                      day.onFire
                                          ? Icons.local_fire_department
                                          : icon,
                                      size: 14,
                                      color: day.onFire
                                          ? const Color(0xff441700)
                                          : foreground,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _Legend(Icons.check, 'Treinado'),
                        _Legend(Icons.close, 'Falta'),
                        _Legend(Icons.fitness_center, 'Planejado'),
                        _Legend(Icons.remove, 'Descanso'),
                        _Legend(Icons.more_horiz, 'Sem planejamento'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Semana anterior',
                        onPressed:
                            (selectedWeek ?? panel.week.start).year <= 1900
                            ? null
                            : () => changeWeek(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      const Expanded(
                        child: Text(
                          'Resumo semanal',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Próxima semana',
                        onPressed:
                            selectedWeek == null ||
                                !selectedWeek!.isBefore(panel.week.start)
                            ? null
                            : () => changeWeek(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  if (selectedWeek == null)
                    _WeekCard(week: panel.week)
                  else
                    FutureBuilder<ConsistencyWeek>(
                      future: weekFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasData) {
                          return _WeekCard(week: snapshot.data!);
                        }
                        return Column(
                          children: [
                            const Text(
                              'Não foi possível carregar esta semana.',
                            ),
                            TextButton(
                              onPressed: () => setState(
                                () => weekFuture = store.gateway.week(
                                  selectedWeek!,
                                ),
                              ),
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(text)],
  );
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});
  final ConsistencyWeek week;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${shortDate(week.start)} a ${shortDate(week.end)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text('${week.days} dias treinados · ${week.sessions} sessões'),
          Text(
            '${(week.seconds / 60).floor()} minutos · ${week.volume.toStringAsFixed(0)} kg de volume registrado',
          ),
          Text(
            week.goal == null
                ? 'Sem meta registrada nesta semana.'
                : 'Meta: ${week.days}/${week.goal} dias',
          ),
          if (week.goal != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                value: (week.days / week.goal!).clamp(0, 1),
              ),
            ),
          Text(
            week.adherence == null
                ? 'Adesão: ainda não há dias planejados encerrados.'
                : 'Adesão: ${(week.adherence! * 100).toStringAsFixed(0)}% · ${week.fulfilled}/${week.planned} dias planejados encerrados',
          ),
          if (week.planned > 0 && week.fulfilled == week.planned)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Você cumpriu todos os dias planejados já encerrados. Continue assim!',
              ),
            ),
        ],
      ),
    ),
  );
}

class ConsistencySettings extends StatefulWidget {
  const ConsistencySettings({
    super.key,
    required this.store,
    required this.suggested,
  });
  final ConsistencyStore store;
  final List<int> suggested;
  @override
  State<ConsistencySettings> createState() => _ConsistencySettingsState();
}

class _ConsistencySettingsState extends State<ConsistencySettings> {
  late final config = widget.store.config!;
  late final days =
      (config.routines.isEmpty ? widget.suggested : config.routines.last.days)
          .toSet();
  late int goal = config.goals.isEmpty
      ? days.length.clamp(1, 7)
      : config.goals.last.days;
  late final zone = TextEditingController(text: config.zone);
  bool saving = false;
  String? error;
  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final value = await widget.store.gateway.configure(
        zone.text.trim(),
        days.toList()..sort(),
        goal,
      );
      widget.store.config = value;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = widget.store.message(e);
        });
      }
    }
  }

  @override
  void dispose() {
    zone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Rotina e meta')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Em quais dias você planeja treinar?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(weekdays[d - 1]),
                      selected: days.contains(d),
                      onSelected: saving
                          ? null
                          : (selected) => setState(() {
                              if (selected) {
                                days.add(d);
                              } else {
                                days.remove(d);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Dias fora da rotina são descanso. Um treino extra conta para a meta, mas não aumenta a sequência de dias planejados.',
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: goal,
                decoration: const InputDecoration(labelText: 'Meta semanal'),
                items: [
                  for (var d = 1; d <= 7; d++)
                    DropdownMenuItem(
                      value: d,
                      child: Text('$d ${d == 1 ? 'dia' : 'dias'} por semana'),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => goal = value!),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: zone,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Fuso horário',
                  helperText: 'Ex.: America/Sao_Paulo, Europe/Lisbon ou UTC',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                config.enabled
                    ? 'Mudanças na rotina valem no dia seguinte; na meta, na próxima segunda-feira. Alterar o fuso vale para novos treinos e preserva as datas antigas.'
                    : 'A rotina vale a partir de hoje. Dias anteriores não são considerados faltas. As datas já registradas são preservadas.',
              ),
              for (final revision in config.routines.where(
                (r) => r.start.isAfter(config.today),
              ))
                Text('Rotina já agendada para ${shortDate(revision.start)}.'),
              for (final revision in config.goals.where(
                (g) => g.start.isAfter(config.today),
              ))
                Text(
                  'Meta já agendada: ${revision.days} dias a partir de ${shortDate(revision.start)}.',
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Salvando…' : 'Salvar rotina e meta'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
