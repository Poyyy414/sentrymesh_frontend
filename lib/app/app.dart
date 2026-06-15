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
    final initialRoute = initialUser == null
        ? AppRouter.login
        : initialUser.role == 'responder'
        ? AppRouter.responderShell
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
