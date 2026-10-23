import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/leetcode_graphql_service.dart';
import 'services/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF05070D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = await LocalStorageService.create();
  final graphQLService = LeetCodeGraphQLService();

  runApp(LeetoApp(
    storageService: storageService,
    graphQLService: graphQLService,
  ));
}
