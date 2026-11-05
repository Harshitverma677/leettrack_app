import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/leetcode_profile.dart';
import '../models/leetcode_submission.dart';
import '../models/teammate.dart';

class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  String _keyPrimaryUsername(String? uid) =>
      uid != null && uid.isNotEmpty ? 'leeto_${uid}_primary_username' : 'leeto_primary_username';

  String _keyPrimaryProfile(String? uid) =>
      uid != null && uid.isNotEmpty ? 'leeto_${uid}_primary_profile' : 'leeto_primary_profile';

  String _keyPrimarySubmissions(String? uid) =>
      uid != null && uid.isNotEmpty ? 'leeto_${uid}_primary_submissions' : 'leeto_primary_submissions';

  String _keyTeammates(String? uid) =>
      uid != null && uid.isNotEmpty ? 'leeto_${uid}_teammates_roster' : 'leeto_teammates_roster';

  String _keyDailyGoal(String? uid) =>
      uid != null && uid.isNotEmpty ? 'leeto_${uid}_daily_goal' : 'leeto_daily_goal';

  static const String _keyRemindersEnabled = 'leeto_reminders_enabled';

  // --- Primary Profile (User's own LeetCode handle and profile) ---

  Future<String?> getPrimaryUsername([String? uid]) async {
    return _prefs.getString(_keyPrimaryUsername(uid));
  }

  Future<void> savePrimaryUsername(String username, [String? uid]) async {
    await _prefs.setString(_keyPrimaryUsername(uid), username.trim());
  }

  Future<LeetCodeProfile?> getPrimaryProfile([String? uid]) async {
    final raw = _prefs.getString(_keyPrimaryProfile(uid));
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        return LeetCodeProfile.fromJson(decoded);
      } catch (_) {}
    }
    return null;
  }

  Future<void> savePrimaryProfile(LeetCodeProfile profile, [String? uid]) async {
    await _prefs.setString(_keyPrimaryProfile(uid), json.encode(profile.toJson()));
  }

  Future<List<LeetCodeSubmission>> getPrimarySubmissions([String? uid]) async {
    final raw = _prefs.getString(_keyPrimarySubmissions(uid));
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as List<dynamic>;
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => LeetCodeSubmission.fromJson(e))
            .toList();
      } catch (_) {}
    }
    return [];
  }

  Future<void> savePrimarySubmissions(
    List<LeetCodeSubmission> submissions, [
    String? uid,
  ]) async {
    final jsonList = submissions.map((s) => s.toJson()).toList();
    await _prefs.setString(_keyPrimarySubmissions(uid), json.encode(jsonList));
  }

  /// Clear only the saved primary LeetCode username and cached primary profile
  Future<void> clearPrimaryProfile([String? uid]) async {
    await _prefs.remove(_keyPrimaryUsername(uid));
    await _prefs.remove(_keyPrimaryProfile(uid));
    await _prefs.remove(_keyPrimarySubmissions(uid));
  }

  // --- Teammate Roster (Separate from Primary Profile) ---

  Future<List<Teammate>> loadTeammates([String? uid]) async {
    final raw = _prefs.getString(_keyTeammates(uid));
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as List<dynamic>;
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => Teammate.fromJson(item))
            .toList();
      } catch (_) {}
    }

    // Do NOT seed showcase/placeholder teammates.
    // Leaderboard immediately after setup must contain ONLY the primary user.
    return [];
  }

  Future<void> saveTeammates(List<Teammate> teammates, [String? uid]) async {
    final jsonList = teammates.map((t) => t.toJson()).toList();
    await _prefs.setString(_keyTeammates(uid), json.encode(jsonList));
  }

  /// Wipe teammate records only, strictly preserving primary profile and preferences
  Future<void> clearTeammates([String? uid]) async {
    await _prefs.remove(_keyTeammates(uid));
  }

  // --- Study Goals & Reminders ---

  Future<int> getDailyGoal([String? uid]) async {
    return _prefs.getInt(_keyDailyGoal(uid)) ?? 2;
  }

  Future<void> setDailyGoal(int goal, [String? uid]) async {
    await _prefs.setInt(_keyDailyGoal(uid), goal);
  }

  Future<bool> getRemindersEnabled() async {
    return _prefs.getBool(_keyRemindersEnabled) ?? false;
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    await _prefs.setBool(_keyRemindersEnabled, enabled);
  }

  /// Full reset if needed
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
