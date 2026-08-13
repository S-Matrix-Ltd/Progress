import 'package:flutter/material.dart';
import '../models/day_entry.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../widgets/day_row_widget.dart';
import 'login_screen.dart';

const List<String> kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
const List<String> kWeekdayShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _auth = AuthService();

  Future<void> _handleLogout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  int year = DateTime.now().year;
  int month = DateTime.now().month;

  List<DayEntry> days = [];
  final rateOTCtrl = TextEditingController(text: '0');
  final rateNightCtrl = TextEditingController(text: '0');
  final rateOFFCtrl = TextEditingController(text: '0');
  final rateGrossCtrl = TextEditingController(text: '0');

  double totOT = 0, totalAmount = 0;
  int totNight = 0, totDuty = 0, totDayOff = 0;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  int _daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

  Future<void> _loadMonth() async {
    final count = _daysInMonth(year, month);
    final saved = await _storage.loadMonth(year, month);
    final rates = await _storage.loadRates();
    if (rates != null) {
      rateOTCtrl.text = _numStr(rates.rateOT);
      rateNightCtrl.text = _numStr(rates.rateNight);
      rateOFFCtrl.text = _numStr(rates.rateOFF);
      rateGrossCtrl.text = _numStr(rates.rateGross);
    }
    setState(() {
      days = saved ?? List.generate(count, (_) => DayEntry());
      if (days.length != count) {
        // Mash mash er upor month change hole list size adjust
        final adjusted = List.generate(count, (i) => i < days.length ? days[i] : DayEntry());
        days = adjusted;
      }
    });
    _recalc();
  }

  String _numStr(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  void _recalc() {
    final rOT = double.tryParse(rateOTCtrl.text) ?? 0;
    final rNight = double.tryParse(rateNightCtrl.text) ?? 0;
    final rOFF = double.tryParse(rateOFFCtrl.text) ?? 0;
    final rGross = double.tryParse(rateGrossCtrl.text) ?? 0;

    double ot = 0;
    int night = 0, duty = 0, dayoff = 0;
    for (final e in days) {
      ot += e.ot;
      if (e.hasNight) night++;
      if (e.hasDuty) duty++;
      if (e.hasDayoff) dayoff++;
    }
    setState(() {
      totOT = ot;
      totNight = night;
      totDuty = duty;
      totDayOff = dayoff;
      totalAmount = (ot * rOT) + (night * rNight) + (duty * rOFF) + rGross;
    });
    _autoSave();
  }

  Future<void> _autoSave() async {
    await _storage.saveMonth(year, month, days);
    await _storage.saveRates(RateSettings(
      rateOT: double.tryParse(rateOTCtrl.text) ?? 0,
      rateNight: double.tryParse(rateNightCtrl.text) ?? 0,
      rateOFF: double.tryParse(rateOFFCtrl.text) ?? 0,
      rateGross: double.tryParse(rateGrossCtrl.text) ?? 0,
    ));
  }

  void _onStatusTap(int idx, String type) {
    final entry = days[idx];
    final statuses = List<String>.from(entry.statuses);

    if (statuses.contains(type)) {
      statuses.remove(type);
    } else {
      if (type == 'dayoff') {
        if (statuses.contains('night') || statuses.contains('duty')) {
          _showMsg('আগে Night/Duty unmark korun, tarpor Day Off marking sombhob.');
          return;
        }
        statuses
          ..clear()
          ..add('dayoff');
      } else {
        if (statuses.contains('dayoff')) {
          _showMsg('Day Off active thakle Night/Duty mark kora jabe na.');
          return;
        }
        statuses.add(type);
      }
    }
    setState(() => entry.statuses = statuses);
    _recalc();
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFFB91C1C)));
  }

  Future<void> _handleReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Month?'),
        content: Text('${kMonthNames[month - 1]} $year - shob entry muche jabe. Confirm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: Color(0xFFB91C1C)))),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        days = List.generate(_daysInMonth(year, month), (_) => DayEntry());
      });
      _recalc();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F6),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _header(),
            const SizedBox(height: 14),
            _monthPicker(),
            const SizedBox(height: 14),
            _rateSettingsCard(),
            const SizedBox(height: 14),
            _dayTableCard(),
            const SizedBox(height: 14),
            _summaryGrid(),
            const SizedBox(height: 14),
            _totalDisplay(),
            const SizedBox(height: 14),
            _actionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E2A82), Color(0xFF3730A3), Color(0xFF0369A1)],
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MONTHLY DUTY & OT', style: TextStyle(color: Color(0xFFA5F3FC), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
                SizedBox(height: 4),
                Text('Statement', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, color: Colors.white70, size: 22),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _monthPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0369A1).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: const Color(0xFF0369A1), width: 4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, size: 18, color: Color(0xFF0369A1)),
          const SizedBox(width: 10),
          const Expanded(child: Text('MONTH / YEAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          DropdownButton<int>(
            value: month,
            underline: const SizedBox(),
            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(kMonthNames[i]))),
            onChanged: (v) {
              if (v == null) return;
              setState(() => month = v);
              _loadMonth();
            },
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              initialValue: year.toString(),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
              onFieldSubmitted: (v) {
                final y = int.tryParse(v);
                if (y != null) {
                  setState(() => year = y);
                  _loadMonth();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: const Color(0xFF3730A3), width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('RATE SETTINGS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF3730A3))),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: [
              _rateField('OT Rate / hr', rateOTCtrl),
              _rateField('Night Duty Rate', rateNightCtrl),
              _rateField('Off Duty Rate', rateOFFCtrl),
              _rateField('Gross / Fixed', rateGrossCtrl),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rateField(String label, TextEditingController ctrl) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
          TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
            onChanged: (_) => _recalc(),
          ),
        ],
      ),
    );
  }

  Widget _dayTableCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: const Color(0xFF3730A3), width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF3730A3), Color(0xFF6D28D9)]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('DATE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.left)),
                Expanded(flex: 2, child: Text('OT', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('N', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('D', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('OFF', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...List.generate(days.length, (i) {
            final d = i + 1;
            final date = DateTime(year, month, d);
            final wd = date.weekday; // Mon=1..Sun=7
            final isWeekend = wd == 4 || wd == 5; // Thu/Fri
            final dateLabel = '${d.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}.$year';
            final weekdayLabel = kWeekdayShort[wd % 7];
            return DayRowWidget(
              dateLabel: dateLabel,
              weekdayLabel: weekdayLabel,
              isWeekend: isWeekend,
              isEven: i % 2 == 1,
              entry: days[i],
              onOtChanged: (v) {
                days[i].ot = v;
                _recalc();
              },
              onStatusTap: (type) => _onStatusTap(i, type),
            );
          }),
        ],
      ),
    );
  }

  Widget _summaryGrid() {
    return Row(
      children: [
        _sumChip('${_trimZero(totOT)}', 'OT HOURS', const Color(0xFF047857)),
        _sumChip('$totNight', 'NIGHT', const Color(0xFF7C3AED)),
        _sumChip('$totDuty', 'DUTY', const Color(0xFF0369A1)),
        _sumChip('$totDayOff', 'DAY OFF', const Color(0xFFB91C1C)),
      ],
    );
  }

  String _trimZero(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  Widget _sumChip(String val, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  Widget _totalDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF312E81)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text('TOTAL AMOUNT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(
            totalAmount.toStringAsFixed(2),
            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showMsg('PDF export Phase 2 e add hobe.'),
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Export PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3730A3), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleReset,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reset'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFEF2F2), foregroundColor: const Color(0xFFB91C1C), padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ],
    );
  }
}
