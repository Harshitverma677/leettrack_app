import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leeto/models/daily_challenge.dart';
import 'package:leeto/models/leetcode_profile.dart';
import 'package:leeto/models/leetcode_submission.dart';
import 'package:leeto/models/teammate.dart';
import 'package:leeto/repositories/teammate_repository.dart';
import 'package:leeto/screens/dashboard_screen.dart';
import 'package:leeto/screens/team_activity_screen.dart';
import 'package:leeto/screens/teammate_detail_screen.dart';
import 'package:leeto/screens/user_profile_screen.dart';
import 'package:leeto/services/leetcode_graphql_service.dart';
import 'package:leeto/services/local_storage_service.dart';
import 'package:leeto/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LeetCode Models & Calculations', () {
    test('LeetCodeProfile calculates accuracy, streak, and 1-year stats', () {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final recentTs = nowSec - 86400; // 1 day ago
      final olderTs = nowSec - (2 * 86400); // 2 days ago

      final mockData = {
        'username': 'testUser',
        'profile': {
          'realName': 'Test Real Name',
          'userAvatar': 'https://example.com/avatar.png',
          'ranking': 12345,
        },
        'submitStatsGlobal': {
          'acSubmissionNum': [
            {'difficulty': 'All', 'count': 50, 'submissions': 80},
            {'difficulty': 'Easy', 'count': 30, 'submissions': 30},
            {'difficulty': 'Medium', 'count': 15, 'submissions': 35},
            {'difficulty': 'Hard', 'count': 5, 'submissions': 15},
          ],
          'totalSubmissionNum': [
            {'difficulty': 'All', 'count': 50, 'submissions': 100},
          ],
        },
        'submissionCalendar': '{"$recentTs": 3, "$olderTs": 2}',
        'tagProblemCounts': {
          'fundamental': [
            {
              'tagName': 'Array',
              'tagSlug': 'array',
              'problemsSolved': 25,
            }
          ],
        },
      };

      final profile = LeetCodeProfile.fromGraphQL(
        matchedUserData: mockData,
        contestRankingData: {'rating': 1650.5, 'globalRanking': 45000},
      );

      expect(profile.username, 'testUser');
      expect(profile.realName, 'Test Real Name');
      expect(profile.totalSolved, 50);
      expect(profile.easySolved, 30);
      expect(profile.mediumSolved, 15);
      expect(profile.hardSolved, 5);
      // Accuracy = 80 / 100 * 100 = 80.0%
      expect(profile.accuracy, 80.0);
      expect(profile.contestRating, 1650.5);
      expect(profile.submissionsInPastOneYear, 5);
      expect(profile.activeDaysInPastOneYear, 2);
      expect(profile.maxStreakInPastOneYear, 2);
    });

    test('DailyChallenge parses GraphQL JSON correctly', () {
      final json = {
        'activeDailyCodingChallengeQuestion': {
          'date': '2026-10-23',
          'link': '/problems/test-problem/',
          'question': {
            'title': 'Test Daily Problem',
            'titleSlug': 'test-problem',
            'difficulty': 'Medium',
            'topicTags': [
              {'name': 'Dynamic Programming', 'slug': 'dynamic-programming'}
            ],
          },
        },
      };

      final daily = DailyChallenge.fromJson(json);
      expect(daily.title, 'Test Daily Problem');
      expect(daily.difficulty, 'Medium');
      expect(daily.topic, 'Dynamic Programming');
      expect(daily.link, 'https://leetcode.com/problems/test-problem/');
    });

    test('LeetCodeSubmission formattedMonthDay and isWithinPastSevenDays', () {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final recentSub = LeetCodeSubmission(
        title: 'Two Sum',
        titleSlug: 'two-sum',
        timestamp: nowSec - 3600, // 1 hour ago
        statusDisplay: 'Accepted',
        difficulty: 'Easy',
      );

      final olderSub = LeetCodeSubmission(
        title: 'Old Problem',
        titleSlug: 'old-problem',
        timestamp: nowSec - (15 * 86400), // 15 days ago
      );

      expect(recentSub.isWithinPastSevenDays, isTrue);
      expect(olderSub.isWithinPastSevenDays, isFalse);
      expect(recentSub.statusDisplay, 'Accepted');
      expect(recentSub.difficulty, 'Easy');
      expect(recentSub.formattedMonthDay, isNotEmpty);
    });
  });

  group('TeammateRepository Tests', () {
    late LocalStorageService storageService;
    late LeetCodeGraphQLService graphQLService;
    late TeammateRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = await LocalStorageService.create();

      final mockClient = MockClient((request) async {
        final body = json.decode(request.body) as Map<String, dynamic>;
        final query = body['query'] as String;

        if (query.contains('activeDailyCodingChallengeQuestion')) {
          return http.Response(
            json.encode({
              'data': {
                'activeDailyCodingChallengeQuestion': {
                  'date': '2026-10-23',
                  'link': '/problems/mock-daily/',
                  'question': {
                    'title': 'Mock Daily Question',
                    'titleSlug': 'mock-daily',
                    'difficulty': 'Hard',
                    'topicTags': [
                      {'name': 'Graph', 'slug': 'graph'}
                    ],
                  },
                },
              },
            }),
            200,
          );
        }

        final username = body['variables']?['username'] ?? 'user';
        return http.Response(
          json.encode({
            'data': {
              'matchedUser': {
                'username': username,
                'profile': {
                  'realName': '$username Name',
                  'userAvatar': null,
                  'ranking': 1000,
                },
                'submitStatsGlobal': {
                  'acSubmissionNum': [
                    {'difficulty': 'All', 'count': 42, 'submissions': 50},
                    {'difficulty': 'Easy', 'count': 30, 'submissions': 30},
                    {'difficulty': 'Medium', 'count': 10, 'submissions': 15},
                    {'difficulty': 'Hard', 'count': 2, 'submissions': 5},
                  ],
                  'totalSubmissionNum': [
                    {'difficulty': 'All', 'count': 42, 'submissions': 70},
                  ],
                },
                'submissionCalendar': '{}',
                'tagProblemCounts': {
                  'fundamental': [],
                  'intermediate': [],
                  'advanced': [],
                },
              },
              'userContestRanking': {'rating': 1500.0, 'globalRanking': 5000},
              'recentAcSubmissionList': [
                {
                  'title': 'Sub 1',
                  'titleSlug': 'sub-1',
                  'timestamp': '1700000000',
                  'statusDisplay': 'Accepted',
                }
              ],
            },
          }),
          200,
        );
      });

      graphQLService = LeetCodeGraphQLService(client: mockClient);
      repo = TeammateRepository(
        graphQLService: graphQLService,
        storageService: storageService,
      );
    });

    test('Loads initial roster and filters by search query', () async {
      await repo.initialize();
      expect(repo.rawTeammates.length, 3);

      repo.setSearchQuery('harshit');
      expect(repo.leaderboardTeammates.length, 1);
      expect(repo.leaderboardTeammates.first.username, 'vuvcVjbwmU');

      repo.setSearchQuery('');
      expect(repo.leaderboardTeammates.length, 3);
    });

    test('wipeTeammates removes other teammates and preserves current user',
        () async {
      await repo.initialize();
      expect(repo.rawTeammates.length, 3);
      expect(repo.otherTeammatesCount, 2);

      final removed = await repo.wipeTeammates();
      expect(removed, 2);
      expect(repo.rawTeammates.length, 1);
      expect(repo.rawTeammates.first.username.toLowerCase(), 'vuvcvjbwmu');
      expect(repo.otherTeammatesCount, 0);
    });

    test('Rejects duplicate teammates and empty usernames', () async {
      await repo.initialize();

      expect(
        () => repo.addTeammate('   '),
        throwsA(isA<Exception>()),
      );

      expect(
        () => repo.addTeammate('vuvcVjbwmU'),
        throwsA(isA<Exception>()),
      );
    });

    test('Removes a teammate properly', () async {
      await repo.initialize();
      expect(repo.rawTeammates.length, 3);

      await repo.removeTeammate('_palakdeep');
      expect(repo.rawTeammates.length, 2);
      expect(repo.findByUsername('_palakdeep'), isNull);
    });
  });

  group('Widget Tests', () {
    testWidgets(
        'Dashboard renders + Add Member, no LEETO branding, no Weekly Analysis',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await LocalStorageService.create();
      final graphQLService = LeetCodeGraphQLService();

      final repo = TeammateRepository(
        graphQLService: graphQLService,
        storageService: storageService,
      );

      await storageService.saveTeammates([
        Teammate(
          username: 'alice',
          displayName: 'Alice Coder',
          profile: const LeetCodeProfile(
            username: 'alice',
            totalSolved: 150,
            easySolved: 100,
            mediumSolved: 40,
            hardSolved: 10,
            streak: 5,
            hasSolvedToday: true,
            submissionCalendar: {},
            topTopics: [],
          ),
        ),
      ]);

      await repo.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChangeNotifierProvider<TeammateRepository>.value(
            value: repo,
            child: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Add Member button is present
      expect(find.text('Add Member'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      // Verify LEETO branding is removed
      expect(find.text('LEETO'), findsNothing);
      expect(find.text('Team Active • Daily Sync'), findsNothing);

      // Verify Weekly Analysis icon is removed
      expect(find.byIcon(Icons.bar_chart_rounded), findsNothing);

      // Verify Leaderboard chips no longer contain "+ Add"
      expect(find.text('Add'), findsNothing);
      expect(find.text('Solved'), findsOneWidget);
    });

    testWidgets('Teammate detail screen renders 1-year heatmap',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await LocalStorageService.create();
      final graphQLService = LeetCodeGraphQLService();

      final repo = TeammateRepository(
        graphQLService: graphQLService,
        storageService: storageService,
      );

      await storageService.saveTeammates([
        Teammate(
          username: 'palakdeep',
          displayName: 'Palakdeep',
          profile: const LeetCodeProfile(
            username: 'palakdeep',
            totalSolved: 169,
            easySolved: 142,
            mediumSolved: 27,
            hardSolved: 0,
            accuracy: 81.3,
            contestRating: 1496.0,
            streak: 0,
            hasSolvedToday: false,
            submissionCalendar: {},
            topTopics: [
              TopicCount(
                tagName: 'Array',
                tagSlug: 'array',
                problemsSolved: 79,
              ),
            ],
          ),
          recentSubmissions: const [
            LeetCodeSubmission(
              title: 'Minimum Add to Make Parentheses Valid',
              titleSlug: 'minimum-add-to-make-parentheses-valid',
              timestamp: 1728259200,
            ),
          ],
        ),
      ]);

      await repo.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChangeNotifierProvider<TeammateRepository>.value(
            value: repo,
            child: const TeammateDetailScreen(username: 'palakdeep'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Palakdeep'), findsOneWidget);
      expect(find.text('@palakdeep'), findsOneWidget);
      expect(find.text('169'), findsOneWidget);
      expect(find.text('submissions in the past one year'), findsOneWidget);
      expect(find.text('Total active days: '), findsOneWidget);
      expect(find.text('Max streak: '), findsOneWidget);
    });

    testWidgets(
        'UserProfileScreen has no Settings button and shows Wipe teammate profiles',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await LocalStorageService.create();
      final graphQLService = LeetCodeGraphQLService();

      final repo = TeammateRepository(
        graphQLService: graphQLService,
        storageService: storageService,
      );

      await storageService.saveTeammates([
        const Teammate(
          username: 'vuvcVjbwmU',
          displayName: 'Harshit Verma',
          isCurrentUser: true,
        ),
        const Teammate(
          username: 'palakdeep',
          displayName: 'Palakdeep',
          isCurrentUser: false,
        ),
      ]);

      await repo.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChangeNotifierProvider<TeammateRepository>.value(
            value: repo,
            child: const UserProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Settings icon is removed
      expect(find.byIcon(Icons.settings_outlined), findsNothing);

      // Check Wipe teammate profiles section exists below heatmap
      expect(find.text('Wipe teammate profiles'), findsOneWidget);
      expect(find.text('Wipe 1 Teammate Profile'), findsOneWidget);
    });

    testWidgets(
        'TeamActivityScreen displays rolling past 7 days submissions only',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await LocalStorageService.create();
      final graphQLService = LeetCodeGraphQLService();

      final repo = TeammateRepository(
        graphQLService: graphQLService,
        storageService: storageService,
      );

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await storageService.saveTeammates([
        Teammate(
          username: 'palakdeep',
          displayName: 'Palakdeep',
          recentSubmissions: [
            LeetCodeSubmission(
              title: 'Recent Problem 1',
              titleSlug: 'recent-problem-1',
              timestamp: nowSec - 3600, // 1 hr ago
              statusDisplay: 'Accepted',
              difficulty: 'Easy',
            ),
            LeetCodeSubmission(
              title: 'Old Problem Past 7 Days',
              titleSlug: 'old-problem',
              timestamp: nowSec - (10 * 86400), // 10 days ago
              statusDisplay: 'Accepted',
              difficulty: 'Hard',
            ),
          ],
        ),
      ]);

      await repo.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChangeNotifierProvider<TeammateRepository>.value(
            value: repo,
            child: const TeamActivityScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Recent problem should be displayed
      expect(find.text('Recent Problem 1'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);

      // Old problem beyond 7 days should be filtered out
      expect(find.text('Old Problem Past 7 Days'), findsNothing);
    });
  });
}
