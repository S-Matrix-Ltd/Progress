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
/// Notun niyom: Mark kora (Night/Duty/Off Day) status onujayi r kono row
/// color hoy na — shudhu Weekend (Thu/Fri) row-er fixed green color
/// thake. Baki shob row plain/zebra thake, protyek row-er majhe shudhu
/// ekta halka border-line diye alada dekhano hoy.
Color rowBackgroundColor(DayEntry entry, bool isWeekend, bool isEven) {
  if (isWeekend) return kWeekendBg;
  return isEven ? kZebra : Colors.transparent;
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
    // Ekhon shudhu Weekend row-e color thake, mark kore r kono row-e
    // color hoy na — tai "onColoredBg" ekhon shudhu isWeekend-er upor
    // depend kore.
    final onColoredBg = isWeekend;
    final textColor = const Color(0xFF0F172A);

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
          // DATE + DAY — flex kombe deya hoyeche jate content-er por
          // extra khali jayga (majhkhane boro gap) na thake.
          Expanded(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
              height: 30,
              child: TextFormField(
                initialValue: entry.ot == 0 ? '' : _fmtNum(entry.ot),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6D28D9)),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
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
