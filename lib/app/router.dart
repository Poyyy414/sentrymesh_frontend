import 'package:flutter/material.dart';

import '../features/alerts/alert_details_screen.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/family_safety/family_safety_screen.dart';
import '../features/messages/message_details_screen.dart';
import '../features/navigation/sentry_mesh_shell.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/responder/responder_shell.dart';
import '../features/rescue_request/rescue_request_screen.dart';
import '../features/safe_route/safe_route_map_screen.dart';
import '../features/splash/splash_screen.dart';

class AppRouter {
  const AppRouter._();

  static const root = '/';
  static const appShell = '/app';
  static const responderShell = '/responder';
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const alertDetails = '/alerts/details';
  static const alerts = '/alerts';
  static const safeRoute = '/safe-route';
  static const familySafety = '/family-safety';
  static const rescueRequest = '/rescue-request';
  static const messageDetails = '/messages/details';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final page = switch (settings.name) {
      root => const LoginScreen(),
      appShell => const SentryMeshShell(),
      responderShell => const ResponderShell(),
      splash => const SplashScreen(),
      login => const LoginScreen(),
      register => const RegisterScreen(),
      alertDetails => const AlertDetailsScreen(),
      alerts => const AlertsScreen(),
      safeRoute => const SafeRouteMapScreen(),
      familySafety => const FamilySafetyScreen(),
      rescueRequest => const RescueRequestScreen(),
      messageDetails => const MessageDetailsScreen(),
      profile => const ProfileScreen(),
      editProfile => const EditProfileScreen(),
      _ => const LoginScreen(),
    };

    return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
  }
}
