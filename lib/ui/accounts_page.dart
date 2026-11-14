import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/msa.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  bool _msaBusy = false;
  DeviceCode? _deviceCode;
  String? _msaError;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    return Scaffold(
      appBar: AppBar(title: Text(s['accounts'])),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Add Microsoft
          Card(
            child: _msaBusy
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_deviceCode != null) ...[
                          Text(s['msLoginHint'],
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          SelectableText(
                            _deviceCode!.userCode,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 4,
                                    color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => _openUrl(_deviceCode!.verificationUrl),
                            icon: const Icon(Icons.open_in_new),
                            label: Text(s['openMsPage']),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(s['waitingCode']),
                            ],
                          ),
                        ] else
                          const Center(child: CircularProgressIndicator()),
                        if (_msaError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_msaError!,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error)),
                          ),
                      ],
                    ),
                  )
                : ListTile(
                    leading: const Icon(Icons.microsoft_outlined),
                    title: Text(s['msLogin']),
                    subtitle: const Text('Xbox Live • Minecraft Java'),
                    onTap: _startMsa,
                  ),
          ),
          // Add offline
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(s['addOffline']),
              onTap: _addOffline,
            ),
          ),
          const SizedBox(height: 8),
          // Accounts list
          ...st.accounts.map((a) => _AccountTile(
                account: a,
                active: a.uuid == st.activeAccountUuid,
                onSetActive: () async {
                  await st.setActiveAccount(a.uuid);
                },
                onRefresh: () => _refresh(a),
                onRemove: () async {
                  await st.removeAccount(a.uuid);
                },
              )),
        ],
      ),
    );
  }

  Future<void> _startMsa() async {
    final st = AppScope.of(context);
    setState(() {
      _msaBusy = true;
      _msaError = null;
      _deviceCode = null;
    });
    try {
      final dc = await MsaService.startDeviceCode();
      if (!mounted) return;
      setState(() => _deviceCode = dc);
      _openUrl(dc.verificationUrl);
      final acc = await MsaService.login(dc);
      await st.addAccount(acc);
      if (!mounted) return;
      setState(() => _msaBusy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msaError = e.toString();
      });
      // keep busy=false so user can retry
      setState(() => _msaBusy = false);
    }
  }

  Future<void> _refresh(McAccount acc) async {
    final st = AppScope.of(context);
    final s = st.s;
    final fresh = await MsaService.refresh(acc);
    if (!mounted) return;
    if (fresh != null) {
      await st.updateAccount(fresh);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s['refreshed'])));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s['refreshFailed'])));
    }
  }

  Future<void> _addOffline() async {
    final st = AppScope.of(context);
    final s = st.s;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s['addOffline']),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: s['offlineName']),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s['cancel'])),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(s['ok'])),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final uuidName = name.toLowerCase();
    var h = 0;
    for (final c in uuidName.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final uuid =
        '${_hex4(h)}0000-4000-8000-${_hex4(h >> 16)}${_hex4(h * 7)}';
    final acc = McAccount(
      uuid: uuid,
      username: name,
      type: 'offline',
    );
    await st.addAccount(acc);
  }

  static String _hex4(int v) =>
      (v & 0xffff).toRadixString(16).padLeft(4, '0');

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }
}

class _AccountTile extends StatelessWidget {
  final McAccount account;
  final bool active;
  final VoidCallback onSetActive;
  final VoidCallback onRefresh;
  final VoidCallback onRemove;

  const _AccountTile({
    required this.account,
    required this.active,
    required this.onSetActive,
    required this.onRefresh,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    return Card(
      child: ListTile(
        leading: account.skinUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: account.skinUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              )
            : CircleAvatar(
                child: Text(account.username.isEmpty
                    ? '?'
                    : account.username[0].toUpperCase()),
              ),
        title: Text(account.username,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(account.isMsa ? s['msAccount'] : s['offlineAccount']),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'active') onSetActive();
            if (v == 'refresh') onRefresh();
            if (v == 'remove') onRemove();
          },
          itemBuilder: (ctx) => [
            if (!active)
              PopupMenuItem(value: 'active', child: Text(s['setActive'])),
            if (account.isMsa)
              PopupMenuItem(value: 'refresh', child: Text(s['refresh'])),
            PopupMenuItem(value: 'remove', child: Text(s['remove'])),
          ],
        ),
        onTap: onSetActive,
      ),
    );
  }
}
