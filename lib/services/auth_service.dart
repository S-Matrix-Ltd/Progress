import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Shob login/registration/password related kaj ei service handle kore.
/// Kono backend nei — shobkichu phone-e local vabe shared_preferences-e
/// save thake, tai internet chara-o kaj kore.
class AuthService {
  static const _profileKey = 'auth-profile-v1';
  static const _loggedInKey = 'auth-logged-in-v1';

  String hashPassword(String plain) {
    final bytes = utf8.encode(plain);
    return sha256.convert(bytes).toString();
  }

  Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_profileKey) != null;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  Future<UserProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  /// Notun user registration. Success hole shathe shathe login kore dey.
  Future<String?> register({
    required String name,
    required String employeeId,
    required String company,
    required String address,
    required String username,
    required String password,
  }) async {
    if (name.trim().isEmpty || username.trim().isEmpty || password.isEmpty) {
      return 'Name, Username o Password lagbe';
    }
    if (password.length < 4) {
      return 'Password kompokkhe 4 character hote hobe';
    }
    final profile = UserProfile(
      name: name.trim(),
      employeeId: employeeId.trim(),
      company: company.trim(),
      address: address.trim(),
      username: username.trim(),
      passwordHash: hashPassword(password),
    );
    await _saveProfile(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, true);
    return null; // null মানে error nei, success
  }

  /// Login attempt. rememberMe true hole login state save thakbe
  /// (app abar khulle direct Home dekhabe). false hole shudhu ei
  /// session-er jonne login thakbe, app abar khulle Login chaibe.
  Future<String?> login(String username, String password, {bool rememberMe = true}) async {
    final profile = await getProfile();
    if (profile == null) {
      return 'Kono account registered nei. Age Register korun.';
    }
    if (profile.username.trim().toLowerCase() != username.trim().toLowerCase() ||
        profile.passwordHash != hashPassword(password)) {
      return 'Username ba Password bhul hoyeche';
    }
    if (rememberMe) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loggedInKey, true);
    }
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
  }

  /// Password change. Old password mile tobe notun password set hobe.
  Future<String?> changePassword(String oldPassword, String newPassword) async {
    final profile = await getProfile();
    if (profile == null) return 'Profile paoa jayni';
    if (profile.passwordHash != hashPassword(oldPassword)) {
      return 'Purono Password bhul hoyeche';
    }
    if (newPassword.length < 4) {
      return 'Notun Password kompokkhe 4 character hote hobe';
    }
    profile.passwordHash = hashPassword(newPassword);
    await _saveProfile(profile);
    return null;
  }

  /// Settings screen theke profile info (name/ID/company/address) update.
  /// Username o password change hoy na ei function diye.
  Future<void> updateProfile({
    required String name,
    required String employeeId,
    required String company,
    required String address,
  }) async {
    final profile = await getProfile();
    if (profile == null) return;
    profile.name = name;
    profile.employeeId = employeeId;
    profile.company = company;
    profile.address = address;
    await _saveProfile(profile);
  }

  /// Kono sensitive kaj (reset / mark-unmark) korar age password verify.
  Future<bool> verifyPassword(String password) async {
    final profile = await getProfile();
    if (profile == null) return false;
    return profile.passwordHash == hashPassword(password);
  }

  /// Forgot Password flow: Username + Employee ID mile identity verify
  /// hoy (email/SMS backend nei bole ei simple upay), tারপর notun
  /// password set kora jay.
  Future<String?> resetPasswordWithIdentity({
    required String username,
    required String employeeId,
    required String newPassword,
  }) async {
    final profile = await getProfile();
    if (profile == null) {
      return 'Kono account registered nei';
    }
    if (profile.username.trim().toLowerCase() != username.trim().toLowerCase() ||
        profile.employeeId.trim().toLowerCase() != employeeId.trim().toLowerCase()) {
      return 'Username ba Employee ID mile ni';
    }
    if (newPassword.length < 4) {
      return 'Notun Password kompokkhe 4 character hote hobe';
    }
    profile.passwordHash = hashPassword(newPassword);
    await _saveProfile(profile);
    return null;
  }
}
