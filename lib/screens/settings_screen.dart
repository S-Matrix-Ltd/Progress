import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import '../main.dart';
import '../models/app_settings.dart';
import '../models/day_entry.dart';
import '../models/theme_option.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../services/reminder_service.dart';
import '../services/i18n.dart';
import 'change_password_screen.dart';
import 'data_history_screen.dart';
import 'login_screen.dart';
import 'month_view_screen.dart';
import 'register_screen.dart' show kSecurityQuestions;

/// Right-side theke slide-in hoye ashe emon route — Settings-er
/// protyekta section (Profile / Appearance / Rates / Reminder /
/// Change Password) ei transition diye khole, ar kaj shesh kore
/// back gele shei animation reverse hoye "slide out" hoye jay.
Route<T> slideInRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Smooth slide + fade combo — age shudhu slide chilo, ekhon
      // shathe shathe fade-in-o hoy, tai transition ta aro "soft" lage.
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final slideTween = Tween(begin: const Offset(0.08, 0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: animation.drive(slideTween), child: child),
      );
    },
  );
}

/// Save chapar age password verify kore. Shob edit-panel-e ei ekই
/// dialog use hoy — profile/rate/appearance/reminder, sob khetre
/// "view korar shomoy na, SAVE korar shomoy" password chay.
/// Settings > Security theke "Require Password" off kora thakle
/// password ar chaibe na — shudhu ekta shadharon Yes/No confirm dialog dekhabe.
Future<bool> verifyWithPasswordPrompt(BuildContext context, AuthService auth) async {
  if (!context.mounted) return false;
  final settings = await SettingsService().load();
  if (!context.mounted) return false;

  if (!settings.requirePasswordOnSave) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('save_confirm_title_1')),
        content: Text(tr('save_confirm_body_1')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('confirm'))),
        ],
      ),
    );
    return confirmed ?? false;
  }

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

  @override
  Widget build(BuildContext context) {
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
            _navTile(Icons.shield_outlined, tr('security'), tr('security_desc'), () => _openPanel(const SecurityPanel()), color: primary),
            const Divider(height: 1),
            _navTile(Icons.lock_outline, tr('change_password'), 'Update account password', () async {
              await Navigator.push(context, slideInRoute(const ChangePasswordScreen()));
            }, color: primary),
            const Divider(height: 1),
            _navTile(Icons.history, tr('data_history'), tr('data_history_desc'), () async {
              await Navigator.push(context, slideInRoute(const DataHistoryScreen()));
            }, color: primary),
          ]),
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _navTile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? color}) {
    final tileColor = color ?? Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: tileColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: tileColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: color)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
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
  String _username = '';
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
      _username = p.username;
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
          // Username shudhu dekhano hoy (login credential, tai edit-jogyo na).
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.alternate_email, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('username'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_username, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
// Security panel — password-on-save/mark toggle
// ---------------------------------------------------------------------
class SecurityPanel extends StatefulWidget {
  const SecurityPanel({super.key});
  @override
  State<SecurityPanel> createState() => _SecurityPanelState();
}

class _SecurityPanelState extends State<SecurityPanel> {
  final _auth = AuthService();
  final _settingsService = SettingsService();
  AppSettings _settings = AppSettings();
  UserProfile? _profile;
  final _answerCtrl = TextEditingController();
  String? _selectedQuestion;
  bool _loading = true;
  bool _dirty = false;
  bool _savingQuestion = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _settingsService.load();
    final p = await _auth.getProfile();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _profile = p;
      _selectedQuestion = (p != null && p.securityQuestion.trim().isNotEmpty) ? p.securityQuestion : null;
      _loading = false;
    });
  }

  /// Security question/answer alada, nijer verify+save flow — main
  /// "Require Password" toggle-er dirty/save cycle theke independent.
  Future<void> _updateSecurityQuestion() async {
    if (_selectedQuestion == null || _answerCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('security_question_required')), backgroundColor: const Color(0xFFB91C1C)));
      return;
    }
    final verified = await verifyWithPasswordPrompt(context, _auth);
    if (!verified) return;
    setState(() => _savingQuestion = true);
    await _auth.updateSecurityQuestion(_selectedQuestion!, _answerCtrl.text);
    if (!mounted) return;
    setState(() => _savingQuestion = false);
    _answerCtrl.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('saved_msg')), backgroundColor: const Color(0xFF047857)));
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Ei panel-er nijer save-o notun toggle mene chole: jodi user
  /// password OFF korte chay, purono (still ON) state diye ekbar
  /// verify kore nijeke ashsto kore, tarpor off hoy.
  Future<void> _save() async {
    final ctrl = TextEditingController();
    bool ok = true;
    if (_settings.requirePasswordOnSave) {
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
      if (proceed != true) return;
      ok = await _auth.verifyPassword(ctrl.text);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('wrong_password')), backgroundColor: const Color(0xFFB91C1C)));
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('save_confirm_title_1')),
          content: Text(tr('save_confirm_body_1')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('confirm'))),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _settingsService.save(_settings);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final primary = Theme.of(context).colorScheme.primary;
    return PanelScaffold(
      title: tr('security'),
      dirty: _dirty,
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('require_password_save_desc'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _settings.requirePasswordOnSave,
            onChanged: (v) {
              setState(() => _settings.requirePasswordOnSave = v);
              _markDirty();
            },
            title: Text(tr('require_password_save'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            subtitle: Text(_settings.requirePasswordOnSave ? 'ON' : 'OFF', style: const TextStyle(fontSize: 11)),
            activeColor: primary,
          ),
          const Divider(height: 32),
          Text(tr('security_question_setup'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedQuestion,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: tr('security_question'),
              prefixIcon: const Icon(Icons.help_outline, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: kSecurityQuestions
                .map((q) => DropdownMenuItem(value: q, child: Text(q, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _selectedQuestion = v),
          ),
          const SizedBox(height: 10),
          buildTextField(tr('security_answer'), _answerCtrl),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _savingQuestion ? null : _updateSecurityQuestion,
              icon: _savingQuestion
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 17),
              label: Text(tr('save')),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
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
  bool? _exactAlarmGranted;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshPermissionStatus();
  }

  Future<void> _refreshPermissionStatus() async {
    final can = await ReminderService.canScheduleExact();
    if (!mounted) return;
    setState(() => _exactAlarmGranted = can);
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
      // Exact Alarm (Android 12+) permission — ei ta na thakle notification
      // thik shomoy-e ashbe na. Ei call shorasori OS-er Settings screen
      // khole dey, user shekhane ekta toggle ON korben. Eta ekta "fire and
      // forget" intent — return howar por-e amra abar check kore dekhi
      // (canScheduleExact) actual obostha ki.
      await ReminderService.requestExactAlarmPermission();
      // Battery optimization exemption-o chaই — Xiaomi/Oppo/Vivo-er moto
      // phone-e eta na thakle scheduled reminder background-e ashe na,
      // eta na hole test notification (akhoni show) thik ashe kintu
      // scheduled ta ashe na — thik ei problem-tai report kora hoyeche.
      await ReminderService.requestIgnoreBatteryOptimizations();
      final mode = await ReminderService.scheduleDaily(TimeOfDay(hour: _settings.reminderHour, minute: _settings.reminderMinute));
      await _refreshPermissionStatus();
      if (!mounted) return;
      if (mode.startsWith('failed')) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr('reminder_schedule_failed')),
            content: SingleChildScrollView(child: Text(mode, style: const TextStyle(fontSize: 11))),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel')))],
          ),
        );
        return;
      }
      final canExact = await ReminderService.canScheduleExact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(canExact ? tr('reminder_scheduled_msg') : tr('reminder_scheduled_inexact_msg')),
          backgroundColor: canExact ? const Color(0xFF047857) : const Color(0xFFB45309),
        ),
      );
    } else {
      await ReminderService.cancel();
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _sendTest() async {
    final ok = await ReminderService.showTestNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? tr('test_notification_sent') : tr('test_notification_failed')),
        backgroundColor: ok ? const Color(0xFF047857) : const Color(0xFFB91C1C),
      ),
    );
  }

  /// Diagnostic test — daily-repeat er jotilota bad diye, shudhu 1
  /// minute pore ekta notification schedule kore. User-ke app CLOSE
  /// kore wait korte bola hoy — eta diye background scheduling ashole
  /// kaj kore kina shorasori bujha jay.
  Future<void> _scheduleOneMinuteTest() async {
    await ReminderService.requestPermission();
    await ReminderService.requestExactAlarmPermission();
    await ReminderService.requestIgnoreBatteryOptimizations();
    final mode = await ReminderService.scheduleOneTimeTest(const Duration(minutes: 1));
    await _refreshPermissionStatus();
    if (!mounted) return;
    if (mode.startsWith('failed')) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('test_notification_failed')),
          content: SingleChildScrollView(child: Text(mode, style: const TextStyle(fontSize: 11))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel')))],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${tr('one_min_test_scheduled')} ($mode)'),
        backgroundColor: const Color(0xFF047857),
      ),
    );
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
          const SizedBox(height: 4),
          Text(tr('reminder_alarm_hint'), style: TextStyle(fontSize: 10.5, color: primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          // Exact Alarm permission-er live status — custom ROM-e ei
          // permission thakleo/na thakleo device-visor-e alada rokom
          // behave korte pare, tai shorasori dekhano hoy.
          if (_exactAlarmGranted != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: (_exactAlarmGranted! ? const Color(0xFF047857) : const Color(0xFFB45309)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_exactAlarmGranted! ? Icons.check_circle : Icons.warning_amber_rounded,
                      size: 15, color: _exactAlarmGranted! ? const Color(0xFF047857) : const Color(0xFFB45309)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _exactAlarmGranted! ? tr('exact_alarm_granted') : tr('exact_alarm_not_granted'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _exactAlarmGranted! ? const Color(0xFF047857) : const Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
            ),
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
          const SizedBox(height: 12),
          // Test button — akhoni ekta notification pathiye dekha jay
          // device-e notification dekhano-i thik moto kaj kore kina,
          // scheduling-er upor nirbhor na kore.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sendTest,
              icon: const Icon(Icons.notifications_active_outlined, size: 17),
              label: Text(tr('send_test_notification')),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Diagnostic test — daily-repeat er jotilota chara shudhu 1
          // minute pore ekta notification ashe kina check kore. Ei
          // button chaপার por app minimize/close kore wait korte hobe.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _scheduleOneMinuteTest,
              icon: const Icon(Icons.timer_outlined, size: 17),
              label: Text(tr('schedule_one_min_test')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB45309),
                side: const BorderSide(color: Color(0xFFB45309)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Battery settings-e shorasori niye jay — jate user manually
          // "No restriction"/"Unrestricted" select korte paren. Onek
          // OEM-e (Xiaomi/Oppo/Vivo) ei manual step chara automatic
          // request-o kaj kore na.
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                await openAppSettings();
              },
              icon: const Icon(Icons.battery_saver_outlined, size: 16),
              label: Text(tr('open_battery_settings'), style: const TextStyle(fontSize: 11.5)),
            ),
          ),
          const SizedBox(height: 6),
          Text(tr('battery_optimization_hint'),
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}
