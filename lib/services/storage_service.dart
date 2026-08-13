import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/day_entry.dart';

class StorageService {
  static String monthKey(int year, int month) =>
      'ot-statement-v1:$year-${month.toString().padLeft(2, '0')}';
  static const ratesKey = 'ot-rates-v1';

  Future<void> saveMonth(int year, int month, List<DayEntry> data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = data.map((e) => e.toJson()).toList();
    await prefs.setString(monthKey(year, month), jsonEncode(list));
  }

  Future<List<DayEntry>?> loadMonth(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(monthKey(year, month));
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.map((e) => DayEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveRates(RateSettings rates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ratesKey, jsonEncode(rates.toJson()));
  }

  Future<RateSettings?> loadRates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ratesKey);
    if (raw == null) return null;
    return RateSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
