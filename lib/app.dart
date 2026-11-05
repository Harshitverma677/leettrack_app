import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'repositories/teammate_repository.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/primary_profile_setup_screen.dart';
import 'services/firestore_service.dart';
import 'services/leetcode_graphql_service.dart';
import 'services/local_storage_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class LeetoApp extends StatelessWidget {
  final LocalStorageService storageService;
  final LeetCodeGraphQLService graphQLService;
  final FirestoreService firestoreService;
  final Stream<User?>? authStateStream;

  LeetoApp({
    super.key,
    required this.storageService,
    required this.graphQLService,
    FirestoreService? firestoreService,
    this.authStateStream,
  }) : firestoreService = firestoreService ?? FirestoreService();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(
          value: storageService,
        ),
        Provider<LeetCodeGraphQLService>.value(
          value: graphQLService,
        ),
        Provider<FirestoreService>.value(
          value: firestoreService,
        ),
        ChangeNotifierProvider<TeammateRepository>(
          create: (_) => TeammateRepository(
            graphQLService: graphQLService,
            storageService: storageService,
            firestoreService: firestoreService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'LEETO',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: StreamBuilder<User?>(
          stream: authStateStream ?? FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              );
            }

            if (authSnapshot.hasError) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: Text('Unable to check login status.'),
                ),
              );
            }

            return AuthRouter(user: authSnapshot.data);
          },
        ),
      ),
    );
  }
}

class AuthRouter extends StatefulWidget {
  final User? user;

  const AuthRouter({super.key, required this.user});

  @override
  State<AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<AuthRouter> {
  @override
  void initState() {
    super.initState();
    _syncUser();
  }

  @override
  void didUpdateWidget(AuthRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.uid != widget.user?.uid) {
      _syncUser();
    }
  }

  void _syncUser() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final repo = context.read<TeammateRepository>();
      repo.bindUser(widget.user?.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return const AuthScreen();
    }

    final repo = context.watch<TeammateRepository>();

    // Wait until repository is bound to the current user and loaded
    if (repo.currentUserId != widget.user!.uid ||
        !repo.isInitialized ||
        repo.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (!repo.hasPrimaryProfile) {
      return const PrimaryProfileSetupScreen();
    }

    return const DashboardScreen();
  }
}
