import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/instance_service.dart';
import '../services/mojang.dart';

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
  String _versionQuery = '';
  String? _selectedVersion;
  String _loader = 'vanilla';
  String? _loaderVersion;
  List<String> _loaderVersions = [];
  bool _loading = true;
  bool _creating = false;
  String? _error;

  static const _loaders = [
    ('vanilla', 'Vanilla', Icons.grass),
    ('fabric', 'Fabric', Icons.auto_awesome),
    ('quilt', 'Quilt', Icons.auto_awesome_outlined),
    ('forge', 'Forge', Icons.build),
    ('neoforge', 'NeoForge', Icons.build_circle_outlined),
  ];

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
      .where((v) => _showSnapshots || v.isRelease)
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
      setState(() => _loaderVersions = vs);
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
        onStepContinue: () {
          if (_step < 2) {
            setState(() => _step++);
          } else {
            _create();
          }
        },
        onStepCancel: () {
          if (_step > 0) setState(() => _step--);
        },
        steps: [
          Step(
            title: Text(s['stepName']),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: s['stepName'],
                  hintText: s['nameHint'],
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
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
              subtitle: Text(v.isRelease ? s['release'] : s['snapshot']),
              onChanged: (val) => setState(() => _selectedVersion = val),
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
          children: _loaders
              .map((l) => ChoiceChip(
                    label: Text(l.$2),
                    avatar: Icon(l.$3, size: 18),
                    selected: _loader == l.$1,
                    onSelected: (_) => _pickLoader(l.$1),
                  ))
              .toList(),
        ),
        if (_loader != 'vanilla') ...[
          const SizedBox(height: 12),
          Text('${s['stepLoaderVersion']}'),
          const SizedBox(height: 6),
          if (_loaderVersions.isEmpty)
            const Text('—')
          else
            ..._loaderVersions.take(12).map(
                  (lv) => RadioListTile<String>(
                    value: lv,
                    groupValue: _loaderVersion,
                    title: Text(lv),
                    onChanged: (v) => setState(() => _loaderVersion = v),
                    dense: true,
                  ),
                ),
        ],
        const SizedBox(height: 12),
        if (_creating)
          const Center(child: CircularProgressIndicator())
        else
          FilledButton.icon(
            onPressed: ready ? _create : null,
            icon: const Icon(Icons.check),
            label: Text(s['createInstance']),
          ),
      ],
    );
  }
}
