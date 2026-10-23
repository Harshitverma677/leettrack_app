import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'repositories/teammate_repository.dart';
import 'screens/dashboard_screen.dart';
import 'screens/primary_profile_setup_screen.dart';
import 'services/leetcode_graphql_service.dart';
import 'services/local_storage_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class LeetoApp extends StatelessWidget {
  final LocalStorageService storageService;
  final LeetCodeGraphQLService graphQLService;

  const LeetoApp({
    super.key,
    required this.storageService,
    required this.graphQLService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(value: storageService),
        Provider<LeetCodeGraphQLService>.value(value: graphQLService),
        ChangeNotifierProvider<TeammateRepository>(
          create: (_) => TeammateRepository(
            graphQLService: graphQLService,
            storageService: storageService,
          )..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'LEETO',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Consumer<TeammateRepository>(
          builder: (context, repo, child) {
            if (!repo.isInitialized) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            if (!repo.hasPrimaryProfile) {
              return const PrimaryProfileSetupScreen();
            }
            return const DashboardScreen();
          },
        ),
      ),
    );
  }
}
