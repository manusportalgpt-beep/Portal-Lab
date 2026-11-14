import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/instance_service.dart';
import '../services/mojang.dart';
import '../theme.dart';
import 'widgets/brand_icons.dart';

class CreateInstancePage extends StatefulWidget {
  const CreateInstancePage({super.key});

  @override
  State<CreateInstancePage> createState() => _CreateInstancePageState();
}

class _CreateInstancePageState extends State<CreateInstancePage> {
  final _name = TextEditingController();
  int _step = 0;

  List<MojangVersion> _allVersions = [];
  bool _showSnapshots = false;
  bool _showOld = false;
  String _versionQuery = '';
  String? _selectedVersion;
  String _loader = 'vanilla';
  String? _loaderVersion;
  List<String> _loaderVersions = [];
  bool _loading = true;
  bool _creating = false;
  String? _error;
  String _icon = 'grass';

  static const _loaders = ['vanilla', 'fabric', 'quilt', 'forge', 'neoforge'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final vs = await MojangService.versions();
      if (!mounted) return;
      setState(() {
        _allVersions = vs;
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

  List<MojangVersion> get _filtered => _allVersions
      .where((v) {
        if (v.isRelease) return true;
        if (v.isSnapshot) return _showSnapshots;
        return _showOld;
      })
      .where((v) =>
          _versionQuery.isEmpty ||
          v.id.toLowerCase().contains(_versionQuery.toLowerCase()))
      .take(80)
      .toList();

  Future<void> _pickLoader(String l) async {
    setState(() {
      _loader = l;
      _loaderVersion = null;
      _loaderVersions = [];
    });
    if (l == 'vanilla' || _selectedVersion == null) return;
    try {
      final vs = await MojangService.loaderVersions(_selectedVersion!, l);
      if (!mounted) return;
      setState(() {
        _loaderVersions = vs;
        // Auto-pick the recommended (first) loader version.
        _loaderVersion = vs.isNotEmpty ? vs.first : null;
      });
    } catch (_) {
      if (mounted) setState(() => _loaderVersions = []);
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    final st = AppScope.of(context);
    try {
      final name = _name.text.trim().isEmpty
          ? 'Minecraft $_selectedVersion'
          : _name.text.trim();
      final inst = await InstanceService.create(
        name: name,
        gameVersion: _selectedVersion ?? '1.20.1',
        loader: _loader,
        loaderVersion: _loaderVersion ?? '',
        icon: _icon,
        memoryMb: st.defaultMemoryMb,
      );
      await st.addInstance(inst);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(st.s['created'])));
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${st.s['error']}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    return Scaffold(
      appBar: AppBar(title: Text(s['createTitle'])),
      body: Stepper(
        currentStep: _step,
        physics: const ClampingScrollPhysics(),
        onStepTapped: (i) => setState(() => _step = i),
        onStepContinue: () {
          if (_step < 2) {
            setState(() => _step++);
          } else {
            _create();
          }
        },
        onStepCancel: () {
          if (_step > 0) {
            setState(() => _step--);
          } else {
            Navigator.of(context).pop();
          }
        },
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              FilledButton(
                onPressed: _step == 2 &&
                        (_loader != 'vanilla' && _loaderVersion == null)
                    ? null
                    : details.onStepContinue,
                child: Text(
                    _step == 2 ? s['createInstance'] : s['done']),
              ),
              TextButton(
                onPressed: details.onStepCancel,
                child: Text(_step == 0 ? s['cancel'] : s['back']),
              ),
            ],
          ),
        ),
        steps: [
          Step(
            title: Text(s['stepName']),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: s['stepName'],
                      hintText: s['nameHint'],
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(s['pickIcon'],
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: PortalThemes.instanceIcons.entries
                        .map((e) => _IconDot(
                              icon: e.value,
                              selected: _icon == e.key,
                              onTap: () => setState(() => _icon = e.key),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: Text(s['stepVersion']),
            isActive: _step >= 1,
            state: _step > 1
                ? StepState.complete
                : _step == 1
                    ? StepState.indexed
                    : StepState.disabled,
            content: _buildVersionStep(s),
          ),
          Step(
            title: Text(s['stepLoader']),
            isActive: _step >= 2,
            state: _step == 2 ? StepState.indexed : StepState.disabled,
            content: _buildLoaderStep(s),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionStep(dynamic s) {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Column(children: [
        Text('${s['error']}: $_error'),
        TextButton(onPressed: _load, child: Text(s['retry'])),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s['showSnapshots']),
          value: _showSnapshots,
          onChanged: (v) => setState(() => _showSnapshots = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s['showOldVersions']),
          value: _showOld,
          onChanged: (v) => setState(() => _showOld = v),
        ),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _versionQuery = v),
        ),
        const SizedBox(height: 8),
        ..._filtered.map((v) => RadioListTile<String>(
              value: v.id,
              groupValue: _selectedVersion,
              title: Text(v.id),
              subtitle: Text(v.isRelease
                  ? s['release']
                  : v.isSnapshot
                      ? s['snapshot']
                      : v.type == 'old_beta'
                          ? s['oldBeta']
                          : s['oldAlpha']),
              onChanged: (val) async {
                setState(() => _selectedVersion = val);
                await _pickLoader(_loader);
              },
            )),
      ],
    );
  }

  Widget _buildLoaderStep(dynamic s) {
    final ready = _selectedVersion != null &&
        (_loader == 'vanilla' || _loaderVersion != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _loaders
              .map((l) => ChoiceChip(
                    label: Text(l[0].toUpperCase() + l.substring(1)),
                    avatar: LoaderBadge(loader: l, size: 24),
                    selected: _loader == l,
                    onSelected: (_) => _pickLoader(l),
                  ))
              .toList(),
        ),
        if (_loader != 'vanilla') ...[
          const SizedBox(height: 12),
          Text('${s['stepLoaderVersion']}:'),
          const SizedBox(height: 6),
          if (_loaderVersions.isEmpty)
            const Text('—')
          else
            ..._loaderVersions.take(12).map(
                  (lv) => RadioListTile<String>(
                    value: lv,
                    groupValue: _loaderVersion,
                    title: Text(lv),
                    subtitle: _loaderVersions.first == lv
                        ? Text(s['recommended'],
                            style: const TextStyle(
                                fontSize: 11, color: Colors.green))
                        : null,
                    onChanged: (v) => setState(() => _loaderVersion = v),
                    dense: true,
                  ),
                ),
        ],
        const SizedBox(height: 12),
        if (_creating)
          const Center(child: CircularProgressIndicator())
        else if (ready)
          Card(
            child: ListTile(
              leading: LoaderBadge(loader: _loader, size: 40),
              title: Text(
                  _name.text.trim().isEmpty
                      ? 'Minecraft $_selectedVersion'
                      : _name.text.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${_selectedVersion} • ${_loader[0].toUpperCase()}${_loader.substring(1)}${_loaderVersion == null ? '' : ' $_loaderVersion'}'),
            ),
          ),
      ],
    );
  }
}

class _IconDot extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _IconDot(
      {required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? cs.primaryContainer : null,
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Icon(icon,
            size: 22,
            color:
                selected ? cs.onPrimaryContainer : cs.onSurfaceVariant),
      ),
    );
  }
}
