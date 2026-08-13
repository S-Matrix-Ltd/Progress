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

  /// Shob save howa mash-er list, notun theke purono order-e, current
  /// rate diye total calculate kore. Data History screen ei function
  /// use kore.
  Future<List<MonthSummary>> listAllMonths() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('ot-statement-v1:')).toList();
    final rates = await loadRates() ?? RateSettings();
    final List<MonthSummary> result = [];
    for (final k in keys) {
      final parts = k.split(':')[1].split('-');
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year == null || month == null) continue;
      final entries = await loadMonth(year, month) ?? [];
      double ot = 0;
      int night = 0, duty = 0, dayoff = 0;
      for (final e in entries) {
        ot += e.ot;
        if (e.hasNight) night++;
        if (e.hasDuty) duty++;
        if (e.hasDayoff) dayoff++;
      }
      final total = (ot * rates.rateOT) + (night * rates.rateNight) + (duty * rates.rateOFF) + rates.rateGross;
      result.add(MonthSummary(year: year, month: month, otHours: ot, night: night, duty: duty, dayOff: dayoff, total: total));
    }
    result.sort((a, b) {
      if (a.year != b.year) return b.year.compareTo(a.year);
      return b.month.compareTo(a.month);
    });
    return result;
  }

  Future<void> deleteMonth(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(monthKey(year, month));
  }
}
