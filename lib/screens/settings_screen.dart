import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../main.dart';
import '../models/app_settings.dart';
import '../models/day_entry.dart';
import '../models/theme_option.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../services/reminder_service.dart';
import '../services/i18n.dart';
import 'change_password_screen.dart';
import 'data_history_screen.dart';
import 'login_screen.dart';

/// Right-side theke slide-in hoye ashe emon route — Settings-er
/// protyekta section (Profile / Appearance / Rates / Reminder /
/// Change Password) ei transition diye khole, ar kaj shesh kore
/// back gele shei animation reverse hoye "slide out" hoye jay.
Route<T> slideInRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(1, 0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

/// Save chapar age password verify kore. Shob edit-panel-e ei ekই
/// dialog use hoy — profile/rate/appearance/reminder, sob khetre
/// "view korar shomoy na, SAVE korar shomoy" password chay.
/// Age fingerprint/biometric try kora hoy (device-e thakle) — success
/// hole password ar lagbe na. Fingerprint na thakle/fail korle
/// shorasori password dialog-e fallback kore.
Future<bool> verifyWithPasswordPrompt(BuildContext context, AuthService auth) async {
  try {
    final localAuth = LocalAuthentication();
    final supported = await localAuth.isDeviceSupported();
    final canCheck = await localAuth.canCheckBiometrics;
    if (supported && canCheck) {
      final didAuth = await localAuth.authenticate(
        localizedReason: tr('biometric_reason'),
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (didAuth) return true;
    }
  } catch (_) {
    // Biometric na thakle/error hole niche password dialog-e fallback hobe.
  }
  if (!context.mounted) return false;
  final ctrl = TextEditingController();
  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('save_password_title')),
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
  final ok = await auth.verifyPassword(ctrl.text);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('wrong_password')), backgroundColor: const Color(0xFFB91C1C)));
  }
  return ok;
}

Widget buildTextField(String label, TextEditingController ctrl, {int maxLines = 1, VoidCallback? onChanged}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      onChanged: (_) => onChanged?.call(),
    ),
  );
}

Widget buildRateField(String label, TextEditingController ctrl, {VoidCallback? onChanged}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      onChanged: (_) => onChanged?.call(),
    ),
  );
}

/// Common scaffold shob slide-in panel-er jonne — title + Save action
/// consistent rakhe.
class PanelScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final VoidCallback onSave;
  final bool dirty;

  const PanelScaffold({super.key, required this.title, required this.body, required this.onSave, required this.dirty});

  Future<bool> _confirmLeave(BuildContext context) async {
    if (!dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('unsaved_changes_title')),
        content: Text(tr('unsaved_changes_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('stay'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('leave'))),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave(context);
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [IconButton(onPressed: onSave, icon: const Icon(Icons.save), tooltip: tr('save'))],
        ),
        body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: body)),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Main Settings screen — ekhon shudhu ekta nav list. Protyekta row tap
