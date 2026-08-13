/// App-level settings: theme, language, currency.
/// Login/profile theke alada — eta shudhu UI/preference control kore.
class AppSettings {
  String theme; // 'system' | 'light' | 'dark'
  String language; // 'bn' | 'en'
  String currency; // 'BDT' | 'USD' | 'INR'

  AppSettings({
    this.theme = 'system',
    this.language = 'bn',
    this.currency = 'BDT',
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
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        theme: json['theme'] as String? ?? 'system',
        language: json['language'] as String? ?? 'bn',
        currency: json['currency'] as String? ?? 'BDT',
      );
}
