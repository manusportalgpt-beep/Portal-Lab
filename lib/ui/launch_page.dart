import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/instance_service.dart';
import '../services/pojav.dart';
import '../store.dart';
import 'accounts_page.dart';
import 'controls_page.dart';
import 'instance_settings_page.dart';
import 'widgets/brand_icons.dart';

/// The launch screen: pre-flight checks, account, memory, Pojav handover.
class LaunchPage extends StatefulWidget {
  final String instanceId;
  const LaunchPage({super.key, required this.instanceId});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  GameInstance? _inst;
  bool _checking = true;
  bool _exporting = false;
  String? _exportedPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    final st = AppScope.of(context);
    final inst = st.instanceById(widget.instanceId);
    if (inst != null) {
      // Pre-flight: make sure all standard folders exist.
      await Store.saveInstance(inst);
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _inst = inst;
      _checking = false;
    });
  }

  Future<void> _exportMrpack() async {
    if (_inst == null || _exporting) return;
    final s = AppScope.of(context).s;
    setState(() => _exporting = true);
    try {
      final path = await InstanceService.exportMrpack(_inst!);
      await InstanceService.markPlayed(_inst!);
      if (!mounted) return;
      setState(() {
        _exportedPath = path;
        _exporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s['exported']}: $path')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s['error']}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    final inst = _inst ?? st.instanceById(widget.instanceId);
    if (inst == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final acc = st.activeAccount;
    final isAndroid = Platform.isAndroid;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s['launchTitle'])),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Instance card
          Card(
            child: ListTile(
              leading: LoaderBadge(loader: inst.loader, size: 46),
              title: Text(inst.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 17)),
              subtitle: Text(
                  '${inst.loaderLabel} ${inst.loaderVersion.isEmpty ? '' : inst.loaderVersion} • MC ${inst.gameVersion}'),
              trailing: IconButton(
                tooltip: s['settingsTab'],
                icon: const Icon(Icons.tune),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        InstanceSettingsPage(instanceId: inst.id))),
              ),
            ),
          ),

          // Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_checking)
                    const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 3))
                  else
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _checking ? s['checkingFiles'] : s['readyToLaunch'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!_checking)
                    Badge(
                      label: Text('${inst.mods.length}'),
                      child: const Icon(Icons.extension_outlined),
                    ),
                ],
              ),
            ),
          ),

          // Account
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Text(
                  (acc?.username.isEmpty ?? true)
                      ? '?'
                      : acc!.username[0].toUpperCase(),
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(acc?.username ?? s['notSelected']),
              subtitle: Text(
                  '${s['accountLabel']} • ${acc == null ? s['addAccount'] : (acc.isMsa ? s['msAccount'] : s['offlineAccount'])}'),
              trailing: TextButton(
                onPressed: () => openAccounts(context),
                child: Text(s['selectAccount']),
              ),
            ),
          ),

          // Memory quick info
          Card(
            child: ListTile(
              leading: const Icon(Icons.memory_outlined),
              title: Text(
                  '${s['memoryLabel']}: ${inst.memoryMb == 0 ? s['memoryAuto'] : '${inst.memoryMb} MB'}'),
              subtitle: Text(s['memoryHint']),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      InstanceSettingsPage(instanceId: inst.id))),
            ),
          ),

          const SizedBox(height: 8),

          if (!isAndroid) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(s['launchIos'],
                            style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Main launch actions
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: _exporting ? null : _exportMrpack,
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.archive),
              label: Text(
                  _exporting ? s['exporting'] : s['exportForPojav']),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: () async {
                await PojavService.openOrInstall();
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(s['launchInPojav']),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ControlsPage())),
              icon: const Icon(Icons.gamepad_outlined),
              label: Text(s['controlsTitle']),
            ),

            // Guide
            const SizedBox(height: 16),
            Text(s['pojavGuide'],
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GuideStep(n: 1, text: s['pojavStep1']),
                    _GuideStep(n: 2, text: s['pojavStep2']),
                    _GuideStep(n: 3, text: s['pojavStep3']),
                    _GuideStep(n: 4, text: s['pojavStep4']),
                  ],
                ),
              ),
            ),
            if (_exportedPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  '${s['exportPath']}: $_exportedPath',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            TextButton.icon(
              onPressed: () async {
                await PojavService.openStore();
              },
              icon: const Icon(Icons.shop_outlined),
              label: Text(s['openStore']),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int n;
  final String text;
  const _GuideStep({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer,
            ),
            alignment: Alignment.center,
            child: Text('$n',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}
