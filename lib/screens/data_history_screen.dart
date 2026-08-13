import 'package:flutter/material.dart';
import '../models/day_entry.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'home_screen.dart' show kMonthNames;

class DataHistoryScreen extends StatefulWidget {
  const DataHistoryScreen({super.key});
  @override
  State<DataHistoryScreen> createState() => _DataHistoryScreenState();
}

class _DataHistoryScreenState extends State<DataHistoryScreen> {
  final _storage = StorageService();
  final _auth = AuthService();
  List<MonthSummary> _months = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final months = await _storage.listAllMonths();
    if (!mounted) return;
    setState(() {
      _months = months;
      _loading = false;
    });
  }

  Future<void> _deleteMonth(MonthSummary m) async {
    final pwCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Confirm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${kMonthNames[m.month - 1]} ${m.year} - entry ta muche jabe. Password din:'),
            const SizedBox(height: 10),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFB91C1C))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _auth.verifyPassword(pwCtrl.text);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password bhul'), backgroundColor: Color(0xFFB91C1C)));
      return;
    }
    await _storage.deleteMonth(m.year, m.month);
    _load();
  }

  String _trimZero(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _months.isEmpty
              ? const Center(child: Text('Kono saved data nei'))
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _months.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = _months[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${kMonthNames[m.month - 1]} ${m.year}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  'OT: ${_trimZero(m.otHours)}h  |  Night: ${m.night}  |  Duty: ${m.duty}  |  Off: ${m.dayOff}',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 4),
                                Text('Total: ${m.total.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0369A1))),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _deleteMonth(m),
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
