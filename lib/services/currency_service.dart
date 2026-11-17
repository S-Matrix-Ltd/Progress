import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// BDT theke USD-e live rate anar service. Rate SharedPreferences-e
/// cache kora thake (6 ghonta validity) — jate protibar Home screen
/// open korle notun internet call na lage, r offline thakle-o last
/// jana rate diye kaj chalano jay.
class CurrencyService {
  static const _rateKey = 'bdt_usd_rate';
  static const _rateTimeKey = 'bdt_usd_rate_time';
  static const _cacheValidity = Duration(hours: 6);
  static const _fallbackRate = 0.0082; // approx BDT->USD, internet na thakle last-resort default

  Future<double> getBdtToUsdRate({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = prefs.getDouble(_rateKey);
      final cachedAt = prefs.getInt(_rateTimeKey);
      if (cached != null && cachedAt != null) {
        final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cachedAt));
        if (age < _cacheValidity) return cached;
      }
    }
    try {
      final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/BDT')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rate = (data['rates'] as Map<String, dynamic>?)?['USD'];
        if (rate is num && rate > 0) {
          await prefs.setDouble(_rateKey, rate.toDouble());
          await prefs.setInt(_rateTimeKey, DateTime.now().millisecondsSinceEpoch);
          return rate.toDouble();
        }
      }
    } catch (_) {
      // Network fail hole cache/fallback e fire jabe, app crash korbe na.
    }
    final cached = prefs.getDouble(_rateKey);
    return cached ?? _fallbackRate;
  }
}
