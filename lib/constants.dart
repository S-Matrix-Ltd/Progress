/// App-wide constants.
///
/// kAppVersion: build.yml protibar `--dart-define=APP_VERSION=1.0.<run_number>`
/// diye pass kore, tai APK-r shown version ar GitHub Release tag
/// (v1.0.<run_number>) shomoyi eki thake — ekhon r kokhono "1.0.0"-e
/// atke thakbe na. Local `flutter run` e dart-define na dile default
/// '1.0.0' e fallback kore.
const String kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

const String kDeveloperCredit = 'Developed by S Matrix Ltd.';
const String kCopyrightNotice = '© ${_kCopyrightYear} S Matrix Ltd. All rights reserved.';
const int _kCopyrightYear = 2026;

/// kReleasesUrl ta apnar GitHub repo-r shathe match kore change kore
/// nin (username/repo), tarpor "Check for Updates" button thik link e
/// niye jabe.
const String kReleasesUrl = 'https://github.com/S-Matrix-Ltd/Progress/releases';

/// GitHub API diye "latest release" tag ber kore version compare korার
/// jonne (Check for Updates button-e "notun update ache kina" age check
/// kore, tarpor link open hoy).
const String kReleasesApiUrl = 'https://api.github.com/repos/S-Matrix-Ltd/Progress/releases/latest';
