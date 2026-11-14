import 'dart:io' show Platform;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../models.dart';
import '../services/curseforge.dart';
import '../services/instance_service.dart';
import '../services/modrinth.dart';
import '../store.dart';
import '../theme.dart';
import 'controls_page.dart';
import 'instance_settings_page.dart';
import 'launch_page.dart';
import 'portalus_page.dart';
import 'widgets/brand_icons.dart';

class InstanceDetailPage extends StatefulWidget {
  final String instanceId;
  const InstanceDetailPage({super.key, required this.instanceId});

  @override
  State<InstanceDetailPage> createState() => _InstanceDetailPageState();
}

class _InstanceDetailPageState extends State<InstanceDetailPage> {
  GameInstance? _inst;
  List<ModEntry> _entries = [];
  String _folder = 'mods';
  bool _exporting = false;
  bool _checkingUpdates = false;
  Map<String, CatalogVersion> _updates = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() {
    final st = AppScope.of(context);
    final inst = st.instanceById(widget.instanceId);
    setState(() => _inst = inst);
    if (inst != null) {
      InstanceService.scanFolder(inst, _folder).then((f) {
        if (mounted) setState(() => _entries = f);
      });
    }
  }

  Future<void> _scan() async {
    final inst = _inst;
    if (inst == null) return;
    final entries = await InstanceService.scanFolder(inst, _folder);
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _export({required bool mrpack}) async {
    if (_inst == null || _exporting) return;
    final s = AppScope.of(context).s;
    setState(() => _exporting = true);
    try {
      final path = mrpack
          ? await InstanceService.exportMrpack(_inst!)
          : await InstanceService.exportZip(_inst!);
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

  Future<void> _toggleMod(ModEntry m, bool value) async {
    final st = AppScope.of(context);
    await InstanceService.setModEnabled(_inst!, m, value);
    await st.saveInstance(_inst!);
    await _scan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(value ? st.s['modEnabled'] : st.s['modDisabled'])));
  }

  Future<void> _removeMod(ModEntry m) async {
    final s = AppScope.of(context).s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s['removeModQ']),
        content: Text(m.name),
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
    await InstanceService.removeModFile(_inst!, m.fileName,
        folder: m.folder);
    await AppScope.of(context).saveInstance(_inst!);
    await _scan();
  }

  Future<void> _checkUpdates() async {
    if (_inst == null || _checkingUpdates) return;
    final s = AppScope.of(context).s;
    setState(() => _checkingUpdates = true);
    final updates = await InstanceService.checkUpdates(_inst!);
    if (!mounted) return;
    setState(() {
      _updates = {
        for (final u in updates)
          '${u.mod.source}:${u.mod.projectId}': u.version
      };
      _checkingUpdates = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(updates.isEmpty
            ? s['allUpdated']
            : '${s['updatesFound']}: ${updates.length}')));
  }

