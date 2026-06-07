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
    return AppDependenciesScope(
      dependencies: dependencies,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: AppTheme.light,
        initialRoute: AppRouter.root,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
