import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const DutyOtApp());
}

class DutyOtApp extends StatelessWidget {
  const DutyOtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monthly Duty & OT Statement',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorSchemeSeed: const Color(0xFF3730A3),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFEEF2F6),
      ),
      home: const AuthGate(),
    );
  }
}

/// App chalu howar shomoy check kore: user ki loggedin, registered,
/// naki notun. Sei onujayi shothik screen dekhay.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();
  bool _loading = true;
  Widget _target = const SizedBox();

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final loggedIn = await _auth.isLoggedIn();
    if (loggedIn) {
      setState(() {
        _target = const HomeScreen();
        _loading = false;
      });
      return;
    }
    final registered = await _auth.isRegistered();
    setState(() {
      _target = registered ? const LoginScreen() : const RegisterScreen();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFEEF2F6),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _target;
  }
}
