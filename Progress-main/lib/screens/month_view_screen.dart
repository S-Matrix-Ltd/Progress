import 'package:flutter/material.dart';
import '../main.dart';
import '../models/day_entry.dart';
import '../models/user_profile.dart';
import '../models/theme_option.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/currency_service.dart';
import '../services/pdf_service.dart';
import '../services/i18n.dart';

const List<String> _kWeekdayShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// Previous Month History theke "Load" chapleyi ekhon ar main
/// (editable) interface-e niye jay na — eta ekta READ-ONLY view,
/// PDF-er moto shudhu dekhার jonne. Kono field edit kora jay na,
/// shudhu dekha ar chaile PDF export kora jay.
class MonthViewScreen extends StatefulWidget {
  final int year;
  final int month;
  const MonthViewScreen({super.key, required this.year, required this.month});

  @override
  State<MonthViewScreen> createState() => _MonthViewScreenState();
}

class _MonthViewScreenState extends State<MonthViewScreen> {
  final _storage = StorageService();
  final _auth = AuthService();
  final _settingsService = SettingsService();
  final _currencyService = CurrencyService();
  final _pdfService = PdfService();

  bool _loading = true;
  List<DayEntry> _days = [];
  UserProfile? _profile;
  String _currency = 'BDT';
  double _usdRate = 0;

  double totOT = 0, totalAmount = 0;
  int totNight = 0, totDuty = 0, totDayOff = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days = await _storage.loadMonth(widget.year, widget.month);
    final rates = await _storage.loadRates() ?? RateSettings();
    final profile = await _auth.getProfile();
    final settings = await _settingsService.load();

    final list = days ?? [];
    double ot = 0;
    int night = 0, duty = 0, dayoff = 0;
    for (final e in list) {
      ot += e.ot;
      if (e.hasNight) night++;
      if (e.hasDuty) duty++;
      if (e.hasDayoff) dayoff++;
    }
    final amount = (ot * rates.rateOT) + (night * rates.rateNight) + (duty * rates.rateOFF) + rates.rateGross;

    if (!mounted) return;
    setState(() {
      _days = list;
      _profile = profile;
      _currency = settings.currency;
      totOT = ot;
      totNight = night;
      totDuty = duty;
      totDayOff = dayoff;
      totalAmount = amount;
      _loading = false;
    });

    if (_currency == 'USD') {
      final rate = await _currencyService.getBdtToUsdRate();
      if (mounted) setState(() => _usdRate = rate);
    }
  }

  Future<void> _exportPdf() async {
    final rates = await _storage.loadRates() ?? RateSettings();
    final isUsd = _currency == 'USD';
    final pdfAmount = isUsd ? totalAmount * _usdRate : totalAmount;
    await _pdfService.exportMonth(
      profile: _profile,
      year: widget.year,
      month: widget.month,
      days: _days,
      rates: rates,
      totOT: totOT,
      totNight: totNight,
      totDuty: totDuty,
      totDayOff: totDayOff,
      totalAmount: pdfAmount,
      currencyCode: _currency,
    );
  }

  @override
  Widget build(BuildContext context) {
    final opt = themeOptionFor(themeNotifier.value);
    final isUsd = _currency == 'USD';
    final displayAmount = isUsd ? totalAmount * _usdRate : totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text('${trMonthNames[widget.month - 1]} ${widget.year}'),
        actions: [
          IconButton(onPressed: _exportPdf, icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'Export PDF'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  if (_days.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(tr('no_saved_data'))),
                    )
                  else ...[
                    _readOnlyTable(opt.primary),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _sumChip('${_trimZero(totOT)}', tr('ot_hours'), const Color(0xFF047857)),
                        const SizedBox(width: 8),
                        _sumChip('$totNight', tr('night'), const Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        _sumChip('$totDuty', tr('duty'), const Color(0xFF0369A1)),
                        const SizedBox(width: 8),
                        _sumChip('$totDayOff', tr('day_off'), const Color(0xFFB91C1C)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [const Color(0xFF0F172A), const Color(0xFF1E293B), opt.primary.withOpacity(0.9)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(tr('total_amount'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          Text('$_currency ${displayAmount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 26, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  String _trimZero(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  Widget _sumChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyTable(Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text(tr('col_date'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900))),
                Expanded(flex: 1, child: Text(tr('col_day'), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text(tr('col_ot'), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(tr('col_night'), style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(tr('col_duty'), style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(tr('col_off'), style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...List.generate(_days.length, (i) {
            final d = i + 1;
            final date = DateTime(widget.year, widget.month, d);
            final wd = date.weekday;
            final isWeekend = wd == DateTime.thursday || wd == DateTime.friday;
            final e = _days[i];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: isWeekend ? const Color(0xFF52B788) : (i.isEven ? const Color(0xFFF4F7FB) : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('${d.toString().padLeft(2, '0')}.${widget.month.toString().padLeft(2, '0')}.${widget.year}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                  Expanded(flex: 1, child: Text(_kWeekdayShort[wd % 7], textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700))),
                  Expanded(flex: 1, child: Text(e.ot == 0 ? '-' : _trimZero(e.ot), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                  Expanded(flex: 2, child: Center(child: _statusDot(e.hasNight, const Color(0xFF7C3AED)))),
                  Expanded(flex: 2, child: Center(child: _statusDot(e.hasDuty, const Color(0xFF0369A1)))),
                  Expanded(flex: 2, child: Center(child: _statusDot(e.hasDayoff, const Color(0xFFB91C1C)))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statusDot(bool active, Color color) {
    if (!active) return const SizedBox(width: 16, height: 16);
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      child: const Icon(Icons.check, size: 12, color: Colors.white),
    );
  }
}