// korle right theke slide kore corresponding panel ashe.
// ---------------------------------------------------------------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  final _storage = StorageService();
  List<MonthSummary> _months = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMonths();
  }

  Future<void> _loadMonths() async {
    final months = await _storage.listAllMonths();
    if (!mounted) return;
    setState(() {
      _months = months;
      _loading = false;
    });
  }

  Future<void> _openPanel(Widget panel) async {
    final saved = await Navigator.push(context, slideInRoute<bool>(panel));
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('saved_msg')), backgroundColor: const Color(0xFF047857)));
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('logout_confirm_title')),
        content: Text(tr('logout_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('logout'), style: const TextStyle(color: Color(0xFFB91C1C)))),
        ],
      ),
    );
    if (confirm != true) return;
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  Future<void> _loadMonth(MonthSummary m) async {
    Navigator.of(context).pop({'year': m.year, 'month': m.month});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _card([
            _navTile(Icons.person_outline, tr('profile_info'), 'Name, ID, Company, Address', () => _openPanel(const ProfilePanel()), color: primary),
            const Divider(height: 1),
            _navTile(Icons.palette_outlined, tr('appearance'), 'Language & Theme', () => _openPanel(const AppearancePanel()), color: primary),
            const Divider(height: 1),
            _navTile(Icons.calculate_outlined, tr('configuration_rates'), 'OT / Night / Off / Gross rate', () => _openPanel(const RatesPanel()), color: primary),
            const Divider(height: 1),
            _navTile(Icons.alarm, tr('daily_reminder'), 'Daily entry notification', () => _openPanel(const ReminderPanel()), color: const Color(0xFFEA580C)),
            const Divider(height: 1),
            _navTile(Icons.lock_outline, tr('change_password'), 'Update account password', () async {
              await Navigator.push(context, slideInRoute(const ChangePasswordScreen()));
            }, color: primary),
          ]),
          const SizedBox(height: 16),

          _sectionTitle(tr('previous_month_history'), primary),
          _card(
            _months.isEmpty
                ? [Text(tr('no_saved_data'), style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))]
                : [
                    ..._months.take(6).map((m) {
                      final label = '${trMonthNames[m.month - 1].toUpperCase()} ${m.year}';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                            ElevatedButton(
                              onPressed: () => _loadMonth(m),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                minimumSize: Size.zero,
                              ),
                              child: Text(tr('load'), style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton(
                      onPressed: () async {
                        await Navigator.push(context, slideInRoute(const DataHistoryScreen()));
                      },
                      child: Text('${tr('data_history')} →'),
                    ),
                  ],
          ),
          const SizedBox(height: 16),

          _card([
            _navTile(Icons.logout, tr('logout'), tr('logout_desc'), _handleLogout, color: const Color(0xFFB91C1C)),
          ]),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(tr('back')),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _navTile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Profile Info panel
// ---------------------------------------------------------------------
class ProfilePanel extends StatefulWidget {
  const ProfilePanel({super.key});
  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel> {
  final _auth = AuthService();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _auth.getProfile();
    if (p != null) {
      _nameCtrl.text = p.name;
      _idCtrl.text = p.employeeId;
      _companyCtrl.text = p.company;
      _addressCtrl.text = p.address;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    final verified = await verifyWithPasswordPrompt(context, _auth);
    if (!verified) return;
    await _auth.updateProfile(
      name: _nameCtrl.text.trim(),
      employeeId: _idCtrl.text.trim(),
      company: _companyCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return PanelScaffold(
      title: tr('profile_info'),
      dirty: _dirty,
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildTextField('Name', _nameCtrl, onChanged: _markDirty),
          buildTextField('Employee ID', _idCtrl, onChanged: _markDirty),
          buildTextField('Company', _companyCtrl, onChanged: _markDirty),
          buildTextField('Address', _addressCtrl, maxLines: 2, onChanged: _markDirty),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Appearance panel (Language + Theme)
// ---------------------------------------------------------------------
class AppearancePanel extends StatefulWidget {
  const AppearancePanel({super.key});
  @override
  State<AppearancePanel> createState() => _AppearancePanelState();
}

class _AppearancePanelState extends State<AppearancePanel> {
  final _auth = AuthService();
  final _settingsService = SettingsService();
  AppSettings _settings = AppSettings();
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _settingsService.load();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _loading = false;
    });
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    final verified = await verifyWithPasswordPrompt(context, _auth);
    if (!verified) return;
    await _settingsService.save(_settings);
    themeNotifier.value = _settings.theme;
    languageNotifier.value = _settings.language;
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return PanelScaffold(
      title: tr('appearance'),
      dirty: _dirty,
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('language'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _settings.language,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'bn', child: Text('বাংলা')), // native name, intentionally not translated
            ],
            onChanged: (v) {
              setState(() => _settings.language = v ?? 'bn');
              _markDirty();
            },
          ),
          const SizedBox(height: 16),
          Text(tr('currency'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: (_settings.currency == 'BDT' || _settings.currency == 'USD') ? _settings.currency : 'BDT',
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: const [
              DropdownMenuItem(value: 'BDT', child: Text('BDT (৳)')),
              DropdownMenuItem(value: 'USD', child: Text('USD (\$) — live rate')),
            ],
            onChanged: (v) {
              setState(() => _settings.currency = v ?? 'BDT');
              _markDirty();
            },
          ),
          const SizedBox(height: 16),
          Text(tr('theme'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kThemeOptionsList.map((opt) {
              final selected = _settings.theme == opt.id;
              return GestureDetector(
                onTap: () {
                  setState(() => _settings.theme = opt.id);
                  _markDirty();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: opt.swatch,
                    borderRadius: BorderRadius.circular(10),
                    border: selected ? Border.all(color: Colors.black87, width: 2.5) : null,
                  ),
                  child: Text(opt.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Configuration & Rates panel
// ---------------------------------------------------------------------
class RatesPanel extends StatefulWidget {
  const RatesPanel({super.key});
  @override
  State<RatesPanel> createState() => _RatesPanelState();
}

class _RatesPanelState extends State<RatesPanel> {
  final _auth = AuthService();
  final _storage = StorageService();
  final _rateOTCtrl = TextEditingController();
  final _rateNightCtrl = TextEditingController();
  final _rateOFFCtrl = TextEditingController();
  final _rateGrossCtrl = TextEditingController();
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _numStr(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  Future<void> _load() async {
    final rates = await _storage.loadRates();
    if (rates != null) {
      _rateOTCtrl.text = _numStr(rates.rateOT);
      _rateNightCtrl.text = _numStr(rates.rateNight);
      _rateOFFCtrl.text = _numStr(rates.rateOFF);
      _rateGrossCtrl.text = _numStr(rates.rateGross);
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    final verified = await verifyWithPasswordPrompt(context, _auth);
    if (!verified) return;
    await _storage.saveRates(RateSettings(
      rateOT: double.tryParse(_rateOTCtrl.text) ?? 0,
      rateNight: double.tryParse(_rateNightCtrl.text) ?? 0,
      rateOFF: double.tryParse(_rateOFFCtrl.text) ?? 0,
      rateGross: double.tryParse(_rateGrossCtrl.text) ?? 0,
    ));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return PanelScaffold(
      title: tr('configuration_rates'),
      dirty: _dirty,
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildRateField(tr('ot_rate'), _rateOTCtrl, onChanged: _markDirty),
          buildRateField(tr('night_rate'), _rateNightCtrl, onChanged: _markDirty),
          buildRateField(tr('off_rate'), _rateOFFCtrl, onChanged: _markDirty),
          buildRateField(tr('gross_rate'), _rateGrossCtrl, onChanged: _markDirty),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Daily Reminder panel
// ---------------------------------------------------------------------
class ReminderPanel extends StatefulWidget {
  const ReminderPanel({super.key});
  @override
  State<ReminderPanel> createState() => _ReminderPanelState();
}

class _ReminderPanelState extends State<ReminderPanel> {
  final _auth = AuthService();
  final _settingsService = SettingsService();
  AppSettings _settings = AppSettings();
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _settingsService.load();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _loading = false;
    });
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _settings.reminderHour, minute: _settings.reminderMinute),
    );
    if (picked == null) return;
    setState(() {
      _settings.reminderHour = picked.hour;
      _settings.reminderMinute = picked.minute;
    });
    _markDirty();
  }

  String _fmtTime(int h, int m) {
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  Future<void> _save() async {
    final verified = await verifyWithPasswordPrompt(context, _auth);
    if (!verified) return;
    await _settingsService.save(_settings);
    if (_settings.reminderEnabled) {
      final granted = await ReminderService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('notification_permission_denied')), backgroundColor: const Color(0xFFB91C1C)),
        );
        return;
      }
      await ReminderService.scheduleDaily(TimeOfDay(hour: _settings.reminderHour, minute: _settings.reminderMinute));
    } else {
      await ReminderService.cancel();
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final primary = Theme.of(context).colorScheme.primary;
    return PanelScaffold(
      title: tr('daily_reminder'),
      dirty: _dirty,
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('reminder_desc'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _settings.reminderEnabled,
            onChanged: (v) {
              setState(() => _settings.reminderEnabled = v);
              _markDirty();
            },
            title: Text(_settings.reminderEnabled ? 'ON' : 'OFF', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            activeColor: primary,
          ),
          if (_settings.reminderEnabled)
            InkWell(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Color(0xFF475569)),
                    const SizedBox(width: 10),
                    Text(tr('reminder_time'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(_fmtTime(_settings.reminderHour, _settings.reminderMinute),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
