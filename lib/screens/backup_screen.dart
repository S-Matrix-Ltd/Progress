import 'package:flutter/material.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _email;
  bool _auto = false;
  bool _busy = false;
  String? _last;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    String? email;
    try {
      email = await BackupService.currentEmail();
    } catch (_) {}
    final auto = await BackupService.isAutoEnabled();
    final last = await BackupService.lastBackupTime();
    if (!mounted) return;
    setState(() {
      _email = email;
      _auto = auto;
      _last = last;
    });
  }

  void _msg(String m, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: ok ? const Color(0xFF047857) : const Color(0xFFB91C1C)),
    );
  }

  Future<void> _run(Future<BackupResult> Function() job) async {
    setState(() => _busy = true);
    final r = await job();
    if (!mounted) return;
    setState(() => _busy = false);
    _msg(r.message, r.ok);
    await _refresh();
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Drive?'),
        content: const Text('Eta ei phone-er ekhon-kar shob data muche Drive backup-er data boshabe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => BackupService.restore());
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.cloud_outlined, color: primary),
              title: Text(_email ?? 'Not signed in'),
              subtitle: Text(_last == null ? 'No backup from this phone yet' : 'Last backup: ${_last!.substring(0, 16).replaceFirst('T', ' ')}'),
            ),
          ),
          const SizedBox(height: 10),
          if (_busy) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _run(() => BackupService.backupNow()),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Backup now'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Restore from Drive'),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              value: _auto,
              title: const Text('Auto backup'),
              subtitle: const Text('Data save korle kichu second pore nijei backup hobe'),
              onChanged: _busy
                  ? null
                  : (v) async {
                      if (v && _email == null) {
                        final acc = await BackupService.signIn();
                        if (acc == null) return;
                      }
                      await BackupService.setAutoEnabled(v);
                      await _refresh();
                    },
            ),
          ),
          if (_email != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await BackupService.signOut();
                      await _refresh();
                    },
              child: const Text('Sign out of Google'),
            ),
        ],
      ),
    );
  }
}
