import 'package:flutter/material.dart';
import 'dart:io';
import '../main.dart';
import '../models/app_settings.dart';
import '../models/day_entry.dart';
import '../models/user_profile.dart';
import '../models/theme_option.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/i18n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../services/pdf_service.dart';
import '../widgets/day_row_widget.dart';
import 'settings_screen.dart';

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
  final _settingsService = SettingsService();
  final _pdfService = PdfService();

  UserProfile? _profile;
  AppSettings _appSettings = AppSettings();

  void _onGlobalSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    // Settings e rate/profile change hote pare, tai fire ei firey eshe reload.
    if (!mounted) return;
    await _loadProfile();
    await _loadAppSettings();
    if (result != null && result['year'] != null && result['month'] != null) {
      setState(() {
        year = result['year'] as int;
        month = result['month'] as int;
      });
    }
    await _loadMonth();
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
    _loadProfile();
    _loadAppSettings();
    // Language/Theme onno kono screen theke change hole (ba je kono
    // karone shathe shathe rebuild na hole) — ei listener fail-safe
    // hishebe Home screen force rebuild kore.
    themeNotifier.addListener(_onGlobalSettingsChanged);
    languageNotifier.addListener(_onGlobalSettingsChanged);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onGlobalSettingsChanged);
    languageNotifier.removeListener(_onGlobalSettingsChanged);
    super.dispose();
  }

  Future<void> _loadAppSettings() async {
    final s = await _settingsService.load();
    if (!mounted) return;
    setState(() => _appSettings = s);
  }

  Future<void> _loadProfile() async {
    final p = await _auth.getProfile();
    if (!mounted) return;
    setState(() => _profile = p);
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

  /// Password prompt — Reset o Unmark-er moto sensitive kaj-e use hoy.
  Future<bool> _promptPassword(String title) async {
    final ctrl = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (proceed != true) return false;
    final ok = await _auth.verifyPassword(ctrl.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password bhul'), backgroundColor: Color(0xFFB91C1C)));
    }
    return ok;
  }

  Future<void> _onStatusTap(int idx, String type) async {
    final entry = days[idx];
    final statuses = List<String>.from(entry.statuses);

    if (statuses.contains(type)) {
      // Unmark korte password lagbe — bhul kore click hoye gele
      // accidentally data muche jabe na.
      final verified = await _promptPassword('Unmark korte Password din');
      if (!verified) return;
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
    final verified = await _promptPassword('Reset korte Password din');
    if (!verified) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Month?'),
        content: Text('${trMonthNames[month - 1]} $year - shob entry muche jabe. Confirm?'),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            const SizedBox(height: 14),
            _colorLegend(),
            const SizedBox(height: 14),
            _footer(),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExportPdf() async {
    final rates = RateSettings(
      rateOT: double.tryParse(rateOTCtrl.text) ?? 0,
      rateNight: double.tryParse(rateNightCtrl.text) ?? 0,
      rateOFF: double.tryParse(rateOFFCtrl.text) ?? 0,
      rateGross: double.tryParse(rateGrossCtrl.text) ?? 0,
    );
    await _pdfService.exportMonth(
      profile: _profile,
      year: year,
      month: month,
      days: days,
      rates: rates,
      totOT: totOT,
      totNight: totNight,
      totDuty: totDuty,
      totDayOff: totDayOff,
      totalAmount: totalAmount,
      currencySymbol: _appSettings.currencySymbol,
    );
  }

  Widget _colorLegend() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('color_indicator'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF475569))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _legendChip(kNight, tr('night_duty')),
              _legendChip(kDuty, tr('regular_duty')),
              _legendChip(kDayoff, tr('day_off')),
              _legendChip(kAmberCombo, tr('night_plus_duty')),
              _legendChip(kWeekendBg, tr('weekend')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _footer() {
    return Column(
      children: [
        Text('Progress App • v$kAppVersion', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () async {
            final uri = Uri.parse(kReleasesUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else if (mounted) {
              _showMsg('Link open kora gelo na.');
            }
          },
          child: Text(tr('check_updates'), style: const TextStyle(fontSize: 11.5)),
        ),
        const SizedBox(height: 2),
        Text(kDeveloperCredit, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _header() {
    final name = (_profile?.name.isNotEmpty ?? false) ? _profile!.name.toUpperCase() : '';
    final id = _profile?.employeeId ?? '';
    final company = _profile?.company ?? '';
    final address = _profile?.address ?? '';
    final opt = themeOptionFor(themeNotifier.value);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: opt.headerGradient,
        ),
        boxShadow: [BoxShadow(color: opt.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('header_title'),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.25)),
                    const SizedBox(height: 4),
                    Text(tr('header_subtitle'),
                        style: const TextStyle(color: Color(0xFFA5F3FC), fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.menu, color: Colors.white70, size: 24),
                tooltip: tr('settings'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      image: (_profile?.photoPath != null)
                          ? DecorationImage(image: FileImage(File(_profile!.photoPath!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: (_profile?.photoPath == null) ? const Icon(Icons.person, color: Colors.white, size: 24) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                            overflow: TextOverflow.ellipsis),
                        if (id.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text('ID: $id', style: const TextStyle(color: Color(0xFFCBD5F5), fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                        if (company.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(company, style: const TextStyle(color: Color(0xFFCBD5F5), fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(address,
                              style: const TextStyle(color: Color(0xFFA5B4D6), fontSize: 11, height: 1.3),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _monthPicker() {
    final opt = themeOptionFor(themeNotifier.value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: opt.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: opt.primary, width: 4)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month, size: 18, color: opt.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(tr('month_year'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          DropdownButton<int>(
            value: month,
            underline: const SizedBox(),
            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(trMonthNames[i]))),
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
    final opt = themeOptionFor(themeNotifier.value);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: opt.primary, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(tr('rate_settings'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: opt.primary)),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: [
              _rateField(tr('ot_rate'), rateOTCtrl),
              _rateField(tr('night_rate'), rateNightCtrl),
              _rateField(tr('off_rate'), rateOFFCtrl),
              _rateField(tr('gross_rate'), rateGrossCtrl),
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
    final opt = themeOptionFor(themeNotifier.value);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: opt.primary, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [opt.headerGradient[1], opt.headerGradient.last]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text(tr('col_date'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.left)),
                Expanded(flex: 2, child: Text(tr('col_ot'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(tr('col_night'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(tr('col_duty'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(tr('col_off'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
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
        _sumChip('${_trimZero(totOT)}', tr('ot_hours'), const Color(0xFF047857)),
        _sumChip('$totNight', tr('night'), const Color(0xFF7C3AED)),
        _sumChip('$totDuty', tr('duty'), const Color(0xFF0369A1)),
        _sumChip('$totDayOff', tr('day_off'), const Color(0xFFB91C1C)),
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
    final opt = themeOptionFor(themeNotifier.value);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF0F172A), const Color(0xFF1E293B), opt.primary.withOpacity(0.9)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(tr('total_amount'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(
            '${_appSettings.currencySymbol} ${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    final opt = themeOptionFor(themeNotifier.value);
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleExportPdf,
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: Text(tr('export_pdf')),
            style: ElevatedButton.styleFrom(backgroundColor: opt.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleReset,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(tr('reset')),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFEF2F2), foregroundColor: const Color(0xFFB91C1C), padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ],
    );
  }
}
