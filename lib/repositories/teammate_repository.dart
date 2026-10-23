import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/daily_challenge.dart';
import '../models/leetcode_profile.dart';
import '../models/teammate.dart';
import '../services/leetcode_graphql_service.dart';
import '../services/local_storage_service.dart';

enum SortType {
  solved,
  streak,
  accuracy,
}

class TeammateRepository extends ChangeNotifier {
  final LeetCodeGraphQLService graphQLService;
  final LocalStorageService storageService;

  String? _primaryUsername;
  LeetCodeProfile? _primaryProfile;
  List<Teammate> _teammates = [];
  DailyChallenge? _dailyChallenge;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  String _searchQuery = '';
  SortType _sortType = SortType.solved;
  int _dailyGoal = 2;
  DateTime? _lastSyncTime;

  TeammateRepository({
    required this.graphQLService,
    required this.storageService,
  });

  bool get isInitialized => _isInitialized;
  bool get hasPrimaryProfile =>
      _primaryUsername != null && _primaryUsername!.trim().isNotEmpty;
  String? get primaryUsername => _primaryUsername;
  String get currentUserHandle => _primaryUsername ?? '';
  LeetCodeProfile? get primaryProfile => _primaryProfile;

  List<Teammate> get rawTeammates => List.unmodifiable(_teammates);
  int get teammateCount => _teammates.length;
  DailyChallenge? get dailyChallenge => _dailyChallenge;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  SortType get sortType => _sortType;
  int get dailyGoal => _dailyGoal;
  DateTime? get lastSyncTime => _lastSyncTime;

  Teammate? get primaryTeammate {
    if (!hasPrimaryProfile) return null;
    return Teammate(
      username: _primaryUsername!,
      displayName: _primaryProfile?.realName ?? _primaryUsername!,
      avatarUrl: _primaryProfile?.userAvatar,
      profile: _primaryProfile,
      recentSubmissions: const [],
      isCurrentUser: true,
    );
  }

