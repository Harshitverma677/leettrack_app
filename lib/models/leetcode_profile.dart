import 'dart:convert';

class TopicCount {
  final String tagName;
  final String tagSlug;
  final int problemsSolved;

  const TopicCount({
    required this.tagName,
    required this.tagSlug,
    required this.problemsSolved,
  });

  factory TopicCount.fromJson(Map<String, dynamic> json) {
    return TopicCount(
      tagName: json['tagName']?.toString() ?? '',
      tagSlug: json['tagSlug']?.toString() ?? '',
      problemsSolved: (json['problemsSolved'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'tagName': tagName,
        'tagSlug': tagSlug,
        'problemsSolved': problemsSolved,
      };
}

class LeetCodeProfile {
  final String username;
  final String? realName;
  final String? userAvatar;
  final int? ranking;
  final int? reputation;
  final int totalSolved;
  final int easySolved;
  final int mediumSolved;
  final int hardSolved;
  final double? accuracy;
  final double? contestRating;
  final int? contestGlobalRanking;
  final int streak;
  final bool hasSolvedToday;
  final Map<String, int> submissionCalendar;
  final List<TopicCount> topTopics;

  const LeetCodeProfile({
    required this.username,
    this.realName,
    this.userAvatar,
    this.ranking,
    this.reputation,
    required this.totalSolved,
    required this.easySolved,
    required this.mediumSolved,
    required this.hardSolved,
    this.accuracy,
    this.contestRating,
    this.contestGlobalRanking,
    required this.streak,
    required this.hasSolvedToday,
    required this.submissionCalendar,
    required this.topTopics,
  });

  // Calculate 90-day stats
  int get submissionsInPast90Days {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ninetyDaysAgo = nowSeconds - (90 * 86400);

    int total = 0;
    submissionCalendar.forEach((tsStr, count) {
      final ts = int.tryParse(tsStr) ?? 0;
      if (ts >= ninetyDaysAgo) {
        total += count;
      }
    });
    return total;
  }

  int get activeDaysInPast90Days {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ninetyDaysAgo = nowSeconds - (90 * 86400);

    int active = 0;
    submissionCalendar.forEach((tsStr, count) {
      final ts = int.tryParse(tsStr) ?? 0;
      if (ts >= ninetyDaysAgo && count > 0) {
        active++;
      }
    });
    return active;
  }

  // Calculate 1-year (365-day) stats matching LeetCode annual calendar
  int get submissionsInPastOneYear {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final oneYearAgo = nowSeconds - (365 * 86400);

    int total = 0;
    submissionCalendar.forEach((tsStr, count) {
      final ts = int.tryParse(tsStr) ?? 0;
      if (ts >= oneYearAgo) {
        total += count;
      }
    });
    return total;
  }

  int get activeDaysInPastOneYear {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final oneYearAgo = nowSeconds - (365 * 86400);

    int active = 0;
    submissionCalendar.forEach((tsStr, count) {
      final ts = int.tryParse(tsStr) ?? 0;
      if (ts >= oneYearAgo && count > 0) {
        active++;
      }
    });
    return active;
  }

  int get maxStreakInPastOneYear {
    if (submissionCalendar.isEmpty) return 0;

    final activeDatesUtc = <String>{};
    submissionCalendar.forEach((tsStr, count) {
      if (count > 0) {
        final ts = int.tryParse(tsStr) ?? 0;
        if (ts > 0) {
          final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
          activeDatesUtc.add(
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}');
        }
      }
    });

    final nowUtc = DateTime.now().toUtc();
    final today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final startDate = today.subtract(const Duration(days: 364));

    int maxStreak = 0;
    int currentStreak = 0;
    var cur = startDate;

    while (!cur.isAfter(today)) {
      final ymd =
          '${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}';
      if (activeDatesUtc.contains(ymd)) {
        currentStreak++;
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }
      cur = cur.add(const Duration(days: 1));
    }

    return maxStreak;
  }

  int get totalActiveDays {
    int active = 0;
    submissionCalendar.forEach((_, count) {
      if (count > 0) active++;
    });
    return active;
  }

  // Solves on specific date (YYYY-MM-DD in UTC)
  int getSolvesOnDate(DateTime date) {
    final dateUtc = DateTime.utc(date.year, date.month, date.day);
    final targetYmd = '${dateUtc.year}-${dateUtc.month.toString().padLeft(2, '0')}-${dateUtc.day.toString().padLeft(2, '0')}';

    int count = 0;
    submissionCalendar.forEach((tsStr, cnt) {
      final ts = int.tryParse(tsStr) ?? 0;
      if (ts > 0) {
        final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
        final dYmd = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        if (dYmd == targetYmd) {
          count += cnt;
        }
      }
    });
    return count;
  }

  factory LeetCodeProfile.fromGraphQL({
    required Map<String, dynamic> matchedUserData,
    Map<String, dynamic>? contestRankingData,
  }) {
    final username = matchedUserData['username']?.toString() ?? '';
    final profile = matchedUserData['profile'] as Map<String, dynamic>? ?? {};
    final realName = profile['realName']?.toString();
    final userAvatar = profile['userAvatar']?.toString();
    final ranking = (profile['ranking'] as num?)?.toInt();
    final reputation = (profile['reputation'] as num?)?.toInt();

    // Stats
    int total = 0;
    int easy = 0;
    int medium = 0;
    int hard = 0;

    int totalAcSubmissions = 0;
    int totalAllSubmissions = 0;

    final submitStats = matchedUserData['submitStatsGlobal'] as Map<String, dynamic>?;
    if (submitStats != null) {
      final acList = submitStats['acSubmissionNum'] as List<dynamic>? ?? [];
      for (final item in acList) {
        if (item is Map<String, dynamic>) {
          final diff = item['difficulty']?.toString();
          final cnt = (item['count'] as num?)?.toInt() ?? 0;
          final subs = (item['submissions'] as num?)?.toInt() ?? 0;

          if (diff == 'All') {
            total = cnt;
            totalAcSubmissions = subs;
          } else if (diff == 'Easy') {
            easy = cnt;
          } else if (diff == 'Medium') {
            medium = cnt;
          } else if (diff == 'Hard') {
            hard = cnt;
          }
        }
      }

      final allList = submitStats['totalSubmissionNum'] as List<dynamic>? ?? [];
      for (final item in allList) {
        if (item is Map<String, dynamic>) {
          final diff = item['difficulty']?.toString();
          final subs = (item['submissions'] as num?)?.toInt() ?? 0;
          if (diff == 'All') {
            totalAllSubmissions = subs;
          }
        }
      }
    }

    double? accuracy;
    if (totalAllSubmissions > 0 && totalAcSubmissions > 0) {
      accuracy = (totalAcSubmissions / totalAllSubmissions) * 100.0;
    }

    // Contest Ranking
    double? contestRating;
    int? contestGlobalRanking;
    if (contestRankingData != null) {
      final r = contestRankingData['rating'] as num?;
      if (r != null) {
        contestRating = r.toDouble();
      }
      final gr = contestRankingData['globalRanking'] as num?;
      if (gr != null) {
        contestGlobalRanking = gr.toInt();
      }
    }

    // Submission calendar
    Map<String, int> subCalMap = {};
    final rawCal = matchedUserData['submissionCalendar'];
    if (rawCal is String && rawCal.isNotEmpty) {
      try {
        final decoded = json.decode(rawCal) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          if (val is num) {
            subCalMap[key] = val.toInt();
          }
        });
      } catch (_) {}
    }

    // Compute streak and today's activity
    final streakResult = _computeStreak(subCalMap);

    // Topics
    List<TopicCount> topics = [];
    final tagCounts = matchedUserData['tagProblemCounts'] as Map<String, dynamic>?;
    if (tagCounts != null) {
      for (final category in ['fundamental', 'intermediate', 'advanced']) {
        final list = tagCounts[category] as List<dynamic>?;
        if (list != null) {
          for (final item in list) {
            if (item is Map<String, dynamic>) {
              topics.add(TopicCount.fromJson(item));
            }
          }
        }
      }
    }
    // Sort topics descending by solves
    topics.sort((a, b) => b.problemsSolved.compareTo(a.problemsSolved));

    return LeetCodeProfile(
      username: username,
      realName: (realName != null && realName.isNotEmpty) ? realName : null,
      userAvatar: userAvatar,
      ranking: ranking,
      reputation: reputation,
      totalSolved: total,
      easySolved: easy,
      mediumSolved: medium,
      hardSolved: hard,
      accuracy: accuracy,
      contestRating: contestRating,
      contestGlobalRanking: contestGlobalRanking,
      streak: streakResult.streak,
      hasSolvedToday: streakResult.hasSolvedToday,
      submissionCalendar: subCalMap,
      topTopics: topics,
    );
  }

  static _StreakResult _computeStreak(Map<String, int> calendar) {
    if (calendar.isEmpty) {
      return const _StreakResult(streak: 0, hasSolvedToday: false);
    }

    final activeDatesUtc = <String>{};
    calendar.forEach((tsStr, count) {
      if (count > 0) {
        final ts = int.tryParse(tsStr) ?? 0;
        if (ts > 0) {
          final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
          activeDatesUtc.add('${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}');
        }
      }
    });

    final nowUtc = DateTime.now().toUtc();
    final todayStr = '${nowUtc.year}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}';

    final hasToday = activeDatesUtc.contains(todayStr);

    var checkDate = hasToday
        ? nowUtc
        : nowUtc.subtract(const Duration(days: 1));

    int streak = 0;
    while (true) {
      final ymd = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (activeDatesUtc.contains(ymd)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return _StreakResult(streak: streak, hasSolvedToday: hasToday);
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'realName': realName,
        'userAvatar': userAvatar,
        'ranking': ranking,
        'reputation': reputation,
        'totalSolved': totalSolved,
        'easySolved': easySolved,
        'mediumSolved': mediumSolved,
        'hardSolved': hardSolved,
        'accuracy': accuracy,
        'contestRating': contestRating,
        'contestGlobalRanking': contestGlobalRanking,
        'streak': streak,
        'hasSolvedToday': hasSolvedToday,
        'submissionCalendar': submissionCalendar,
        'topTopics': topTopics.map((e) => e.toJson()).toList(),
      };

  factory LeetCodeProfile.fromJson(Map<String, dynamic> json) {
    Map<String, int> subCalMap = {};
    final rawCal = json['submissionCalendar'];
    if (rawCal is Map) {
      rawCal.forEach((k, v) {
        if (v is num) {
          subCalMap[k.toString()] = v.toInt();
        }
      });
    }

    List<TopicCount> topics = [];
    final rawTopics = json['topTopics'] as List<dynamic>?;
    if (rawTopics != null) {
      for (final t in rawTopics) {
        if (t is Map<String, dynamic>) {
          topics.add(TopicCount.fromJson(t));
        }
      }
    }

    return LeetCodeProfile(
      username: json['username']?.toString() ?? '',
      realName: json['realName']?.toString(),
      userAvatar: json['userAvatar']?.toString(),
      ranking: (json['ranking'] as num?)?.toInt(),
      reputation: (json['reputation'] as num?)?.toInt(),
      totalSolved: (json['totalSolved'] as num?)?.toInt() ?? 0,
      easySolved: (json['easySolved'] as num?)?.toInt() ?? 0,
      mediumSolved: (json['mediumSolved'] as num?)?.toInt() ?? 0,
      hardSolved: (json['hardSolved'] as num?)?.toInt() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      contestRating: (json['contestRating'] as num?)?.toDouble(),
      contestGlobalRanking: (json['contestGlobalRanking'] as num?)?.toInt(),
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      hasSolvedToday: json['hasSolvedToday'] == true,
      submissionCalendar: subCalMap,
      topTopics: topics,
    );
  }
}

class _StreakResult {
  final int streak;
  final bool hasSolvedToday;
  const _StreakResult({required this.streak, required this.hasSolvedToday});
}
