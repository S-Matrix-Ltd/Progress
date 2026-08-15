import 'package:flutter/material.dart';
import '../main.dart';
import '../models/app_settings.dart';
import '../models/day_entry.dart';
import '../models/user_profile.dart';
import '../models/theme_option.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/i18n.dart';
import '../services/currency_service.dart';
import '../services/update_service.dart';
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
  final _currencyService = CurrencyService();
  final _updateService = UpdateService();

  UserProfile? _profile;
  AppSettings _appSettings = AppSettings();
  double _usdRate = 0;
  bool _monthExpanded = false;
  bool _yearExpanded = false;

  void _onGlobalSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      slideInRoute(const SettingsScreen()),
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
    if (s.currency == 'USD') _loadUsdRate();
  }

  Future<void> _loadUsdRate() async {
    final rate = await _currencyService.getBdtToUsdRate();
    if (!mounted) return;
    setState(() => _usdRate = rate);
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
    if (!mounted) return false;
    final ctrl = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: tr('password'), border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('confirm'))),
        ],
      ),
    );
    if (proceed != true) return false;
    final ok = await _auth.verifyPassword(ctrl.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('wrong_password')), backgroundColor: const Color(0xFFB91C1C)));
    }
    return ok;
  }

  Future<void> _onStatusTap(int idx, String type) async {
    final entry = days[idx];
    final statuses = List<String>.from(entry.statuses);

    if (statuses.contains(type)) {
      // Unmark korte password lagbe — bhul kore click hoye gele
      // accidentally data muche jabe na.
      final verified = await _promptPassword(tr('unmark_password_title'));
      if (!verified) return;
      statuses.remove(type);
    } else {
      if (type == 'dayoff') {
        if (statuses.contains('night') || statuses.contains('duty')) {
          _showMsg(tr('unmark_dayoff_first'));
          return;
        }
        statuses
          ..clear()
          ..add('dayoff');
      } else {
        if (statuses.contains('dayoff')) {
          _showMsg(tr('dayoff_blocks_others'));
          return;
        }
        statuses.add(type);
      }
    }
    setState(() => entry.statuses = statuses);
    _recalc();
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFB91C1C),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _handleReset() async {
    final verified = await _promptPassword(tr('reset_month_password_title'));
    if (!verified) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('reset_month_title')),
        content: Text('${trMonthNames[month - 1]} $year ${tr('reset_month_confirm')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('reset'), style: const TextStyle(color: Color(0xFFB91C1C)))),
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
    final isUsd = _appSettings.currency == 'USD';
    final pdfAmount = isUsd ? totalAmount * _usdRate : totalAmount;
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
      totalAmount: pdfAmount,
      currencyCode: _appSettings.currency,
    );
  }

  Widget _colorLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _legendChip(kNight, tr('night_duty')),
            const SizedBox(width: 12),
            _legendChip(kDuty, tr('regular_duty')),
            const SizedBox(width: 12),
            _legendChip(kDayoff, tr('day_off')),
            const SizedBox(width: 12),
            _legendChip(kAmberCombo, tr('night_plus_duty')),
            const SizedBox(width: 12),
            _legendChip(kWeekendBg, tr('weekend')),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 11, height: 11, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _footer() {
    return Column(
      children: [
        Text('${tr('version_label')} $kAppVersion', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _handleCheckUpdate,
          child: Text(tr('check_updates'), style: const TextStyle(fontSize: 11.5)),
        ),
        const SizedBox(height: 2),
        Text(kDeveloperCredit, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
        Text(kCopyrightNotice, style: const TextStyle(fontSize: 9.5, color: Color(0xFFB0B8C4))),
        const SizedBox(height: 10),
      ],
    );
  }

  Future<void> _handleCheckUpdate() async {
    _showMsg(tr('checking_updates'));
    final result = await _updateService.checkForUpdate(kAppVersion);
    if (!mounted) return;

    if (!result.success) {
      _showMsg('${tr('update_check_failed')}${result.errorDetail.isNotEmpty ? ' [${result.errorDetail}]' : ''}');
      return;
    }
    if (!result.hasUpdate) {
      _showMsg(tr('no_update_available'));
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('update_available_title')),
        content: Text('${tr('update_available_body')} v${result.latestVersion}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('later'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('update_now'))),
        ],
      ),
    );
    if (proceed != true) return;

    final uri = Uri.parse(kReleasesUrl);
    // canLaunchUrl() maje-maje custom ROM/Android 11+ package-visibility
    // restriction-er karone bhul kore 'false' dey, tai direct launchUrl
    // try kore dekha hocche, fail korle tobei error dekhano hobe.
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _showMsg(tr('link_open_failed'));
    } catch (_) {
      if (mounted) _showMsg(tr('link_open_failed'));
    }
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
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, size: 18, color: opt.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('month_year'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
              _pickerChip(trMonthNames[month - 1], _monthExpanded, () {
                setState(() {
                  _monthExpanded = !_monthExpanded;
                  _yearExpanded = false;
                });
              }),
              const SizedBox(width: 8),
              _pickerChip('$year', _yearExpanded, () {
                setState(() {
                  _yearExpanded = !_yearExpanded;
                  _monthExpanded = false;
                });
              }),
            ],
          ),
          // Picker box-er thik nichei inline-e expand hoy (bottom-sheet
          // popup na) — select korle abar compress hoye close hoye jay.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _monthExpanded
                ? _monthExpandGrid(opt.primary)
                : (_yearExpanded ? _yearExpandGrid(opt.primary) : const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }

  Widget _pickerChip(String label, bool expanded, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthExpandGrid(Color primary) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(12, (i) {
          final selected = (i + 1) == month;
          return _pickChip(trMonthNames[i], selected, primary, () {
            setState(() {
              month = i + 1;
              _monthExpanded = false;
            });
            _loadMonth();
          });
        }),
      ),
    );
  }

  Widget _yearExpandGrid(Color primary) {
    final years = List.generate(11, (i) => DateTime.now().year - 5 + i);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: years.map((y) {
          final selected = y == year;
          return _pickChip('$y', selected, primary, () {
            setState(() {
              year = y;
              _yearExpanded = false;
            });
            _loadMonth();
          });
        }).toList(),
      ),
    );
  }

  Widget _pickChip(String label, bool selected, Color primary, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? primary : const Color(0xFFCBD5E1)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : const Color(0xFF334155))),
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
                Expanded(flex: 3, child: Text(tr('col_date'), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900), textAlign: TextAlign.left, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 1, child: Text(tr('col_ot'), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(tr('col_night'), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900, height: 1.15), textAlign: TextAlign.center, maxLines: 2, softWrap: true)),
                Expanded(flex: 2, child: Text(tr('col_duty'), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900, height: 1.15), textAlign: TextAlign.center, maxLines: 2, softWrap: true)),
                Expanded(flex: 2, child: Text(tr('col_off'), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900, height: 1.15), textAlign: TextAlign.center, maxLines: 2, softWrap: true)),
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
    final isUsd = _appSettings.currency == 'USD';
    final displayAmount = isUsd ? totalAmount * _usdRate : totalAmount;
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
            '${_appSettings.currency} ${displayAmount.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 21, fontWeight: FontWeight.w900),
          ),
          if (isUsd && _usdRate == 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(tr('rate_loading'), style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5)),
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
