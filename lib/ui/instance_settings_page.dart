import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/instance_service.dart';
import '../services/mojang.dart';
import '../store.dart';
import '../theme.dart';
import 'widgets/brand_icons.dart';

/// Instance settings: rename, icon, version change, memory, JVM args, notes.
class InstanceSettingsPage extends StatefulWidget {
  final String instanceId;
  const InstanceSettingsPage({super.key, required this.instanceId});

  @override
  State<InstanceSettingsPage> createState() => _InstanceSettingsPageState();
}

class _InstanceSettingsPageState extends State<InstanceSettingsPage> {
  GameInstance? _inst;
  final _name = TextEditingController();
  final _args = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  // Version change state
  List<MojangVersion> _allVersions = [];
  String _versionQuery = '';
  bool _showSnapshots = false;
  bool _showOld = false;
  String? _newVersion;
  String _newLoader = 'vanilla';
  String? _newLoaderVersion;
  List<String> _loaderVersions = [];
  bool _versionsLoading = true;

  static const _loaders = [
    'vanilla',
    'fabric',
    'quilt',
    'forge',
    'neoforge',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    final inst = AppScope.of(context).instanceById(widget.instanceId);
    _inst = inst;
    _name.text = inst?.name ?? '';
    _args.text = inst?.javaArgs ?? '';
    _notes.text = inst?.notes ?? '';
    _newVersion = inst?.gameVersion;
    _newLoader = inst?.loader ?? 'vanilla';
    _newLoaderVersion =
        (inst == null || inst.loaderVersion.isEmpty) ? null : inst.loaderVersion;
    _loadVersions();
  }

