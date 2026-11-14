import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/curseforge.dart';
import '../services/instance_service.dart';
import '../services/modrinth.dart';
import '../theme.dart';

class ProjectPage extends StatefulWidget {
  final CatalogProject project;
  const ProjectPage({super.key, required this.project});

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  Map<String, dynamic>? _details;
  List<CatalogVersion> _versions = [];
  bool _loading = true;
  bool _installing = false;
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
      final p = widget.project;
      final Map<String, dynamic> details;
      final List<CatalogVersion> versions;
      if (p.source == 'modrinth') {
        details = await ModrinthService.project(p.id);
        versions = await ModrinthService.versions(p.id);
      } else {
        details = await CurseForgeService.project(p.id);
        versions = await CurseForgeService.versions(p.id);
      }
      if (!mounted) return;
      setState(() {
        _details = details;
        _versions = versions;
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

  /// Pick an instance, then install the best compatible version.
  Future<void> _install() async {
    final st = AppScope.of(context);
    final s = st.s;
    if (st.instances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s['noInstances'])));
      return;
    }
    if (widget.project.projectType == 'modpack') {
      await _installModpack();
      return;
    }
    final inst = await showModalBottomSheet<GameInstance>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(s['pickInstance'],
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...st.instances.map((i) => ListTile(
                  leading: const Icon(Icons.grid_view),
                  title: Text(i.name),
                  subtitle: Text('${i.loaderLabel} • ${i.gameVersion}'),
                  onTap: () => Navigator.pop(ctx, i),
                )),
          ],
        ),
      ),
    );
    if (inst == null || !mounted) return;

    // find best compatible version
    CatalogVersion? best;
    for (final v in _versions) {
      final gvOk = v.gameVersions.isEmpty ||
          v.gameVersions.contains(inst.gameVersion);
      final loaderOk = v.loaders.isEmpty ||
          inst.loader == 'vanilla' ||
          v.loaders.contains(inst.loader);
      if (gvOk && loaderOk) {
        best = v;
        break;
      }
    }
    best ??= _versions.isNotEmpty ? _versions.first : null;
    if (best == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s['noCompatibleVersion'])));
      return;
    }
    await InstanceService.installMod(inst, best);
    inst.mods.add(ModEntry(
      source: widget.project.source,
      projectId: widget.project.id,
      versionId: best.id,
      name: widget.project.title,
      fileName: best.fileName,
      gameVersions: best.gameVersions,
      loaders: best.loaders,
      iconUrl: widget.project.iconUrl,
    ));
    await st.saveInstance(inst);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s['installed']}: ${best.versionNumber}')));
  }

  Future<void> _installModpack() async {
    final st = AppScope.of(context);
    final s = st.s;
    if (_versions.isEmpty) return;
    final v = _versions.first;
    setState(() => _installing = true);
    try {
      final GameInstance inst;
      if (widget.project.source == 'modrinth') {
        inst = await InstanceService.installModrinthModpack(
            widget.project.title, v.downloadUrl);
      } else {
        inst = await InstanceService.installCurseForgeModpack(
            widget.project.title, v.downloadUrl);
      }
      await st.addInstance(inst);
      if (!mounted) return;
      setState(() => _installing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s['packInstalled']}: ${inst.name}')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _installing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s['error']}: $e')));
    }
  }

  Future<void> _openWeb() async {
    final p = widget.project;
    final url = p.source == 'modrinth'
        ? 'https://modrinth.com/${_ptPath(p.projectType)}/${p.id}'
        : 'https://www.curseforge.com/minecraft/${_ptPath(p.projectType)}/${p.id}';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  static String _ptPath(String t) => switch (t) {
        'modpack' => 'modpacks',
        'resourcepack' => 'resourcepacks',
        'shader' => 'shaders',
        _ => 'mods',
      };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    final p = widget.project;
    final body = (_details?['body'] as String?) ?? '';
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: _openWeb,
                tooltip: s['web'],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: p.iconUrl == null
                  ? Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest)
                  : CachedNetworkImage(
                      imageUrl: p.iconUrl!,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(14),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(p.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${s['byAuthor']} ${p.author} • ${fmtCount(p.downloads)} ${s['downloadsWord']}',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 12),
                if (_installing)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton.icon(
                    onPressed: _install,
                    icon: const Icon(Icons.download),
                    label: Text(p.projectType == 'modpack'
                        ? s['installModpack']
                        : s['installToInstance']),
                  ),
                const SizedBox(height: 18),
                Text(s['description'],
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(_stripMarkdown(
                    body.isEmpty ? p.description : body)),
                const SizedBox(height: 18),
                Text(s['versions'],
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (_loading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ))
                else if (_error != null)
                  Column(children: [
                    Text('${s['error']}: $_error'),
                    TextButton(onPressed: _load, child: Text(s['retry'])),
                  ])
                else
                  ..._versions.take(20).map((v) => Card(
                        child: ListTile(
                          leading: Icon(
                            v.versionType == 'release'
                                ? Icons.verified
                                : Icons.science_outlined,
                            color: v.versionType == 'release'
                                ? Colors.green
                                : Colors.orange,
                          ),
                          title: Text(v.versionNumber,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${_shortDate(v.datePublished)} • ${fmtSize(v.size)}'),
                          trailing: TextButton(
                            onPressed: () => _installVersion(v),
                            child: Text(s['install']),
                          ),
                        ),
                      )),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _installVersion(CatalogVersion v) async {
    final st = AppScope.of(context);
    final s = st.s;
    if (st.instances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s['noInstances'])));
      return;
    }
    final inst = await showModalBottomSheet<GameInstance>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(s['pickInstance'],
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...st.instances.map((i) => ListTile(
                  leading: const Icon(Icons.grid_view),
                  title: Text(i.name),
                  subtitle: Text('${i.loaderLabel} • ${i.gameVersion}'),
                  onTap: () => Navigator.pop(ctx, i),
                )),
          ],
        ),
      ),
    );
    if (inst == null || !mounted) return;
    await InstanceService.installMod(inst, v);
    inst.mods.add(ModEntry(
      source: widget.project.source,
      projectId: widget.project.id,
      versionId: v.id,
      name: widget.project.title,
      fileName: v.fileName,
      gameVersions: v.gameVersions,
      loaders: v.loaders,
      iconUrl: widget.project.iconUrl,
    ));
    await st.saveInstance(inst);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s['installed']}: ${v.versionNumber}')));
  }

  static String _shortDate(String d) =>
      d.length >= 10 ? d.substring(0, 10) : d;

  static String _stripMarkdown(String md) {
    var t = md
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'[#*_`>~|]'), '')
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    t = t.split('\n').map((l) => l.trim()).join('\n');
    return t.trim();
  }
}
