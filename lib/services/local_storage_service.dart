import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/leetcode_profile.dart';
import '../models/leetcode_submission.dart';
import '../models/teammate.dart';

class LocalStorageService {
  static const String _keyPrimaryUsername = 'leeto_primary_username';
  static const String _keyPrimaryProfile = 'leeto_primary_profile';
  static const String _keyPrimarySubmissions = 'leeto_primary_submissions';
  static const String _keyTeammates = 'leeto_teammates_roster';
  static const String _keyDailyGoal = 'leeto_daily_goal';
  static const String _keyRemindersEnabled = 'leeto_reminders_enabled';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  // --- Primary Profile (User's own LeetCode handle and profile) ---

  Future<String?> getPrimaryUsername() async {
    return _prefs.getString(_keyPrimaryUsername);
  }

  Future<void> savePrimaryUsername(String username) async {
    await _prefs.setString(_keyPrimaryUsername, username.trim());
  }

  Future<LeetCodeProfile?> getPrimaryProfile() async {
    final raw = _prefs.getString(_keyPrimaryProfile);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        return LeetCodeProfile.fromJson(decoded);
      } catch (_) {}
    }
    return null;
  }

  Future<void> savePrimaryProfile(LeetCodeProfile profile) async {
    await _prefs.setString(_keyPrimaryProfile, json.encode(profile.toJson()));
  }

  Future<List<LeetCodeSubmission>> getPrimarySubmissions() async {
    final raw = _prefs.getString(_keyPrimarySubmissions);
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
      List<LeetCodeSubmission> submissions) async {
    final jsonList = submissions.map((s) => s.toJson()).toList();
    await _prefs.setString(_keyPrimarySubmissions, json.encode(jsonList));
  }

  /// Clear only the saved primary LeetCode username and cached primary profile
  Future<void> clearPrimaryProfile() async {
    await _prefs.remove(_keyPrimaryUsername);
    await _prefs.remove(_keyPrimaryProfile);
    await _prefs.remove(_keyPrimarySubmissions);
  }

  // --- Teammate Roster (Separate from Primary Profile) ---

  Future<List<Teammate>> loadTeammates() async {
    final raw = _prefs.getString(_keyTeammates);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as List<dynamic>;
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => Teammate.fromJson(item))
            .toList();
      } catch (_) {}
    }

    // Default showcase teammates (only peers, no primary user)
    final initialRoster = [
      const Teammate(
        username: '_palakdeep',
        displayName: 'Palakdeep',
        isCurrentUser: false,
      ),
      const Teammate(
        username: 'janhavi0411',
        displayName: 'janhavi',
        isCurrentUser: false,
      ),
    ];

    await saveTeammates(initialRoster);
    return initialRoster;
  }

  Future<void> saveTeammates(List<Teammate> teammates) async {
    final jsonList = teammates.map((t) => t.toJson()).toList();
    await _prefs.setString(_keyTeammates, json.encode(jsonList));
  }

  /// Wipe teammate records only, strictly preserving primary profile and preferences
  Future<void> clearTeammates() async {
    await _prefs.remove(_keyTeammates);
  }

  // --- Study Goals & Reminders ---

  Future<int> getDailyGoal() async {
    return _prefs.getInt(_keyDailyGoal) ?? 2;
  }

  Future<void> setDailyGoal(int goal) async {
    await _prefs.setInt(_keyDailyGoal, goal);
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
