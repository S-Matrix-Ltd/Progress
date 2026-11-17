import 'package:flutter/material.dart';

/// Ekta color theme-er shob info — button e dekhanor jonne 'swatch',
/// MaterialApp-er colorSchemeSeed-er jonne 'seed', header/table-header
/// gradient-er jonne 'headerGradient', r borders/buttons-er jonne 'primary'.
class ThemeOption {
  final String id;
  final String label;
  final Color swatch;
  final Color seed;
  final Color primary;
  final Brightness brightness;
  final List<Color> headerGradient;

  const ThemeOption({
    required this.id,
    required this.label,
    required this.swatch,
    required this.seed,
    required this.primary,
    required this.brightness,
    required this.headerGradient,
  });
}

const List<ThemeOption> kThemeOptionsList = [
  ThemeOption(
    id: 'indigo',
    label: 'Indigo',
    swatch: Color(0xFF4F46E5),
    seed: Color(0xFF4F46E5),
    primary: Color(0xFF4F46E5),
    brightness: Brightness.light,
    headerGradient: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF4338CA)],
  ),
  ThemeOption(
    id: 'ocean',
    label: 'Ocean',
    swatch: Color(0xFF0284C7),
    seed: Color(0xFF0284C7),
    primary: Color(0xFF0284C7),
    brightness: Brightness.light,
    headerGradient: [Color(0xFF0C4A6E), Color(0xFF0284C7), Color(0xFF0369A1)],
  ),
  ThemeOption(
    id: 'emerald',
    label: 'Emerald',
    swatch: Color(0xFF059669),
    seed: Color(0xFF059669),
    primary: Color(0xFF059669),
    brightness: Brightness.light,
    headerGradient: [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF047857)],
  ),
  ThemeOption(
    id: 'sunset',
    label: 'Sunset',
    swatch: Color(0xFFEA580C),
    seed: Color(0xFFEA580C),
    primary: Color(0xFFEA580C),
    brightness: Brightness.light,
    headerGradient: [Color(0xFF7C2D12), Color(0xFFEA580C), Color(0xFFC2410C)],
  ),
  ThemeOption(
    id: 'purple',
    label: 'Purple',
    swatch: Color(0xFF7C3AED),
    seed: Color(0xFF7C3AED),
    primary: Color(0xFF6D28D9),
    brightness: Brightness.light,
    headerGradient: [Color(0xFF2E2A82), Color(0xFF3730A3), Color(0xFF0369A1)],
  ),
  ThemeOption(
    id: 'dark',
    label: 'Dark',
    swatch: Color(0xFF1E293B),
    seed: Color(0xFF6366F1),
    primary: Color(0xFF6366F1),
    brightness: Brightness.dark,
    headerGradient: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF312E81)],
  ),
];

final Map<String, ThemeOption> kThemeOptions = {
  for (final o in kThemeOptionsList) o.id: o,
};

ThemeOption themeOptionFor(String id) => kThemeOptions[id] ?? kThemeOptions['purple']!;
