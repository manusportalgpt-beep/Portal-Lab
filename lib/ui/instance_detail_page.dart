import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/instance_service.dart';

class InstanceDetailPage extends StatefulWidget {
  final String instanceId;
  const InstanceDetailPage({super.key, required this.instanceId});

  @override
  State<InstanceDetailPage> createState() => _InstanceDetailPageState();
}

class _InstanceDetailPageState extends State<InstanceDetailPage> {
  GameInstance? _inst;
  List<String> _files = [];
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final st = AppScope.of(context);
    GameInstance? inst;
    for (final i in st.instances) {
      if (i.id == widget.instanceId) inst = i;
    }
    setState(() => _inst = inst);
    if (inst != null) {
      InstanceService.modFiles(inst).then((f) {
        if (mounted) setState(() => _files = f);
      });
    }
  }

  Future<void> _export() async {
    if (_inst == null || _exporting) return;
    final s = AppScope.of(context).s;
    setState(() => _exporting = true);
    try {
      final path = await InstanceService.exportZip(_inst!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s['exported']}: $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s['error']}: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _delete() async {
    if (_inst == null) return;
    final s = AppScope.of(context).s;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s['deleteInstanceQ']),
        content: Text(s['deleteInstanceHint']),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s['cancel'])),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s['delete'])),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppScope.of(context).deleteInstance(_inst!.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _play() async {
    final s = AppScope.of(context).s;
    final isAndroid = Platform.isAndroid;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s['launchTitle'],
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(isAndroid ? s['launchAndroid'] : s['launchIos']),
              const SizedBox(height: 16),
              if (isAndroid) ...[
                FilledButton.icon(
                  onPressed: () => _tryOpen(
                      'https://play.google.com/store/apps/details?id=net.kdt.pojavlaunch'),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(s['installPojav']),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tryOpen(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    if (_inst == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    final inst = _inst!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(inst.name),
          actions: [
            IconButton(
              tooltip: s['export'],
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.archive_outlined),
            ),
            IconButton(
              tooltip: s['delete'],
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: s['overview']),
            Tab(text: s['modsTab']),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _play,
          icon: const Icon(Icons.play_arrow),
          label: Text(s['play']),
        ),
        body: TabBarView(
          children: [
            _buildOverview(context, inst, s),
            _buildMods(context, inst, s),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(BuildContext context, GameInstance inst, dynamic s) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                          icon: Icons.verified_outlined,
                          label: s['versionLabel'],
                          value: inst.gameVersion),
                    ),
                    Expanded(
                      child: _InfoTile(
                          icon: Icons.handyman_outlined,
                          label: s['loaderLabel'],
                          value:
                              '${inst.loaderLabel}${inst.loaderVersion.isEmpty ? '' : ' ${inst.loaderVersion}'}'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                          icon: Icons.calendar_month_outlined,
                          label: s['lastPlayed'],
                          value: inst.lastPlayed.isEmpty
                              ? s['never']
                              : inst.lastPlayed.substring(0, 10)),
                    ),
                    Expanded(
                      child: _InfoTile(
                          icon: Icons.extension_outlined,
                          label: s['modsTab'],
                          value: '${_files.length}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.archive_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Platform.isAndroid ? s['launchAndroid'] : s['launchIos'],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMods(BuildContext context, GameInstance inst, dynamic s) {
    if (_files.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.extension_outlined, size: 72),
          const SizedBox(height: 12),
          Text(s['noMods'],
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(s['noModsHint'], textAlign: TextAlign.center),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _files.length,
      itemBuilder: (context, i) {
        final f = _files[i];
        final meta = inst.mods
            .where((m) => m.fileName == f)
            .toList();
        return Card(
          child: ListTile(
            leading: const Icon(Icons.extension),
            title: Text(meta.isNotEmpty ? meta.first.name : f,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(s['removeModQ']),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(s['cancel'])),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(s['delete'])),
                    ],
                  ),
                );
                if (ok != true) return;
                await InstanceService.removeModFile(inst, f);
                _reload();
              },
            ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
