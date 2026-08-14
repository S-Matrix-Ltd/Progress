import 'package:flutter/material.dart';

/// Global language state — Settings theke change korle shathe shathe
/// shob screen reflect hoy (main.dart-er MaterialApp ei value listen kore).
final ValueNotifier<String> languageNotifier = ValueNotifier('bn');

const Map<String, Map<String, String>> _kStrings = {
  'header_title': {'en': 'Monthly Duty & Payout Summary', 'bn': 'মাসিক ডিউটি ও পেআউট সামারি'},
  'header_subtitle': {'en': 'Track Duty, OT & Estimated Earnings', 'bn': 'ডিউটি, ওটি ও আনুমানিক আয় ট্র্যাক করুন'},
  'month_year': {'en': 'MONTH / YEAR', 'bn': 'মাস / বছর'},
  'rate_settings': {'en': 'RATE SETTINGS', 'bn': 'রেট সেটিংস'},
  'ot_rate': {'en': 'OT Rate / hr', 'bn': 'ওটি রেট/ঘণ্টা'},
  'night_rate': {'en': 'Night Duty Rate', 'bn': 'নাইট ডিউটি রেট'},
  'off_rate': {'en': 'Off Duty Rate', 'bn': 'অফ ডিউটি রেট'},
  'gross_rate': {'en': 'Gross / Fixed', 'bn': 'গ্রস / ফিক্সড'},
  'col_date': {'en': 'DATE', 'bn': 'তারিখ'},
  'col_ot': {'en': 'OT', 'bn': 'ওটি'},
  'col_night': {'en': 'Night', 'bn': 'নাইট'},
  'col_duty': {'en': 'Duty', 'bn': 'ডিউটি'},
  'col_off': {'en': 'OFF', 'bn': 'অফ'},
  'ot_hours': {'en': 'OT HOURS', 'bn': 'ওটি ঘণ্টা'},
  'night': {'en': 'NIGHT', 'bn': 'নাইট'},
  'duty': {'en': 'DUTY', 'bn': 'ডিউটি'},
  'day_off': {'en': 'DAY OFF', 'bn': 'ছুটি'},
  'total_amount': {'en': 'TOTAL AMOUNT', 'bn': 'সর্বমোট টাকা'},
  'export_pdf': {'en': 'Export PDF', 'bn': 'পিডিএফ এক্সপোর্ট'},
  'reset': {'en': 'Reset', 'bn': 'রিসেট'},
  'color_indicator': {'en': 'COLOR INDICATOR', 'bn': 'কালার নির্দেশক'},
  'night_duty': {'en': 'Night Duty', 'bn': 'নাইট ডিউটি'},
  'regular_duty': {'en': 'Regular Duty', 'bn': 'রেগুলার ডিউটি'},
  'night_plus_duty': {'en': 'Night + Duty', 'bn': 'নাইট + ডিউটি'},
  'weekend': {'en': 'Weekend (Thu/Fri)', 'bn': 'সাপ্তাহিক ছুটি (বৃহস্পতি/শুক্র)'},
  'check_updates': {'en': 'Check for Updates', 'bn': 'আপডেট চেক করুন'},
  'settings': {'en': 'Settings', 'bn': 'সেটিংস'},
  'logout': {'en': 'Logout', 'bn': 'লগআউট'},
  'save_all': {'en': 'Save All Changes', 'bn': 'সব পরিবর্তন সেভ করুন'},
  'save': {'en': 'Save', 'bn': 'সেভ'},
  'saved_msg': {'en': 'Saved successfully', 'bn': 'সফলভাবে সেভ হয়েছে'},
  'profile_info': {'en': 'PROFILE INFO', 'bn': 'প্রোফাইল তথ্য'},
  'configuration_rates': {'en': 'CONFIGURATION & RATES', 'bn': 'কনফিগারেশন ও রেট'},
  'appearance': {'en': 'APPEARANCE', 'bn': 'থিম ও ভাষা'},
  'theme': {'en': 'Theme', 'bn': 'থিম'},
  'language': {'en': 'Language', 'bn': 'ভাষা'},
  'daily_reminder': {'en': 'Daily Entry Reminder', 'bn': 'দৈনিক এন্ট্রি রিমাইন্ডার'},
  'reminder_desc': {'en': 'Get a daily notification to fill today\'s entry', 'bn': 'প্রতিদিনের এন্ট্রি দেওয়ার জন্য নোটিফিকেশন পাবেন'},
  'reminder_time': {'en': 'Reminder Time', 'bn': 'রিমাইন্ডার সময়'},
  'calculator': {'en': 'Calculator', 'bn': 'ক্যালকুলেটর'},
  'open_calculator': {'en': 'Open Calculator', 'bn': 'ক্যালকুলেটর খুলুন'},
  'data_account': {'en': 'DATA & ACCOUNT', 'bn': 'ডেটা ও অ্যাকাউন্ট'},
  'data_history': {'en': 'Data History', 'bn': 'ডেটা হিস্টোরি'},
  'data_history_desc': {'en': 'View past months\' entries', 'bn': 'পুরোনো মাসের এন্ট্রি দেখুন'},
  'previous_month_history': {'en': 'Previous Month History', 'bn': 'পূর্ববর্তী মাসের তথ্য'},
  'load': {'en': 'Load', 'bn': 'লোড'},
  'change_password': {'en': 'Change Password', 'bn': 'পাসওয়ার্ড পরিবর্তন'},
  'change_password_desc': {'en': 'Update account password', 'bn': 'অ্যাকাউন্ট পাসওয়ার্ড আপডেট করুন'},
  'logout_desc': {'en': 'Sign out of your account', 'bn': 'অ্যাকাউন্ট থেকে সাইন আউট করুন'},
  'back': {'en': 'Back', 'bn': 'পেছনে'},
};

String tr(String key) {
  final lang = languageNotifier.value;
  return _kStrings[key]?[lang] ?? _kStrings[key]?['en'] ?? key;
}

const Map<String, List<String>> kMonthNamesByLang = {
  'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
  'bn': ['জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'],
};

List<String> get trMonthNames => kMonthNamesByLang[languageNotifier.value] ?? kMonthNamesByLang['en']!;
