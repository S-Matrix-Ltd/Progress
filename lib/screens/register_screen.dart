import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

const Color kPrimaryColor = Color(0xFF3730A3);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      _showMsg('Password mile ni');
      return;
    }
    setState(() => _loading = true);
    final error = await _auth.register(
      name: _nameCtrl.text,
      employeeId: _idCtrl.text,
      company: _companyCtrl.text,
      address: _addressCtrl.text,
      username: _usernameCtrl.text,
      password: _passwordCtrl.text,
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (error != null) {
      _showMsg(error);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFB91C1C)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _headerLogo(),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Registration',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimaryColor)),
                          const SizedBox(height: 16),
                          _field(_nameCtrl, 'Full Name', Icons.person_outline, required: true),
                          const SizedBox(height: 12),
                          _field(_idCtrl, 'Employee ID', Icons.badge_outlined),
                          const SizedBox(height: 12),
                          _field(_companyCtrl, 'Company Name', Icons.apartment_outlined),
                          const SizedBox(height: 12),
                          _field(_addressCtrl, 'Address', Icons.location_on_outlined, maxLines: 2),
                          const Divider(height: 32),
                          _field(_usernameCtrl, 'Username', Icons.alternate_email, required: true),
                          const SizedBox(height: 12),
                          _passwordField(_passwordCtrl, 'Password'),
                          const SizedBox(height: 12),
                          _passwordField(_confirmCtrl, 'Confirm Password'),
                          const SizedBox(height: 20),
                          _loading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Register', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Already have an account? Login'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerLogo() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [Color(0xFF2E2A82), Color(0xFF0369A1)]),
          ),
          child: const Icon(Icons.badge, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 10),
        const Text('Monthly Duty & OT Statement',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? '$label lagbe' : null : null,
    );
  }

  Widget _passwordField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (v) => (v == null || v.isEmpty) ? '$label lagbe' : null,
    );
  }
}
