import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/i18n.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _auth = AuthService();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String? _error;
  bool _busy = false;
  bool _obscure = true;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = tr('new_password_not_match'));
      return;
    }
    setState(() => _busy = true);
    final err = await _auth.changePassword(_oldCtrl.text, _newCtrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('password_changed_msg')), backgroundColor: const Color(0xFF047857)),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('change_password'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextFormField(
            controller: _oldCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(labelText: tr('current_password'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _newCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(labelText: tr('new_password'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(labelText: tr('confirm_new_password'), border: const OutlineInputBorder()),
          ),
          Row(
            children: [
              Checkbox(value: !_obscure, onChanged: (v) => setState(() => _obscure = !(v ?? false))),
              Text(tr('show_password')),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3730A3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(tr('update_password')),
            ),
          ),
        ],
      ),
    );
  }
}
