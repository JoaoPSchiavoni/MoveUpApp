import 'package:flutter/material.dart';

import '../../core/local_database.dart';
import '../consistency/presentation/consistency_page.dart';
import 'measurements.dart';
import 'progress_chart.dart';

class MeasurementsPage extends StatefulWidget {
  const MeasurementsPage({super.key, required this.data});
  final LocalData data;
  @override
  State<MeasurementsPage> createState() => _MeasurementsPageState();
}

class _MeasurementsPageState extends State<MeasurementsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed && mounted) {
      setState(() {
        state = load();
      });
    }
  }

  late final store = MeasurementStore(widget.data);
  late Future<(DateTime, List<Map<String, dynamic>>)> state = load();
  String field = 'weight';
  Future<(DateTime, List<Map<String, dynamic>>)> load() async =>
      (await store.today(), await store.all());
  Future<void> edit(DateTime today, Map<String, dynamic>? current) async {
    final values = current?['values'] as Map? ?? {};
    final controllers = {
      for (final key in measurementFields.keys)
        key: TextEditingController(text: values[key]?.toString() ?? ''),
    };
    String? error;
    bool saving = false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => PopScope(
          canPop: !saving,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .8,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      '${current == null ? 'Registrar' : 'Corrigir'} medidas • ${monthNames[today.month - 1]}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Preencha as medidas que deseja acompanhar. Use o mesmo lado e a mesma forma de medir a cada mês.',
                    ),
                    for (final entry in measurementFields.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: TextField(
                          controller: controllers[entry.key],
                          enabled: !saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(labelText: entry.value),
                        ),
                      ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setSheet(() => saving = true);
                              try {
                                final input = <String, double>{};
                                for (final e in controllers.entries) {
                                  if (e.value.text.trim().isNotEmpty) {
                                    final number = double.tryParse(
                                      e.value.text.trim().replaceAll(',', '.'),
                                    );
                                    if (number == null) {
                                      throw const FormatException(
                                        'Use números válidos nas medidas.',
                                      );
                                    }
                                    input[e.key] = number;
                                  }
                                }
                                await store.save(monthKey(today), input);
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  setSheet(
                                    () => error = e is FormatException
                                        ? e.message
                                        : 'Não foi possível salvar suas medidas.',
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setSheet(() => saving = false);
                                }
                              }
                            },
                      child: Text(saving ? 'Salvando…' : 'Concluir'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Controllers belong to the sheet and are disposed after its dismissal animation.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final c in controllers.values) {
      c.dispose();
    }
    if (saved == true && mounted) {
      setState(() {
        state = load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Medidas do corpo')),
    body: FutureBuilder(
      future: state,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() {
                state = load();
              }),
              child: const Text('Não foi possível carregar. Tentar novamente'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (today, records) = snapshot.data!;
        final current = records
            .where((r) => r['month'] == monthKey(today))
            .firstOrNull;
        final points =
            records.where((r) => (r['values'] as Map)[field] != null).toList()
              ..sort(
                (a, b) =>
                    (a['month'] as String).compareTo(b['month'] as String),
              );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '${monthNames[today.month - 1]} ${today.year}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          current == null
                              ? Icons.straighten
                              : Icons.check_circle_outline,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          current == null
                              ? 'Sua referência deste mês'
                              : 'Medidas deste mês registradas',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          current == null
                              ? 'Registre suas medidas uma vez por mês para acompanhar sua evolução.'
                              : 'O próximo registro estará disponível em 01/${(today.month == 12 ? 1 : today.month + 1).toString().padLeft(2, '0')}/${today.month == 12 ? today.year + 1 : today.year}. Você pode corrigir os valores deste mês.',
                        ),
                        if (current != null) ...[
                          const SizedBox(height: 12),
                          for (final entry
                              in (current['values'] as Map).entries)
                            Text(
                              '${measurementFields[entry.key]}: ${entry.value}',
                            ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => edit(today, current),
                          icon: Icon(
                            current == null ? Icons.add : Icons.edit_outlined,
                          ),
                          label: Text(
                            current == null
                                ? 'Registrar medidas'
                                : 'Corrigir registro deste mês',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: field,
                  decoration: const InputDecoration(
                    labelText: 'Medida no gráfico',
                  ),
                  items: [
                    for (final entry in measurementFields.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (v) => setState(() => field = v!),
                ),
                const SizedBox(height: 16),
                ProgressChart(
                  points: [
                    for (final r in points)
                      ChartPoint(
                        (int.parse((r['month'] as String).substring(0, 4)) *
                                    12 +
                                int.parse((r['month'] as String).substring(5)))
                            .toDouble(),
                        ((r['values'] as Map)[field] as num).toDouble(),
                        r['month'] as String,
                      ),
                  ],
                  xLabel: 'Mês',
                  xTickLabel: (value) {
                    final n = value.toInt();
                    return '${(n % 12 == 0 ? 12 : n % 12).toString().padLeft(2, '0')}/${n % 12 == 0 ? n ~/ 12 - 1 : n ~/ 12}';
                  },
                  emptyMessage: 'Registre uma medida para começar seu gráfico.',
                  yLabel: measurementFields[field]!,
                ),
                const SizedBox(height: 20),
                for (final r in records.reversed)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.straighten),
                      title: Text(r['month'] as String),
                      subtitle: Text(
                        (r['values'] as Map).entries
                            .map(
                              (e) => '${measurementFields[e.key]}: ${e.value}',
                            )
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
