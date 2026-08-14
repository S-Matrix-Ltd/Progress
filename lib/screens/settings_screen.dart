import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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
import 'calculator_screen.dart';
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
  List<MonthSummary> _months = [];
  bool _loading = true;
  bool _dirty = false;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _auth.getProfile();
    final settings = await _settingsService.load();
    final rates = await _storage.loadRates();
    final months = await _storage.listAllMonths();
    if (profile != null) {
      _nameCtrl.text = profile.name;
      _idCtrl.text = profile.employeeId;
      _companyCtrl.text = profile.company;
      _addressCtrl.text = profile.address;
      _photoPath = profile.photoPath;
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
      _months = months;
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
      photoPath: _photoPath,
    );
    await _storage.saveRates(RateSettings(
      rateOT: double.tryParse(_rateOTCtrl.text) ?? 0,
      rateNight: double.tryParse(_rateNightCtrl.text) ?? 0,
      rateOFF: double.tryParse(_rateOFFCtrl.text) ?? 0,
      rateGross: double.tryParse(_rateGrossCtrl.text) ?? 0,
    ));
    await _settingsService.save(_settings);
    themeNotifier.value = _settings.theme;
    languageNotifier.value = _settings.language;

    if (_settings.reminderEnabled) {
      await ReminderService.requestPermission();
      await ReminderService.scheduleDaily(TimeOfDay(hour: _settings.reminderHour, minute: _settings.reminderMinute));
    } else {
      await ReminderService.cancel();
    }

    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('saved_msg')), backgroundColor: const Color(0xFF047857)),
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

  Future<void> _loadMonth(MonthSummary m) async {
    if (_dirty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('Age changes save korun, tarpor onno mash load korun.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thik Ache')),
          ],
        ),
      );
      if (ok != true) return;
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop({'year': m.year, 'month': m.month});
  }

  Future<void> _pickReminderTime() async {
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

  /// Gallery theke chobi pick kore, app-er nijer documents folder-e
  /// stable naam die copy kore rakhe (temp cache path bhorosajogyo na,
  /// tai copy kora hoy).
  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final savedPath = '${dir.path}/profile_photo.jpg';
    await File(picked.path).copy(savedPath);
    if (!mounted) return;
    setState(() => _photoPath = savedPath);
    _markDirty();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final primary = Theme.of(context).colorScheme.primary;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeaveIfDirty();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('settings')),
          actions: [
            IconButton(onPressed: _saveAll, icon: const Icon(Icons.save), tooltip: tr('save')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _sectionTitle(tr('profile_info'), primary),
            _card([
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: primary.withOpacity(0.15),
                      backgroundImage: _photoPath != null ? FileImage(File(_photoPath!)) : null,
                      child: _photoPath == null ? Icon(Icons.person, size: 38, color: primary) : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickPhoto,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          child: const Icon(Icons.camera_alt, size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _textField('Name', _nameCtrl),
              _textField('Employee ID', _idCtrl),
              _textField('Company', _companyCtrl),
              _textField('Address', _addressCtrl, maxLines: 2),
            ]),
            const SizedBox(height: 16),

            _sectionTitle(tr('appearance'), primary),
            _card([
              Text(tr('language'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _settings.language,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                ],
                onChanged: (v) {
                  setState(() => _settings.language = v ?? 'bn');
                  languageNotifier.value = _settings.language;
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
                      themeNotifier.value = opt.id;
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
            ]),
            const SizedBox(height: 16),

            _expansionCard(
              icon: Icons.calculate_outlined,
              iconColor: primary,
              title: tr('configuration_rates'),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.4,
                  children: [
                    _rateField(tr('ot_rate'), _rateOTCtrl),
                    _rateField(tr('night_rate'), _rateNightCtrl),
                    _rateField(tr('off_rate'), _rateOFFCtrl),
                    _rateField(tr('gross_rate'), _rateGrossCtrl),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            _expansionCard(
              icon: Icons.alarm,
              iconColor: const Color(0xFFEA580C),
              title: tr('daily_reminder'),
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
                    onTap: _pickReminderTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(10),
                      ),
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
            const SizedBox(height: 16),

            _expansionCard(
              icon: Icons.lock_outline,
              iconColor: primary,
              title: tr('change_password'),
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                  child: Text(tr('change_password')),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _sectionTitle(tr('calculator'), primary),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculatorScreen()));
                },
                icon: const Icon(Icons.calculate),
                label: Text(tr('open_calculator')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _sectionTitle(tr('previous_month_history'), primary),
            _card(
              _months.isEmpty
                  ? [Text('Kono saved data nei.', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))]
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
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const DataHistoryScreen()));
                        },
                        child: Text('${tr('data_history')} →'),
                      ),
                    ],
            ),
            const SizedBox(height: 16),

            _card([
              _navTile(Icons.logout, tr('logout'), tr('logout_desc'), _handleLogout, color: const Color(0xFFB91C1C)),
            ]),
            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final leave = await _confirmLeaveIfDirty();
                      if (leave && mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: Text(tr('back')),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveAll,
                    icon: const Icon(Icons.save),
                    label: Text(tr('save')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
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

  Widget _expansionCard({required IconData icon, required Color iconColor, required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: iconColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: iconColor),
          title: Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: iconColor)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: children,
        ),
      ),
    );
  }

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

  Widget _navTile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
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
    );
  }
}
