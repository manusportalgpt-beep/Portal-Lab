import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/msa.dart';

/// A dedicated Microsoft sign-in window: code, steps, live status.
class MsaLoginPage extends StatefulWidget {
  final void Function(McAccount)? onSuccess;
  const MsaLoginPage({super.key, this.onSuccess});

  @override
  State<MsaLoginPage> createState() => _MsaLoginPageState();
}

class _MsaLoginPageState extends State<MsaLoginPage> {
  DeviceCode? _deviceCode;
  String? _error;
  bool _starting = true;
  bool _done = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
      _deviceCode = null;
    });
    try {
      final dc = await MsaService.startDeviceCode();
      if (!mounted) return;
      setState(() {
        _deviceCode = dc;
        _starting = false;
      });
      final acc = await MsaService.login(dc);
      if (!mounted) return;
      await AppScope.of(context).addAccount(acc);
      if (!mounted) return;
      setState(() => _done = true);
      widget.onSuccess?.call(acc);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openUrl(String url) async {
    setState(() => _opening = true);
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s['msLoginTitle'])),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.key_rounded, size: 44),
              ),
              const SizedBox(height: 16),
              Text(
                s['msLogin'],
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                s['secureNote'],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),

              if (_starting && _deviceCode == null)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),

              if (_deviceCode != null && !_done) ...[
                // Step 1: the code
                _StepCard(
                  n: 1,
                  title: s['msStep1'],
                  child: Column(
                    children: [
                      SelectableText(
                        _deviceCode!.userCode,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              color: cs.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text: _deviceCode!.userCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(s['copied'])));
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(s['copyCode']),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Step 2: open the page
                _StepCard(
                  n: 2,
                  title: s['msStep2'],
                  child: FilledButton.icon(
                    onPressed: _opening
                        ? null
                        : () => _openUrl(_deviceCode!.verificationUrl),
                    icon: _opening
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.open_in_new),
                    label: Text(s['openMsPage']),
                  ),
                ),
                const SizedBox(height: 10),
                // Step 3: waiting
                _StepCard(
                  n: 3,
                  title: s['msStep3'],
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(s['waitingCode'],
                              style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                ),
              ],

              if (_done)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle,
                          size: 64, color: Colors.green.shade600),
                      const SizedBox(height: 8),
                      Text(s['refreshed'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),

              if (_error != null) ...[
                Card(
                  color: cs.errorContainer.withOpacity(0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '${s['error']}: $_error',
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.refresh),
                  label: Text(s['retry']),
                ),
              ],
              if (_deviceCode != null && !_done && _error == null)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s['cancel']),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int n;
  final String title;
  final Widget child;
  const _StepCard(
      {required this.n, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primaryContainer,
                  ),
                  alignment: Alignment.center,
                  child: Text('$n',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