  Future<void> _updateAll() async {
    final st = AppScope.of(context);
    final s = st.s;
    if (_updates.isEmpty) return;
    for (final e in _entries) {
      final v = _updates['${e.source}:${e.projectId}'];
      if (v != null) {
        InstanceService.applyUpdate(_inst!, ModUpdate(e, v));
      }
    }
    await st.saveInstance(_inst!);
    setState(() => _updates = {});
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s['updatingMods'])));
    await Future.delayed(const Duration(seconds: 2));
    await _scan();
  }

  Future<void> _changeModVersion(ModEntry m) async {
    final st = AppScope.of(context);
    final s = st.s;
    if (m.projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s['noCompatibleVersion'])));
      return;
    }
    try {
      final List<CatalogVersion> versions;
      if (m.source == 'modrinth') {
        versions = await ModrinthService.versions(m.projectId);
      } else {
        versions = await CurseForgeService.versions(m.projectId);
      }
      final picked = await showModalBottomSheet<CatalogVersion>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s['changeModVersion'],
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              ...versions.take(25).map((v) => ListTile(
                    leading: Icon(
                        v.versionType == 'release'
                            ? Icons.verified
                            : Icons.science_outlined,
                        size: 20,
                        color: v.versionType == 'release'
                            ? Colors.green
                            : Colors.orange),
                    title: Text(v.versionNumber,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                        '${v.gameVersions.join(', ')} • ${v.loaders.join(', ')}',
                        style: const TextStyle(fontSize: 11)),
                    trailing: v.id == m.versionId
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(ctx, v),
                  )),
            ],
          ),
        ),
      );
      if (picked == null || !mounted) return;
      InstanceService.applyUpdate(_inst!, ModUpdate(m, picked));
      await st.saveInstance(_inst!);
      await _scan();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s['installed']}: ${picked.versionNumber}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s['error']}: $e')));
    }
  }

  void _askPortalusAboutMod(ModEntry m) {
    final s = AppScope.of(context).s;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PortalusPage(
              initialPrompt:
                  '${s['tellAboutMod']}: ${m.name}${m.author == null ? '' : ' (${s['byAuthor']} ${m.author})'}. ${m.description ?? ''}',
              contextInfo: m.name,
            )));
  }

  void _askPortalusAboutInstance() {
    final s = AppScope.of(context).s;
    final inst = _inst!;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PortalusPage(
              initialPrompt:
                  '${s['qqNotLaunching']}? ${inst.name}: MC ${inst.gameVersion}, ${inst.loaderLabel} ${inst.loaderVersion}, ${inst.mods.length} mods.',
              contextInfo: inst.name,
            )));
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
    final icon = PortalThemes.instanceIcons[inst.icon] ??
        Icons.grid_view;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(inst.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'export_zip') _export(mrpack: false);
                if (v == 'export_mrpack') _export(mrpack: true);
                if (v == 'delete') _delete();
                if (v == 'portalus') _askPortalusAboutInstance();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                    value: 'export_zip',
                    child: Text(s['exportZip'])),
                PopupMenuItem(
                    value: 'export_mrpack',
                    child: Text(s['exportMrpack'])),
                PopupMenuItem(
                    value: 'portalus',
                    child: Text(s['askPortalus'])),
                PopupMenuItem(
                    value: 'delete',
                    child: Text(s['delete'])),
              ],
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: s['overview']),
            Tab(text: s['modsTab']),
            Tab(text: s['settingsTab']),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final st = AppScope.of(context);
            await st.setLastInstance(inst.id);
            if (!context.mounted) return;
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LaunchPage(instanceId: inst.id)));
          },
          icon: const Icon(Icons.play_arrow),
          label: Text(s['play']),
        ),
        body: TabBarView(
          children: [
            _buildOverview(context, inst, s),
            _buildMods(context, inst, s),
            _buildSettings(context, inst, s),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(BuildContext context, GameInstance inst, S s) {
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
                          value: '${inst.mods.length}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.play_circle_outline,
                color: Theme.of(context).colorScheme.primary),
            title: Text(s['launcherViaPojav']),
            subtitle: Text(
              Platform.isAndroid ? s['launchAndroid'] : s['launchIos'],
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.gamepad_outlined),
            title: Text(s['controlsTitle']),
            subtitle: Text(s['controlsHint'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ControlsPage())),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ],
    );
  }

  Widget _buildMods(BuildContext context, GameInstance inst, S s) {
    return Column(
      children: [
        // Folder chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              for (final f in [
                ('mods', s['modsTab']),
                ('resourcepacks', s['typeResourcepack']),
                ('shaderpacks', s['typeShader']),
                ('datapacks', s['typeDatapack']),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.$2),
                    selected: _folder == f.$1,
                    onSelected: (_) {
                      setState(() => _folder = f.$1);
                      _scan();
                    },
                  ),
                ),
            ],
          ),
        ),
        // Update bar
        if (_folder == 'mods')
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _checkingUpdates ? null : _checkUpdates,
                    icon: _checkingUpdates
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.update, size: 18),
                    label: Text(
                        _checkingUpdates
                            ? s['checkingUpdates']
                            : s['checkUpdates'],
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
                if (_updates.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _updateAll,
                    child: Text(
                        '${s['updateAll']} (${_updates.length})',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: _entries.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.extension_outlined, size: 72),
                    const SizedBox(height: 12),
                    Text(s['noMods'],
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(s['noModsHint'], textAlign: TextAlign.center),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _scan,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                    itemCount: _entries.length,
                    itemBuilder: (context, i) {
                      final m = _entries[i];
                      return _ModTile(
                        mod: m,
                        hasUpdate:
                            _updates.containsKey('${m.source}:${m.projectId}'),
                        onToggle: (v) => _toggleMod(m, v),
                        onChangeVersion: () => _changeModVersion(m),
                        onAsk: () => _askPortalusAboutMod(m),
                        onDelete: () => _removeMod(m),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSettings(BuildContext context, GameInstance inst, S s) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: Text(s['instanceSettings']),
            subtitle: Text(
                '${s['changeVersion']} • ${s['memoryLabel']} • ${s['javaArgs']} • ${s['notesLabel']}'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    InstanceSettingsPage(instanceId: inst.id))),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: Text(s['exportZip']),
            subtitle: Text(Store.exportsDir.path,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: _exporting ? null : () => _export(mrpack: false),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_zip_outlined),
            title: Text(s['exportMrpack']),
            subtitle: Text('PojavLauncher'),
            onTap: _exporting ? null : () => _export(mrpack: true),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: Text(s['duplicate']),
            onTap: () async {
              final st = AppScope.of(context);
              final copy = await InstanceService.duplicate(inst);
              await st.addInstance(copy);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(st.s['duplicated'])));
            },
          ),
        ),
      ],
    );
  }
}

