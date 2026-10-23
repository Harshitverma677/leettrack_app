import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leeto/app.dart';
import 'package:leeto/services/leetcode_graphql_service.dart';
import 'package:leeto/services/local_storage_service.dart';

void main() {
  testWidgets('LeetoApp launches into dashboard with + Add Member action in header',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
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
