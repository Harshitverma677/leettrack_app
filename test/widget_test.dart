import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leeto/app.dart';
import 'package:leeto/models/leetcode_profile.dart';
import 'package:leeto/models/teammate.dart';
import 'package:leeto/services/firestore_service.dart';
import 'package:leeto/services/leetcode_graphql_service.dart';
import 'package:leeto/services/local_storage_service.dart';

class FakeUser extends Fake implements User {
  @override
  final String uid;

  FakeUser({this.uid = 'test_user_123'});
}

class FakeFirestoreService extends Fake implements FirestoreService {
  final Map<String, dynamic>? userDoc;

  FakeFirestoreService({this.userDoc});

  @override
  Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    return userDoc;
  }

  @override
  Future<List<Teammate>> getMembers(String uid) async {
    return [];
  }
}

void main() {
  testWidgets('First launch requires primary profile setup',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await LocalStorageService.create();
    final graphQLService = LeetCodeGraphQLService();
    final fakeUser = FakeUser(uid: 'user_first_launch');
    final firestoreService = FakeFirestoreService(userDoc: null);

    await tester.pumpWidget(LeetoApp(
      storageService: storageService,
      graphQLService: graphQLService,
      firestoreService: firestoreService,
      authStateStream: Stream.value(fakeUser),
    ));

    await tester.pumpAndSettle();

    // On first launch without primary profile, prompt for setup
    expect(find.text('Set up your LeetCode profile'), findsOneWidget);
    expect(find.text('Verify & Continue'), findsOneWidget);
  });

  testWidgets(
      'Subsequent launch opens directly into dashboard with + Add Member',
      (WidgetTester tester) async {
    const uid = 'user_with_profile';
    SharedPreferences.setMockInitialValues({
      'leeto_${uid}_primary_username': 'vuvcVjbwmU',
      'leeto_primary_username': 'vuvcVjbwmU',
    });
    final storageService = await LocalStorageService.create();
    await storageService.savePrimaryProfile(
      const LeetCodeProfile(
        username: 'vuvcVjbwmU',
        totalSolved: 100,
        easySolved: 50,
        mediumSolved: 40,
        hardSolved: 10,
        streak: 5,
        hasSolvedToday: true,
        submissionCalendar: {},
        topTopics: [],
      ),
      uid,
    );

    final graphQLService = LeetCodeGraphQLService();
    final fakeUser = FakeUser(uid: uid);
    final firestoreService = FakeFirestoreService(userDoc: {
      'primaryProfileSetupComplete': true,
      'primaryLeetCodeUsername': 'vuvcVjbwmU',
      'primaryLeetCodeProfile': {
        'username': 'vuvcVjbwmU',
        'totalSolved': 100,
        'easySolved': 50,
        'mediumSolved': 40,
        'hardSolved': 10,
        'streak': 5,
        'hasSolvedToday': true,
        'submissionCalendar': <String, int>{},
        'topTopics': <Map<String, dynamic>>[],
      },
    });

    await tester.pumpWidget(LeetoApp(
      storageService: storageService,
      graphQLService: graphQLService,
      firestoreService: firestoreService,
      authStateStream: Stream.value(fakeUser),
    ));

    await tester.pumpAndSettle();

    // Verify "Add Member" with add icon is in the header, and LEETO text is removed
    expect(find.text('Add Member'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('LEETO'), findsNothing);
    expect(find.text('LEADERBOARD'), findsOneWidget);
  });
}