class _ModTile extends StatelessWidget {
  final ModEntry mod;
  final bool hasUpdate;
  final void Function(bool) onToggle;
  final VoidCallback onChangeVersion;
  final VoidCallback onAsk;
  final VoidCallback onDelete;

  const _ModTile({
    required this.mod,
    required this.hasUpdate,
    required this.onToggle,
    required this.onChangeVersion,
    required this.onAsk,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    final cs = Theme.of(context).colorScheme;
    final updateLabel = hasUpdate ? ' ${s['update']}' : '';
    return Card(
      child: Opacity(
        opacity: mod.enabled ? 1.0 : 0.55,
        child: ListTile(
          contentPadding:
              const EdgeInsets.only(left: 12, right: 4),
          leading: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: mod.iconUrl != null
                    ? CachedNetworkImage(
                        imageUrl: mod.iconUrl!,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 46,
                          height: 46,
                          color: cs.surfaceContainerHighest,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 46,
                          height: 46,
                          color: cs.primaryContainer,
                          child: Icon(Icons.extension,
                              size: 22, color: cs.onPrimaryContainer),
                        ),
                      )
                    : Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.extension,
                            size: 22, color: cs.onPrimaryContainer),
                      ),
              ),
              if (mod.source != 'local')
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: SourceBadge(source: mod.source, size: 16),
                ),
            ],
          ),
          title: Text(
            mod.name + updateLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: hasUpdate ? cs.primary : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mod.author != null || mod.versionNumber != null)
                Text(
                  [
                    if (mod.author != null && mod.author!.isNotEmpty)
                      '${s['authorLabel']}: ${mod.author}',
                    if (mod.versionNumber != null)
                      '${s['versionLabel']}: ${mod.versionNumber}',
                  ].join(' • '),
                  style: const TextStyle(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                '${s['fileLabel']}: ${mod.fileName}',
                style: const TextStyle(fontSize: 10.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: mod.enabled,
                onChanged: onToggle,
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'change') onChangeVersion();
                  if (v == 'ask') onAsk();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'change', child: Text(s['changeModVersion'])),
                  PopupMenuItem(value: 'ask', child: Text(s['tellAboutMod'])),
                  PopupMenuItem(value: 'delete', child: Text(s['delete'])),
                ],
              ),
            ],
          ),
        ),
      ),
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
