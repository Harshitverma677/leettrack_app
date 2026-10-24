import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/daily_challenge.dart';
import '../models/leetcode_profile.dart';
import '../models/leetcode_submission.dart';
import '../models/teammate.dart';

class LeetCodeGraphQLService {
  static const String endpoint = 'https://leetcode.com/graphql';
  final http.Client _client;

  LeetCodeGraphQLService({http.Client? client})
      : _client = client ?? http.Client();

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://leetcode.com',
  };

  /// Fetch public profile, submit stats, contest rating, and topics
  Future<LeetCodeProfile> fetchUserProfile(String username) async {
    const query = r'''
      query getUserProfile($username: String!) {
        matchedUser(username: $username) {
          username
          profile {
            realName
            userAvatar
            ranking
            reputation
          }
          submitStatsGlobal {
            acSubmissionNum {
              difficulty
              count
              submissions
            }
            totalSubmissionNum {
              difficulty
              count
              submissions
            }
          }
          submissionCalendar
          tagProblemCounts {
            advanced {
              tagName
              tagSlug
              problemsSolved
            }
            intermediate {
              tagName
              tagSlug
              problemsSolved
            }
            fundamental {
              tagName
              tagSlug
              problemsSolved
            }
          }
        }
        userContestRanking(username: $username) {
          rating
          globalRanking
          attendedContestsCount
          topPercentage
        }
      }
    ''';

    final response = await _client.post(
      Uri.parse(endpoint),
      headers: _headers,
      body: json.encode({
        'query': query,
        'variables': {'username': username.trim()},
      }),
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('HTTP error ${response.statusCode}: ${response.reasonPhrase}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data.containsKey('errors') && data['errors'] is List && (data['errors'] as List).isNotEmpty) {
      final errorList = data['errors'] as List;
      final msg = errorList.first['message'] ?? 'GraphQL error';
      // If matchedUser is null, user does not exist
      if (data['data'] == null || data['data']['matchedUser'] == null) {
        throw Exception('User "$username" not found on LeetCode: $msg');
      }
    }

    final dataMap = data['data'] as Map<String, dynamic>?;
    if (dataMap == null || dataMap['matchedUser'] == null) {
      throw Exception('User "$username" not found on LeetCode');
    }

    final matchedUser = dataMap['matchedUser'] as Map<String, dynamic>;
    final contestRanking = dataMap['userContestRanking'] as Map<String, dynamic>?;

    return LeetCodeProfile.fromGraphQL(
      matchedUserData: matchedUser,
      contestRankingData: contestRanking,
    );
  }

  final Map<String, String> _difficultyCache = {};

  /// Fetch recent accepted submissions
  Future<List<LeetCodeSubmission>> fetchRecentSubmissions(
    String username, {
    int limit = 20,
  }) async {
    const query = r'''
      query getRecentSubmissions($username: String!, $limit: Int!) {
        recentAcSubmissionList(username: $username, limit: $limit) {
          title
          titleSlug
          timestamp
          statusDisplay
        }
      }
    ''';

    try {
      final response = await _client.post(
        Uri.parse(endpoint),
        headers: _headers,
        body: json.encode({
          'query': query,
          'variables': {
            'username': username.trim(),
            'limit': limit,
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}: ${response.reasonPhrase}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['data']?['recentAcSubmissionList'] as List<dynamic>?;
      if (list == null) return [];

      final submissions = <LeetCodeSubmission>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          var sub = LeetCodeSubmission.fromJson(item);
          // If within past 7 days and difficulty not yet cached, attempt to resolve difficulty
          if (sub.isWithinPastSevenDays && sub.titleSlug.isNotEmpty) {
            final diff = await _fetchQuestionDifficulty(sub.titleSlug);
            if (diff != null) {
              sub = sub.copyWith(difficulty: diff);
            }
          }
          submissions.add(sub);
        }
      }

      return submissions;
    } catch (e) {
      // Re-throw so callers don't overwrite cached data on network failure
      rethrow;
    }
  }

  /// Helper to fetch real question difficulty for recent submissions
  Future<String?> _fetchQuestionDifficulty(String titleSlug) async {
    if (_difficultyCache.containsKey(titleSlug)) {
      return _difficultyCache[titleSlug];
    }

    const query = r'''
      query getQuestionDifficulty($titleSlug: String!) {
        question(titleSlug: $titleSlug) {
          difficulty
        }
      }
    ''';

    try {
      final response = await _client.post(
        Uri.parse(endpoint),
        headers: _headers,
        body: json.encode({
          'query': query,
          'variables': {'titleSlug': titleSlug},
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final diff =
            data['data']?['question']?['difficulty']?.toString();
        if (diff != null && diff.isNotEmpty) {
          _difficultyCache[titleSlug] = diff;
          return diff;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Fetch today's Daily Coding Challenge
  Future<DailyChallenge?> fetchDailyChallenge() async {
    const query = r'''
      query questionOfToday {
        activeDailyCodingChallengeQuestion {
          date
          link
          question {
            questionFrontendId
            title
            titleSlug
            difficulty
            topicTags {
              name
              slug
            }
          }
        }
      }
    ''';

    try {
      final response = await _client.post(
        Uri.parse(endpoint),
        headers: _headers,
        body: json.encode({'query': query}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['data'] == null) return null;

      return DailyChallenge.fromJson(data['data'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Convenience method to refresh full teammate profile and submissions
  Future<Teammate> fetchFullTeammateData(Teammate teammate) async {
    final profile = await fetchUserProfile(teammate.username);
    final submissions = await fetchRecentSubmissions(teammate.username);

    return teammate.copyWith(
      profile: profile,
      recentSubmissions: submissions,
      lastUpdated: DateTime.now(),
    );
  }
}
