import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'services/i18n.dart';
import 'models/theme_option.dart';

/// Global theme controller — Settings screen theke update hoy, ekhon
/// eta ekta ThemeOption-er id ('indigo'/'ocean'/'emerald'/'sunset'/
/// 'purple'/'dark') store kore. MaterialApp eta listen kore reactively
/// rebuild hoy.
final ValueNotifier<String> themeNotifier = ValueNotifier('purple');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService().load();
  themeNotifier.value = settings.theme;
  languageNotifier.value = settings.language;
  runApp(const DutyOtApp());
}

class DutyOtApp extends StatelessWidget {
  const DutyOtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: themeNotifier,
      builder: (context, themeId, _) {
        final option = themeOptionFor(themeId);
        return ValueListenableBuilder<String>(
          valueListenable: languageNotifier,
          builder: (context, lang, __) {
            return MaterialApp(
              title: 'Monthly Duty & OT Statement',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                fontFamily: 'Roboto',
                colorSchemeSeed: option.seed,
                useMaterial3: true,
                brightness: option.brightness,
                scaffoldBackgroundColor:
                    option.brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
              ),
              home: const AuthGate(),
            );
          },
        );
      },
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
