import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

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
      home: const HomeScreen(),
    );
  }
}
