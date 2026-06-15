import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../alerts/alerts_screen.dart';
import '../family_safety/family_safety_screen.dart';
import '../home/home_screen.dart';
import '../messages/messages_screen.dart';
import '../safe_route/safe_route_map_screen.dart';

class SentryMeshShell extends StatefulWidget {
  const SentryMeshShell({super.key});

  @override
  State<SentryMeshShell> createState() => _SentryMeshShellState();
}

class _SentryMeshShellState extends State<SentryMeshShell> {
  int _currentIndex = 0;
  bool _mapTabCreated = false;

  Future<void> _logout() async {
    await AppDependenciesScope.of(context).authRepository.logout();
    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const AlertsScreen(),
      _mapTabCreated ? const SafeRouteMapScreen() : const SizedBox.shrink(),
      const MessagesScreen(),
      Stack(
        children: [
          const FamilySafetyScreen(),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: _ResidentLogoutButton(onPressed: _logout),
          ),
        ],
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: SentryBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() {
          _currentIndex = index;
          if (index == 2) _mapTabCreated = true;
        }),
      ),
    );
  }
}

class _ResidentLogoutButton extends StatelessWidget {
  const _ResidentLogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: 'Logout',
        onPressed: onPressed,
        icon: const Icon(
          Icons.logout_rounded,
          color: AppTheme.dangerRed,
          size: 25,
        ),
      ),
    );
  }
}
