/// App-level settings: theme, language, currency, daily reminder.
/// Login/profile theke alada — eta shudhu UI/preference control kore.
class AppSettings {
  String theme; // theme_option.dart-er ThemeOption id: indigo/ocean/emerald/sunset/purple/dark
  String language; // 'bn' | 'en'
  String currency; // 'BDT' | 'USD' | 'INR'
  bool reminderEnabled;
  int reminderHour; // 24hr format
  int reminderMinute;

  AppSettings({
    this.theme = 'purple',
    this.language = 'en',
    this.currency = 'BDT',
    this.reminderEnabled = false,
    this.reminderHour = 21,
    this.reminderMinute = 0,
  });

  static const Map<String, String> currencySymbols = {
    'BDT': '৳',
    'USD': '\$',
    'INR': '₹',
  };

  String get currencySymbol => currencySymbols[currency] ?? '৳';

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'language': language,
        'currency': currency,
        'reminderEnabled': reminderEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // Purono version-er 'system'/'light'/'dark' value thakle notun
    // color-theme scheme-e migrate kore dey.
    String rawTheme = json['theme'] as String? ?? 'purple';
    if (rawTheme == 'system' || rawTheme == 'light') rawTheme = 'purple';
    if (!['indigo', 'ocean', 'emerald', 'sunset', 'purple', 'dark'].contains(rawTheme)) {
      rawTheme = 'purple';
    }
    return AppSettings(
      theme: rawTheme,
      language: json['language'] as String? ?? 'en',
      currency: json['currency'] as String? ?? 'BDT',
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderHour: (json['reminderHour'] as num?)?.toInt() ?? 21,
      reminderMinute: (json['reminderMinute'] as num?)?.toInt() ?? 0,
    );
  }
}
