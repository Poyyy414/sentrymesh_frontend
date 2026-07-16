import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/services/connectivity_service.dart';
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
  ConnectivityStatus _connectivity = ConnectivityStatus.online;
  int _pendingQueueCount = 0;
  StreamSubscription<ConnectivityStatus>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setupConnectivityMonitor();
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _setupConnectivityMonitor() {
    final deps = AppDependenciesScope.of(context);
    deps.connectivityService.currentStatus().then((status) {
      if (!mounted) return;
      setState(() => _connectivity = status);
      // The service may have already resolved tower-vs-cloud and fired its
      // one status-change event before this listener subscribed (broadcast
      // streams don't replay), so apply the resolved backend explicitly here
      // instead of waiting for a future change that may never come.
      _switchBackendIfNeeded();
      _reconnectSocket();
    });
    _updatePendingCount();

    _connectivitySub = deps.connectivityService.onStatusChanged.listen((status) {
      if (!mounted) return;
      final wasOffline = _connectivity != ConnectivityStatus.online;
      setState(() => _connectivity = status);

      _switchBackendIfNeeded();
      if (wasOffline && status == ConnectivityStatus.online) {
        _syncQueuedOperations();
        _reconnectSocket();
      }
      _updatePendingCount();
    });
  }

  Future<void> _syncQueuedOperations() async {
    final deps = AppDependenciesScope.of(context);
    final count = await deps.syncQueue.pendingCount;
    if (count == 0) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Syncing $count queued operations...'),
          backgroundColor: AppTheme.signalBlue,
        ),
      );
    }

    await deps.syncQueue.processAll(deps.apiClient);
    _updatePendingCount();

    // Refresh caches with fresh data from server
    try {
      await Future.wait([
        deps.rescueRepository.fetchEvacuationCenters(),
        deps.alertRepository.fetchAlerts(),
        deps.teamRepository.fetchTeams(),
      ]);
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data synced'),
          backgroundColor: AppTheme.safeGreen,
        ),
      );
    }
  }

  void _switchBackendIfNeeded() {
    final deps = AppDependenciesScope.of(context);
    final cs = deps.connectivityService;
    deps.apiClient.updateBaseUrl(cs.activeApiUrl);
    deps.aiClient.updateBaseUrl(cs.activeAiUrl);
  }

  void _reconnectSocket() {
    final deps = AppDependenciesScope.of(context);
    final user = deps.initialUser;
    if (user != null) {
      deps.towerSocket.reconnect(
        role: user.role,
        userId: user.id,
        baseUrl: deps.connectivityService.activeApiUrl,
      );
    }
  }

  Future<void> _updatePendingCount() async {
    final deps = AppDependenciesScope.of(context);
    final count = await deps.syncQueue.pendingCount;
    if (mounted) setState(() => _pendingQueueCount = count);
  }

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
      body: Column(
        children: [
          if (_connectivity != ConnectivityStatus.online)
            _ConnectivityBanner(
              status: _connectivity,
              pendingCount: _pendingQueueCount,
            ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: screens),
          ),
        ],
      ),
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

class _ConnectivityBanner extends StatelessWidget {
  const _ConnectivityBanner({
    required this.status,
    required this.pendingCount,
  });

  final ConnectivityStatus status;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final isOffline = status == ConnectivityStatus.offline;
    final color = isOffline ? AppTheme.dangerRed : const Color(0xFFE8A317);
    final icon = isOffline
        ? Icons.cloud_off_rounded
        : Icons.cloud_queue_rounded;
    final label = isOffline ? 'Offline' : 'Limited connection';
    final queueLabel =
        pendingCount > 0 ? ' - $pendingCount queued' : '';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 4,
        bottom: 4,
        left: 16,
        right: 16,
      ),
      color: color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$label$queueLabel',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
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
