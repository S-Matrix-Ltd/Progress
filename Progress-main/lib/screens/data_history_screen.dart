import 'package:flutter/material.dart';
import '../main.dart';
import '../models/day_entry.dart';
import '../models/theme_option.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/i18n.dart';
import 'settings_screen.dart';
import 'month_view_screen.dart';

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
        title: Text(tr('delete_confirm_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${trMonthNames[m.month - 1]} ${m.year} ${tr('delete_confirm_body')}'),
            const SizedBox(height: 10),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: tr('password'), border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete'), style: const TextStyle(color: Color(0xFFB91C1C))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _auth.verifyPassword(pwCtrl.text);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('wrong_password')), backgroundColor: const Color(0xFFB91C1C)));
      return;
    }
    await _storage.deleteMonth(m.year, m.month);
    _load();
  }

  String _trimZero(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  Widget _miniStat(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = themeOptionFor(themeNotifier.value).primary;
    return Scaffold(
      appBar: AppBar(title: Text(tr('data_history'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _months.isEmpty
              ? Center(child: Text(tr('no_saved_data')))
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _months.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = _months[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border(left: BorderSide(color: primary, width: 4)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.push(context, slideInRoute(MonthViewScreen(year: m.year, month: m.month))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(color: primary.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
                                child: Icon(Icons.calendar_month, color: primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${trMonthNames[m.month - 1]} ${m.year}',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _miniStat('OT ${_trimZero(m.otHours)}h', const Color(0xFF047857)),
                                        _miniStat('${tr('night')} ${m.night}', const Color(0xFF7C3AED)),
                                        _miniStat('${tr('duty')} ${m.duty}', const Color(0xFF0369A1)),
                                        _miniStat('${tr('day_off')} ${m.dayOff}', const Color(0xFFB91C1C)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('${tr('total_label')}: ${m.total.toStringAsFixed(2)}',
                                        style: TextStyle(fontWeight: FontWeight.w800, color: primary, fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _deleteMonth(m),
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
                                tooltip: tr('delete'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
