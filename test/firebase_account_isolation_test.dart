import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leeto/models/leetcode_profile.dart';
import 'package:leeto/models/teammate.dart';
import 'package:leeto/repositories/teammate_repository.dart';
import 'package:leeto/services/firestore_service.dart';
import 'package:leeto/services/leetcode_graphql_service.dart';
import 'package:leeto/services/local_storage_service.dart';

class MockCloudFirestoreService extends Fake implements FirestoreService {
  final Map<String, Map<String, dynamic>> users = {};
  final Map<String, Map<String, Map<String, dynamic>>> members = {};
  bool shouldFailWrites = false;

  @override
  Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    return users[uid];
  }

  @override
  Future<void> createUserAccount({
    required String uid,
    required String email,
    String? displayName,
  }) async {
    if (shouldFailWrites) {
      throw Exception('Network error writing user document');
    }
    users[uid] = {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'primaryProfileSetupComplete': false,
      'schemaVersion': 1,
    };
  }

  @override
  Future<void> savePrimaryProfile({
    required String uid,
    required String username,
    required LeetCodeProfile profile,
  }) async {
    if (shouldFailWrites) {
      throw Exception('Firestore write failure: network timed out');
    }
    final existing = users[uid] ?? {'uid': uid};
    existing['primaryLeetCodeUsername'] =
        profile.username.isNotEmpty ? profile.username : username;
    existing['primaryLeetCodeUsernameNormalized'] =
        (profile.username.isNotEmpty ? profile.username : username).toLowerCase();
    existing['primaryLeetCodeProfile'] = profile.toJson();
    existing['primaryProfileSetupComplete'] = true;
    existing['schemaVersion'] = 1;
    users[uid] = existing;
  }

  @override
  Future<List<Teammate>> getMembers(String uid) async {
    final userMembers = members[uid] ?? {};
    return userMembers.values.map((data) {
      return Teammate(
        username: data['leetCodeUsername'] ?? '',
        displayName: data['displayName'],
        avatarUrl: data['avatarUrl'],
        profile: data['profile'] != null
            ? LeetCodeProfile.fromJson(Map<String, dynamic>.from(data['profile']))
            : null,
        isCurrentUser: false,
      );
    }).toList();
  }

  @override
  Future<void> addMember({
    required String uid,
    required String username,
    String? displayName,
    required LeetCodeProfile profile,
  }) async {
    if (shouldFailWrites) {
      throw Exception('Firestore write failure: permission denied');
    }
    final norm = username.toLowerCase().trim();
    final userMembers = members.putIfAbsent(uid, () => {});
    if (userMembers.containsKey(norm)) {
      throw Exception('Teammate @$username is already on your leaderboard');
    }
    userMembers[norm] = {
      'memberId': norm,
      'ownerUid': uid,
      'leetCodeUsername': username,
      'leetCodeUsernameNormalized': norm,
      'displayName': displayName,
      'avatarUrl': profile.userAvatar,
      'profile': profile.toJson(),
    };
  }

  @override
  Future<void> removeMember(String uid, String username) async {
    final norm = username.toLowerCase().trim();
    members[uid]?.remove(norm);
  }

  @override
  Future<int> wipeMembers(String uid) async {
    final count = members[uid]?.length ?? 0;
    members[uid]?.clear();
    return count;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCloudFirestoreService firestoreService;
  late LocalStorageService storageService;
  late LeetCodeGraphQLService graphQLService;
  late TeammateRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = await LocalStorageService.create();
    firestoreService = MockCloudFirestoreService();

    final mockClient = MockClient((request) async {
      final body = json.decode(request.body) as Map<String, dynamic>;
      final vars = body['variables'] as Map<String, dynamic>? ?? {};
      final username = vars['username']?.toString() ?? 'default_user';

      return http.Response(
        json.encode({
          'data': {
            'matchedUser': {
              'username': username,
              'profile': {
                'realName': '$username Name',
                'userAvatar': 'https://example.com/$username.png',
                'ranking': 500,
                'reputation': 50,
              },
              'submitStatsGlobal': {
                'acSubmissionNum': [
                  {'difficulty': 'All', 'count': 42, 'submissions': 70},
                  {'difficulty': 'Easy', 'count': 20, 'submissions': 30},
                  {'difficulty': 'Medium', 'count': 15, 'submissions': 25},
                  {'difficulty': 'Hard', 'count': 7, 'submissions': 15},
                ],
                'totalSubmissionNum': [
                  {'difficulty': 'All', 'count': 42, 'submissions': 100},
                ],
              },
              'submissionCalendar': '{"1700000000": 3}',
              'tagProblemCounts': {
                'fundamental': [],
                'intermediate': [],
                'advanced': [],
              },
            },
          },
        }),
        200,
      );
    });

    graphQLService = LeetCodeGraphQLService(client: mockClient);
    repo = TeammateRepository(
      graphQLService: graphQLService,
      storageService: storageService,
      firestoreService: firestoreService,
    );
  });

  group('Firebase Account & Firestore Isolation Tests', () {
    test('1. First account creation requires primary profile setup', () async {
      const uid = 'user_abc';
      await firestoreService.createUserAccount(
        uid: uid,
        email: 'alice@example.com',
        displayName: 'Alice',
      );

      await repo.bindUser(uid);

      // Has no primary profile yet
      expect(repo.hasPrimaryProfile, isFalse);
      expect(repo.primaryUsername, isNull);
      expect(repo.rawTeammates, isEmpty);
      expect(repo.leaderboardTeammates, isEmpty);
    });

    test(
        '2. Primary setup validates and immediately shows ONLY the primary profile on leaderboard',
        () async {
      const uid = 'user_abc';
      await firestoreService.createUserAccount(
        uid: uid,
        email: 'alice@example.com',
      );
      await repo.bindUser(uid);

      // Set up primary profile
      await repo.setupPrimaryProfile('alice_coder');

      expect(repo.hasPrimaryProfile, isTrue);
      expect(repo.primaryUsername, 'alice_coder');

      // Crucial requirement: Leaderboard immediately after setup contains ONLY the primary account
      expect(repo.leaderboardTeammates.length, 1);
      expect(repo.leaderboardTeammates.first.username, 'alice_coder');
      expect(repo.leaderboardTeammates.first.isCurrentUser, isTrue);

      // No mock showcase teammates or foreign entries
      expect(repo.rawTeammates, isEmpty);

      // Verify written to Firestore
      final cloudDoc = await firestoreService.getUserDocument(uid);
      expect(cloudDoc?['primaryProfileSetupComplete'], isTrue);
      expect(cloudDoc?['primaryLeetCodeUsername'], 'alice_coder');
    });

    test(
        '3. Firestore write failure keeps user on setup without committing local cloud save',
        () async {
      const uid = 'user_failure_test';
      await repo.bindUser(uid);

      firestoreService.shouldFailWrites = true;

      expect(
        () => repo.setupPrimaryProfile('alice_fail'),
        throwsA(isA<Exception>()),
      );

      // State is not marked as having primary profile
      expect(repo.hasPrimaryProfile, isFalse);
      expect(repo.primaryUsername, isNull);
    });

    test('4. Add member writes to UID subcollection and appears on leaderboard',
        () async {
      const uid = 'user_abc';
      await repo.bindUser(uid);
      await repo.setupPrimaryProfile('alice_coder');

      // Add a teammate
      await repo.addTeammate('bob_peer', displayName: 'Bob');

      expect(repo.rawTeammates.length, 1);
      expect(repo.rawTeammates.first.username, 'bob_peer');

      // Leaderboard now has Alice (primary) + Bob (teammate)
      expect(repo.leaderboardTeammates.length, 2);
      expect(repo.leaderboardTeammates[0].username, 'alice_coder');
      expect(repo.leaderboardTeammates[1].username, 'bob_peer');

      // Verified in Firestore under user_abc/members
      final cloudMembers = await firestoreService.getMembers(uid);
      expect(cloudMembers.length, 1);
      expect(cloudMembers.first.username, 'bob_peer');
    });

    test(
        '5. Duplicate members and primary username are prevented with clear messages',
        () async {
      const uid = 'user_abc';
      await repo.bindUser(uid);
      await repo.setupPrimaryProfile('alice_coder');
      await repo.addTeammate('bob_peer');

      // 1. Trying to add primary username as teammate
      expect(
        () => repo.addTeammate('alice_coder'),
        throwsA(predicate((e) =>
            e.toString().contains('This is your primary profile handle'))),
      );

      // 2. Case-insensitive duplicate check for existing teammate
      expect(
        () => repo.addTeammate('BOB_PEER'),
        throwsA(predicate((e) =>
            e.toString().contains('already on the leaderboard') ||
            e.toString().contains('already on your leaderboard'))),
      );
    });

    test('6. Member removal deletes document from cloud and local state',
        () async {
      const uid = 'user_abc';
      await repo.bindUser(uid);
      await repo.setupPrimaryProfile('alice_coder');
      await repo.addTeammate('bob_peer');

      expect(repo.rawTeammates.length, 1);

      await repo.removeTeammate('bob_peer');

      expect(repo.rawTeammates.length, 0);
      expect(repo.leaderboardTeammates.length, 1); // Only Alice left
      final cloudMembers = await firestoreService.getMembers(uid);
      expect(cloudMembers, isEmpty);
    });

    test(
        '7. Account isolation: User A and User B data are completely separated',
        () async {
      const userA = 'uid_alice_123';
      const userB = 'uid_bob_456';

      // 1. User A sets up account
      await repo.bindUser(userA);
      await repo.setupPrimaryProfile('alice_leet');
      await repo.addTeammate('charlie_teammate');

      expect(repo.primaryUsername, 'alice_leet');
      expect(repo.leaderboardTeammates.length, 2);

      // 2. User A signs out (bindUser(null))
      await repo.bindUser(null);
      expect(repo.currentUserId, isNull);
      expect(repo.primaryUsername, isNull);
      expect(repo.rawTeammates, isEmpty);
      expect(repo.leaderboardTeammates, isEmpty);

      // 3. User B signs in (fresh account)
      await repo.bindUser(userB);
      expect(repo.hasPrimaryProfile, isFalse);
      expect(repo.primaryUsername, isNull);
      expect(repo.rawTeammates, isEmpty);
      expect(repo.leaderboardTeammates, isEmpty);

      // User B sets up their own profile and members
      await repo.setupPrimaryProfile('bob_leet');
      await repo.addTeammate('david_teammate');

      expect(repo.primaryUsername, 'bob_leet');
      expect(repo.leaderboardTeammates.length, 2);
      expect(repo.leaderboardTeammates.map((t) => t.username),
          containsAll(['bob_leet', 'david_teammate']));
      expect(repo.leaderboardTeammates.map((t) => t.username),
          isNot(contains('alice_leet')));
      expect(repo.leaderboardTeammates.map((t) => t.username),
          isNot(contains('charlie_teammate')));

      // 4. User B signs out and User A signs back in
      await repo.bindUser(null);
      await repo.bindUser(userA);

      // User A's data is fully restored from cloud
      expect(repo.primaryUsername, 'alice_leet');
      expect(repo.leaderboardTeammates.length, 2);
      expect(repo.leaderboardTeammates.map((t) => t.username),
          containsAll(['alice_leet', 'charlie_teammate']));
      expect(repo.leaderboardTeammates.map((t) => t.username),
          isNot(contains('bob_leet')));
    });
  });
}
