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
      );
    }
    final initialRoute = initialUser == null
        ? AppRouter.login
        : initialUser.role == 'responder'
        ? AppRouter.responderShell
        : initialUser.role == 'super_admin'
        ? AppRouter.adminShell
        : AppRouter.appShell;

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
