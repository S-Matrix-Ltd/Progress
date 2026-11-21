import 'dart:async';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show themeNotifier;
import '../models/app_settings.dart';
import 'i18n.dart';
import 'settings_service.dart';

const String _kDriveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';
const String _kBackupFileName = 'progress-backup.json';
const String _kAutoBackupKey = 'backup-auto-enabled-v1';
const String _kLastBackupKey = 'backup-last-time-v1';

class BackupResult {
  final bool ok;
  final String message;
  BackupResult(this.ok, this.message);
}

/// Google Drive "appDataFolder" backup. Ei folder shudhu ei app-er
/// jonne, user-er baki Drive file dekha/chhoa jay na.
class BackupService {
  static final GoogleSignIn _gsi = GoogleSignIn(scopes: [_kDriveAppDataScope]);
  static Timer? _debounce;

  // Je key gulo backup hobe. Login state ('auth-logged-in-v1') ar
  // backup-er nijer flag ei list-e nei, tai restore-e ogulo bodlay na.
  static bool _isBackupKey(String k) =>
      k == 'auth-profile-v1' ||
      k == 'app-settings-v1' ||
      k == 'ot-rates-v1' ||
      k.startsWith('ot-statement-v1:');

  static Future<String?> currentEmail() async {
    final acc = _gsi.currentUser ?? await _gsi.signInSilently();
    return acc?.email;
  }

  static Future<bool> isAutoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoBackupKey) ?? false;
  }

  static Future<void> setAutoEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoBackupKey, v);
  }

  static Future<String?> lastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastBackupKey);
  }

  static Future<GoogleSignInAccount?> signIn({bool switchAccount = false}) async {
    if (switchAccount) await _gsi.signOut();
    return _gsi.currentUser ?? await _gsi.signInSilently() ?? await _gsi.signIn();
  }

  static Future<void> signOut() async {
    await setAutoEnabled(false);
    await _gsi.signOut();
  }

  static Future<Map<String, String>> _headers(GoogleSignInAccount acc) async {
    final h = await acc.authHeaders;
    return {...h};
  }

  static Future<String?> _findFileId(Map<String, String> h) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'spaces': 'appDataFolder',
      'q': "name='$_kBackupFileName'",
      'fields': 'files(id,modifiedTime)',
      'orderBy': 'modifiedTime desc',
    });
    final res = await http.get(uri, headers: h).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Drive list failed: HTTP ${res.statusCode} ${_short(res.body)}');
    }
    final files = (jsonDecode(res.body)['files'] as List?) ?? [];
    if (files.isEmpty) return null;
    return files.first['id'] as String;
  }

  static String _short(String s) => s.length > 150 ? s.substring(0, 150) : s;

  static Future<String> _buildJson() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, String>{};
    for (final k in prefs.getKeys()) {
      if (_isBackupKey(k)) {
        final v = prefs.getString(k);
        if (v != null) data[k] = v;
      }
    }
    return jsonEncode({
      'app': 'progress',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    });
  }

  /// Backup now. Account na thakle sign-in dekhabe.
  static Future<BackupResult> backupNow() async {
    try {
      final acc = await signIn();
      if (acc == null) return BackupResult(false, 'Sign-in cancelled');
      final h = await _headers(acc);
      final content = await _buildJson();
      final id = await _findFileId(h);
      http.Response res;
      if (id == null) {
        const boundary = 'progress_backup_boundary';
        final meta = jsonEncode({
          'name': _kBackupFileName,
          'parents': ['appDataFolder'],
        });
        final body = '--$boundary\r\n'
            'Content-Type: application/json; charset=UTF-8\r\n\r\n'
            '$meta\r\n'
            '--$boundary\r\n'
            'Content-Type: application/json; charset=UTF-8\r\n\r\n'
            '$content\r\n'
            '--$boundary--';
        res = await http
            .post(
              Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
              headers: {...h, 'Content-Type': 'multipart/related; boundary=$boundary'},
              body: utf8.encode(body),
            )
            .timeout(const Duration(seconds: 30));
      } else {
        res = await http
            .patch(
              Uri.parse('https://www.googleapis.com/upload/drive/v3/files/$id?uploadType=media'),
              headers: {...h, 'Content-Type': 'application/json; charset=UTF-8'},
              body: utf8.encode(content),
            )
            .timeout(const Duration(seconds: 30));
      }
      if (res.statusCode != 200) {
        return BackupResult(false, 'Backup failed: HTTP ${res.statusCode} ${_short(res.body)}');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastBackupKey, DateTime.now().toIso8601String());
      return BackupResult(true, 'Backup saved to ${acc.email}');
    } catch (e) {
      return BackupResult(false, 'Backup failed: $e');
    }
  }

  /// Restore. markLoggedIn true hole (reinstall-er por) restore-er shathe
  /// shathe login state-o set hoy, tai direct Home-e jawa jay.
  static Future<BackupResult> restore({bool markLoggedIn = false}) async {
    try {
      final acc = await signIn();
      if (acc == null) return BackupResult(false, 'Sign-in cancelled');
      final h = await _headers(acc);
      final id = await _findFileId(h);
      if (id == null) {
        return BackupResult(false, 'No backup found for ${acc.email}');
      }
      final res = await http
          .get(Uri.parse('https://www.googleapis.com/drive/v3/files/$id?alt=media'), headers: h)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        return BackupResult(false, 'Restore failed: HTTP ${res.statusCode} ${_short(res.body)}');
      }
      final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (decoded['app'] != 'progress' || decoded['data'] is! Map) {
        return BackupResult(false, 'Backup file is not valid');
      }
      final data = (decoded['data'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
      if (!data.containsKey('auth-profile-v1')) {
        return BackupResult(false, 'Backup has no account profile');
      }
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().where(_isBackupKey).toList()) {
        await prefs.remove(k);
      }
      for (final e in data.entries) {
        if (_isBackupKey(e.key)) await prefs.setString(e.key, e.value);
      }
      if (markLoggedIn) await prefs.setBool('auth-logged-in-v1', true);
      final AppSettings s = await SettingsService().load();
      themeNotifier.value = s.theme;
      languageNotifier.value = s.language;
      final months = data.keys.where((k) => k.startsWith('ot-statement-v1:')).length;
      return BackupResult(true, 'Restored $months month(s) from ${acc.email}');
    } catch (e) {
      return BackupResult(false, 'Restore failed: $e');
    }
  }

  /// Data save hole (StorageService theke) call hoy. Auto-backup on
  /// thakle ar sign-in kora thakle 6 second pore silently backup kore.
  static void scheduleAutoBackup() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 6), () async {
      try {
        if (!await isAutoEnabled()) return;
        final acc = _gsi.currentUser ?? await _gsi.signInSilently();
        if (acc == null) return;
        await backupNow();
      } catch (_) {}
    });
  }
}
