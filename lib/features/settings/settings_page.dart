import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/appearance.dart';
import '../../core/local_database.dart';
import '../../core/data_transfer.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.appearance,
    this.local,
    required this.apiUrl,
  });
  final Appearance appearance;
  final LocalData? local;
  final String apiUrl;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool busy = false;
  String? message;
  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is FormatException ? e.message : 'Não foi possível concluir a operação. Seus dados foram preservados.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    final content = await widget.local!.exportBackup();
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(utf8.encode(content), mimeType: 'application/json'),
        ],
        fileNameOverrides: [
          'moveup-backup-${DateTime.now().millisecondsSinceEpoch}.json',
        ],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    if (mounted) {
      setState(
        () => message =
            'Backup preparado. Salve o arquivo em um local de sua confiança.',
      );
    }
  }

  Future<void> restore() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Backup MoveUp',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 50 * 1024 * 1024) {
      throw const FormatException('Arquivo maior que 50 MB.');
    }
    final content = await file.readAsString();
    final backup = BackupService(widget.local!);
    final rows = backup.validate(content);
    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar backup?'),
        content: Text(
          'O arquivo contém ${rows.length} registros. Ele substituirá os dados locais, inclusive o treino em andamento. Exporte seu backup atual antes de continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    await backup.restore(content);
    await widget.appearance.load();
    if (mounted) {
      setState(
        () => message = 'Backup restaurado. Sua biblioteca foi atualizada.',
      );
    }
  }

  Future<void> migrate() async {
    final controller = TextEditingController(text: widget.apiUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trazer dados da API'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Importe fichas, histórico e rotina para este aparelho. A biblioteca local deve estar vazia. Os dados na API são preservados.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Endereço da API'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('Informe um endereço HTTP ou HTTPS válido.');
    }
    await BackupService(widget.local!).importApi(url);
    if (mounted) {
      setState(
        () => message = 'Fichas, sessões e rotina importadas para o aparelho.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Preferências')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.appearance.error != null) Text(widget.appearance.error!),
            const Text(
              'Aparência',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ThemeMode>(
              isExpanded: true,
              initialValue: widget.appearance.mode,
              decoration: const InputDecoration(labelText: 'Tema'),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(
                    'Automático • segue o celular',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Noturno')),
              ],
              onChanged: busy
                  ? null
                  : (v) => run(() => widget.appearance.set(v!)),
            ),
            const SizedBox(height: 28),
            if (widget.local != null) ...[
              const Text(
                'Seus dados',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
              const SizedBox(height: 8),
              const Text(
                'Treinos, histórico e medidas ficam neste aparelho e funcionam sem internet. Um backup permite recuperar seus dados ao trocar de celular ou reinstalar o app.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : () => run(export),
                icon: const Icon(Icons.ios_share),
                label: const Text('Exportar backup'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : () => run(restore),
                icon: const Icon(Icons.restore),
                label: const Text('Restaurar backup'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: busy ? null : () => run(migrate),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Trazer dados da API'),
              ),
            ] else
              const Text(
                'Este modo usa dados da API ou da demonstração. O backup local está disponível no modo padrão do app.',
              ),
            if (busy) const LinearProgressIndicator(),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(message!),
              ),
          ],
        ),
      ),
    ),
  );
}
