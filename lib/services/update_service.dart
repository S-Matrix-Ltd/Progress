import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class UpdateCheckResult {
  final bool success;
  final bool hasUpdate;
  final String latestVersion;
  UpdateCheckResult({required this.success, required this.hasUpdate, required this.latestVersion});
}

/// GitHub-er "latest release" tag check kore current installed
/// version-er sathe compare kore — "Check for Updates" button-e chapleyi
/// shorasori browser open na kore, age dekhe je sotti notun version
/// ache kina, thakleyi tobe link open korার permission (dialog) dekhay.
class UpdateService {
  Future<UpdateCheckResult> checkForUpdate(String currentVersion) async {
    try {
      final res = await http.get(
        Uri.parse(kReleasesApiUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          // GitHub API User-Agent chara request-e 403 Forbidden dey —
          // eijonnoi age "internet problem" mistakenly dekhaতো, asol
          // internet thik-i chilo.
          'User-Agent': 'ProgressApp-SMatrixLtd',
        },
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final tag = (data['tag_name'] as String?) ?? '';
        final latest = tag.startsWith('v') ? tag.substring(1) : tag;
        if (latest.isEmpty) return UpdateCheckResult(success: false, hasUpdate: false, latestVersion: '');
        return UpdateCheckResult(success: true, hasUpdate: _isNewer(latest, currentVersion), latestVersion: latest);
      }
    } catch (_) {
      // Network fail — success:false pathiye dicche, UI eta handle korbe.
    }
    return UpdateCheckResult(success: false, hasUpdate: false, latestVersion: '');
  }

  bool _isNewer(String latest, String current) {
    List<int> parse(String v) => v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final l = parse(latest);
    final c = parse(current);
    final len = l.length > c.length ? l.length : c.length;
    for (var i = 0; i < len; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}
