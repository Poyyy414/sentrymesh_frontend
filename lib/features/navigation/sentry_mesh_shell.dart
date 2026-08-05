import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/config/map_tile_config.dart';
import '../../core/di/injection.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/connectivity_banner.dart';
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
  ActiveBackend? _lastActiveBackend;
  int _pendingQueueCount = 0;
  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  Timer? _mapConnectivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupConnectivityMonitor();
        _refreshMapConnectivity();
      }
    });
    // MapTileConfig.checkConnectivity() only ran once at app startup
    // (main.dart) — a resident who joins/leaves the tower hotspot mid-session
    // otherwise gets the wrong tile source (or a responder-side bug already
    // fixed for this exact reason) until the app restarts. Re-check
    // periodically here so it reflects current reality across every tab.
    _mapConnectivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refreshMapConnectivity();
    });
  }

  Future<void> _refreshMapConnectivity() async {
    await MapTileConfig.checkConnectivity();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _mapConnectivityTimer?.cancel();
    super.dispose();
  }

  void _setupConnectivityMonitor() {
    final deps = AppDependenciesScope.of(context);
    deps.connectivityService.currentStatus().then((status) async {
      if (!mounted) return;
      setState(() => _connectivity = status);
      // The service may have already resolved tower-vs-cloud and fired its
      // one status-change event before this listener subscribed (broadcast
      // streams don't replay), so apply the resolved backend explicitly here
      // instead of waiting for a future change that may never come.
      _switchBackendIfNeeded();
      _reconnectSocket();
      if (status == ConnectivityStatus.online) {
        await _syncQueuedOperations();
      }
      _lastActiveBackend = deps.connectivityService.activeBackend;
    });
    _updatePendingCount();

    _connectivitySub = deps.connectivityService.onStatusChanged.listen((
      status,
    ) {
      if (!mounted) return;
      final wasOffline = _connectivity != ConnectivityStatus.online;
      // Tower and cloud both count as ConnectivityStatus.online, so
      // wasOffline alone misses the tower -> cloud handover — the exact
      // moment queued writes actually need to reach the real backend.
      // Track the active backend directly so that flip triggers a sync too.
      final newBackend = deps.connectivityService.activeBackend;
      final backendFlippedToCloud =
          _lastActiveBackend == ActiveBackend.tower &&
          newBackend == ActiveBackend.cloud;
      setState(() => _connectivity = status);

      _switchBackendIfNeeded();
      if ((wasOffline || backendFlippedToCloud) &&
          status == ConnectivityStatus.online) {
        _syncQueuedOperations();
        _reconnectSocket();
      }
      _lastActiveBackend = newBackend;
      _updatePendingCount();
    });
  }

  bool _isSyncing = false;

  // The initial currentStatus() check and the onStatusChanged stream can
  // both resolve "online" close together at startup — without this guard
  // that would fire processAll() twice concurrently and could resend the
  // same queued operation before either call persists the emptied queue.
  Future<void> _syncQueuedOperations() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _doSyncQueuedOperations();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _doSyncQueuedOperations() async {
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
        deps.familyRepository.fetchMembers(),
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
        token: deps.storageService.readAuthToken(),
        baseUrl: deps.connectivityService.activeApiUrl,
      );
    }
  }

  Future<void> _updatePendingCount() async {
    final deps = AppDependenciesScope.of(context);
    final count = await deps.syncQueue.pendingCount;
    if (mounted) setState(() => _pendingQueueCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const AlertsScreen(),
      _mapTabCreated ? const SafeRouteMapScreen() : const SizedBox.shrink(),
      const MessagesScreen(),
      const FamilySafetyScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (_connectivity != ConnectivityStatus.online)
            ConnectivityBanner(
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
