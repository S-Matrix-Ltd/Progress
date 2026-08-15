import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/i18n.dart';

const Color kForgotPrimary = Color(0xFF3730A3);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPassCtrl.text != _confirmCtrl.text) {
      _showMsg(tr('new_password_not_match'));
      return;
    }
    setState(() => _loading = true);
    final error = await _auth.resetPasswordWithIdentity(
      username: _usernameCtrl.text,
      employeeId: _idCtrl.text,
      newPassword: _newPassCtrl.text,
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (error != null) {
      _showMsg(error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('password_reset_success')),
          backgroundColor: const Color(0xFF15803D)),
    );
    Navigator.of(context).pop();
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFB91C1C)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(tr('forgot_password_title')),
        backgroundColor: kForgotPrimary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(tr('verify_identity'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kForgotPrimary)),
                      const SizedBox(height: 6),
                      Text(
                        tr('verify_identity_desc'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _usernameCtrl,
                        decoration: InputDecoration(
                          labelText: tr('username'),
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? '${tr('username')} ${tr('field_required')}' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _idCtrl,
                        decoration: InputDecoration(
                          labelText: tr('employee_id'),
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? '${tr('employee_id')} ${tr('field_required')}' : null,
                      ),
                      const Divider(height: 32),
                      TextFormField(
                        controller: _newPassCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: tr('new_password'),
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? '${tr('new_password')} ${tr('field_required')}' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: tr('confirm_new_password'),
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? '${tr('confirm_new_password')} ${tr('field_required')}' : null,
                      ),
                      const SizedBox(height: 20),
                      _loading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kForgotPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(tr('reset_password'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
