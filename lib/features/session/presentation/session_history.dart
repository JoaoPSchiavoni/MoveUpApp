import 'package:flutter/material.dart';

import '../domain/session.dart';
import 'session_summary.dart';

class SessionHistory extends StatefulWidget {
  const SessionHistory({super.key, required this.gateway});
  final SessionGateway gateway;
  @override
  State<SessionHistory> createState() => _SessionHistoryState();
}

class _SessionHistoryState extends State<SessionHistory> {
  final items = <TrainingSession>[];
  bool loading = false, hasMore = true;
  int page = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = reset ? 1 : page + 1;
      final result = await widget.gateway.history(page: next);
      if (!mounted) return;
      setState(() {
        if (reset) items.clear();
        final existing = items.map((s) => s.id).toSet();
        items.addAll(result.items.where((s) => existing.add(s.id)));
        page = next;
        hasMore = result.hasMore;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is SessionFailure
              ? e.message
              : 'Não foi possível carregar o histórico.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open(TrainingSession item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SessionHistoryDetail(gateway: widget.gateway, id: item.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: RefreshIndicator(
        onRefresh: () => load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Histórico de treinos',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text('Cada treino concluído é um passo à frente.'),
            const SizedBox(height: 24),
            if (items.isEmpty && !loading && error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Seus treinos concluídos aparecerão aqui.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final session in items)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(session.name),
                  subtitle: Text(
                    '${sessionDate(session.startedAt)}\n${sessionDuration(session)} · ${session.completed} séries concluídas',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(session),
                ),
              ),
            if (error != null) ...[
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: () => load(reset: page == 0),
                child: const Text('Tentar novamente'),
              ),
            ],
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!loading && error == null && hasMore && items.isNotEmpty)
              OutlinedButton(
                onPressed: load,
                child: const Text('Carregar mais'),
              ),
          ],
        ),
      ),
    ),
  );
}

class SessionHistoryDetail extends StatefulWidget {
  const SessionHistoryDetail({
    super.key,
    required this.gateway,
    required this.id,
  });
  final SessionGateway gateway;
  final String id;
  @override
  State<SessionHistoryDetail> createState() => _SessionHistoryDetailState();
}

class _SessionHistoryDetailState extends State<SessionHistoryDetail> {
  late Future<TrainingSession> future = widget.gateway.load(widget.id);
  @override
  Widget build(BuildContext context) => FutureBuilder<TrainingSession>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasData) return SessionSummaryPage(session: snapshot.data!);
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes do treino realizado')),
        body: Center(
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Não foi possível carregar o treino.'),
                    TextButton(
                      onPressed: () => setState(
                        () => future = widget.gateway.load(widget.id),
                      ),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
