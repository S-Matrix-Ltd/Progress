/// Ekta din-er duty/OT entry.
/// statuses: 'night', 'duty', 'dayoff' — original JS logic-er moto
/// (dayoff mutually exclusive with night/duty).
class DayEntry {
  double ot;
  List<String> statuses;

  DayEntry({this.ot = 0, List<String>? statuses}) : statuses = statuses ?? [];

  bool get hasNight => statuses.contains('night');
  bool get hasDuty => statuses.contains('duty');
  bool get hasDayoff => statuses.contains('dayoff');

  Map<String, dynamic> toJson() => {'ot': ot, 'statuses': statuses};

  factory DayEntry.fromJson(Map<String, dynamic> json) => DayEntry(
        ot: (json['ot'] as num?)?.toDouble() ?? 0,
        statuses: (json['statuses'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class RateSettings {
  double rateOT;
  double rateNight;
  double rateOFF;
  double rateGross;

  RateSettings({
    this.rateOT = 0,
    this.rateNight = 0,
    this.rateOFF = 0,
    this.rateGross = 0,
  });

  Map<String, dynamic> toJson() => {
        'rateOT': rateOT,
        'rateNight': rateNight,
        'rateOFF': rateOFF,
        'rateGross': rateGross,
      };

  factory RateSettings.fromJson(Map<String, dynamic> json) => RateSettings(
        rateOT: (json['rateOT'] as num?)?.toDouble() ?? 0,
        rateNight: (json['rateNight'] as num?)?.toDouble() ?? 0,
        rateOFF: (json['rateOFF'] as num?)?.toDouble() ?? 0,
        rateGross: (json['rateGross'] as num?)?.toDouble() ?? 0,
      );
}

/// Data History screen-e ekta mash-er summary dekhanor jonne.
class MonthSummary {
  final int year;
  final int month;
  final double otHours;
  final int night;
  final int duty;
  final int dayOff;
  final double total;

  MonthSummary({
    required this.year,
    required this.month,
    required this.otHours,
    required this.night,
    required this.duty,
    required this.dayOff,
    required this.total,
  });
}
