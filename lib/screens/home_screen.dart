import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
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

  /// Mark/unmark ba OT hour change korle true hoy, explicit "Save"
  /// button chapa na porjonto storage-e persist hoy na.
  bool _dirty = false;

  void _onGlobalSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    if (!(await _confirmDiscardIfDirty())) return;
    _dirty = false;
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
    _autoCheckUpdateSilently();
  }

  /// App khulleyi background-e update check kore. Halka throttle (30 min)
  /// ache — GitHub API rate-limit (60 req/hour per IP) e jate na lage,
  /// nahole baar baar app open/close korle "Could Not Check" dekhabe.
  /// Manual "Check for Updates" button-e kono throttle nei — shobshomoy
  /// fresh check hoy. Fail hole (network/DNS issue etc.) UI-te kono error
  /// dekhano hoy na — chup chap ignore kore. Update paoa gele shudhu
  /// tokhon ekta dialog dekhay.
  static DateTime? _lastAutoCheck;

  Future<void> _autoCheckUpdateSilently() async {
    final last = _lastAutoCheck;
    if (last != null && DateTime.now().difference(last) < const Duration(minutes: 30)) return;
    _lastAutoCheck = DateTime.now();
    try {
      final result = await _updateService.checkForUpdate(kAppVersion);
      if (!result.success || !result.hasUpdate) return; // chup chap ignore
      if (!mounted) return;

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('update_available_title')),
          content: Text('${tr('auto_update_found_body')} v${result.latestVersion}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('later'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('update_now'))),
          ],
        ),
      );
      if (proceed == true) await _openReleasesUrl();
    } catch (_) {
      // Silent — background check, user-facing error dekhano hobe na.
    }
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
    // Age ekhane protibar _autoSave() call hoto (autosave-on-every-tap).
    // Ekhon mark/unmark ba OT change shudhu local state/total update kore
    // — actual storage-e persist shudhu explicit "Save" button chaple hoy
    // (double confirmation-er por), tai ekhane autosave call kora hoy na.
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

  /// Notun, "smooth" (scale+fade animation shoho, rounded card) confirm
  /// popup — Unmark ar Save-e ekhon ei ekta simple Yes/No popup use hoy,
  /// password chay na (age Reset-er moto password lagto, ekhon r na).
  Future<bool> _smoothConfirm({
    required IconData icon,
    required String title,
    String? message,
    String? confirmLabel,
    Color? accent,
  }) async {
    if (!mounted) return false;
    final color = accent ?? themeOptionFor(themeNotifier.value).primary;
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.38),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.85 + (0.15 * curved.value),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 26, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                        child: Icon(icon, color: color, size: 26),
                      ),
                      const SizedBox(height: 14),
                      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      if (message != null) ...[
                        const SizedBox(height: 8),
                        Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Theme.of(context).textTheme.bodySmall?.color)),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                              child: Text(tr('cancel')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(confirmLabel ?? tr('confirm')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _onStatusTap(int idx, String type) async {
    final entry = days[idx];
    final statuses = List<String>.from(entry.statuses);
    final marking = !statuses.contains(type);

    if (marking) {
      if (type == 'dayoff') {
        if (statuses.contains('night') || statuses.contains('duty')) {
          _showMsg(tr('unmark_dayoff_first'));
          return;
        }
      } else if (statuses.contains('dayoff')) {
        _showMsg(tr('dayoff_blocks_others'));
        return;
      }
    }

    // Mark: kono confirmation lagbe na — shathe shathe apply hoy.
    // Unmark: ekta smooth popup e confirm korte hoy (password chay na).
    if (!marking) {
      final ok = await _smoothConfirm(
        icon: Icons.remove_circle_outline,
        title: tr('unmark_confirm_title'),
      );
      if (!ok) return;
    }

    if (marking) {
      if (type == 'dayoff') {
        statuses
          ..clear()
          ..add('dayoff');
      } else {
        statuses.add(type);
      }
    } else {
      statuses.remove(type);
    }
    setState(() {
      entry.statuses = statuses;
      _dirty = true;
    });
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

  void _showSuccessMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF047857)),
    );
  }

  /// Home screen theke chole jawar age (month/year switch, Settings-e
  /// jawa) — unsaved (mark/unmark kora kintu Save na kora) change thakle
  /// shatorko kore, na hole shuture eshe chole jay.
  Future<bool> _confirmDiscardIfDirty() async {
    if (!_dirty) return true;
    if (!mounted) return false;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('unsaved_changes_title')),
        content: Text(tr('unsaved_home_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('stay'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('leave'))),
        ],
      ),
    );
    return leave ?? false;
  }

  /// Explicit "Save" button — ekhon shudhu ekta smooth confirm popup
  /// dekhay (age double dialog + password lagto, ekhon r na).
  Future<void> _handleSave() async {
    if (!_dirty) {
      _showMsg(tr('no_changes_to_save'));
      return;
    }
    final ok = await _smoothConfirm(
      icon: Icons.save_outlined,
      title: tr('save_confirm_title_1'),
      message: tr('save_confirm_body_1'),
      confirmLabel: tr('save'),
    );
    if (!ok) return;

    await _autoSave();
    if (!mounted) return;
    setState(() => _dirty = false);
    _showSuccessMsg(tr('changes_saved_msg'));
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

  Widget _currencyToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _currencyPill('BDT'),
          _currencyPill('USD'),
        ],
      ),
    );
  }

  Widget _currencyPill(String code) {
    final selected = _appSettings.currency == code;
    return GestureDetector(
      onTap: () => _switchCurrency(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(code, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: selected ? const Color(0xFF0F172A) : Colors.white70)),
      ),
    );
  }

  Future<void> _switchCurrency(String code) async {
    if (_appSettings.currency == code) return;
    setState(() => _appSettings.currency = code);
    await _settingsService.save(_appSettings);
    if (code == 'USD') _loadUsdRate();
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
      // Ekhon actual error (errorDetail) o choto kore dekhano hoy — jate
      // asol karon (rate-limit / timeout / DNS) bujha jay, shudhu ekta
      // generic "check internet" bole na atke thake. DNS lookup fail
      // (jemon "Failed host lookup") holeo ekta specific, actionable
      // hint dekhano hoy — WiFi/Mobile Data switch korte bola hoy.
      final isDnsIssue = result.errorDetail.toLowerCase().contains('lookup') ||
          result.errorDetail.toLowerCase().contains('socketexception');
      final openAnyway = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('update_check_failed_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isDnsIssue ? tr('update_check_dns_hint') : tr('update_check_failed_body')),
              if (result.errorDetail.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(result.errorDetail, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('open_releases_page'))),
          ],
        ),
      );
      if (openAnyway == true) await _openReleasesUrl();
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
    await _openReleasesUrl();
  }

  Future<void> _openReleasesUrl() async {
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
      child: Row(
        children: [
          Icon(Icons.calendar_month, size: 18, color: opt.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(tr('month_year'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          // Month ar Year ekhon dutो alada compact chip — protyekta
          // click korle nijer chhoto (shudhu ekta wheel) picker khole.
          _miniPickChip(trMonthNames[month - 1], () => _openSingleWheelPicker(isMonth: true)),
          const SizedBox(width: 6),
          _miniPickChip('$year', () => _openSingleWheelPicker(isMonth: false)),
        ],
      ),
    );
  }

  Widget _miniPickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
            const SizedBox(width: 3),
            const Icon(Icons.unfold_more, size: 14, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  /// Compact, single-wheel (shudhu Month, ba shudhu Year) bottom sheet.
  /// `isMonth` onujayi kon wheel dekhabe seta thik hoy.
  Future<void> _openSingleWheelPicker({required bool isMonth}) async {
    if (!(await _confirmDiscardIfDirty())) return;
    final opt = themeOptionFor(themeNotifier.value);
    final years = List.generate(21, (i) => DateTime.now().year - 10 + i);
    int tempIdx = isMonth ? month - 1 : years.indexOf(year);
    if (!isMonth && tempIdx < 0) tempIdx = years.indexOf(DateTime.now().year);
    final items = isMonth ? trMonthNames : years.map((y) => '$y').toList();

    final resultIdx = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                Text(isMonth ? tr('col_date') : tr('month_year'),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: opt.primary)),
                SizedBox(
                  height: 170,
                  child: Stack(
                    children: [
                      Center(
                        child: Container(
                          height: 42,
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          decoration: BoxDecoration(color: opt.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      CupertinoPicker(
                        scrollController: FixedExtentScrollController(initialItem: tempIdx),
                        itemExtent: 42,
                        onSelectedItemChanged: (i) => tempIdx = i,
                        children: items
                            .map((v) => Center(child: Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, tempIdx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: opt.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(tr('confirm')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (resultIdx == null || !mounted) return;
    setState(() {
      if (isMonth) {
        month = resultIdx + 1;
      } else {
        year = years[resultIdx];
      }
      _dirty = false;
    });
    _loadMonth();
  }

  Widget _colHeaderBox(String label) {
    // Shob box-er height fix (44) rakha hoyeche — "OFF DAY DUTY" 2 line-e
    // wrap hoy bole age oi box ta lomba hoye baki gula-r sathe onek elomelo
    // dekhaতো, ekhon shobkoyta ek shoman height-e center-aligned thake.
    return Container(
      height: 44,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900, height: 1.15),
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [opt.headerGradient[1], opt.headerGradient.last]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _colHeaderBox(tr('col_date'))),
                const SizedBox(width: 4),
                Expanded(flex: 1, child: _colHeaderBox(tr('col_ot'))),
                const SizedBox(width: 4),
                Expanded(flex: 2, child: _colHeaderBox(tr('col_night'))),
                const SizedBox(width: 4),
                Expanded(flex: 2, child: _colHeaderBox(tr('col_duty'))),
                const SizedBox(width: 4),
                Expanded(flex: 2, child: _colHeaderBox(tr('col_off'))),
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
                _dirty = true;
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF0F172A), const Color(0xFF1E293B), opt.primary.withOpacity(0.9)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Currency (BDT/USD) toggle ekhon Total Amount box-er upor-right
          // corner-e — Settings-e na giye shorasori ekhan theke switch kora jay.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_currencyToggle()],
          ),
          const SizedBox(height: 4),
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
            style: ElevatedButton.styleFrom(backgroundColor: opt.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleSave,
            icon: Icon(_dirty ? Icons.save : Icons.save_outlined, size: 19),
            label: Text(_dirty ? '${tr('save_changes')} •' : tr('save_changes')),
            style: ElevatedButton.styleFrom(
              backgroundColor: _dirty ? const Color(0xFF047857) : opt.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}
