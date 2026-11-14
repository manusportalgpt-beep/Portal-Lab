import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/modrinth.dart';
import '../services/mojang.dart';
import '../theme.dart';
import 'accounts_page.dart';
import 'create_instance_page.dart';
import 'instance_detail_page.dart';
import 'launch_page.dart';
import 'portalus_page.dart';
import 'settings_page.dart';
import 'skin_page.dart';
import 'widgets/brand_icons.dart';
import 'widgets/player_head.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MojangVersion> _versions = [];
  List<CatalogProject> _popular = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vs = await MojangService.versions();
      final pop = await ModrinthService.search(
          projectType: 'mod', sort: 'downloads', limit: 6);
      if (!mounted) return;
      setState(() {
        _versions = vs.where((v) => v.isRelease).take(5).toList();
        _popular = pop;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    final acc = st.activeAccount;
    final totalMods =
        st.instances.fold<int>(0, (sum, i) => sum + i.mods.length);
    final last = st.lastInstance;

    return Scaffold(
      appBar: AppBar(
        title: Text(s['appName'],
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: s['tabSettings'],
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => openAccounts(context),
              child: _AccountAvatar(account: acc),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Greeting card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s['hello']}, ${acc?.username ?? s['noAccount']}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          if (acc == null)
                            TextButton.icon(
                              onPressed: () => openAccounts(context),
                              icon: const Icon(Icons.person_add_alt, size: 18),
                              label: Text(s['addAccount']),
                            )
                          else
                            Text(
                              acc.isMsa ? s['msAccount'] : s['offlineAccount'],
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    if (acc != null)
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => SkinPage(account: acc))),
                        child: PlayerHead.of(acc, size: 56, radius: 10),
                      ),
                  ],
                ),
              ),
            ),

            // Quick launch
            if (last != null) ...[
              const SizedBox(height: 8),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    st.setLastInstance(last.id);
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LaunchPage(instanceId: last.id)));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        LoaderBadge(loader: last.loader, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['quickLaunch'],
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                              Text(last.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              Text(
                                '${last.loaderLabel} • MC ${last.gameVersion}',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            st.setLastInstance(last.id);
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    LaunchPage(instanceId: last.id)));
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: Text(s['play']),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Stats
            const SizedBox(height: 18),
            Text(s['quickStats'],
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                _StatCard(
                    icon: Icons.grid_view,
                    value: '${st.instances.length}',
                    label: s['statInstances']),
                const SizedBox(width: 10),
                _StatCard(
                    icon: Icons.extension,
                    value: '$totalMods',
                    label: s['statMods']),
                const SizedBox(width: 10),
                _StatCard(
                    icon: Icons.people,
                    value: '${st.accounts.length}',
                    label: s['statAccounts']),
              ],
            ),

            // Quick actions
            const SizedBox(height: 18),
            Text(s['quickActions'],
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.add_box,
                    label: s['createInstance'],
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CreateInstancePage())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.auto_awesome,
                    label: s['portalusName'],
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PortalusPage())),
                  ),
                ),
              ],
            ),

            // New versions
            const SizedBox(height: 18),
            Text(s['newVersions'],
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (_loading && _versions.isEmpty)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(s['error']),
                subtitle: Text(_error!,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing:
                    TextButton(onPressed: _load, child: Text(s['retry'])),
              )
            else
              ..._versions.map((v) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.history_edu),
                      title: Text(v.id),
                      subtitle: Text(
                          '${s['release']} • ${v.releaseTime.substring(0, 10)}'),
                      trailing: Chip(label: Text(v.id.split('.').first)),
                    ),
                  )),

            // Popular mods
            const SizedBox(height: 18),
            Text(s['popularMods'],
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (_popular.isEmpty)
              Text(s['empty'])
            else
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _popular.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final p = _popular[i];
                    return _PopularCard(project: p);
                  },
                ),
              ),

            // Recent instances
            if (st.instances.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(s['tabInstances'],
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              ...st.instances.take(3).map((inst) => Card(
                    child: ListTile(
                      leading: LoaderBadge(loader: inst.loader, size: 40),
                      title: Text(inst.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${inst.loaderLabel} • MC ${inst.gameVersion} • ${inst.mods.length} ${s['modsTab']}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  InstanceDetailPage(instanceId: inst.id))),
                    ),
                  )),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  final McAccount? account;
  const _AccountAvatar({required this.account});

  @override
  Widget build(BuildContext context) {
    if (account == null) {
      return const CircleAvatar(child: Icon(Icons.person_outline));
    }
    return PlayerHead.of(account!, size: 34, radius: 8);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularCard extends StatelessWidget {
  final CatalogProject project;
  const _PopularCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: project.iconUrl == null
                        ? Container(
                            width: 44,
                            height: 44,
                            color: cs.primaryContainer,
                            child: Icon(Icons.extension,
                                color: cs.onPrimaryContainer),
                          )
                        : CachedNetworkImage(
                            imageUrl: project.iconUrl!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(project.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  SourceBadge(source: project.source, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${fmtCount(project.downloads)} ${AppScope.of(context).s['downloadsWord']}',
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
