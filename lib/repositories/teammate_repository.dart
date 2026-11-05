import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/daily_challenge.dart';
import '../models/leetcode_profile.dart';
import '../models/leetcode_submission.dart';
import '../models/teammate.dart';
import '../services/firestore_service.dart';
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
  final FirestoreService? firestoreService;

  String? _currentUserId;
  String? _primaryUsername;
  LeetCodeProfile? _primaryProfile;
  List<LeetCodeSubmission> _primarySubmissions = [];
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
    this.firestoreService,
  });

  String? get currentUserId => _currentUserId;
  bool get isInitialized => _isInitialized;
  bool get hasPrimaryProfile =>
      _primaryUsername != null && _primaryUsername!.trim().isNotEmpty;
  String? get primaryUsername => _primaryUsername;
  String get currentUserHandle => _primaryUsername ?? '';
  LeetCodeProfile? get primaryProfile => _primaryProfile;
  List<LeetCodeSubmission> get primarySubmissions =>
      List.unmodifiable(_primarySubmissions);

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
      recentSubmissions: _primarySubmissions,
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

  /// Bind the repository to an authenticated user (or null on sign out)
  Future<void> bindUser(String? uid) async {
    if (uid == null) {
      // User signed out: clear in-memory state cleanly to avoid data leakage
      _currentUserId = null;
      _primaryUsername = null;
      _primaryProfile = null;
      _primarySubmissions = [];
      _teammates = [];
      _dailyChallenge = null;
      _errorMessage = null;
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Prevent redundant sync if already bound and loaded
    if (_currentUserId == uid && _isInitialized && !_isLoading) {
      return;
    }

    _currentUserId = uid;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Read cached state for this UID for fast display
      _primaryUsername = await storageService.getPrimaryUsername(uid);
      _primaryProfile = await storageService.getPrimaryProfile(uid);
      _primarySubmissions = await storageService.getPrimarySubmissions(uid);
      _dailyGoal = await storageService.getDailyGoal(uid);
      _teammates = await storageService.loadTeammates(uid);

      // 2. Fetch authoritative state from Cloud Firestore if available
      if (firestoreService != null) {
        final userDoc = await firestoreService!.getUserDocument(uid);
        if (userDoc != null && userDoc['primaryProfileSetupComplete'] == true) {
          final cloudHandle = userDoc['primaryLeetCodeUsername']?.toString();
          final rawProfile = userDoc['primaryLeetCodeProfile'];

          if (cloudHandle != null && cloudHandle.isNotEmpty) {
            _primaryUsername = cloudHandle;
            await storageService.savePrimaryUsername(cloudHandle, uid);
          }

          if (rawProfile is Map<String, dynamic>) {
            _primaryProfile = LeetCodeProfile.fromJson(rawProfile);
            await storageService.savePrimaryProfile(_primaryProfile!, uid);
          } else if (rawProfile is Map) {
            _primaryProfile =
                LeetCodeProfile.fromJson(Map<String, dynamic>.from(rawProfile));
            await storageService.savePrimaryProfile(_primaryProfile!, uid);
          }
        } else if (userDoc != null &&
            userDoc['primaryProfileSetupComplete'] != true) {
          // Cloud indicates profile setup is not complete
          _primaryUsername = null;
          _primaryProfile = null;
          _primarySubmissions = [];
          await storageService.clearPrimaryProfile(uid);
        }

        // 3. Load cloud members subcollection
        final cloudMembers = await firestoreService!.getMembers(uid);
        _teammates = cloudMembers;

        // Ensure primary profile is never duplicated inside peer teammates roster
        if (_primaryUsername != null) {
          final pLower = _primaryUsername!.toLowerCase();
          _teammates.removeWhere((t) => t.username.toLowerCase() == pLower);
        }
        await storageService.saveTeammates(_teammates, uid);
      }

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();

      // If primary profile is configured, fetch live stats in background
      if (hasPrimaryProfile) {
        unawaited(refreshAll(silent: true));
      }
    } catch (e) {
      _isInitialized = true;
      _isLoading = false;
      _errorMessage = 'Cloud sync error: $e';
      notifyListeners();
    }
  }

  /// Initialize fallback (for local-only / tests)
  Future<void> initialize() async {
    if (_currentUserId != null) {
      await bindUser(_currentUserId);
      return;
    }
    _isLoading = true;
    notifyListeners();

    try {
      _primaryUsername = await storageService.getPrimaryUsername();
      _primaryProfile = await storageService.getPrimaryProfile();
      _primarySubmissions = await storageService.getPrimarySubmissions();
      _dailyGoal = await storageService.getDailyGoal();
      _teammates = await storageService.loadTeammates();

      if (_primaryUsername != null) {
        final pLower = _primaryUsername!.toLowerCase();
        _teammates.removeWhere((t) => t.username.toLowerCase() == pLower);
      }

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();

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

  /// Setup and verify the user's primary LeetCode profile
  Future<void> setupPrimaryProfile(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      throw Exception('Please enter a LeetCode username');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Verify username against LeetCode GraphQL
      final profile = await graphQLService.fetchUserProfile(trimmed);
      List<LeetCodeSubmission> submissions = [];
      try {
        submissions = await graphQLService.fetchRecentSubmissions(trimmed);
      } catch (_) {}

      // 2. Persist to Firestore under currently authenticated user
      if (_currentUserId != null && firestoreService != null) {
        await firestoreService!.savePrimaryProfile(
          uid: _currentUserId!,
          username: trimmed,
          profile: profile,
        );
      }

      final displayUsername =
          profile.username.isNotEmpty ? profile.username : trimmed;
      _primaryUsername = displayUsername;
      _primaryProfile = profile;
      _primarySubmissions = submissions;

      await storageService.savePrimaryUsername(displayUsername, _currentUserId);
      await storageService.savePrimaryProfile(profile, _currentUserId);
      await storageService.savePrimarySubmissions(submissions, _currentUserId);

      // Ensure primary user is not in teammates
      _teammates.removeWhere(
          (t) => t.username.toLowerCase() == displayUsername.toLowerCase());
      await storageService.saveTeammates(_teammates, _currentUserId);

      _isLoading = false;
      notifyListeners();

      // Trigger background sync
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
          await storageService.savePrimaryProfile(updatedPrimary, _currentUserId);
        } catch (_) {}
        try {
          final updatedSubs =
              await graphQLService.fetchRecentSubmissions(_primaryUsername!);
          _primarySubmissions = updatedSubs;
          await storageService.savePrimarySubmissions(updatedSubs, _currentUserId);
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
      await storageService.saveTeammates(_teammates, _currentUserId);
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

  /// Refresh a single member (peer teammate or primary profile)
  Future<Teammate> refreshTeammate(String username) async {
    final lower = username.toLowerCase();
    if (_primaryUsername != null && _primaryUsername!.toLowerCase() == lower) {
      final updatedPrimary =
          await graphQLService.fetchUserProfile(_primaryUsername!);
      _primaryProfile = updatedPrimary;
      await storageService.savePrimaryProfile(updatedPrimary, _currentUserId);

      try {
        final updatedSubs =
            await graphQLService.fetchRecentSubmissions(_primaryUsername!);
        _primarySubmissions = updatedSubs;
        await storageService.savePrimarySubmissions(updatedSubs, _currentUserId);
      } catch (_) {}

      notifyListeners();
      return primaryTeammate!;
    }

    final idx = _teammates.indexWhere(
      (t) => t.username.toLowerCase() == lower,
    );
    if (idx == -1) {
      throw Exception('Teammate not found');
    }

    final current = _teammates[idx];
    final updated = await graphQLService.fetchFullTeammateData(current);
    _teammates[idx] = updated.copyWith(isCurrentUser: false);
    await storageService.saveTeammates(_teammates, _currentUserId);
    notifyListeners();
    return _teammates[idx];
  }

  /// Verify and add a new teammate to cloud and local state
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
    List<LeetCodeSubmission> submissions = [];
    try {
      submissions = await graphQLService.fetchRecentSubmissions(trimmedUser);
    } catch (_) {}

    final validatedHandle =
        profile.username.isNotEmpty ? profile.username : trimmedUser;

    // Persist to Cloud Firestore under current user's members subcollection
    if (_currentUserId != null && firestoreService != null) {
      await firestoreService!.addMember(
        uid: _currentUserId!,
        username: validatedHandle,
        displayName: displayName,
        profile: profile,
      );
    }

    final newTeammate = Teammate(
      username: validatedHandle,
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
    await storageService.saveTeammates(_teammates, _currentUserId);
    notifyListeners();
  }

  /// Wipe all teammate records from cloud and local roster, preserving primary profile
  Future<int> wipeTeammates() async {
    int count = _teammates.length;
    if (_currentUserId != null && firestoreService != null) {
      count = await firestoreService!.wipeMembers(_currentUserId!);
    }
    _teammates.clear();
    await storageService.clearTeammates(_currentUserId);
    notifyListeners();
    return count;
  }

  /// Remove single teammate from cloud and local roster
  Future<void> removeTeammate(String username) async {
    // Primary profile cannot be deleted via teammate removal
    if (_primaryUsername != null &&
        username.toLowerCase() == _primaryUsername!.toLowerCase()) {
      return;
    }

    if (_currentUserId != null && firestoreService != null) {
      await firestoreService!.removeMember(_currentUserId!, username);
    }

    _teammates.removeWhere(
      (t) => t.username.toLowerCase() == username.toLowerCase(),
    );
    await storageService.saveTeammates(_teammates, _currentUserId);
    notifyListeners();
  }

  /// Sign out primary profile locally
  Future<void> signOutPrimaryProfile() async {
    _primaryUsername = null;
    _primaryProfile = null;
    _primarySubmissions = [];
    await storageService.clearPrimaryProfile(_currentUserId);
    notifyListeners();
  }

  /// Update daily problem goal
  Future<void> updateDailyGoal(int goal) async {
    _dailyGoal = goal;
    await storageService.setDailyGoal(goal, _currentUserId);
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
    _primarySubmissions.clear();
    _teammates.clear();
    await initialize();
  }
}
