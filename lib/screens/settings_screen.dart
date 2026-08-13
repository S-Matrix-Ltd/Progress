import 'package:flutter/material.dart';
import '../main.dart';
import '../models/app_settings.dart';
import '../models/day_entry.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import 'change_password_screen.dart';
import 'data_history_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  final _settingsService = SettingsService();
  final _storage = StorageService();

  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final _rateOTCtrl = TextEditingController();
  final _rateNightCtrl = TextEditingController();
  final _rateOFFCtrl = TextEditingController();
  final _rateGrossCtrl = TextEditingController();

  AppSettings _settings = AppSettings();
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _auth.getProfile();
    final settings = await _settingsService.load();
    final rates = await _storage.loadRates();
    if (profile != null) {
      _nameCtrl.text = profile.name;
      _idCtrl.text = profile.employeeId;
      _companyCtrl.text = profile.company;
      _addressCtrl.text = profile.address;
    }
    if (rates != null) {
      _rateOTCtrl.text = _numStr(rates.rateOT);
      _rateNightCtrl.text = _numStr(rates.rateNight);
      _rateOFFCtrl.text = _numStr(rates.rateOFF);
      _rateGrossCtrl.text = _numStr(rates.rateGross);
    }
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  String _numStr(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _saveAll() async {
    await _auth.updateProfile(
      name: _nameCtrl.text.trim(),
      employeeId: _idCtrl.text.trim(),
      company: _companyCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
    );
    await _storage.saveRates(RateSettings(
      rateOT: double.tryParse(_rateOTCtrl.text) ?? 0,
      rateNight: double.tryParse(_rateNightCtrl.text) ?? 0,
      rateOFF: double.tryParse(_rateOFFCtrl.text) ?? 0,
      rateGross: double.tryParse(_rateGrossCtrl.text) ?? 0,
    ));
    await _settingsService.save(_settings);
    themeNotifier.value = themeModeFromString(_settings.theme);
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save hoyeche'), backgroundColor: Color(0xFF047857)),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Apni ki logout korte chan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Color(0xFFB91C1C))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Apnar changes save hoyni. Save na kore jaben?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thakun')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Chole Jai')),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeaveIfDirty();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            IconButton(onPressed: _saveAll, icon: const Icon(Icons.save), tooltip: 'Save'),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _sectionTitle('PROFILE INFO'),
            _card([
              _textField('Name', _nameCtrl),
              _textField('Employee ID', _idCtrl),
              _textField('Company', _companyCtrl),
              _textField('Address', _addressCtrl, maxLines: 2),
            ]),
            const SizedBox(height: 16),
            _sectionTitle('CONFIGURATION & RATES'),
            _card([
              _dropdownRow('Currency', _settings.currency, const ['BDT', 'USD', 'INR'], (v) {
                setState(() => _settings.currency = v!);
                _markDirty();
              }),
              const SizedBox(height: 12),
              _rateField('OT Rate / hr', _rateOTCtrl),
              _rateField('Night Duty Rate', _rateNightCtrl),
              _rateField('Off Duty Rate', _rateOFFCtrl),
              _rateField('Gross / Fixed', _rateGrossCtrl),
            ]),
            const SizedBox(height: 16),
            _sectionTitle('APPEARANCE'),
            _card([
              _dropdownRow(
                'Theme',
                _settings.theme,
                const ['system', 'light', 'dark'],
                (v) {
                  setState(() => _settings.theme = v!);
                  _markDirty();
                },
                display: const {'system': 'System Default', 'light': 'Light', 'dark': 'Dark'},
              ),
              const SizedBox(height: 12),
              _dropdownRow(
                'Language',
                _settings.language,
                const ['bn', 'en'],
                (v) {
                  setState(() => _settings.language = v!);
                  _markDirty();
                },
                display: const {'bn': 'বাংলা', 'en': 'English'},
              ),
            ]),
            const SizedBox(height: 16),
            _sectionTitle('DATA & ACCOUNT'),
            _card([
              _navTile(Icons.history, 'Data History', 'Pichoner mash gulor entry dekhun', () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const DataHistoryScreen()));
              }),
              const Divider(height: 20),
              _navTile(Icons.lock_outline, 'Change Password', 'Account password update korun', () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
              }),
              const Divider(height: 20),
              _navTile(Icons.logout, 'Logout', 'Account theke ber hon', _handleLogout,
                  color: const Color(0xFFB91C1C)),
            ]),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveAll,
                icon: const Icon(Icons.save),
                label: const Text('Save All Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3730A3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF3730A3), letterSpacing: 0.5)),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _textField(String label, TextEditingController ctrl, {int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
          onChanged: (_) => _markDirty(),
        ),
      );

  Widget _rateField(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
          onChanged: (_) => _markDirty(),
        ),
      );

  Widget _dropdownRow(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    Map<String, String>? display,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        DropdownButton<String>(
          value: value,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(display?[o] ?? o))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _navTile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color ?? const Color(0xFF3730A3)),
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
    );
  }
}
