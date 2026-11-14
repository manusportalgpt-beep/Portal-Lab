import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app_state.dart';
import '../models.dart';
import '../services/net.dart';
import '../services/skins.dart';
import '../store.dart';
import 'widgets/player_head.dart';

/// Skin management for a single account.
///
/// Microsoft accounts: the skin is uploaded through the official Minecraft
/// Services API — every player on servers sees it. Offline accounts: a
/// device-only local override (launcher icons and preview); other players
/// keep seeing the standard offline skin by nickname.
class SkinPage extends StatefulWidget {
  final McAccount account;
  const SkinPage({super.key, required this.account});

  @override
  State<SkinPage> createState() => _SkinPageState();
}

class _SkinPageState extends State<SkinPage> {
  int _source = 0; // 0 = url, 1 = player, 2 = file
  String _variant = 'classic';
  bool _busy = false;
  final _urlCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  List<String> _files = [];
  String? _pickedFile;
  PlayerSkin? _foundSkin;
  String? _previewUrl;
  String? _previewPath;

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    final m = acc.localSkinModel ?? acc.skinModel;
    _variant = m ??
        (SkinService.defaultSlim(acc.uuid) ? 'slim' : 'classic');
    _scanFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMsaProfile());
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  McAccount get acc => widget.account;

  void _scanFiles() {
    final out = <String>[];
    for (final dir in [Store.exportsDir, SkinService.skinsDir]) {
      try {
        if (!dir.existsSync()) continue;
        for (final e in dir.listSync()) {
          if (e is File && e.path.toLowerCase().endsWith('.png')) {
            out.add(e.path);
          }
        }
      } catch (_) {}
    }
    out.sort();
    setState(() => _files = out);
  }

  /// Silently refresh the Microsoft profile (active skin) on open.
  Future<void> _refreshMsaProfile() async {
    if (!acc.isMsa || acc.accessToken == null) return;
    try {
      final (prof, fresh) = await SkinService.withTokenRefresh(
          acc, (t) => SkinService.ownProfile(t));
      if (!mounted || prof.isEmpty) return;
      final updated = SkinService.applyProfile(fresh ?? acc, prof);
      await AppScope.of(context).updateAccount(updated);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _ok(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _findPlayer() async {
    final s = AppScope.of(context).s;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final skin = await SkinService.skinByName(name);
      if (!mounted) return;
      if (skin == null) {
        _err(s['skinPlayerNotFound']);
        return;
      }
      setState(() {
        _foundSkin = skin;
        _previewUrl = skin.url;
        _previewPath = null;
        _variant = skin.variant == 'slim' ? 'slim' : 'classic';
      });
      _ok(s['skinFound']);
    } catch (e) {
      _err('${s['error']}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final st = AppScope.of(context);
    final s = st.s;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (acc.isMsa) {
        if (acc.accessToken == null) {
          _err(s['skinNeedMsa']);
          return;
        }
        String? url;
        File? file;
        if (_source == 0) {
          url = _urlCtrl.text.trim();
          if (url.isEmpty) {
            _err(s['skinUrlHint']);
            return;
          }
        } else if (_source == 1) {
          url = _foundSkin?.url;
          if (url == null) {
            _err(s['skinPlayerNotFound']);
            return;
          }
        } else {
          if (_pickedFile == null) {
            _err(s['skinFilesTitle']);
            return;
          }
          file = File(_pickedFile!);
        }
        final (prof, fresh) =
            await SkinService.withTokenRefresh(acc, (t) async {
          if (file != null) {
            return SkinService.uploadFromFile(t, file, _variant);
          }
          return SkinService.uploadFromUrl(t, url!, _variant);
        });
        final base = fresh ?? acc;
        if (prof.isNotEmpty) {
          SkinService.applyProfile(base, prof);
        } else {
          final (p2, f2) = await SkinService.withTokenRefresh(
              base, (t) => SkinService.ownProfile(t));
          SkinService.applyProfile(f2 ?? base, p2);
        }
        await st.updateAccount(base);
        if (!mounted) return;
        setState(() {});
        _ok(s['skinUploaded']);
      } else {
        List<int> bytes;
        if (_source == 2) {
          if (_pickedFile == null) {
            _err(s['skinFilesTitle']);
            return;
          }
          bytes = await File(_pickedFile!).readAsBytes();
        } else {
          final url =
              _source == 0 ? _urlCtrl.text.trim() : _foundSkin?.url;
          if (url == null || url.isEmpty) {
            _err(_source == 1 ? s['skinPlayerNotFound'] : s['skinUrlHint']);
            return;
          }
          bytes = await SkinService.downloadSkinBytes(url);
        }
        await SkinService.applyLocalSkin(acc, bytes, _variant);
        await st.updateAccount(acc);
        if (!mounted) return;
        setState(() {
          _previewPath = acc.localSkinPath;
          _previewUrl = null;
        });
        _ok(s['skinLocalSaved']);
      }
    } on FormatException {
      _err(s['skinBadPng']);
    } on HttpError catch (e) {
      _err('${s['error']}: $e');
    } catch (e) {
      _err('${s['error']}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final st = AppScope.of(context);
    final s = st.s;
    if (_busy || !acc.isMsa) return;
    setState(() => _busy = true);
    try {
      final (prof, fresh) = await SkinService.withTokenRefresh(
          acc, (t) => SkinService.resetToDefault(t));
      final base = fresh ?? acc;
      if (prof.isNotEmpty) {
        SkinService.applyProfile(base, prof);
      } else {
        final (p2, f2) = await SkinService.withTokenRefresh(
            base, (t) => SkinService.ownProfile(t));
        SkinService.applyProfile(f2 ?? base, p2);
      }
      await st.updateAccount(base);
      if (!mounted) return;
      setState(() {});
      _ok(s['skinResetDone']);
    } catch (e) {
      _err('${s['error']}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeLocal() async {
    final st = AppScope.of(context);
    final s = st.s;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SkinService.clearLocalSkin(acc);
      await st.updateAccount(acc);
      if (!mounted) return;
      setState(() {
        _previewPath = null;
      });
      _ok(s['skinLocalRemoved']);
    } catch (e) {
      _err('${s['error']}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    final cs = Theme.of(context).colorScheme;
    final previewUrl = _previewUrl ?? (_previewPath == null ? acc.skinUrl : null);
    final previewPath = _previewPath ?? acc.localSkinPath;
    final localActive = acc.localSkinPath != null;
    final isMsa = acc.isMsa;

    return Scaffold(
      appBar: AppBar(title: Text(s['skinsTitle'])),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Preview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  PlayerBody(
                    skinUrl: previewUrl,
                    skinPath: previewPath,
                    name: acc.username,
                    uuid: acc.uuid,
                    slim: _variant == 'slim',
                    height: 170,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlayerHead(
                          skinUrl: previewUrl,
                          skinPath: previewPath,
                          name: acc.username,
                          uuid: acc.uuid,
                          size: 56,
                          radius: 10,
                          slim: _variant == 'slim',
                        ),
                        const SizedBox(height: 10),
                        Text(acc.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 17)),
                        Text(isMsa ? s['msAccount'] : s['offlineAccount'],
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        if (isMsa)
                          Chip(
                            avatar: const Icon(Icons.cloud_done_outlined,
                                size: 16),
                            label: Text(acc.skinUrl != null
                                ? s['skinCurrentMsa']
                                : s['skinCurrentDefault']),
                            visualDensity: VisualDensity.compact,
                          )
                        else if (localActive)
                          Chip(
                            avatar: Icon(Icons.smartphone_outlined,
                                size: 16, color: cs.primary),
                            label: Text(s['skinLocalActive']),
                            visualDensity: VisualDensity.compact,
                          )
                        else
                          Chip(
                            avatar: const Icon(Icons.help_outline, size: 16),
                            label: Text(s['skinCurrentDefault']),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Model
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['skinModel'],
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'classic', label: Text(s['skinClassic'])),
                      ButtonSegment(
                          value: 'slim', label: Text(s['skinSlim'])),
                    ],
                    selected: {_variant},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) =>
                        setState(() => _variant = v.first),
                  ),
                ],
              ),
            ),
          ),

          // Source
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['skinSource'],
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                          value: 0,
                          label: Text(s['skinFromUrl']),
                          icon: const Icon(Icons.link, size: 16)),
                      ButtonSegment(
                          value: 1,
                          label: Text(s['skinFromPlayer']),
                          icon: const Icon(Icons.person_search_outlined,
                              size: 16)),
                      ButtonSegment(
                          value: 2,
                          label: Text(s['skinFromFile']),
                          icon: const Icon(Icons.folder_outlined, size: 16)),
                    ],
                    selected: {_source},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() {
                      _source = v.first;
                      _foundSkin = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (_source == 0) ...[
                    TextField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: s['skinFromUrl'],
                        hintText: s['skinUrlHint'],
                        prefixIcon: const Icon(Icons.link),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          final u = _urlCtrl.text.trim();
                          if (u.isEmpty) return;
                          setState(() {
                            _previewUrl = u;
                            _previewPath = null;
                          });
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: Text(s['skinPreviewUrl']),
                      ),
                    ),
                  ] else if (_source == 1) ...[
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: s['skinPlayerHint'],
                        prefixIcon: const Icon(Icons.person_search_outlined),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _findPlayer(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _findPlayer,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.search, size: 18),
                        label: Text(s['skinFind']),
                      ),
                    ),
                    if (_foundSkin != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${s['skinFound']}: ${_nameCtrl.text.trim()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ] else ...[
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(s['skinFilesTitle']),
                      trailing: IconButton(
                        tooltip: s['skinRefresh'],
                        onPressed: _scanFiles,
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                    if (_files.isEmpty)
                      Text(s['skinNoFiles'],
                          style: Theme.of(context).textTheme.bodySmall)
                    else
                      for (final f in _files)
                        ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          leading: const Icon(Icons.image_outlined),
                          title: Text(p.basename(f),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          selected: _pickedFile == f,
                          selectedTileColor: cs.primaryContainer.withOpacity(0.3),
                          trailing: _pickedFile == f
                              ? const Icon(Icons.check_circle)
                              : null,
                          onTap: () => setState(() {
                            _pickedFile = f;
                            _previewPath = f;
                            _previewUrl = null;
                          }),
                        ),
                  ],
                ],
              ),
            ),
          ),

          // Actions
          if (isMsa) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: _busy ? null : _apply,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(s['skinApplyMsa']),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _reset,
              icon: const Icon(Icons.restart_alt),
              label: Text(s['skinReset']),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.public, size: 18, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(s['skinApplyMsaHint'],
                            style: const TextStyle(fontSize: 12.5))),
                  ],
                ),
              ),
            ),
          ] else ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: _busy ? null : _apply,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_for_offline_outlined),
              label: Text(s['skinApplyLocal']),
            ),
            if (localActive) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _removeLocal,
                icon: const Icon(Icons.link_off),
                label: Text(s['skinRemoveLocal']),
              ),
            ],
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.smartphone_outlined,
                        size: 18, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(s['skinApplyLocalHint'],
                            style: const TextStyle(fontSize: 12.5))),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
