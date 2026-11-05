import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'services/leetcode_graphql_service.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

  // Initialize services
  final storageService = await LocalStorageService.create();
  final graphQLService = LeetCodeGraphQLService();
  final firestoreService = FirestoreService();

  runApp(
    LeetoApp(
      storageService: storageService,
      graphQLService: graphQLService,
      firestoreService: firestoreService,
    ),
  );
}
