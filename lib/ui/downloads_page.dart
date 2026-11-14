import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/download_manager.dart';
import '../theme.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    final dm = DownloadManager.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(s['tabDownloads'],
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: dm.tasks.isEmpty ? null : dm.clearFinished,
            icon: const Icon(Icons.clear_all),
            label: Text(s['clear']),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: dm,
        builder: (context, _) {
          if (dm.tasks.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 60),
                Icon(Icons.download_done_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(s['noDownloads'],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: dm.tasks.length,
            itemBuilder: (context, i) {
              final t = dm.tasks[i];
              return _TaskTile(task: t);
            },
          );
        },
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final DownloadTask task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    final dm = DownloadManager.instance;
    final statusLabel = switch (task.status) {
      'queued' => s['stQueued'],
      'running' => s['stRunning'],
      'done' => s['stDone'],
      'error' => s['stError'],
      'canceled' => s['stCanceled'],
      _ => task.status,
    };
    return Card(
      child: ListTile(
        leading: switch (task.status) {
          'done' => const Icon(Icons.check_circle, color: Colors.green),
          'error' => const Icon(Icons.error_outline, color: Colors.red),
          'running' => SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              value: task.progress,
              strokeWidth: 3,
            ),
          ),
          _ => const Icon(Icons.schedule),
        },
        title: Text(task.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.status == 'running')
              LinearProgressIndicator(value: task.progress),
            const SizedBox(height: 4),
            Text(
              '$statusLabel${task.total > 0 ? ' • ${fmtSize(task.received)} / ${fmtSize(task.total)}' : task.error != null ? ' • ${task.error!}' : ''}',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: task.status == 'queued'
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => dm.cancel(task),
              )
            : null,
      ),
    );
  }
}
