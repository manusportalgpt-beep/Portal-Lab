import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'create_instance_page.dart';
import 'instance_detail_page.dart';
import 'launch_page.dart';
import 'widgets/brand_icons.dart';

enum _InstSort { lastPlayed, created, name }

class InstancesPage extends StatefulWidget {
  const InstancesPage({super.key});

  @override
  State<InstancesPage> createState() => _InstancesPageState();
}

class _InstancesPageState extends State<InstancesPage> {
  _InstSort _sort = _InstSort.created;

  List<GameInstance> _sorted(AppState st) {
    final list = [...st.instances];
    switch (_sort) {
      case _InstSort.lastPlayed:
        list.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
      case _InstSort.created:
        list.sort((a, b) => b.created.compareTo(a.created));
      case _InstSort.name:
        list.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    final instances = _sorted(st);

    return Scaffold(
      appBar: AppBar(
        title: Text(s['tabInstances'],
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          PopupMenuButton<_InstSort>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: _InstSort.lastPlayed,
                child: Text(s['sortLastPlayed']),
              ),
              PopupMenuItem(
                value: _InstSort.created,
                child: Text(s['sortCreated']),
              ),
              PopupMenuItem(
                value: _InstSort.name,
                child: Text(s['sortByName']),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateInstancePage())),
        icon: const Icon(Icons.add),
        label: Text(s['createInstance']),
      ),
      body: st.instances.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 60),
                Icon(Icons.grid_view_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(s['noInstances'],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(s['noInstancesHint'],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
              itemCount: instances.length,
              itemBuilder: (context, i) {
                final inst = instances[i];
                return _InstanceCard(
                  inst: inst,
                  onPlay: () {
                    st.setLastInstance(inst.id);
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LaunchPage(instanceId: inst.id)));
                  },
                  onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          InstanceDetailPage(instanceId: inst.id))),
                );
              },
            ),
    );
  }
}

class _InstanceCard extends StatefulWidget {
  final GameInstance inst;
  final VoidCallback onPlay;
  final VoidCallback onOpen;
  const _InstanceCard(
      {required this.inst, required this.onPlay, required this.onOpen});

  @override
  State<_InstanceCard> createState() => _InstanceCardState();
}

class _InstanceCardState extends State<_InstanceCard> {
  int _sizeBytes = -1;

  @override
  void initState() {
    super.initState();
    _computeSize();
  }

  Future<void> _computeSize() async {
    final bytes = await compute(_instanceSize, widget.inst.id);
    if (mounted) setState(() => _sizeBytes = bytes);
  }

  static int _instanceSize(String id) => Store.instanceSizeBytes(id);

  @override
  Widget build(BuildContext context) {
    final inst = widget.inst;
    final s = AppScope.of(context).s;
    final cs = Theme.of(context).colorScheme;
    final icon = PortalThemes.instanceIcons[inst.icon] ?? Icons.grid_view;
    return Card(
      child: ListTile(
        leading: LoaderBadge(loader: inst.loader, size: 46),
        title:
            Text(inst.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${inst.loaderLabel} ${inst.loaderVersion.isEmpty ? '' : inst.loaderVersion} • ${inst.gameVersion}'),
            Row(
              children: [
                Icon(icon, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${inst.mods.length} ${s['modsTab']}${_sizeBytes < 0 ? '' : ' • ${s['storageUsed']}: ${fmtSize(_sizeBytes)}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.play_arrow, color: cs.primary),
          onPressed: widget.onPlay,
          tooltip: s['play'],
        ),
        onTap: widget.onOpen,
      ),
    );
  }
}
