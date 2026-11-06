import 'daily_challenge.dart';
import 'leetcode_profile.dart';
import 'leetcode_submission.dart';

class Teammate {
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final LeetCodeProfile? profile;
  final List<LeetCodeSubmission> recentSubmissions;
  final DateTime? lastUpdated;
  final bool isCurrentUser;

  const Teammate({
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.profile,
    this.recentSubmissions = const [],
    this.lastUpdated,
    this.isCurrentUser = false,
  });

  String get effectiveName {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    if (profile?.realName != null && profile!.realName!.trim().isNotEmpty) {
      return profile!.realName!.trim();
    }
    return username;
  }

  String get effectiveAvatar {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) return avatarUrl!;
    if (profile?.userAvatar != null && profile!.userAvatar!.isNotEmpty) {
      return profile!.userAvatar!;
    }
    return '';
  }

  int get totalSolved => profile?.totalSolved ?? 0;
  int get easySolved => profile?.easySolved ?? 0;
  int get mediumSolved => profile?.mediumSolved ?? 0;
  int get hardSolved => profile?.hardSolved ?? 0;
  double? get accuracy => profile?.accuracy;
  int get streak => profile?.streak ?? 0;
  bool get hasSolvedToday => profile?.hasSolvedToday ?? false;
  double? get contestRating => profile?.contestRating;

  /// Checks whether this teammate solved today's official LeetCode Daily Coding Challenge.
  /// Strictly checks against the active [DailyChallenge] title or titleSlug and ensures
  /// the submission was accepted during the challenge window (not an old solve or a random problem).
  bool hasSolvedDailyChallenge(DailyChallenge? dailyChallenge) {
    if (dailyChallenge == null || !dailyChallenge.isValid) return false;

    final potdSlug = dailyChallenge.titleSlug.trim().toLowerCase();
    final potdTitle = dailyChallenge.title.trim().toLowerCase();

    for (final sub in recentSubmissions) {
      final subSlug = sub.titleSlug.trim().toLowerCase();
      final subTitle = sub.title.trim().toLowerCase();

      final matchesSlug = potdSlug.isNotEmpty && subSlug == potdSlug;
      final matchesTitle = potdTitle.isNotEmpty && subTitle == potdTitle;

      if (!matchesSlug && !matchesTitle) continue;

      if (sub.statusDisplay != null &&
          sub.statusDisplay!.trim().isNotEmpty &&
          sub.statusDisplay!.trim().toLowerCase() != 'accepted') {
        continue;
      }

      if (_isSubmissionForDailyChallenge(sub, dailyChallenge)) {
        return true;
      }
    }

    return false;
  }

  static bool _isSubmissionForDailyChallenge(
    LeetCodeSubmission sub,
    DailyChallenge dailyChallenge,
  ) {
    final challengeDateStr = dailyChallenge.date.trim();

    // 1. Direct UTC calendar date match against dailyChallenge.date (standard LeetCode day)
    final subUtc =
        DateTime.fromMillisecondsSinceEpoch(sub.timestamp * 1000, isUtc: true);
    final subUtcDateStr =
        '${subUtc.year}-${subUtc.month.toString().padLeft(2, '0')}-${subUtc.day.toString().padLeft(2, '0')}';

    if (challengeDateStr.isNotEmpty && subUtcDateStr == challengeDateStr) {
      return true;
    }

    // 2. Local date match: submitted today in user's local timezone
    final now = DateTime.now();
    final subLocal = sub.dateTime;
    final isSameLocalDate = subLocal.year == now.year &&
        subLocal.month == now.month &&
        subLocal.day == now.day;

    if (isSameLocalDate) {
      return true;
    }

    // 3. Rolling 24-hour window tolerance
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    final diffSeconds = nowSec - sub.timestamp;
    if (diffSeconds >= 0 && diffSeconds <= 86400) {
      return true;
    }

    return false;
  }

  Teammate copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    LeetCodeProfile? profile,
    List<LeetCodeSubmission>? recentSubmissions,
    DateTime? lastUpdated,
    bool? isCurrentUser,
  }) {
    return Teammate(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profile: profile ?? this.profile,
      recentSubmissions: recentSubmissions ?? this.recentSubmissions,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'profile': profile?.toJson(),
        'recentSubmissions':
            recentSubmissions.map((s) => s.toJson()).toList(),
        'lastUpdated': lastUpdated?.toIso8601String(),
        'isCurrentUser': isCurrentUser,
      };

  factory Teammate.fromJson(Map<String, dynamic> json) {
    return Teammate(
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      profile: json['profile'] != null
          ? LeetCodeProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
      recentSubmissions: (json['recentSubmissions'] as List<dynamic>?)
              ?.map((e) =>
                  LeetCodeSubmission.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString())
          : null,
      isCurrentUser: json['isCurrentUser'] == true,
    );
  }
}
