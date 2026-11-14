import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'create_instance_page.dart';
import 'instance_detail_page.dart';

class InstancesPage extends StatelessWidget {
  const InstancesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;

    return Scaffold(
      appBar: AppBar(
        title: Text(s['tabInstances'],
            style: const TextStyle(fontWeight: FontWeight.w700)),
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
              itemCount: st.instances.length,
              itemBuilder: (context, i) {
                final inst = st.instances[i];
                return Card(
                  child: ListTile(
                    leading: _InstanceIcon(loader: inst.loader),
                    title: Text(inst.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${inst.loaderLabel} ${inst.loaderVersion.isEmpty ? '' : inst.loaderVersion} • ${inst.gameVersion}'),
                    trailing: inst.mods.isEmpty
                        ? null
                        : Badge(
                            isLabelVisible: true,
                            label: Text('${inst.mods.length}'),
                            child: const Icon(Icons.extension_outlined),
                          ),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            InstanceDetailPage(instanceId: inst.id))),
                  ),
                );
              },
            ),
    );
  }
}

class _InstanceIcon extends StatelessWidget {
  final String loader;
  const _InstanceIcon({required this.loader});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = switch (loader) {
      'fabric' => (Icons.auto_awesome, const Color(0xFFDBB55A)),
      'quilt' => (Icons.auto_awesome_outlined, const Color(0xFF9C5EEB)),
      'forge' => (Icons.build, const Color(0xFF5B6228)),
      'neoforge' => (Icons.build_circle_outlined, const Color(0xFFFF9B50)),
      _ => (Icons.grass, const Color(0xFF5B8731)),
    };
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.18),
      child: Icon(icon, color: color),
    );
  }
}
