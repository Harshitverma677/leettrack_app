import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leeto/app.dart';
import 'package:leeto/services/leetcode_graphql_service.dart';
import 'package:leeto/services/local_storage_service.dart';

void main() {
  testWidgets('First launch requires primary profile setup',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await LocalStorageService.create();
    final graphQLService = LeetCodeGraphQLService();

    await tester.pumpWidget(LeetoApp(
      storageService: storageService,
      graphQLService: graphQLService,
    ));

    await tester.pumpAndSettle();

    // On first launch without primary profile, prompt for setup
    expect(find.text('Set up your LeetCode profile'), findsOneWidget);
    expect(find.text('Verify & Continue'), findsOneWidget);
  });

  testWidgets('Subsequent launch opens directly into dashboard with + Add Member',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'leeto_primary_username': 'vuvcVjbwmU',
    });
    final storageService = await LocalStorageService.create();
    final graphQLService = LeetCodeGraphQLService();

    await tester.pumpWidget(LeetoApp(
      storageService: storageService,
      graphQLService: graphQLService,
    ));

    await tester.pumpAndSettle();

    // Verify "Add Member" with add icon is in the header, and LEETO text is removed
    expect(find.text('Add Member'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('LEETO'), findsNothing);
    expect(find.text('LEADERBOARD'), findsOneWidget);
  });
}