  @override
  void dispose() {
    _name.dispose();
    _args.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadVersions() async {
    try {
      final vs = await MojangService.versions();
      if (!mounted) return;
      setState(() {
        _allVersions = vs;
        _versionsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _versionsLoading = false);
    }
  }

  Future<void> _pickLoader(String l) async {
    setState(() {
      _newLoader = l;
      _newLoaderVersion = null;
      _loaderVersions = [];
    });
    if (l == 'vanilla' || _newVersion == null) return;
    try {
      final vs = await MojangService.loaderVersions(_newVersion!, l);
      if (!mounted) return;
      setState(() => _loaderVersions = vs);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_inst == null || _saving) return;
    final st = AppScope.of(context);
    final s = st.s;
    setState(() => _saving = true);
    _inst!.name = _name.text.trim().isEmpty ? _inst!.name : _name.text.trim();
    _inst!.javaArgs = _args.text.trim();
    _inst!.notes = _notes.text;
    if (_newVersion != null &&
        (_newVersion != _inst!.gameVersion ||
            _newLoader != _inst!.loader)) {
      await InstanceService.changeVersion(
        _inst!,
        gameVersion: _newVersion!,
        loader: _newLoader,
        loaderVersion: _newLoaderVersion ?? '',
      );
    }
    await st.saveInstance(_inst!);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s['done'])));
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    if (_inst == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final inst = _inst!;
    final sizeBytes = Store.instanceSizeBytes(inst.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(s['settingsTab']),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(s['save']),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Name + icon
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: s['stepName'],
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(s['pickIcon'],
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: PortalThemes.instanceIcons.entries
                        .map((e) => _IconChoice(
                              icon: e.value,
                              selected: inst.icon == e.key,
                              onTap: () {
                                setState(() => inst.icon = e.key);
                              },
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

          // Version change
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      LoaderBadge(loader: _newLoader, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s['changeVersion'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(s['changeVersionHint'],
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  if (_versionsLoading)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ))
                  else ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s['showSnapshots'],
                          style: const TextStyle(fontSize: 13)),
                      value: _showSnapshots,
                      onChanged: (v) => setState(() => _showSnapshots = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s['showOldVersions'],
                          style: const TextStyle(fontSize: 13)),
                      value: _showOld,
                      onChanged: (v) => setState(() => _showOld = v),
                    ),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        hintText: s['search'],
                      ),
                      onChanged: (v) => setState(() => _versionQuery = v),
                    ),
                    const SizedBox(height: 8),
                    ..._filteredVersions
                        .map((v) => RadioListTile<String>(
                              value: v.id,
                              groupValue: _newVersion,
                              title: Text(v.id),
                              subtitle: Text(v.isRelease
                                  ? s['release']
                                  : v.isSnapshot
                                      ? s['snapshot']
                                      : v.type == 'old_beta'
                                          ? s['oldBeta']
                                          : s['oldAlpha']),
                              dense: true,
                              onChanged: (val) async {
                                setState(() => _newVersion = val);
                                await _pickLoader(_newLoader);
                              },
                            ))
                        .toList(),
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      children: _loaders
                          .map((l) => ChoiceChip(
                                label: Text(l[0].toUpperCase() + l.substring(1)),
                                selected: _newLoader == l,
                                onSelected: (_) => _pickLoader(l),
                              ))
                          .toList(),
                    ),
                    if (_newLoader != 'vanilla') ...[
                      const SizedBox(height: 10),
                      Text('${s['stepLoaderVersion']}:',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      if (_loaderVersions.isEmpty)
                        const Text('—')
                      else
                        ..._loaderVersions.take(8).map(
                              (lv) => RadioListTile<String>(
                                value: lv,
                                groupValue: _newLoaderVersion,
                                title: Text(lv),
                                dense: true,
                                onChanged: (v) =>
                                    setState(() => _newLoaderVersion = v),
                              ),
                            ),
                    ],
                    if (_newVersion != null && _newVersion != inst.gameVersion)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color:
                                    Theme.of(context).colorScheme.error,
                                size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(s['modsMayBreak'],
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),

          // Memory
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${s['memoryLabel']}: ${inst.memoryMb == 0 ? s['memoryAuto'] : '${inst.memoryMb} MB'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(s['memoryHint'],
                      style: Theme.of(context).textTheme.bodySmall),
                  Slider(
                    value: (inst.memoryMb == 0 ? 2048 : inst.memoryMb)
                        .toDouble(),
                    min: 512,
                    max: 8192,
                    divisions: 15,
                    label: inst.memoryMb == 0
                        ? s['memoryAuto']
                        : '${inst.memoryMb} MB',
                    onChanged: (v) =>
                        setState(() => inst.memoryMb = v.round()),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s['memoryAuto'], style: TextStyle(fontSize: 13)),
                    value: inst.memoryMb == 0,
                    onChanged: (v) => setState(() => inst.memoryMb = v ? 0 : 2048),
                  ),
                ],
              ),
            ),
          ),

          // JVM args
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _args,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: s['javaArgs'],
                  hintText: s['javaArgsHint'],
                  prefixIcon: const Icon(Icons.terminal),
                ),
              ),
            ),
          ),

          // Notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _notes,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: s['notesLabel'],
                  hintText: s['notesHint'],
                  prefixIcon: const Icon(Icons.notes),
                ),
              ),
            ),
          ),

          // Storage
          Card(
            child: ListTile(
              leading: const Icon(Icons.sd_storage_outlined),
              title: Text(s['storageUsed']),
              trailing: Text(fmtSize(sizeBytes),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),

          // Duplicate
          Card(
            child: ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: Text(s['duplicate']),
              onTap: () async {
                final st2 = AppScope.of(context);
                final s2 = st2.s;
                final copy = await InstanceService.duplicate(inst);
                await st2.addInstance(copy);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s2['duplicated'])));
              },
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  List<MojangVersion> get _filteredVersions => _allVersions
      .where((v) {
        if (v.isRelease) return true;
        if (v.isSnapshot) return _showSnapshots;
        return _showOld; // old_beta / old_alpha
      })
      .where((v) =>
          _versionQuery.isEmpty ||
          v.id.toLowerCase().contains(_versionQuery.toLowerCase()))
      .take(60)
      .toList();
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _IconChoice(
      {required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? cs.primaryContainer : null,
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Icon(icon,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant),
      ),
    );
  }
}
