import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/msa.dart';
import 'msa_login_page.dart';

/// Opens the accounts page from anywhere.
void openAccounts(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AccountsPage()),
  );
}

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
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
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A4EF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.login,
                    color: Color(0xFF00A4EF)),
              ),
              title: Text(s['msLogin'],
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Xbox Live • Minecraft Java'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MsaLoginPage())),
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
    final cs = Theme.of(context).colorScheme;
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
        subtitle: Text(account.isMsa
            ? '${s['msAccount']} • ${s['active']}'
            : s['offlineAccount']),
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
        tileColor: active ? cs.primaryContainer.withOpacity(0.25) : null,
      ),
    );
  }
}
