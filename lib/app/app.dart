import 'package:flutter/material.dart';

import '../core/di/injection.dart';
import 'constants.dart';
import 'router.dart';
import 'theme.dart';

class SentryMeshApp extends StatelessWidget {
  const SentryMeshApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final initialUser = dependencies.initialUser;
    if (initialUser != null) {
      dependencies.towerSocket.connect(
        role: initialUser.role,
        userId: initialUser.id,
        token: dependencies.storageService.readAuthToken(),
      );
    }
    // Must match login_screen.dart's post-login routing exactly — this one
    // used to only check 'super_admin', so a plain 'admin' user who closed
    // and reopened the app got dropped into the resident shell instead of
    // the admin console they'd just logged into.
    final initialRoute = initialUser == null
        ? AppRouter.login
        : switch (initialUser.role) {
            'admin' || 'super_admin' => AppRouter.adminShell,
            'responder' => AppRouter.responderShell,
            _ => AppRouter.appShell,
          };

    return AppDependenciesScope(
      dependencies: dependencies,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: AppTheme.light,
        initialRoute: initialRoute,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
