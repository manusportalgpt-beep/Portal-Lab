import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/curseforge.dart';
import '../services/instance_service.dart';
import '../services/modrinth.dart';
import '../services/translate.dart';
import '../theme.dart';
import 'portalus_page.dart';
import 'widgets/brand_icons.dart';

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
  String? _filterVersion;

  // Translation state
  bool _translating = false;
  String? _translated;
  String? _translatedFrom;

  List<String> _gallery = [];

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
      final gallery = <String>[];
      final g = details['gallery'];
      if (g is List) {
        for (final item in g.take(8)) {
          if (item is Map && item['url'] is String) {
            gallery.add(item['url'] as String);
          }
        }
      }
      setState(() {
        _details = details;
        _versions = versions;
        _gallery = gallery;
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

  String get _bodyText {
    final body = (_details?['body'] as String?) ?? '';
    return body.isEmpty ? widget.project.description : _stripMarkdown(body);
  }

  Future<void> _translate() async {
    if (_translating) return;
    final st = AppScope.of(context);
    final s = st.s;
    if (_translated != null) {
      // Toggle back to original.
      setState(() => _translated = null);
      return;
    }
    setState(() => _translating = true);
    try {
      final text = _bodyText;
      final translated = await TranslateService.translate(text, st.lang);
      if (!mounted) return;
      setState(() {
        _translated = translated;
        _translatedFrom = st.lang == 'ru' ? 'en' : 'auto';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s['translateFailed'])));
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  Future<void> _install() => _installBest();

  Future<GameInstance?> _pickInstance() async {
    final st = AppScope.of(context);
    final s = st.s;
    if (st.instances.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s['noInstances'])));
      return null;
    }
    return showModalBottomSheet<GameInstance>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(s['pickInstance'],
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...st.instances.map((i) => ListTile(
                  leading: LoaderBadge(loader: i.loader, size: 36),
                  title: Text(i.name),
                  subtitle:
                      Text('${i.loaderLabel} • ${i.gameVersion}'),
                  onTap: () => Navigator.pop(ctx, i),
                )),
          ],
        ),
      ),
    );
  }

  CatalogVersion? _bestFor(GameInstance inst) {
    for (final v in _visibleVersions) {
      final gvOk = v.gameVersions.isEmpty ||
          v.gameVersions.contains(inst.gameVersion);
      final loaderOk = v.loaders.isEmpty ||
          inst.loader == 'vanilla' ||
          v.loaders.contains(inst.loader);
      if (gvOk && loaderOk) return v;
    }
    return _visibleVersions.isNotEmpty ? _visibleVersions.first : null;
  }

  List<CatalogVersion> get _visibleVersions => _versions
      .where((v) =>
          _filterVersion == null ||
          v.gameVersions.isEmpty ||
          v.gameVersions.contains(_filterVersion))
      .toList();

  Future<void> _installBest() async {
    if (widget.project.projectType == 'modpack') {
      await _installModpack();
      return;
    }
    final inst = await _pickInstance();
    if (inst == null || !mounted) return;
    final best = _bestFor(inst);
    if (best == null) {
      final s = AppScope.of(context).s;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s['noCompatibleVersion'])));
      return;
    }
    await _installVersionInto(best, inst);
  }

  Future<void> _installVersionInto(
      CatalogVersion v, GameInstance inst) async {
    final st = AppScope.of(context);
    final s = st.s;
    final p = widget.project;
    final folder = InstanceService.folderForType(p.projectType);
    final existing = inst.mods
        .where((m) => m.projectId == p.id && m.folder == folder)
        .toList();
    InstanceService.installMod(
      inst,
      v,
      title: '${p.title} → ${inst.name}',
      iconUrl: p.iconUrl,
      author: p.author,
      versionNumber: v.versionNumber,
      description: p.description,
      downloadUrl: v.downloadUrl,
      folder: folder,
      replace: existing.isEmpty ? null : existing.first,
    );
    // Update or create the tracked entry.
    if (existing.isEmpty) {
      inst.mods.add(ModEntry(
        source: p.source,
        projectId: p.id,
        versionId: v.id,
        name: p.title,
        fileName: v.fileName,
        gameVersions: v.gameVersions,
        loaders: v.loaders,
        iconUrl: p.iconUrl,
        author: p.author,
        versionNumber: v.versionNumber,
        description: p.description,
        downloadUrl: v.downloadUrl,
        fileSize: v.size,
        folder: folder,
        enabled: true,
      ));
    } else {
      final m = existing.first;
      m.versionId = v.id;
      m.fileName = v.fileName;
      m.versionNumber = v.versionNumber;
      m.gameVersions = v.gameVersions;
      m.loaders = v.loaders;
      m.downloadUrl = v.downloadUrl;
      m.fileSize = v.size;
      m.enabled = true;
    }
    await st.saveInstance(inst);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s['installed']}: ${v.versionNumber}')));
  }

  Future<void> _installVersion(CatalogVersion v) async {
    final inst = await _pickInstance();
    if (inst == null || !mounted) return;
    await _installVersionInto(v, inst);
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s['packInstalled']}: ${inst.name}')));
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
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _askPortalus() {
    final p = widget.project;
    final s = AppScope.of(context).s;
    final prompt =
        '${s['askPortalusAbout']}: ${p.title} (${p.source == 'modrinth' ? 'Modrinth' : 'CurseForge'}). ${p.description}';
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PortalusPage(
              initialPrompt: prompt,
              contextInfo: p.title,
            )));
  }

  static String _ptPath(String t) => switch (t) {
        'modpack' => 'modpacks',
        'resourcepack' => 'resourcepacks',
        'shader' => 'shaders',
        'datapack' => 'data-packs',
        _ => 'mods',
      };

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    final p = widget.project;
    final cs = Theme.of(context).colorScheme;
    final fav = st.isFavorite(p.source, p.id);
    final shownVersions = _visibleVersions.take(20).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            title: Text(p.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
                onPressed: () => st.toggleFavorite(p),
                tooltip: fav ? s['removeFavorite'] : s['addFavorite'],
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                onPressed: _askPortalus,
                tooltip: s['askPortalus'],
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: _openWeb,
                tooltip: s['web'],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: p.iconUrl == null
                  ? Container(
                      color: cs.surfaceContainerHighest)
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
                Row(
                  children: [
                    SourceBadge(source: p.source, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${s['byAuthor']} ${p.author} • ${fmtCount(p.downloads)} ${s['downloadsWord']}',
                  style: TextStyle(color: cs.primary),
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

                // Description + translate
                Row(
                  children: [
                    Text(s['description'],
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _translating ? null : _translate,
                      icon: _translating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.translate, size: 18),
                      label: Text(
                        _translated != null
                            ? s['showOriginal']
                            : s['translateButton'],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_translating && _translated == null)
                  const Center(
                       child: Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  )),
                Text(
                  _translated ?? _bodyText,
                  style: const TextStyle(height: 1.4),
                ),
                if (_translated != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${s['translatedFrom']} $_translatedFrom',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                // Gallery
                if (_gallery.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(s['gallery'],
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _gallery.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: _gallery[i],
                          width: 240,
                          height: 150,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 240,
                            color: cs.surfaceContainerHighest,
                          ),
                          errorWidget: (_, __, ___) => const SizedBox(
                              width: 240, child: Icon(Icons.image_outlined)),
                        ),
                      ),
                    ),
                  ),
                ],

                // Versions
                const SizedBox(height: 18),
                Text(s['versions'],
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (_loading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ))
                else if (_error != null)
                  Column(children: [
                    Text('${s['error']}: $_error'),
                    TextButton(onPressed: _load, child: Text(s['retry'])),
                  ])
                else ...[
                  if (_versions.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(s['any']),
                              selected: _filterVersion == null,
                              onSelected: (_) => setState(
                                  () => _filterVersion = null),
                            ),
                          ),
                          ..._topGameVersions
                              .map((v) => Padding(
                                    padding:
                                        const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(v),
                                      selected: _filterVersion == v,
                                      onSelected: (_) => setState(
                                          () => _filterVersion = v),
                                    ),
                                  ))
                              .toList(),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  ...shownVersions.map((v) => Card(
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${_shortDate(v.datePublished)} • ${fmtSize(v.size)}'),
                          trailing: TextButton(
                            onPressed: () => _installVersion(v),
                            child: Text(s['install']),
                          ),
                        ),
                      )),
                ],
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _topGameVersions {
    final counts = <String, int>{};
    for (final v in _versions) {
      for (final gv in v.gameVersions) {
        counts[gv] = (counts[gv] ?? 0) + 1;
      }
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        final pa = _versionWeight(a);
        final pb = _versionWeight(b);
        if (pa != pb) return pb.compareTo(pa);
        return counts[b]!.compareTo(counts[a]!);
      });
    return keys.take(6).toList();
  }

  static int _versionWeight(String v) {
    final parts = v.split('.');
    if (parts.length < 2) return 0;
    final minor = int.tryParse(parts[1]) ?? 0;
    final patch = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
    return minor * 100 + patch;
  }

  static String _shortDate(String d) =>
      d.length >= 10 ? d.substring(0, 10) : d;

  static String _stripMarkdown(String md) {
    var t = md
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)', multiLine: true), '')
        .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)', multiLine: true), r'$1')
        .replaceAll(RegExp(r'[#*_`>~|]'), '')
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    t = t.split('\n').map((l) => l.trim()).join('\n');
    return t.trim();
  }
}
