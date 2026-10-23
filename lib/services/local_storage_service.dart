import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teammate.dart';

class LocalStorageService {
  static const String _keyTeammates = 'leeto_teammates_roster';
  static const String _keyCurrentUser = 'leeto_current_user_handle';
  static const String _keyDailyGoal = 'leeto_daily_goal';
  static const String _keyRemindersEnabled = 'leeto_reminders_enabled';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  /// Load teammates from disk, or initialize default showcase roster on first launch
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

    // Default showcase roster
    final currentUserHandle = await getCurrentUserHandle() ?? 'vuvcVjbwmU';
    final initialRoster = [
      Teammate(
        username: 'vuvcVjbwmU',
        displayName: 'Harshit Verma',
        isCurrentUser: currentUserHandle.toLowerCase() == 'vuvcvjbwmu',
      ),
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

  /// Save full roster to persistent storage
  Future<void> saveTeammates(List<Teammate> teammates) async {
    final jsonList = teammates.map((t) => t.toJson()).toList();
    await _prefs.setString(_keyTeammates, json.encode(jsonList));
  }

  /// Current user's LeetCode handle
  Future<String?> getCurrentUserHandle() async {
    return _prefs.getString(_keyCurrentUser) ?? 'vuvcVjbwmU';
  }

  Future<void> setCurrentUserHandle(String handle) async {
    await _prefs.setString(_keyCurrentUser, handle.trim());
  }

  /// Daily study goal
  Future<int> getDailyGoal() async {
    return _prefs.getInt(_keyDailyGoal) ?? 2;
  }

  Future<void> setDailyGoal(int goal) async {
    await _prefs.setInt(_keyDailyGoal, goal);
  }

  /// Daily practice reminders
  Future<bool> getRemindersEnabled() async {
    return _prefs.getBool(_keyRemindersEnabled) ?? false;
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    await _prefs.setBool(_keyRemindersEnabled, enabled);
  }

  /// Reset all stored data
  Future<void> clearAll() async {
    await _prefs.remove(_keyTeammates);
    await _prefs.remove(_keyCurrentUser);
    await _prefs.remove(_keyDailyGoal);
    await _prefs.remove(_keyRemindersEnabled);
  }
}
