import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leeto/models/daily_challenge.dart';
import 'package:leeto/models/leetcode_profile.dart';
import 'package:leeto/models/leetcode_submission.dart';
import 'package:leeto/models/teammate.dart';
import 'package:leeto/repositories/teammate_repository.dart';
import 'package:leeto/screens/dashboard_screen.dart';
import 'package:leeto/screens/primary_profile_setup_screen.dart';
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

    test('Primary profile setup and separation from teammates', () async {
      expect(repo.hasPrimaryProfile, isFalse);

      await repo.setupPrimaryProfile('myuser');
      expect(repo.hasPrimaryProfile, isTrue);
      expect(repo.primaryUsername, 'myuser');
      expect(repo.primaryProfile?.totalSolved, 42);

      // Verify primary profile is not in teammates list
      expect(repo.rawTeammates.any((t) => t.username == 'myuser'), isFalse);

      // Cannot add primary user as a teammate
      expect(
        () => repo.addTeammate('myuser'),
        throwsA(isA<Exception>()),
      );
    });

    test('Loads initial teammates roster and filters by search query',
        () async {
      await repo.initialize();
      expect(repo.rawTeammates.length, 2);

      repo.setSearchQuery('palak');
      expect(repo.leaderboardTeammates.length, 1);
      expect(repo.leaderboardTeammates.first.username, '_palakdeep');

      repo.setSearchQuery('');
      expect(repo.leaderboardTeammates.length, 2);
    });

    test('wipeTeammates removes all teammates and preserves primary profile',
        () async {
      await storageService.savePrimaryUsername('vuvcVjbwmU');
      await repo.initialize();
      expect(repo.primaryUsername, 'vuvcVjbwmU');
      expect(repo.rawTeammates.length, 2);
      expect(repo.teammateCount, 2);

      final removed = await repo.wipeTeammates();
      expect(removed, 2);
      expect(repo.rawTeammates.length, 0);
      expect(repo.teammateCount, 0);
      expect(repo.primaryUsername, 'vuvcVjbwmU');
    });

    test('Rejects duplicate teammates and empty usernames', () async {
      await repo.initialize();

      expect(
        () => repo.addTeammate('   '),
        throwsA(isA<Exception>()),
      );

      expect(
        () => repo.addTeammate('_palakdeep'),
        throwsA(isA<Exception>()),
      );
    });

    test('Removes a teammate properly', () async {
      await repo.initialize();
      expect(repo.rawTeammates.length, 2);

      await repo.removeTeammate('_palakdeep');
      expect(repo.rawTeammates.length, 1);
      expect(repo.findByUsername('_palakdeep'), isNull);
    });
  });

  group('Widget Tests', () {
    testWidgets('PrimaryProfileSetupScreen validates input and submits',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await LocalStorageService.create();

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'data': {
              'matchedUser': {
                'username': 'verifiedUser',
                'profile': {'realName': 'Verified Person'},
                'submitStatsGlobal': {
                  'acSubmissionNum': [
                    {'difficulty': 'All', 'count': 100}
                  ]
                },
                'submissionCalendar': '{}',
                'tagProblemCounts': {
                  'fundamental': [],
                  'intermediate': [],
                  'advanced': [],
                },
              }
            }
          }),
          200,
        );
      });

      final graphQLService = LeetCodeGraphQLService(client: mockClient);
      final repo = TeammateRepository(
        graphQLService: graphQLService,
        storageService: storageService,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChangeNotifierProvider<TeammateRepository>.value(
            value: repo,
            child: const PrimaryProfileSetupScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Set up your LeetCode profile'), findsOneWidget);
      expect(find.text('Verify & Continue'), findsOneWidget);

      // Submit empty input -> displays validation error
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your LeetCode username'), findsOneWidget);

      // Enter valid username -> verifies and sets up primary user
      await tester.enterText(find.byType(TextField), 'verifiedUser');
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();

      expect(repo.hasPrimaryProfile, isTrue);
      expect(repo.primaryUsername, 'verifiedUser');
    });

    testWidgets(
        'Dashboard renders + Add Member, no LEETO branding, no Weekly Analysis',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'leeto_primary_username': 'testprimary',
      });
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

      await storageService.savePrimaryUsername('vuvcVjbwmU');
      await storageService.saveTeammates([
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
        'TeamActivityScreen groups submissions under separate date headings',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await LocalStorageService.create();
      final graphQLService = LeetCodeGraphQLService();

      final repo = TeammateRepository(
        graphQLService: graphQLService,
        storageService: storageService,
      );

      final now = DateTime.now();
      final nowSec = now.millisecondsSinceEpoch ~/ 1000;

      await storageService.saveTeammates([
        Teammate(
          username: 'palakdeep',
          displayName: 'Palakdeep',
          recentSubmissions: [
            LeetCodeSubmission(
              title: 'Today Problem 1',
              titleSlug: 'today-problem-1',
              timestamp: nowSec - 10, // 10 seconds ago
              statusDisplay: 'Accepted',
              difficulty: 'Easy',
            ),
            LeetCodeSubmission(
              title: 'Today Problem 2',
              titleSlug: 'today-problem-2',
              timestamp: nowSec - 30, // 30 seconds ago
              statusDisplay: 'Accepted',
              difficulty: 'Medium',
            ),
            LeetCodeSubmission(
              title: 'Old Problem Beyond 7 Days',
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

      // Today date heading should be rendered
      expect(find.textContaining('Today •'), findsOneWidget);

      // Both submissions from today rendered as separate items
      expect(find.text('Today Problem 1'), findsOneWidget);
      expect(find.text('Today Problem 2'), findsOneWidget);

      // Problem beyond 7 days should be filtered out
      expect(find.text('Old Problem Beyond 7 Days'), findsNothing);
    });

    testWidgets(
        'Leaderboard includes primary profile as You and avoids duplicate entries',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'leeto_primary_username': 'myhandle',
      });
      final storageService = await LocalStorageService.create();
      await storageService.savePrimaryProfile(const LeetCodeProfile(
        username: 'myhandle',
        realName: 'My Full Name',
        totalSolved: 300,
        easySolved: 200,
        mediumSolved: 90,
        hardSolved: 10,
        streak: 15,
        hasSolvedToday: false,
        submissionCalendar: {},
        topTopics: [],
      ));

      // Teammate list contains a duplicate of primary handle (different case) plus a peer
      await storageService.saveTeammates([
        const Teammate(
          username: 'MYHANDLE',
          displayName: 'Duplicate Handle',
          isCurrentUser: false,
        ),
        const Teammate(
          username: 'bob',
          displayName: 'Bob The Teammate',
          profile: LeetCodeProfile(
            username: 'bob',
            totalSolved: 120,
            easySolved: 80,
            mediumSolved: 40,
            hardSolved: 0,
            streak: 3,
            hasSolvedToday: false,
            submissionCalendar: {},
            topTopics: [],
          ),
          isCurrentUser: false,
        ),
      ]);

      final graphQLService = LeetCodeGraphQLService();
      final repo = TeammateRepository(
        graphQLService: graphQLService,
        storageService: storageService,
      );

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

      // Check primary profile has 'You' badge
      expect(find.text('You'), findsOneWidget);
      expect(find.text('My Full Name'), findsOneWidget);
      expect(find.text('@myhandle'), findsOneWidget);

      // Check Bob is also in leaderboard
      expect(find.text('Bob The Teammate'), findsOneWidget);
      expect(find.text('@bob'), findsOneWidget);

      // Check duplicate MYHANDLE is not duplicated in leaderboard
      expect(find.text('Duplicate Handle'), findsNothing);

      // Check that You card does not have a remove button (only Bob should have 1 remove button)
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets(
        'Sign Out flow on UserProfileScreen cancels safely and confirms correctly',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'leeto_primary_username': 'user_to_sign_out',
      });
      final storageService = await LocalStorageService.create();
      await storageService.savePrimaryProfile(const LeetCodeProfile(
        username: 'user_to_sign_out',
        totalSolved: 50,
        easySolved: 30,
        mediumSolved: 20,
        hardSolved: 0,
        streak: 2,
        hasSolvedToday: false,
        submissionCalendar: {},
        topTopics: [],
      ));
      await storageService.saveTeammates([
        const Teammate(
          username: 'peer_preserved',
          displayName: 'Peer Preserved',
          isCurrentUser: false,
        ),
      ]);

      final graphQLService = LeetCodeGraphQLService();
      final repo = TeammateRepository(
        graphQLService: graphQLService,
        storageService: storageService,
      );
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

      // Find Sign Out in AppBar and in body
      final appBarSignOut = find.descendant(
        of: find.byType(AppBar),
        matching: find.widgetWithText(TextButton, 'Sign Out'),
      );
      expect(appBarSignOut, findsOneWidget);

      // Tap Sign Out in AppBar to trigger confirmation dialog
      await tester.tap(appBarSignOut);
      await tester.pumpAndSettle();

      expect(find.text('Sign out of primary profile?'), findsOneWidget);
      expect(
          find.text(
              'Are you sure you want to sign out of @user_to_sign_out? This returns LEETO to initial profile setup. Your saved teammate roster and study preferences will be preserved.'),
          findsOneWidget);

      // Test 1: Cancel dialog -> state preserved
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.hasPrimaryProfile, isTrue);
      expect(repo.primaryUsername, 'user_to_sign_out');
      expect(await storageService.getPrimaryUsername(), 'user_to_sign_out');

      // Test 2: Trigger dialog again and Confirm Sign Out
      await tester.tap(appBarSignOut);
      await tester.pumpAndSettle();

      // Tap destructive Sign Out button inside dialog
      final dialogSignOut = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Sign Out'),
      );
      await tester.tap(dialogSignOut);
      await tester.pumpAndSettle();

      // Primary profile state is cleared
      expect(repo.hasPrimaryProfile, isFalse);
      expect(repo.primaryUsername, isNull);
      expect(await storageService.getPrimaryUsername(), isNull);
      expect(await storageService.getPrimaryProfile(), isNull);

      // Teammate roster remains preserved!
      final preservedTeammates = await storageService.loadTeammates();
      expect(preservedTeammates.any((t) => t.username == 'peer_preserved'),
          isTrue);
    });

    testWidgets(
        'Heatmap renders separated month groups with aligned month labels',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await LocalStorageService.create();
      final graphQLService = LeetCodeGraphQLService();
      final repo = TeammateRepository(
        graphQLService: graphQLService,
        storageService: storageService,
      );

      final now = DateTime.now();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);
      final todaySec = todayUtc.millisecondsSinceEpoch ~/ 1000;

      // Add submissions on today and 5 days ago
      final calMap = <String, int>{
        '$todaySec': 4,
        '${todaySec - (5 * 86400)}': 2,
      };

      await storageService.saveTeammates([
        Teammate(
          username: 'janedoe',
          displayName: 'Jane Doe',
          profile: LeetCodeProfile(
            username: 'janedoe',
            totalSolved: 6,
            easySolved: 4,
            mediumSolved: 2,
            hardSolved: 0,
            streak: 1,
            hasSolvedToday: true,
            submissionCalendar: calMap,
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
            child: const TeammateDetailScreen(username: 'janedoe'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check summary stats
      expect(find.text('submissions in the past one year'), findsOneWidget);
      expect(find.text('Total active days: '), findsOneWidget);
      expect(find.text('Max streak: '), findsOneWidget);

      // Verify current month label is rendered
      final currentMonthLabel = DateFormat('MMM').format(todayUtc);
      expect(find.text(currentMonthLabel), findsOneWidget);
    });
  });
}