  Teammate? findByUsername(String username) {
    if (_primaryUsername != null &&
        username.toLowerCase() == _primaryUsername!.toLowerCase()) {
      return primaryTeammate;
    }
    try {
      return _teammates.firstWhere(
        (t) => t.username.toLowerCase() == username.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Filtered and sorted leaderboard list including primary profile ('You')
  /// and peer teammates, deduplicated case-insensitively.
  List<Teammate> get leaderboardTeammates {
    final combined = <Teammate>[];

    // 1. Add primary profile as 'You' if configured
    final primary = primaryTeammate;
    if (primary != null) {
      combined.add(primary);
    }

    // 2. Add peer teammates, ensuring no case-insensitive duplicate of primary profile
    final primaryLower = _primaryUsername?.toLowerCase();
    for (final t in _teammates) {
      if (primaryLower != null && t.username.toLowerCase() == primaryLower) {
        continue;
      }
      combined.add(t.copyWith(isCurrentUser: false));
    }

    var list = combined;

    // 3. Search query filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((t) {
        final matchesUsername = t.username.toLowerCase().contains(q);
        final matchesName = t.effectiveName.toLowerCase().contains(q);
        return matchesUsername || matchesName;
      }).toList();
    }

    // 4. Sorting
    switch (_sortType) {
      case SortType.solved:
        list.sort((a, b) => b.totalSolved.compareTo(a.totalSolved));
        break;
      case SortType.streak:
        list.sort((a, b) {
          final cmp = b.streak.compareTo(a.streak);
          if (cmp != 0) return cmp;
          return b.totalSolved.compareTo(a.totalSolved);
        });
        break;
      case SortType.accuracy:
        list.sort((a, b) {
          final accA = a.accuracy ?? 0.0;
          final accB = b.accuracy ?? 0.0;
          final cmp = accB.compareTo(accA);
          if (cmp != 0) return cmp;
          return b.totalSolved.compareTo(a.totalSolved);
        });
        break;
    }

    return list;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortType(SortType type) {
    _sortType = type;
    notifyListeners();
  }

  /// Initialize from local storage on app start
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _primaryUsername = await storageService.getPrimaryUsername();
      _primaryProfile = await storageService.getPrimaryProfile();
      _dailyGoal = await storageService.getDailyGoal();
      _teammates = await storageService.loadTeammates();

      // Ensure primary profile is never displayed inside teammates roster
      if (_primaryUsername != null) {
        final pLower = _primaryUsername!.toLowerCase();
        _teammates.removeWhere((t) => t.username.toLowerCase() == pLower);
      }

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();

      // If primary profile is configured, trigger live sync in background
      if (hasPrimaryProfile) {
        unawaited(refreshAll(silent: true));
      }
    } catch (e) {
      _isInitialized = true;
      _isLoading = false;
      _errorMessage = 'Failed to load local data: $e';
      notifyListeners();
    }
  }

  /// Setup and verify the user's primary LeetCode profile on first launch
  Future<void> setupPrimaryProfile(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      throw Exception('Please enter a LeetCode username');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Query LeetCode GraphQL to verify profile exists
      final profile = await graphQLService.fetchUserProfile(trimmed);

      _primaryUsername = profile.username.isNotEmpty ? profile.username : trimmed;
      _primaryProfile = profile;

      await storageService.savePrimaryUsername(_primaryUsername!);
      await storageService.savePrimaryProfile(profile);

      // Ensure primary user is not in teammates
      _teammates.removeWhere((t) => t.username.toLowerCase() == _primaryUsername!.toLowerCase());
      await storageService.saveTeammates(_teammates);

      _isLoading = false;
      notifyListeners();

      // Background fetch daily challenge and teammates
      unawaited(refreshAll(silent: true));
    } catch (e) {
      _isLoading = false;
      final msg = e.toString().replaceFirst('Exception: ', '');
      _errorMessage = msg;
      notifyListeners();
      rethrow;
    }
  }

  /// Refresh primary profile, daily challenge, and all teammates
  Future<void> refreshAll({bool silent = false}) async {
    if (!silent) {
      _isRefreshing = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      // 1. Fetch Daily Challenge
      try {
        _dailyChallenge = await graphQLService.fetchDailyChallenge();
      } catch (_) {}

      // 2. Refresh Primary Profile if configured
      if (_primaryUsername != null && _primaryUsername!.isNotEmpty) {
        try {
          final updatedPrimary =
              await graphQLService.fetchUserProfile(_primaryUsername!);
          _primaryProfile = updatedPrimary;
          await storageService.savePrimaryProfile(updatedPrimary);
        } catch (_) {}
      }

      // 3. Fetch all teammates concurrently with individual timeout tolerance
      final updatedList = <Teammate>[];
      for (final teammate in _teammates) {
        try {
          final updated = await graphQLService.fetchFullTeammateData(teammate);
          updatedList.add(updated.copyWith(isCurrentUser: false));
        } catch (e) {
          // Keep cached data on network error
          updatedList.add(teammate);
        }
      }

      _teammates = updatedList;
      _lastSyncTime = DateTime.now();
      await storageService.saveTeammates(_teammates);
    } catch (e) {
      if (!silent) {
        _errorMessage = 'Failed to refresh data: $e';
      }
    } finally {
      _isRefreshing = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh a single teammate
  Future<Teammate> refreshTeammate(String username) async {
    final idx = _teammates.indexWhere(
      (t) => t.username.toLowerCase() == username.toLowerCase(),
    );
    if (idx == -1) {
      throw Exception('Teammate not found');
    }

    final current = _teammates[idx];
    final updated = await graphQLService.fetchFullTeammateData(current);
    _teammates[idx] = updated.copyWith(isCurrentUser: false);
    await storageService.saveTeammates(_teammates);
    notifyListeners();
    return _teammates[idx];
  }

  /// Verify and add a new teammate
  Future<void> addTeammate(String username, {String? displayName}) async {
    final trimmedUser = username.trim();
    if (trimmedUser.isEmpty) {
      throw Exception('Username cannot be empty');
    }

    // Check if user is trying to add themselves as a teammate
    if (_primaryUsername != null &&
        trimmedUser.toLowerCase() == _primaryUsername!.toLowerCase()) {
      throw Exception(
        'This is your primary profile handle. The leaderboard is for tracking teammates.',
      );
    }

    // Check duplicate in teammates list
    final exists = _teammates.any(
      (t) => t.username.toLowerCase() == trimmedUser.toLowerCase(),
    );
    if (exists) {
      throw Exception('Teammate @$trimmedUser is already on the leaderboard');
    }

    // Fetch from LeetCode GraphQL to verify existence and fetch data
    final profile = await graphQLService.fetchUserProfile(trimmedUser);
    final submissions =
        await graphQLService.fetchRecentSubmissions(trimmedUser);

    final newTeammate = Teammate(
      username: profile.username.isNotEmpty ? profile.username : trimmedUser,
      displayName: (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : null,
      avatarUrl: profile.userAvatar,
      profile: profile,
      recentSubmissions: submissions,
      lastUpdated: DateTime.now(),
      isCurrentUser: false,
    );

    _teammates.add(newTeammate);
    await storageService.saveTeammates(_teammates);
    notifyListeners();
  }

  /// Wipe all teammate records, strictly preserving primary profile
  Future<int> wipeTeammates() async {
    final count = _teammates.length;
    _teammates.clear();
    await storageService.clearTeammates();
    notifyListeners();
    return count;
  }

  /// Remove single teammate from local roster
  Future<void> removeTeammate(String username) async {
    // Primary profile cannot be deleted via teammate removal
    if (_primaryUsername != null &&
        username.toLowerCase() == _primaryUsername!.toLowerCase()) {
      return;
    }
    _teammates.removeWhere(
      (t) => t.username.toLowerCase() == username.toLowerCase(),
    );
    await storageService.saveTeammates(_teammates);
    notifyListeners();
  }

  /// Sign out primary profile: clears only primary profile and username from storage and state.
  /// Does NOT touch teammate profiles, their local roster, or unrelated preferences.
  Future<void> signOutPrimaryProfile() async {
    _primaryUsername = null;
    _primaryProfile = null;
    await storageService.clearPrimaryProfile();
    notifyListeners();
  }

  /// Update daily problem goal
  Future<void> updateDailyGoal(int goal) async {
    _dailyGoal = goal;
    await storageService.setDailyGoal(goal);
    notifyListeners();
  }

  /// Update primary handle
  Future<void> updateCurrentUserHandle(String handle) async {
    await setupPrimaryProfile(handle);
  }

  /// Reset all local storage
  Future<void> resetAll() async {
    await storageService.clearAll();
    _primaryUsername = null;
    _primaryProfile = null;
    _teammates.clear();
    await initialize();
  }
}
