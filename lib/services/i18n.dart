import 'package:flutter/material.dart';

/// Global language state — Settings theke change korle shathe shathe
/// shob screen reflect hoy (main.dart-er MaterialApp ei value listen kore).
final ValueNotifier<String> languageNotifier = ValueNotifier('en');

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
  'col_day': {'en': 'DAY', 'bn': 'দিন'},
  'col_ot': {'en': 'OT(H)', 'bn': 'ওটি(ঘ)'},
  'col_night': {'en': 'NIGHT DUTY', 'bn': 'নাইট ডিউটি'},
  'col_duty': {'en': 'OFF DAY DUTY', 'bn': 'অফ ডে ডিউটি'},
  'col_off': {'en': 'OFF DAY', 'bn': 'অফ ডে'},
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
  'version_label': {'en': 'Version', 'bn': 'ভার্শন'},
  'notification_permission_denied': {
    'en': 'Notification permission denied — please allow it from phone Settings > Apps > Progress > Notifications.',
    'bn': 'নোটিফিকেশন পারমিশন দেওয়া হয়নি — ফোনের Settings > Apps > Progress > Notifications থেকে Allow করুন।'
  },
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
  'reminder_alarm_hint': {
    'en': 'Works like a real alarm — you may need to allow "Alarms & reminders" when asked, for exact-time delivery.',
    'bn': 'এটা আসল অ্যালার্মের মতো কাজ করে — সঠিক সময়ে পাওয়ার জন্য "Alarms & reminders" পারমিশন চাইলে অনুমতি দিন।'
  },
  'reminder_scheduled_msg': {'en': 'Daily reminder set successfully', 'bn': 'ডেইলি রিমাইন্ডার সেট হয়েছে'},
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

  // --- Phase 6: dialogs/validators/auth screens (fix banglish leak) ---
  'cancel': {'en': 'Cancel', 'bn': 'বাতিল'},
  'confirm': {'en': 'Confirm', 'bn': 'নিশ্চিত করুন'},
  'password': {'en': 'Password', 'bn': 'পাসওয়ার্ড'},
  'username': {'en': 'Username', 'bn': 'ইউজারনেম'},
  'wrong_password': {'en': 'Wrong password', 'bn': 'পাসওয়ার্ড ভুল'},
  'field_required': {'en': 'is required', 'bn': ' লাগবে'},
  'unmark_password_title': {'en': 'Enter password to unmark', 'bn': 'আনমার্ক করতে পাসওয়ার্ড দিন'},
  'save_password_title': {'en': 'Enter password to save', 'bn': 'সেভ করতে পাসওয়ার্ড দিন'},
  'reset_month_password_title': {'en': 'Enter password to reset', 'bn': 'রিসেট করতে পাসওয়ার্ড দিন'},
  'unmark_dayoff_first': {
    'en': 'Please unmark Night/Duty first, then Day Off can be marked.',
    'bn': 'আগে নাইট/ডিউটি আনমার্ক করুন, তারপর ডে অফ মার্ক করা সম্ভব।'
  },
  'dayoff_blocks_others': {
    'en': 'Night/Duty cannot be marked while Day Off is active.',
    'bn': 'ডে অফ চালু থাকলে নাইট/ডিউটি মার্ক করা যাবে না।'
  },
  'reset_month_title': {'en': 'Reset Month?', 'bn': 'মাস রিসেট করবেন?'},
  'reset_month_confirm': {'en': 'entries will be cleared. Confirm?', 'bn': '- সব এন্ট্রি মুছে যাবে। নিশ্চিত করবেন?'},
  'unsaved_changes_title': {'en': 'Unsaved Changes', 'bn': 'অসংরক্ষিত পরিবর্তন'},
  'unsaved_changes_body': {
    'en': 'Your changes are not saved. Leave without saving?',
    'bn': 'আপনার পরিবর্তন সেভ হয়নি। সেভ না করে চলে যাবেন?'
  },
  'stay': {'en': 'Stay', 'bn': 'থাকুন'},
  'leave': {'en': 'Leave', 'bn': 'চলে যান'},
  'logout_confirm_title': {'en': 'Logout?', 'bn': 'লগআউট করবেন?'},
  'logout_confirm_body': {'en': 'Are you sure you want to logout?', 'bn': 'আপনি কি লগআউট করতে চান?'},
  'no_saved_data': {'en': 'No saved data.', 'bn': 'কোনো সংরক্ষিত তথ্য নেই।'},
  'login': {'en': 'Login', 'bn': 'লগইন'},
  'remember_me': {'en': 'Remember Me', 'bn': 'মনে রাখুন'},
  'forgot_password_q': {'en': 'Forgot Password?', 'bn': 'পাসওয়ার্ড ভুলে গেছেন?'},
  'new_user_register': {'en': 'New user? Register', 'bn': 'নতুন ইউজার? রেজিস্টার করুন'},
  'registration': {'en': 'Registration', 'bn': 'রেজিস্ট্রেশন'},
  'register': {'en': 'Register', 'bn': 'রেজিস্টার'},
  'already_have_account': {'en': 'Already have an account? Login', 'bn': 'অ্যাকাউন্ট আছে? লগইন করুন'},
  'passwords_not_match': {'en': 'Passwords do not match', 'bn': 'পাসওয়ার্ড মিলছে না'},
  'full_name': {'en': 'Full Name', 'bn': 'পূর্ণ নাম'},
  'employee_id': {'en': 'Employee ID', 'bn': 'এমপ্লয়ি আইডি'},
  'company_name': {'en': 'Company Name', 'bn': 'কোম্পানির নাম'},
  'address': {'en': 'Address', 'bn': 'ঠিকানা'},
  'confirm_password': {'en': 'Confirm Password', 'bn': 'পাসওয়ার্ড নিশ্চিত করুন'},
  'new_password': {'en': 'New Password', 'bn': 'নতুন পাসওয়ার্ড'},
  'confirm_new_password': {'en': 'Confirm New Password', 'bn': 'নতুন পাসওয়ার্ড নিশ্চিত করুন'},
  'current_password': {'en': 'Current Password', 'bn': 'বর্তমান পাসওয়ার্ড'},
  'show_password': {'en': 'Show Password', 'bn': 'পাসওয়ার্ড দেখান'},
  'update_password': {'en': 'Update Password', 'bn': 'পাসওয়ার্ড আপডেট করুন'},
  'password_changed_msg': {'en': 'Password changed successfully', 'bn': 'পাসওয়ার্ড পরিবর্তন হয়েছে'},
  'forgot_password_title': {'en': 'Forgot Password', 'bn': 'পাসওয়ার্ড ভুলে গেছেন'},
  'verify_identity': {'en': 'Verify Identity', 'bn': 'পরিচয় যাচাই করুন'},
  'verify_identity_desc': {
    'en': 'Enter the Username and Employee ID you used during registration to set a new password.',
    'bn': 'রেজিস্ট্রেশনের সময় যে Username ও Employee ID দিয়েছিলেন তা লিখে নতুন পাসওয়ার্ড সেট করুন।'
  },
  'reset_password': {'en': 'Reset Password', 'bn': 'পাসওয়ার্ড রিসেট'},
  'password_reset_success': {
    'en': 'Password has been reset. Please login with your new password.',
    'bn': 'পাসওয়ার্ড পরিবর্তন হয়ে গেছে। নতুন পাসওয়ার্ড দিয়ে লগইন করুন।'
  },
  'new_password_not_match': {'en': 'New passwords do not match', 'bn': 'নতুন পাসওয়ার্ড মিলছে না'},
  'delete_confirm_title': {'en': 'Delete Confirm', 'bn': 'মুছে ফেলা নিশ্চিত করুন'},
  'delete_confirm_body': {'en': 'entry will be deleted. Enter password:', 'bn': '- এন্ট্রি মুছে যাবে। পাসওয়ার্ড দিন:'},
  'delete': {'en': 'Delete', 'bn': 'মুছুন'},
  'total_label': {'en': 'Total', 'bn': 'সর্বমোট'},
  'link_open_failed': {'en': 'Could not open the link.', 'bn': 'লিংক খোলা গেল না।'},
  'checking_updates': {'en': 'Checking for updates...', 'bn': 'আপডেট চেক করা হচ্ছে...'},
  'update_check_failed': {'en': 'Could not check for updates. Check your internet.', 'bn': 'আপডেট চেক করা গেল না। ইন্টারনেট চেক করুন।'},
  'update_check_failed_title': {'en': 'Could Not Check for Updates', 'bn': 'আপডেট চেক করা গেল না'},
  'update_check_failed_body': {
    'en': 'This can happen if your network blocks GitHub temporarily. You can still open the releases page directly to check manually.',
    'bn': 'নেটওয়ার্ক সাময়িকভাবে GitHub ব্লক করলে এমন হতে পারে। চাইলে সরাসরি রিলিজ পেজ খুলে ম্যানুয়ালি চেক করতে পারেন।'
  },
  'update_check_dns_hint': {
    'en': "Your phone couldn't resolve GitHub's address (a DNS issue). Try switching between WiFi and Mobile Data, or turn off any VPN, then try again.",
    'bn': 'আপনার ফোন GitHub-এর ঠিকানা খুঁজে পায়নি (DNS সমস্যা)। WiFi ও Mobile Data বদলে দেখুন, অথবা কোনো VPN চালু থাকলে বন্ধ করে আবার চেষ্টা করুন।'
  },
  'open_releases_page': {'en': 'Open Releases Page', 'bn': 'রিলিজ পেজ খুলুন'},
  'no_update_available': {'en': 'You are using the latest version.', 'bn': 'আপনি সর্বশেষ ভার্সন ব্যবহার করছেন।'},
  'update_available_title': {'en': 'Update Available', 'bn': 'নতুন আপডেট এসেছে'},
  'update_available_body': {'en': 'A new version is available:', 'bn': 'নতুন ভার্সন এসেছে:'},
  'update_now': {'en': 'Update Now', 'bn': 'আপডেট করুন'},
  'later': {'en': 'Later', 'bn': 'পরে'},
  'rate_loading': {'en': 'Fetching live rate...', 'bn': 'লাইভ রেট আনা হচ্ছে...'},
  'currency': {'en': 'Currency', 'bn': 'কারেন্সি'},

  // --- Phase 11: security toggle, mark/save double-confirm, smart history, auto-update-check ---
  'security': {'en': 'Security', 'bn': 'সিকিউরিটি'},
  'security_desc': {'en': 'Password protection for saving & entries', 'bn': 'সেভ ও এন্ট্রির জন্য পাসওয়ার্ড সুরক্ষা'},
  'require_password_save': {'en': 'Require Password', 'bn': 'পাসওয়ার্ড আবশ্যক'},
  'require_password_save_desc': {
    'en': 'When ON, resetting a month or deleting saved history will ask for your account password. Marking/unmarking entries and saving no longer require a password — just a quick confirmation.',
    'bn': 'চালু থাকলে কোনো মাস রিসেট বা সেভ করা ইতিহাস মুছে ফেলার সময় অ্যাকাউন্ট পাসওয়ার্ড চাইবে। এন্ট্রি মার্ক/আনমার্ক ও সেভ করতে এখন আর পাসওয়ার্ড লাগে না — শুধু দ্রুত একটা নিশ্চিতকরণ দেখাবে।'
  },
  'mark_confirm_title': {'en': 'Mark this entry?', 'bn': 'এই এন্ট্রি মার্ক করবেন?'},
  'unmark_confirm_title': {'en': 'Unmark this entry?', 'bn': 'এই এন্ট্রি আনমার্ক করবেন?'},
  'mark_password_title': {'en': 'Enter password to mark', 'bn': 'মার্ক করতে পাসওয়ার্ড দিন'},
  'save_changes': {'en': 'Save Changes', 'bn': 'পরিবর্তন সেভ করুন'},
  'save_confirm_title_1': {'en': 'Save changes?', 'bn': 'পরিবর্তন সেভ করবেন?'},
  'save_confirm_body_1': {
    'en': 'This month\'s marked entries will be saved. Continue?',
    'bn': 'এই মাসের মার্ক করা এন্ট্রিগুলো সেভ হবে। এগিয়ে যাবেন?'
  },
  'save_confirm_title_2': {'en': 'Confirm Save', 'bn': 'সেভ নিশ্চিত করুন'},
  'save_confirm_body_2': {
    'en': 'Are you absolutely sure? This will overwrite the previously saved data for this month.',
    'bn': 'আপনি কি একদম নিশ্চিত? এটি এই মাসের আগের সেভ করা তথ্য মুছে নতুন করে সেভ করবে।'
  },
  'changes_saved_msg': {'en': 'Changes saved successfully', 'bn': 'পরিবর্তন সফলভাবে সেভ হয়েছে'},
  'no_changes_to_save': {'en': 'No changes to save', 'bn': 'সেভ করার মতো কোনো পরিবর্তন নেই'},
  'unsaved_home_body': {
    'en': 'You have unmarked/marked entries that are not saved yet. Leave without saving?',
    'bn': 'আপনার কিছু মার্ক/আনমার্ক করা পরিবর্তন এখনো সেভ হয়নি। সেভ না করে চলে যাবেন?'
  },
  'view': {'en': 'View', 'bn': 'দেখুন'},
  'auto_update_found_body': {
    'en': 'A new version was found in the background:', 'bn': 'ব্যাকগ্রাউন্ডে একটি নতুন ভার্সন পাওয়া গেছে:'
  },
  'search_month_hint': {'en': 'Search month or year...', 'bn': 'মাস বা বছর সার্চ করুন...'},
  'no_search_results': {'en': 'No matching month found', 'bn': 'মিলে যাওয়া কোনো মাস পাওয়া যায়নি'},
  'security_question_setup': {'en': 'Set up a security question for password recovery', 'bn': 'পাসওয়ার্ড উদ্ধারের জন্য একটি নিরাপত্তা প্রশ্ন সেট করুন'},
  'security_question': {'en': 'Security Question', 'bn': 'নিরাপত্তা প্রশ্ন'},
  'security_answer': {'en': 'Your Answer', 'bn': 'আপনার উত্তর'},
  'security_question_required': {'en': 'Please choose a security question and provide an answer', 'bn': 'দয়া করে একটি নিরাপত্তা প্রশ্ন বেছে নিয়ে উত্তর দিন'},
  'recover_by_id': {'en': 'Recover with Employee ID', 'bn': 'Employee ID দিয়ে উদ্ধার করুন'},
  'recover_by_question': {'en': 'Recover with Security Question', 'bn': 'নিরাপত্তা প্রশ্ন দিয়ে উদ্ধার করুন'},
  'enter_username_first': {'en': 'Enter your username first', 'bn': 'প্রথমে আপনার ইউজারনেম লিখুন'},
  'no_security_question_set': {'en': 'No security question was set for this account', 'bn': 'এই অ্যাকাউন্টের জন্য কোনো নিরাপত্তা প্রশ্ন সেট করা নেই'},
  'load_question': {'en': 'Load Question', 'bn': 'প্রশ্ন লোড করুন'},
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
