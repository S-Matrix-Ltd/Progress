import 'package:flutter/material.dart';
import '../models/day_entry.dart';

const Color kPrimary = Color(0xFF3730A3);
const Color kNight = Color(0xFF7C3AED);
const Color kDuty = Color(0xFF0369A1);
const Color kDayoff = Color(0xFFB91C1C);
const Color kWeekendBg = Color(0xFF52B788);
const Color kZebra = Color(0xFFF4F7FB);
const Color kAmberCombo = Color(0xFFD97706);

/// Row background color.
/// IMPORTANT: A status mark (night/duty/dayoff) always takes priority
/// over the weekend green — age eta weekend-er khetre dayoff mark
/// korleo green e chapa pore jeto, mark kora dekha jeto na. Ekhon
/// mark korle shob shomoy color change hobe, weekend hok ba na hok.
Color rowBackgroundColor(DayEntry entry, bool isWeekend, bool isEven) {
  final s = entry.statuses;
  if (s.isEmpty) {
    if (isWeekend) return kWeekendBg;
    return isEven ? kZebra : Colors.transparent;
  }
  final hasNight = s.contains('night');
  final hasDuty = s.contains('duty');
  final hasDayoff = s.contains('dayoff');

  if (hasNight && hasDuty) return kAmberCombo.withOpacity(0.55);
  if (hasDayoff) return kDayoff.withOpacity(0.42);
  if (hasNight) return kNight.withOpacity(0.5);
  if (hasDuty) return kDuty.withOpacity(0.5);
  return isWeekend ? kWeekendBg : (isEven ? kZebra : Colors.transparent);
}

class DayRowWidget extends StatelessWidget {
  final String dateLabel;
  final String weekdayLabel;
  final bool isWeekend;
  final bool isEven;
  final DayEntry entry;
  final ValueChanged<double> onOtChanged;
  final ValueChanged<String> onStatusTap;

  const DayRowWidget({
    super.key,
    required this.dateLabel,
    required this.weekdayLabel,
    required this.isWeekend,
    required this.isEven,
    required this.entry,
    required this.onOtChanged,
    required this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = rowBackgroundColor(entry, isWeekend, isEven);
    final isMarked = entry.statuses.isNotEmpty;
    // Marked ba weekend row-e background colored thake, tokhon pill-er
    // background halka shada kore contrast rakha hoyeche.
    final onColoredBg = isMarked || isWeekend;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // Weekday ke ekta chhoto pill-e alada kore deya hoyeche,
                // jate date theke sohoje alada bujha jay.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: onColoredBg ? Colors.white.withOpacity(0.55) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    weekdayLabel,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF334155), fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 32,
              child: TextFormField(
                initialValue: entry.ot == 0 ? '' : _fmtNum(entry.ot),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6D28D9)),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onChanged: (v) => onOtChanged(double.tryParse(v) ?? 0),
              ),
            ),
          ),
          _statusBox('night', kNight, entry.hasNight),
          _statusBox('duty', kDuty, entry.hasDuty),
          _statusBox('dayoff', kDayoff, entry.hasDayoff),
        ],
      ),
    );
  }

  String _fmtNum(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  Widget _statusBox(String type, Color color, bool active) {
    return Expanded(
      flex: 2,
      child: Center(
        child: GestureDetector(
          onTap: () => onStatusTap(type),
          child: Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              color: active ? color : Colors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: active ? color : const Color(0xFF94A3B8), width: 2),
            ),
            child: active ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
        ),
      ),
    );
  }
}
