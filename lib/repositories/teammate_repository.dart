import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/daily_challenge.dart';
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

  List<Teammate> _teammates = [];
  DailyChallenge? _dailyChallenge;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  String _searchQuery = '';
  SortType _sortType = SortType.solved;
  int _dailyGoal = 2;
  String _currentUserHandle = 'vuvcVjbwmU';
  DateTime? _lastSyncTime;

  TeammateRepository({
    required this.graphQLService,
    required this.storageService,
  });

  List<Teammate> get rawTeammates => List.unmodifiable(_teammates);
  DailyChallenge? get dailyChallenge => _dailyChallenge;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  SortType get sortType => _sortType;
  int get dailyGoal => _dailyGoal;
  String get currentUserHandle => _currentUserHandle;
  DateTime? get lastSyncTime => _lastSyncTime;

  Teammate? get currentUserTeammate {
    try {
      return _teammates.firstWhere(
        (t) =>
            t.isCurrentUser ||
            t.username.toLowerCase() == _currentUserHandle.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Teammate? findByUsername(String username) {
    try {
      return _teammates.firstWhere(
        (t) => t.username.toLowerCase() == username.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Filtered and sorted leaderboard list
  List<Teammate> get leaderboardTeammates {
    var list = List<Teammate>.from(_teammates);

    // 1. Search query filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((t) {
        final matchesUsername = t.username.toLowerCase().contains(q);
        final matchesName = t.effectiveName.toLowerCase().contains(q);
        return matchesUsername || matchesName;
      }).toList();
    }

    // 2. Sorting
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

  /// Initialize from storage and trigger live sync
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUserHandle =
          await storageService.getCurrentUserHandle() ?? 'vuvcVjbwmU';
      _dailyGoal = await storageService.getDailyGoal();
      _teammates = await storageService.loadTeammates();
      _isLoading = false;
      notifyListeners();

      // Trigger background sync for live stats
      unawaited(refreshAll(silent: true));
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load local data: $e';
      notifyListeners();
    }
  }

  /// Refresh all teammates and daily challenge
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

      // 2. Fetch all teammates concurrently with timeout tolerance
      final updatedList = <Teammate>[];
      for (final teammate in _teammates) {
        try {
          final updated = await graphQLService.fetchFullTeammateData(teammate);
          // Preserve currentUser flag
          updatedList.add(updated.copyWith(
            isCurrentUser: teammate.isCurrentUser ||
                teammate.username.toLowerCase() ==
                    _currentUserHandle.toLowerCase(),
          ));
        } catch (e) {
          // Keep cached data on individual network failure
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
    _teammates[idx] = updated.copyWith(
      isCurrentUser: current.isCurrentUser ||
          current.username.toLowerCase() == _currentUserHandle.toLowerCase(),
    );
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

    // Check duplicate
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

    final isUser =
        trimmedUser.toLowerCase() == _currentUserHandle.toLowerCase();

    final newTeammate = Teammate(
      username: profile.username.isNotEmpty ? profile.username : trimmedUser,
      displayName: (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : null,
      avatarUrl: profile.userAvatar,
      profile: profile,
      recentSubmissions: submissions,
      lastUpdated: DateTime.now(),
      isCurrentUser: isUser,
    );

    _teammates.add(newTeammate);
    await storageService.saveTeammates(_teammates);
    notifyListeners();
  }

  /// Count of other teammates in roster (excluding current user)
  int get otherTeammatesCount => _teammates.where((t) {
        final isMe = t.isCurrentUser ||
            t.username.toLowerCase() == _currentUserHandle.toLowerCase();
        return !isMe;
      }).length;

  /// Wipe all teammate profiles while strictly preserving the current user's own profile
  Future<int> wipeTeammates() async {
    final beforeCount = _teammates.length;
    _teammates.removeWhere((t) {
      final isMe = t.isCurrentUser ||
          t.username.toLowerCase() == _currentUserHandle.toLowerCase();
      return !isMe;
    });
    final removed = beforeCount - _teammates.length;
    await storageService.saveTeammates(_teammates);
    notifyListeners();
    return removed;
  }

  /// Remove teammate from local roster
  Future<void> removeTeammate(String username) async {
    _teammates.removeWhere(
      (t) => t.username.toLowerCase() == username.toLowerCase(),
    );
    await storageService.saveTeammates(_teammates);
    notifyListeners();
  }

  /// Update daily problem goal
  Future<void> updateDailyGoal(int goal) async {
    _dailyGoal = goal;
    await storageService.setDailyGoal(goal);
    notifyListeners();
  }

  /// Update current user handle
  Future<void> updateCurrentUserHandle(String handle) async {
    _currentUserHandle = handle.trim();
    await storageService.setCurrentUserHandle(_currentUserHandle);

    // Update isCurrentUser flags
    _teammates = _teammates.map((t) {
      final isMe =
          t.username.toLowerCase() == _currentUserHandle.toLowerCase();
      return t.copyWith(isCurrentUser: isMe);
    }).toList();

    await storageService.saveTeammates(_teammates);
    notifyListeners();
  }

  /// Reset all
  Future<void> resetAll() async {
    await storageService.clearAll();
    await initialize();
  }
}
