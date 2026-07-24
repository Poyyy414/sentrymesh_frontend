import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/assets.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/config/map_tile_config.dart';
import '../../core/di/injection.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/geo_bounds.dart';
import '../../core/services/location_service.dart';
import '../../core/services/tower_socket_service.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/offline/sync_queue.dart';
import '../../core/widgets/offline_map_download_button.dart';
import 'widgets/auto_3d_pack_download.dart';
import 'widgets/responder_map_3d_view.dart';
import '../../data/models/evacuation_center_model.dart';
import '../../data/models/prediction_model.dart';
import '../../data/repositories/prediction_repository.dart';
import '../../data/models/rescue_location_model.dart';
import '../../data/models/rescue_navigation_model.dart';
import '../../data/models/rescue_request_model.dart';
import '../../data/models/route_model.dart';
import '../../data/models/team_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/enums/hazard_type.dart';
import '../../shared/enums/rescue_status.dart';
import '../../shared/severity_colors.dart';

Future<void> _logout(BuildContext context) async {
  try {
    await AppDependenciesScope.of(context).authRepository.logout();
  } on AuthException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
    return;
  }
  if (!context.mounted) {
    return;
  }

  Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
}

IconData _incidentIcon(HazardType type) {
  return switch (type) {
    HazardType.flood => Icons.flood,
    HazardType.landslide => Icons.warning_amber_rounded,
    HazardType.typhoon => Icons.cyclone,
    HazardType.medical => Icons.medical_services,
    HazardType.distress => Icons.sos,
    HazardType.infrastructure => Icons.car_crash,
  };
}

String _hazardTitle(HazardType type) {
  return switch (type) {
    HazardType.flood => 'Flood',
    HazardType.landslide => 'Landslide',
    HazardType.typhoon => 'Typhoon',
    HazardType.medical => 'Medical Emergency',
    HazardType.distress => 'Distress / SOS',
    HazardType.infrastructure => 'Infrastructure Hazard',
  };
}

String _rescueStatusLabel(RescueStatus status) {
  return switch (status) {
    RescueStatus.pending => 'Active',
    RescueStatus.acknowledged => 'Dispatched',
    RescueStatus.inProgress => 'En Route',
    RescueStatus.resolved => 'Resolved',
    RescueStatus.cancelled => 'Cancelled',
  };
}


String _timeAgoLabel(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} min ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} hr ago';
  }
  return '${diff.inDays} d ago';
}

class ResponderShell extends StatefulWidget {
  const ResponderShell({super.key});

  @override
  State<ResponderShell> createState() => _ResponderShellState();
}

class _ResponderShellState extends State<ResponderShell> {
  int _currentIndex = 0;
  ConnectivityStatus _connectivity = ConnectivityStatus.online;
  ActiveBackend? _lastActiveBackend;
  int _pendingQueueCount = 0;
  StreamSubscription<ConnectivityStatus>? _connectivitySub;

  static const _screens = [
    ResponderDashboardScreen(),
    ActiveIncidentsScreen(),
    ResponderLiveMapScreen(),
    ResponderTeamsScreen(),
    ResponderReportsScreen(),
  ];

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

  void _switchBackendIfNeeded() {
    final deps = AppDependenciesScope.of(context);
    final cs = deps.connectivityService;
    deps.apiClient.updateBaseUrl(cs.activeApiUrl);
    deps.aiClient.updateBaseUrl(cs.activeAiUrl);
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
    return Scaffold(
      body: Column(
        children: [
          if (_connectivity != ConnectivityStatus.online)
            _ResponderConnectivityBanner(
              status: _connectivity,
              pendingCount: _pendingQueueCount,
            ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.notification_important_outlined),
              selectedIcon: Icon(Icons.notification_important),
              label: 'Incidents',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Teams',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponderConnectivityBanner extends StatelessWidget {
  const _ResponderConnectivityBanner({
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
    final queueLabel = pendingCount > 0 ? ' - $pendingCount queued' : '';

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

class _DashboardStats {
  const _DashboardStats({
    required this.activeIncidents,
    required this.peopleNeedHelp,
    required this.deployedTeams,
    required this.activeAlerts,
    required this.recentRequests,
  });

  final int activeIncidents;
  final int peopleNeedHelp;
  final int deployedTeams;
  final int activeAlerts;
  final List<RescueRequestModel> recentRequests;
}

class ResponderDashboardScreen extends StatefulWidget {
  const ResponderDashboardScreen({super.key});

  @override
  State<ResponderDashboardScreen> createState() =>
      _ResponderDashboardScreenState();
}

class _ResponderDashboardScreenState extends State<ResponderDashboardScreen> {
  _DashboardStats? _stats;
  bool _isLoading = true;
  RescueRequestModel? _myAssignment;
  StreamSubscription<JsonMap>? _sosNewSub;
  StreamSubscription<JsonMap>? _teamAssignmentSub;
  StreamSubscription<JsonMap>? _sosAssignedSub;

  String? get _userId =>
      AppDependenciesScope.of(context).authRepository.currentUser?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
        _subscribeToSosNew();
        _subscribeToTeamAssignment();
        _subscribeToSosAssigned();
      }
    });
  }

  @override
  void dispose() {
    _sosNewSub?.cancel();
    _teamAssignmentSub?.cancel();
    _sosAssignedSub?.cancel();
    super.dispose();
  }

  void _subscribeToSosNew() {
    _sosNewSub?.cancel();
    final socket = AppDependenciesScope.of(context).towerSocket;
    _sosNewSub = socket.onSosNew.listen((data) {
      if (mounted) {
        _showNewSosDialog(data);
        _load();
      }
    });
  }

  void _subscribeToTeamAssignment() {
    _teamAssignmentSub?.cancel();
    final socket = AppDependenciesScope.of(context).towerSocket;
    _teamAssignmentSub = socket.onTeamAssignment.listen((data) {
      if (mounted) {
        final teamName = data['assigned_team_name']?.toString() ?? 'your team';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New SOS assigned to Team $teamName'),
            backgroundColor: const Color(0xFF7B1FA2),
          ),
        );
        _load();
      }
    });
  }

  /// Fires for every dispatch, regardless of team — the auto-dispatcher just
  /// assigned a rescue request to a team, and this is the reliable path to
  /// find out (see TowerSocketService.onSosAssigned for why team:assignment
  /// alone isn't enough). Reloading re-derives whether it's actually *my*
  /// team, and if so surfaces it as the "My Assignment" card + an alert.
  void _subscribeToSosAssigned() {
    _sosAssignedSub?.cancel();
    final socket = AppDependenciesScope.of(context).towerSocket;
    _sosAssignedSub = socket.onSosAssigned.listen((data) async {
      if (!mounted) return;
      final previousAssignmentId = _myAssignment?.id;
      await _load();
      if (!mounted) return;
      if (_myAssignment != null && _myAssignment!.id != previousAssignmentId) {
        _showMyAssignmentDialog(_myAssignment!);
      }
    });
  }

  void _showMyAssignmentDialog(RescueRequestModel request) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(
          Icons.shield_rounded,
          color: Color(0xFF7B1FA2),
          size: 32,
        ),
        title: const Text('Your team was dispatched'),
        content: Text(
          '${_hazardTitle(request.emergencyType)} - ${request.locationLabel ?? request.description}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openAssignment(request);
            },
            icon: const Icon(Icons.directions_run, size: 18),
            label: const Text('Go to Rescue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAssignment(RescueRequestModel request) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ResponderIncidentDetailScreen(
          incident: _Incident.fromRescueRequest(request),
        ),
      ),
    );
    if (mounted) _load();
  }

  void _showNewSosDialog(JsonMap data) {
    final emergencyType = data['emergency_type']?.toString() ?? 'Unknown';
    final description =
        data['description']?.toString() ?? 'No description provided.';
    final peopleNeedingHelp =
        int.tryParse(data['people_needing_help']?.toString() ?? '') ?? 1;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.dangerRed,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: const Row(
            children: [
              Icon(Icons.sos_rounded, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INCOMING SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'New Emergency Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    emergencyType.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.dangerRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$peopleNeedingHelp ${peopleNeedingHelp == 1 ? 'person' : 'people'} need help',
                    style: const TextStyle(
                      color: AppTheme.warningAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Dismiss'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Navigate to Incidents tab if the parent ResponderShell is
              // reachable via the NavigationBar. Since this widget lives
              // inside an IndexedStack, post a rebuild that switches to
              // index 1 (Incidents).
              final shell = context
                  .findAncestorStateOfType<_ResponderShellState>();
              if (shell != null && shell.mounted) {
                shell.setState(() => shell._currentIndex = 1);
              }
            },
            icon: const Icon(Icons.notification_important, size: 18),
            label: const Text('View Incidents'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    try {
      final deps = AppDependenciesScope.of(context);
      final results = await Future.wait([
        deps.rescueRepository.fetchRequests(),
        deps.alertRepository.fetchAlerts(),
        deps.teamRepository.fetchTeams(),
      ]);

      if (!mounted) return;

      final requests = results[0] as List<RescueRequestModel>;
      final alerts = results[1];
      final teams = results[2] as List<TeamModel>;

      final active = requests
          .where(
            (r) =>
                r.status == RescueStatus.pending ||
                r.status == RescueStatus.acknowledged ||
                r.status == RescueStatus.inProgress,
          )
          .toList();

      final userId = _userId;
      TeamModel? myTeam;
      if (userId != null) {
        for (final team in teams) {
          if (team.members.any((m) => m.userId == userId)) {
            myTeam = team;
            break;
          }
        }
      }

      RescueRequestModel? myAssignment;
      if (myTeam != null) {
        for (final request in active) {
          if (request.assignedTeamId == myTeam.id) {
            myAssignment = request;
            break;
          }
        }
      }

      setState(() {
        _stats = _DashboardStats(
          activeIncidents: active.length,
          peopleNeedHelp: active.fold(0, (sum, r) => sum + r.peopleNeedingHelp),
          deployedTeams: active
              .where(
                (r) =>
                    r.status == RescueStatus.acknowledged ||
                    r.status == RescueStatus.inProgress,
              )
              .length,
          activeAlerts: alerts.length,
          recentRequests: requests.take(3).toList(),
        );
        _myAssignment = myAssignment;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stats = const _DashboardStats(
          activeIncidents: 0,
          peopleNeedHelp: 0,
          deployedTeams: 0,
          activeAlerts: 0,
          recentRequests: [],
        );
        _myAssignment = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period.name.toUpperCase()}';

    return _ResponderPage(
      onRefresh: _load,
      header: _ResponderHeader(
        title: 'Responder Console',
        trailing: _BellBadge(count: stats?.activeAlerts ?? 0),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white,
              backgroundImage: AssetImage(AppAssets.avatarResponder),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Response Team',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Command Center',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.safeGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Ready',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      children: [
        if (_myAssignment != null) ...[
          _MyAssignmentCard(
            incident: _Incident.fromRescueRequest(_myAssignment!),
            onGoToRescue: () => _openAssignment(_myAssignment!),
          ),
          const SizedBox(height: 14),
        ],
        _LiveStatusBanner(
          activeIncidents: stats?.activeIncidents ?? 0,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 14),
        _SectionTitle(
          title: 'Situation Overview',
          subtitle: _isLoading ? 'Loading…' : 'Updated $timeStr',
        ),
        const SizedBox(height: 10),
        _LiveStatsGrid(stats: stats, isLoading: _isLoading),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Live Risk Map', chip: 'Active'),
        const SizedBox(height: 10),
        const _HeatmapPreview(),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Recent Incidents',
          action: stats != null ? 'View all' : null,
        ),
        const SizedBox(height: 10),
        _LiveRecentIncidents(
          requests: stats?.recentRequests ?? [],
          isLoading: _isLoading,
        ),
      ],
    );
  }
}

/// Shown at the top of the responder Dashboard whenever the auto-dispatcher
/// has assigned the logged-in responder's team an active rescue — the
/// "what am I supposed to do right now" answer, one tap away from guidance.
class _MyAssignmentCard extends StatelessWidget {
  const _MyAssignmentCard({required this.incident, required this.onGoToRescue});

  final _Incident incident;
  final VoidCallback onGoToRescue;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7B1FA2);

    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: accent, size: 18),
              const SizedBox(width: 6),
              const Text(
                'YOUR TEAM IS ASSIGNED',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              if (incident.priorityRank != null) ...[
                const Spacer(),
                _SeverityPill(
                  label: '#${incident.priorityRank}',
                  color: riskTierColor(incident.riskLevel),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _IconBubble(icon: incident.icon, color: incident.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      incident.location,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      incident.meta,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onGoToRescue,
              icon: const Icon(Icons.directions_run, size: 18),
              label: const Text('Go to Rescue'),
              style: ElevatedButton.styleFrom(backgroundColor: accent),
            ),
          ),
        ],
      ),
    );
  }
}

class ActiveIncidentsScreen extends StatefulWidget {
  const ActiveIncidentsScreen({super.key});

  @override
  State<ActiveIncidentsScreen> createState() => _ActiveIncidentsScreenState();
}

class _ActiveIncidentsScreenState extends State<ActiveIncidentsScreen> {
  List<_Incident> _incidents = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'All';
  StreamSubscription<JsonMap>? _sosNewSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
        _subscribeToSosNew();
      }
    });
  }

  @override
  void dispose() {
    _sosNewSub?.cancel();
    super.dispose();
  }

  void _subscribeToSosNew() {
    _sosNewSub?.cancel();
    final socket = AppDependenciesScope.of(context).towerSocket;
    // A new SOS changes both the queue contents and every active request's
    // relative priority rank, so just reload rather than trying to splice
    // one item into an already-ranked list.
    _sosNewSub = socket.onSosNew.listen((_) {
      if (mounted) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dependencies = AppDependenciesScope.of(context);
      final requests = await dependencies.rescueRepository.fetchRequests();

      if (!mounted) {
        return;
      }

      setState(() {
        _incidents = requests.map(_Incident.fromRescueRequest).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not load incidents: $error';
        _isLoading = false;
      });
    }
  }

  List<_Incident> get _filteredIncidents {
    final statuses = _incidentTabStatuses[_selectedFilter];
    if (statuses == null) return _incidents;
    return _incidents.where((i) => statuses.contains(i.rawStatus)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredIncidents;

    return _ResponderPage(
      onRefresh: _load,
      header: const _SimpleResponderHeader(
        title: 'Priority Incidents',
        leadingIcon: Icons.arrow_back,
        trailingIcon: Icons.filter_alt,
      ),
      children: [
        _IncidentFilters(
          incidents: _incidents,
          selectedFilter: _selectedFilter,
          onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No active incidents.')),
          )
        else
          for (final incident in filtered) ...[
            _IncidentCard(incident: incident, onReturn: _load),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _ResponderIncidentDetailScreen extends StatelessWidget {
  const _ResponderIncidentDetailScreen({required this.incident});

  final _Incident incident;

  @override
  Widget build(BuildContext context) {
    Future<void> updateStatus(RescueStatus status, String confirmation) async {
      try {
        await AppDependenciesScope.of(
          context,
        ).rescueRepository.updateRequestStatus(id: incident.id, status: status);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(confirmation)));
      } on QueuedForSyncException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$error'),
            backgroundColor: AppTheme.warningAmber,
          ),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update incident: $error')),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Incident Details'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'copy_id':
                  Clipboard.setData(ClipboardData(text: incident.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Incident ID copied to clipboard'),
                      ),
                    );
                  }
                case 'share_location':
                  final lat = incident.latitude;
                  final lon = incident.longitude;
                  final locationText = lat != null && lon != null
                      ? '${incident.title} at $lat, $lon'
                      : '${incident.title} at ${incident.location}';
                  Clipboard.setData(ClipboardData(text: locationText));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Location copied to clipboard'),
                      ),
                    );
                  }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'copy_id',
                child: ListTile(
                  leading: Icon(Icons.copy, size: 20),
                  title: Text('Copy ID'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'share_location',
                child: ListTile(
                  leading: Icon(Icons.share_location, size: 20),
                  title: Text('Share Location'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          Row(
            children: [
              _IconBubble(icon: incident.icon, color: incident.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.priorityRank != null
                          ? '${incident.title} - #${incident.priorityRank} Priority'
                                '${incident.riskLevel != null ? ' (${incident.riskLevel} risk)' : ''}'
                          : '${incident.title} - ${incident.severity} Priority',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      incident.location,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const _LivePill(),
            ],
          ),
          const SizedBox(height: 14),
          _DetailTabs(peopleNeedingHelp: incident.people),
          const SizedBox(height: 12),
          _ResponderMapPreview(
            height: 170,
            residentLocation:
                incident.latitude != null && incident.longitude != null
                ? GeoPoint(
                    latitude: incident.latitude!,
                    longitude: incident.longitude!,
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                const _InfoRow(
                  icon: Icons.person,
                  label: 'Reported by',
                  value: 'Community User',
                ),
                _InfoRow(
                  icon: Icons.groups,
                  label: 'People Need Help',
                  value: '${incident.people}',
                ),
                _InfoRow(
                  icon: Icons.schedule,
                  label: 'Status',
                  value: incident.status,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AiReasoningCard(incident: incident),
          const SizedBox(height: 16),
          Text('Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SentryButton(
            label: 'Dispatch Team',
            icon: Icons.airport_shuttle,
            onPressed: () => updateStatus(
              RescueStatus.acknowledged,
              'Team dispatched to ${incident.location}.',
            ),
          ),
          const SizedBox(height: 10),
          SentryButton(
            label: 'Navigate to Location',
            icon: Icons.navigation,
            backgroundColor: AppTheme.safeGreen,
            onPressed: () async {
              await updateStatus(
                RescueStatus.inProgress,
                'Incident marked as en route.',
              );
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      _ResponderNavigationScreen(incident: incident),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => updateStatus(
              RescueStatus.inProgress,
              'Incident marked as on-route.',
            ),
            icon: const Icon(Icons.flag),
            label: const Text('Mark as On-Route'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await updateStatus(
                RescueStatus.resolved,
                'Incident marked resolved.',
              );
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Resolve Incident'),
          ),
        ],
      ),
    );
  }
}

class _ResponderNavigationScreen extends StatefulWidget {
  const _ResponderNavigationScreen({required this.incident});

  final _Incident incident;

  @override
  State<_ResponderNavigationScreen> createState() =>
      _ResponderNavigationScreenState();
}

class _ResponderNavigationScreenState
    extends State<_ResponderNavigationScreen> {
  final _mapController = MapController();

  GeoPoint? _responderLocation;
  RescueLocationModel? _residentLocation;
  RescueNavigationModel? _navigation;
  RouteModel? _route;
  bool _isLoading = true;
  String? _message;
  bool _use3D = false;
  bool _has3DPackReady = false;
  Timer? _connectivityTimer;
  StreamSubscription<GeoPoint>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadNavigation();
        _check3DPackReady();
        _refreshMapConnectivity();
        _startLiveTracking();
      }
    });
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refreshMapConnectivity();
    });
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  // Keeps the responder's own marker moving live while en route, instead of
  // freezing at wherever they were when the screen first loaded or the user
  // last hit refresh — the whole point of navigating to someone in distress.
  void _startLiveTracking() {
    final locationService = AppDependenciesScope.of(context).locationService;
    _locationSubscription?.cancel();
    _locationSubscription = locationService.watchLocation().listen((
      location,
    ) {
      if (mounted) setState(() => _responderLocation = location);
    });
  }

  bool get _can3D => MapTileConfig.isOnline || _has3DPackReady;

  GeoPoint? get _location3DReference =>
      _responderLocation ?? _residentLocation?.point;

  Future<void> _check3DPackReady() async {
    final location = _location3DReference;
    if (location == null) return;
    final ready = await AppDependenciesScope.of(
      context,
    ).offline3DPackService.hasPackReady(location);
    if (mounted) setState(() => _has3DPackReady = ready);
  }

  // See the same fix in _ResponderLiveMapScreenState: MapTileConfig only
  // checks connectivity once at app startup, so it needs re-checking here
  // too or this screen's 3D toggle would stay stuck at launch-time state.
  // Also silently extends 3D offline coverage to wherever the responder
  // currently is, Wi-Fi only, instead of requiring a manual download.
  Future<void> _refreshMapConnectivity() async {
    await MapTileConfig.checkConnectivity();
    if (!mounted) return;
    await maybeAutoDownload3DPack(
      context: context,
      location: _location3DReference,
    );
    await _check3DPackReady();
    if (mounted) setState(() {});
  }

  Future<void> _loadNavigation() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    if (_isRunningWidgetTest) {
      setState(() {
        _isLoading = false;
        _message = 'Navigation fetch skipped during widget tests.';
      });
      return;
    }

    final dependencies = AppDependenciesScope.of(context);
    RescueLocationModel? residentLocation;
    GeoPoint? responderLocation;
    RescueNavigationModel? navigation;
    RouteModel? route;
    String? message;

    try {
      residentLocation = await dependencies.rescueRepository
          .fetchRequestLocation(widget.incident.id);
    } catch (error) {
      message = 'Resident GPS is not available from backend yet: $error';
    }

    try {
      responderLocation = await dependencies.locationService.currentLocation();
    } catch (error) {
      message = [?message, 'Responder GPS is not available: $error'].join('\n');
    }

    if (residentLocation != null && responderLocation != null) {
      try {
        navigation = await dependencies.rescueRepository.fetchNavigation(
          id: widget.incident.id,
          responderLocation: responderLocation,
        );
        route = navigation?.route;

        message = route == null
            ? 'Resident GPS loaded. Backend did not return navigation waypoints yet.'
            : 'Backend route loaded to resident location.';
      } catch (error) {
        message = [
          ?message,
          'Navigation route is not available from backend yet: $error',
        ].join('\n');
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _residentLocation = residentLocation;
      _responderLocation = responderLocation;
      _navigation = navigation;
      _route = route;
      _message = message;
      _isLoading = false;
    });

    final focus = residentLocation?.point ?? responderLocation;
    if (focus != null) {
      _mapController.move(LatLng(focus.latitude, focus.longitude), 15);
    }
  }

  bool get _isRunningWidgetTest {
    return WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }

  void _fitRoute() {
    final points = <LatLng>[];

    final waypoints = _route?.waypoints;
    if (waypoints != null) {
      points.addAll(waypoints.map((p) => LatLng(p.latitude, p.longitude)));
    }
    if (_responderLocation != null) {
      points.add(
        LatLng(_responderLocation!.latitude, _responderLocation!.longitude),
      );
    }
    if (_residentLocation != null) {
      points.add(
        LatLng(_residentLocation!.latitude, _residentLocation!.longitude),
      );
    }
    if (points.length < 2) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Navigate to Resident'),
        actions: [
          IconButton(
            tooltip: _can3D
                ? (_use3D ? 'Switch to 2D map' : 'Switch to 3D map')
                : '3D view needs a connection or an offline 3D map',
            onPressed: _can3D
                ? () => setState(() => _use3D = !_use3D)
                : null,
            icon: Icon(
              _use3D ? Icons.map_rounded : Icons.view_in_ar_rounded,
              color: _can3D ? null : Theme.of(context).disabledColor,
            ),
          ),
          IconButton(
            tooltip: 'Refresh route',
            onPressed: _isLoading ? null : _loadNavigation,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_use3D && _can3D)
            ResponderMap3DView(
              responderLocation: _responderLocation,
              residentLocation: _residentLocation?.point,
              route: _route,
            )
          else
            _ResponderMapPreview(
              height: double.infinity,
              mapController: _mapController,
              responderLocation: _responderLocation,
              residentLocation: _residentLocation?.point,
              route: _route,
            ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: _NavigationFetchStatus(
              isLoading: _isLoading,
              hasResidentLocation: _residentLocation != null,
              hasRoute: _route != null,
              message: _message,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _ResidentRoutePanel(
              incident: widget.incident,
              residentLocation: _residentLocation,
              navigation: _navigation,
              route: _route,
              onRefresh: _loadNavigation,
              onNavigate: _fitRoute,
              isLoading: _isLoading,
              responderLocation: _responderLocation,
            ),
          ),
        ],
      ),
    );
  }
}

class ResponderLiveMapScreen extends StatefulWidget {
  const ResponderLiveMapScreen({super.key});

  @override
  State<ResponderLiveMapScreen> createState() => _ResponderLiveMapScreenState();
}

class _ResponderLiveMapScreenState extends State<ResponderLiveMapScreen> {
  final _mapController = MapController();

  StreamSubscription<GeoPoint>? _locationSubscription;
  StreamSubscription<Map<String, Object?>>? _teamLocationSub;
  StreamSubscription<Map<String, Object?>>? _hazardWarningSub;
  Timer? _refreshTimer;
  GeoPoint? _responderLocation;
  bool _isLocating = false;
  bool _isTracking = false;
  bool _use3D = false;

  List<RescueRequestModel> _sosRequests = const [];
  List<EvacuationCenterModel> _shelters = const [];
  final Map<String, TeamMemberModel> _teamMembers = {};
  List<Map<String, Object?>> _hazardWarningNodes = [];

  bool _showLayerMenu = false;
  bool _showIncidentsLayer = true;
  bool _showTeamsLayer = true;
  bool _showSheltersLayer = true;
  bool _showHazardZonesLayer = true;
  bool _has3DPackReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMapData();
        _listenToTeamLocations();
        _listenToHazardWarnings();
        _check3DPackReady();
        _refreshMapConnectivity();
      }
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadMapData();
        _refreshMapConnectivity();
      }
    });
  }

  // MapTileConfig.checkConnectivity() only runs once at app startup
  // (main.dart) — if that single check happened to fail (e.g. ran before
  // Wi-Fi was fully up), the 3D toggle would stay disabled for the rest of
  // the session even after real internet becomes available. Re-check on
  // the same cadence this screen already refreshes map data, so isOnline
  // reflects current reality. Also silently extends 3D offline coverage to
  // wherever the responder currently is, Wi-Fi only.
  Future<void> _refreshMapConnectivity() async {
    await MapTileConfig.checkConnectivity();
    if (!mounted) return;
    final location = await _location3DReference();
    if (!mounted) return;
    await maybeAutoDownload3DPack(context: context, location: location);
    await _check3DPackReady(location);
    if (mounted) setState(() {});
  }

  bool get _can3D => MapTileConfig.isOnline || _has3DPackReady;

  // This screen only tracks live GPS after the responder taps "Locate" — so
  // _responderLocation is null by default. Without a fallback here, the 3D
  // readiness check would silently never run for anyone who hasn't tapped
  // that button, leaving the toggle looking permanently disabled. A one-shot
  // fetch (not continuous tracking) is enough just to evaluate coverage.
  Future<GeoPoint?> _location3DReference() async {
    if (_responderLocation != null) return _responderLocation;
    try {
      return await AppDependenciesScope.of(
        context,
      ).locationService.currentLocation();
    } catch (_) {
      return null;
    }
  }

  Future<void> _check3DPackReady([GeoPoint? location]) async {
    final resolvedLocation = location ?? await _location3DReference();
    if (resolvedLocation == null || !mounted) return;
    final ready = await AppDependenciesScope.of(
      context,
    ).offline3DPackService.hasPackReady(resolvedLocation);
    if (mounted) setState(() => _has3DPackReady = ready);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _teamLocationSub?.cancel();
    _hazardWarningSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _listenToTeamLocations() {
    final socket = AppDependenciesScope.of(context).towerSocket;
    _teamLocationSub = socket.onTeamLocation.listen((data) {
      if (!mounted) return;
      final userId = data['user_id']?.toString();
      if (userId == null) return;
      final lat = data['latitude'];
      final lng = data['longitude'];
      final latitude = lat is num ? lat.toDouble() : double.tryParse('$lat');
      final longitude = lng is num ? lng.toDouble() : double.tryParse('$lng');
      if (latitude == null || longitude == null) return;

      setState(() {
        _teamMembers[userId] = TeamMemberModel(
          id: userId,
          userId: userId,
          firstName: data['first_name']?.toString() ?? '',
          lastName: data['last_name']?.toString() ?? '',
          role: 'member',
          latitude: latitude,
          longitude: longitude,
          locationUpdatedAt: DateTime.now(),
        );
      });
    });
  }

  void _listenToHazardWarnings() {
    final socket = AppDependenciesScope.of(context).towerSocket;
    _hazardWarningSub = socket.onHazardWarning.listen((data) {
      if (!mounted) return;
      final nodes = data['nodes'];
      if (nodes is List) {
        final parsed = <Map<String, Object?>>[];
        for (final node in nodes) {
          if (node is Map) {
            parsed.add(Map<String, Object?>.from(node));
          }
        }
        if (parsed.isNotEmpty) {
          setState(() {
            _hazardWarningNodes = parsed;
          });
        }
      }
    });
  }

  Future<void> _loadMapData() async {
    final repo = AppDependenciesScope.of(context).rescueRepository;
    try {
      final results = await Future.wait([
        repo.fetchRequests(),
        repo.fetchEvacuationCenters(),
      ]);
      if (!mounted) return;
      setState(() {
        _sosRequests = (results[0] as List<RescueRequestModel>)
            .where((r) => r.latitude != null && r.longitude != null)
            .toList();
        _shelters = results[1] as List<EvacuationCenterModel>;
      });
    } catch (_) {
      // Map data refresh is best-effort; silently ignore errors
    }
  }

  void _showSosBottomSheet(BuildContext context, RescueRequestModel request) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SosRequestSheet(
        request: request,
        shelters: _shelters,
        onShelterAssigned: (shelterId, shelterName, shelterAddress) async {
          final repo = AppDependenciesScope.of(context).rescueRepository;
          try {
            await repo.assignShelter(
              requestId: request.id,
              shelterId: shelterId,
              shelterName: shelterName,
              shelterAddress: shelterAddress,
            );
            if (!context.mounted) return;
            Navigator.of(context).pop();
            _loadMapData();
          } on QueuedForSyncException catch (error) {
            if (!context.mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$error'),
                backgroundColor: AppTheme.warningAmber,
              ),
            );
          } catch (error) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not assign shelter: $error')),
            );
          }
        },
        onNavigate: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _ResponderNavigationScreen(
                incident: _Incident.fromRescueRequest(request),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showShelterInfoSheet(
    BuildContext context,
    EvacuationCenterModel shelter,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ShelterInfoSheet(shelter: shelter),
    );
  }

  Future<void> _locateResponder() async {
    if (_isLocating) {
      return;
    }

    setState(() => _isLocating = true);

    final locationService = AppDependenciesScope.of(context).locationService;

    try {
      final location = await locationService.currentLocation();
      if (!mounted) {
        return;
      }

      setState(() {
        _responderLocation = location;
        _isTracking = true;
      });
      _centerMap(location);
      _startLiveTracking(locationService);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Responder GPS is live on the map.')),
      );
    } on LocationServiceDisabledException {
      if (!mounted) {
        return;
      }
      _showLocationSettingsSnackBar();
    } on LocationPermissionPermanentlyDeniedException {
      if (!mounted) {
        return;
      }
      _showAppSettingsSnackBar();
    } on LocationPermissionDeniedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission was denied')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showLocationUnavailableSnackBar();
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _startLiveTracking(LocationService locationService) {
    _locationSubscription?.cancel();
    _locationSubscription = locationService.watchLocation().listen(
      (location) {
        if (!mounted) {
          return;
        }

        setState(() {
          _responderLocation = location;
          _isTracking = true;
        });
      },
      onError: (_) {
        if (mounted) {
          setState(() => _isTracking = false);
        }
      },
    );
  }

  void _centerMap(GeoPoint location) {
    _mapController.move(LatLng(location.latitude, location.longitude), 15);
  }

  void _showLocationSettingsSnackBar() {
    final locationService = AppDependenciesScope.of(context).locationService;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Turn on device location to show responder GPS'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: locationService.openLocationSettings,
        ),
      ),
    );
  }

  void _showAppSettingsSnackBar() {
    final locationService = AppDependenciesScope.of(context).locationService;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Allow location access in app settings'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: locationService.openAppSettings,
        ),
      ),
    );
  }

  void _showLocationUnavailableSnackBar() {
    final locationService = AppDependenciesScope.of(context).locationService;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Responder location is not available yet.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: locationService.openLocationSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.deepNavy, AppTheme.navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const SizedBox(width: 44),
                Expanded(
                  child: Text(
                    'Live Map',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _can3D
                      ? (_use3D ? 'Switch to 2D map' : 'Switch to 3D map')
                      : '3D view needs a connection or an offline 3D map',
                  onPressed: _can3D
                      ? () => setState(() => _use3D = !_use3D)
                      : null,
                  icon: Icon(
                    _use3D ? Icons.map_rounded : Icons.view_in_ar_rounded,
                    color: _can3D ? Colors.white : Colors.white38,
                  ),
                ),
                IconButton(
                  tooltip: 'Layers',
                  onPressed: () =>
                      setState(() => _showLayerMenu = !_showLayerMenu),
                  icon: const Icon(Icons.layers, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (_use3D && _can3D)
                  ResponderMap3DView(
                    responderLocation: _responderLocation,
                    sosRequests: _showIncidentsLayer ? _sosRequests : const [],
                    shelters: _showSheltersLayer ? _shelters : const [],
                    teamMembers: _showTeamsLayer
                        ? _teamMembers.values.toList()
                        : const [],
                    hazardZones: _showHazardZonesLayer
                        ? _hazardWarningNodes
                        : const [],
                    onSosRequestTap: (request) =>
                        _showSosBottomSheet(context, request),
                    onShelterTap: (shelter) =>
                        _showShelterInfoSheet(context, shelter),
                  )
                else
                  _ResponderMapPreview(
                  height: double.infinity,
                  mapController: _mapController,
                  responderLocation: _responderLocation,
                  sosRequests: _showIncidentsLayer ? _sosRequests : const [],
                  shelters: _showSheltersLayer ? _shelters : const [],
                  teamMembers: _showTeamsLayer
                      ? _teamMembers.values.toList()
                      : const [],
                  hazardZones: _showHazardZonesLayer
                      ? _hazardWarningNodes
                      : const [],
                  onSosRequestTap: (request) =>
                      _showSosBottomSheet(context, request),
                  onShelterTap: (shelter) =>
                      _showShelterInfoSheet(context, shelter),
                ),
                if (_showLayerMenu)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _MapLayerMenu(
                      showIncidents: _showIncidentsLayer,
                      showTeams: _showTeamsLayer,
                      showShelters: _showSheltersLayer,
                      showHazardZones: _showHazardZonesLayer,
                      onToggleIncidents: () => setState(
                        () => _showIncidentsLayer = !_showIncidentsLayer,
                      ),
                      onToggleTeams: () =>
                          setState(() => _showTeamsLayer = !_showTeamsLayer),
                      onToggleShelters: () => setState(
                        () => _showSheltersLayer = !_showSheltersLayer,
                      ),
                      onToggleHazardZones: () => setState(
                        () => _showHazardZonesLayer = !_showHazardZonesLayer,
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _ResponderGpsBadge(
                    location: _responderLocation,
                    isTracking: _isTracking,
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 168,
                  child: _ResponderLocateButton(
                    isLoading: _isLocating,
                    hasLocation: _responderLocation != null,
                    onPressed: _locateResponder,
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 168,
                  child: OfflineMapDownloadButton(
                    heroTag: 'responder_offline_map_fab',
                    center: _responderLocation ?? kDefaultMapCenter,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _NavigationPanel(
                    hasLiveLocation: _responderLocation != null,
                    isTracking: _isTracking,
                    onLocate: _locateResponder,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResponderTeamsScreen extends StatefulWidget {
  const ResponderTeamsScreen({super.key});

  @override
  State<ResponderTeamsScreen> createState() => _ResponderTeamsScreenState();
}

class _ResponderTeamsScreenState extends State<ResponderTeamsScreen> {
  static const _natoAlphabet = [
    'Alpha',
    'Bravo',
    'Charlie',
    'Delta',
    'Echo',
    'Foxtrot',
    'Golf',
    'Hotel',
    'India',
    'Juliet',
    'Kilo',
    'Lima',
    'Mike',
    'November',
    'Oscar',
    'Papa',
    'Quebec',
    'Romeo',
    'Sierra',
    'Tango',
    'Uniform',
    'Victor',
    'Whiskey',
    'X-ray',
    'Yankee',
    'Zulu',
  ];

  List<TeamModel> _teams = [];
  TeamModel? _currentTeam;
  bool _isLoading = true;
  bool _isActing = false;
  String? _error;
  bool _liveLocationEnabled = false;
  Timer? _locationTimer;
  StreamSubscription<Map<String, Object?>>? _locationSub;
  StreamSubscription<Map<String, Object?>>? _joinedSub;
  StreamSubscription<Map<String, Object?>>? _leftSub;

  String? get _userId =>
      AppDependenciesScope.of(context).authRepository.currentUser?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
        _listenToSocket();
      }
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _locationSub?.cancel();
    _joinedSub?.cancel();
    _leftSub?.cancel();
    super.dispose();
  }

  void _listenToSocket() {
    final socket = AppDependenciesScope.of(context).towerSocket;

    _locationSub = socket.onTeamLocation.listen((data) {
      if (!mounted || _currentTeam == null) return;
      final teamId = data['team_id']?.toString();
      if (teamId != _currentTeam!.id) return;
      _load();
    });

    _joinedSub = socket.onTeamMemberJoined.listen((data) {
      if (!mounted) return;
      _load();
    });

    _leftSub = socket.onTeamMemberLeft.listen((data) {
      if (!mounted) return;
      final teamId = data['team_id']?.toString();
      final leftUserId = data['user_id']?.toString();
      if (teamId == _currentTeam?.id && leftUserId == _userId) {
        setState(() => _currentTeam = null);
      }
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final deps = AppDependenciesScope.of(context);
      final teams = await deps.teamRepository.fetchTeams();
      if (!mounted) return;

      final userId = _userId;
      TeamModel? myTeam;
      if (userId != null) {
        for (final team in teams) {
          final isMember = team.members.any((m) => m.userId == userId);
          if (isMember) {
            myTeam = team;
            break;
          }
        }
      }

      setState(() {
        _teams = teams;
        _currentTeam = myTeam;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load teams: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createTeam(String name) async {
    final userId = _userId;
    if (userId == null) return;
    setState(() => _isActing = true);
    try {
      final deps = AppDependenciesScope.of(context);
      await deps.teamRepository.createTeam(name, userId);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create team: $e')));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _joinTeam(TeamModel team) async {
    final userId = _userId;
    if (userId == null) return;
    setState(() => _isActing = true);
    try {
      final deps = AppDependenciesScope.of(context);
      await deps.teamRepository.joinTeam(team.id, userId);
      if (!mounted) return;
      await _load();
    } on QueuedForSyncException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: AppTheme.warningAmber),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join team: $e')));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _leaveTeam() async {
    final userId = _userId;
    final team = _currentTeam;
    if (userId == null || team == null) return;
    setState(() => _isActing = true);
    _stopLiveLocation();
    try {
      final deps = AppDependenciesScope.of(context);
      await deps.teamRepository.leaveTeam(team.id, userId);
      if (!mounted) return;
      setState(() => _currentTeam = null);
      await _load();
    } on QueuedForSyncException catch (error) {
      if (!mounted) return;
      // The leave request is queued but not yet confirmed by the server —
      // don't clear _currentTeam locally until it actually is, or the UI
      // would claim they left a team the backend still has them on.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: AppTheme.warningAmber),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not leave team: $e')));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  void _toggleLiveLocation(bool enabled) {
    setState(() => _liveLocationEnabled = enabled);
    if (enabled) {
      _startLiveLocation();
    } else {
      _stopLiveLocation();
    }
  }

  void _startLiveLocation() {
    _locationTimer?.cancel();
    _sendLocation();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _sendLocation(),
    );
  }

  void _stopLiveLocation() {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (mounted) setState(() => _liveLocationEnabled = false);
  }

  Future<void> _sendLocation() async {
    final team = _currentTeam;
    final userId = _userId;
    if (team == null || userId == null) return;

    try {
      final deps = AppDependenciesScope.of(context);
      final location = await deps.locationService.currentLocation();
      if (!mounted) return;
      await deps.teamRepository.updateLocation(
        team.id,
        userId,
        location.latitude,
        location.longitude,
      );
      deps.towerSocket.emitLocationUpdate(
        team.id,
        location.latitude,
        location.longitude,
      );
    } catch (_) {
      // Location send is best-effort
    }
  }

  void _showCreateTeamDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Team Name',
                hintText: 'e.g. Alpha, Bravo, Charlie',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Text(
              'Suggestions',
              style: Theme.of(dialogContext).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in _natoAlphabet.take(8))
                  ActionChip(
                    label: Text(name, style: const TextStyle(fontSize: 12)),
                    onPressed: () => controller.text = name,
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogContext).pop();
              _createTeam(name);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Color _teamStatusColor(String status) {
    return switch (status) {
      'deployed' => AppTheme.safeGreen,
      'returning' => AppTheme.warningAmber,
      _ => AppTheme.signalBlue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final team = _currentTeam;

    return _ResponderPage(
      onRefresh: _load,
      header: const _SimpleResponderHeader(title: 'Team Coordination'),
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (team != null)
          _buildMyTeamView(team)
        else
          _buildTeamListView(),
      ],
    );
  }

  Widget _buildMyTeamView(TeamModel team) {
    final userId = _userId;
    final statusColor = _teamStatusColor(team.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: AppTheme.deepNavy,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.groups,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Team ${team.name}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${team.members.length} member${team.members.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                _SeverityPill(
                  label: team.status.toUpperCase(),
                  color: statusColor,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _liveLocationEnabled ? Icons.gps_fixed : Icons.gps_off,
                  color: _liveLocationEnabled
                      ? AppTheme.safeGreen
                      : AppTheme.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Location Sharing',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        _liveLocationEnabled
                            ? 'Your GPS is broadcasting to the team'
                            : 'Share your position with team members',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _liveLocationEnabled,
                  onChanged: _toggleLiveLocation,
                  activeTrackColor: AppTheme.safeGreen,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _SectionTitle(title: 'Team Members (${team.members.length})'),
        const SizedBox(height: 10),
        if (team.members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No members in this team yet.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          )
        else
          for (final member in team.members)
            _TeamMemberTile(
              member: member,
              isCurrentUser: member.userId == userId,
            ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isActing ? null : _leaveTeam,
            icon: const Icon(Icons.logout, color: AppTheme.dangerRed),
            label: const Text(
              'Leave Team',
              style: TextStyle(color: AppTheme.dangerRed),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Available Teams (${_teams.length})'),
        const SizedBox(height: 10),
        if (_teams.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    size: 48,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No teams available yet.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isActing ? null : _showCreateTeamDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Team'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          for (final team in _teams) ...[
            _TeamCard(
              team: team,
              statusColor: _teamStatusColor(team.status),
              onJoin: _isActing ? null : () => _joinTeam(team),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: SentryButton(
            label: 'Create New Team',
            icon: Icons.add,
            onPressed: _isActing ? null : _showCreateTeamDialog,
          ),
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.statusColor, this.onJoin});

  final TeamModel team;
  final Color statusColor;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onJoin,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _IconBubble(icon: Icons.groups, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team ${team.name}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${team.memberCount} member${team.memberCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SeverityPill(
                    label: team.status.toUpperCase(),
                    color: statusColor,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to join',
                    style: TextStyle(
                      color: AppTheme.signalBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({required this.member, required this.isCurrentUser});

  final TeamMemberModel member;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final isLeader = member.role == 'leader';
    final locationLabel = member.hasLocation && member.locationUpdatedAt != null
        ? _timeAgoLabel(member.locationUpdatedAt!)
        : 'No location';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isLeader
                ? AppTheme.warningAmber.withValues(alpha: 0.14)
                : AppTheme.signalBlue.withValues(alpha: 0.14),
            child: Icon(
              isLeader ? Icons.star : Icons.person,
              color: isLeader ? AppTheme.warningAmber : AppTheme.signalBlue,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  member.fullName.isEmpty ? 'Member' : member.fullName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrentUser)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text(
                    '(You)',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (isLeader)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningAmber.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LEADER',
                      style: TextStyle(
                        color: AppTheme.warningAmber,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(locationLabel),
          trailing: member.hasLocation
              ? const Icon(
                  Icons.location_on,
                  color: AppTheme.safeGreen,
                  size: 18,
                )
              : const Icon(
                  Icons.location_off,
                  color: AppTheme.textMuted,
                  size: 18,
                ),
        ),
      ),
    );
  }
}

class ResponderReportsScreen extends StatefulWidget {
  const ResponderReportsScreen({super.key});

  @override
  State<ResponderReportsScreen> createState() => _ResponderReportsScreenState();
}

class _ResponderReportsScreenState extends State<ResponderReportsScreen> {
  int _activeIncidents = 0;
  int _resolvedToday = 0;
  int _dispatched = 0;
  int _activeAlerts = 0;
  bool _isLoading = true;
  ConnectivityStatus _connectivity = ConnectivityStatus.online;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final deps = AppDependenciesScope.of(context);
      final connectivity = await deps.connectivityService.currentStatus();
      final results = await Future.wait([
        deps.rescueRepository.fetchRequests(),
        deps.alertRepository.fetchAlerts(),
      ]);

      if (!mounted) return;

      final requests = results[0] as List<RescueRequestModel>;
      final alerts = results[1];
      final today = DateTime.now();

      setState(() {
        _connectivity = connectivity;
        _activeIncidents = requests
            .where(
              (r) =>
                  r.status == RescueStatus.pending ||
                  r.status == RescueStatus.acknowledged ||
                  r.status == RescueStatus.inProgress,
            )
            .length;
        _resolvedToday = requests
            .where(
              (r) =>
                  r.status == RescueStatus.resolved &&
                  r.createdAt.year == today.year &&
                  r.createdAt.month == today.month &&
                  r.createdAt.day == today.day,
            )
            .length;
        _dispatched = requests
            .where(
              (r) =>
                  r.status == RescueStatus.acknowledged ||
                  r.status == RescueStatus.inProgress,
            )
            .length;
        _activeAlerts = alerts.length;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(DateTime.now());

    return _ResponderPage(
      header: const _SimpleResponderHeader(title: 'Reports'),
      children: [
        _SectionTitle(
          title: 'Response Reports',
          subtitle: _isLoading ? 'Loading…' : 'Updated $timeStr',
        ),
        const SizedBox(height: 12),
        _ReportTile(
          title: 'Situation Report',
          subtitle: _isLoading
              ? 'Loading…'
              : '$_activeIncidents active · $_resolvedToday resolved today',
          icon: Icons.summarize,
        ),
        _ReportTile(
          title: 'Team Status',
          subtitle: _isLoading
              ? 'Loading…'
              : '$_dispatched dispatched · ${_networkStatusLabel(_connectivity)}',
          icon: Icons.inventory_2,
        ),
        _ReportTile(
          title: 'Alert Summary',
          subtitle: _isLoading
              ? 'Loading…'
              : '$_activeAlerts active alert${_activeAlerts == 1 ? '' : 's'} in the system',
          icon: Icons.forum,
        ),
      ],
    );
  }
}

String _networkStatusLabel(ConnectivityStatus status) {
  return switch (status) {
    ConnectivityStatus.online => 'network healthy',
    ConnectivityStatus.limited => 'limited connection',
    ConnectivityStatus.offline => 'offline',
  };
}

String _formatTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $ampm';
}

class _ResponderPage extends StatelessWidget {
  const _ResponderPage({
    required this.header,
    required this.children,
    this.onRefresh,
  });

  final Widget header;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget listView = ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );

    if (onRefresh != null) {
      listView = RefreshIndicator(onRefresh: onRefresh!, child: listView);
    }

    return ColoredBox(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            header,
            Expanded(child: listView),
          ],
        ),
      ),
    );
  }
}

class _ResponderHeader extends StatelessWidget {
  const _ResponderHeader({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.deepNavy, AppTheme.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: DecorationImage(
          image: AssetImage(AppAssets.headerTopography),
          fit: BoxFit.cover,
          opacity: 0.22,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _logout(context),
                tooltip: 'Logout',
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              trailing ?? const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SimpleResponderHeader extends StatelessWidget {
  const _SimpleResponderHeader({
    required this.title,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String title;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.deepNavy, AppTheme.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back',
            icon: Icon(leadingIcon ?? Icons.menu, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
          if (trailingIcon != null)
            IconButton(
              onPressed: () {},
              tooltip: 'Action',
              icon: Icon(trailingIcon, color: Colors.white),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _LiveStatusBanner extends StatelessWidget {
  const _LiveStatusBanner({
    required this.activeIncidents,
    required this.isLoading,
  });

  final int activeIncidents;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final subtitle = isLoading
        ? 'Loading incident data…'
        : activeIncidents == 0
        ? 'No active incidents — all clear'
        : '$activeIncidents active incident${activeIncidents == 1 ? '' : 's'} in progress';

    return Card(
      color: AppTheme.deepNavy,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.safeGreen.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sensors, color: AppTheme.safeGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Command Center Ready',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const _SeverityPill(label: 'Live', color: AppTheme.safeGreen),
          ],
        ),
      ),
    );
  }
}

class _AiReasoningCard extends StatefulWidget {
  const _AiReasoningCard({required this.incident});

  final _Incident incident;

  @override
  State<_AiReasoningCard> createState() => _AiReasoningCardState();
}

class _AiReasoningCardState extends State<_AiReasoningCard> {
  NodePredictionModel? _node;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch();
    });
  }

  Future<void> _fetch() async {
    final lat = widget.incident.latitude;
    final lon = widget.incident.longitude;
    if (lat == null || lon == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final node = await AppDependenciesScope.of(context).predictionRepository
          .fetchIncidentPrediction(
            latitude: lat,
            longitude: lon,
            hazardType: widget.incident.hazardType,
          );
      if (mounted)
        setState(() {
          _node = node;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = _node;
    final isAlert = node?.alert ?? false;
    final alertLevel = node?.alertLevel ?? '';
    final pillColor = isAlert ? AppTheme.dangerRed : AppTheme.safeGreen;
    final equityScore = node?.equityScore;
    final rescueRank = node?.rescueRank;

    return Card(
      color: AppTheme.signalBlue.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.signalBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: AppTheme.signalBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'VigilantPath AI Assessment',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (alertLevel.isNotEmpty)
                  _SeverityPill(label: alertLevel, color: pillColor),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Fetching AI hazard assessment…'),
              )
            else if (node == null)
              const _ReasonLine(
                label: 'Status',
                value:
                    'AI assessment unavailable — incident location not pinned yet.',
              )
            else ...[
              _ReasonLine(label: 'Risk', value: node.probabilityLabel),
              _ReasonLine(label: 'Severity', value: node.severityLabel),
              if (equityScore != null)
                _ReasonLine(
                  label: 'Equity',
                  value:
                      'Score ${(equityScore * 100).toStringAsFixed(0)}/100 — ranked by objective threat only',
                ),
              if (rescueRank != null)
                _ReasonLine(
                  label: 'Rank',
                  value: 'Priority #$rescueRank in area (equity-first)',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReasonLine extends StatelessWidget {
  const _ReasonLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _LiveStatsGrid extends StatelessWidget {
  const _LiveStatsGrid({required this.stats, required this.isLoading});

  final _DashboardStats? stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.85,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _StatTile(
          icon: Icons.crisis_alert,
          value: isLoading ? '…' : '${s?.activeIncidents ?? 0}',
          label: 'Active Incidents',
          color: AppTheme.dangerRed,
        ),
        _StatTile(
          icon: Icons.personal_injury,
          value: isLoading ? '…' : '${s?.peopleNeedHelp ?? 0}',
          label: 'People Need Help',
          color: AppTheme.warningAmber,
        ),
        _StatTile(
          icon: Icons.groups,
          value: isLoading ? '…' : '${s?.deployedTeams ?? 0}',
          label: 'Dispatched',
          color: AppTheme.signalBlue,
        ),
        _StatTile(
          icon: Icons.notifications_active,
          value: isLoading ? '…' : '${s?.activeAlerts ?? 0}',
          label: 'Active Alerts',
          color: AppTheme.safeGreen,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _IconBubble(icon: icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveRecentIncidents extends StatelessWidget {
  const _LiveRecentIncidents({required this.requests, required this.isLoading});

  final List<RescueRequestModel> requests;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (requests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'No recent incidents.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < requests.length; i++) ...[
          _CompactIncidentTile(
            icon: _incidentIcon(requests[i].emergencyType),
            title:
                '${_hazardTitle(requests[i].emergencyType)} — ${requests[i].locationLabel ?? 'Unknown location'}',
            subtitle:
                '${_timeAgoLabel(requests[i].createdAt)} · ${requests[i].peopleNeedingHelp} people · ${_rescueStatusLabel(requests[i].status)}',
            severity: severityLabelFromPeopleCount(requests[i].peopleNeedingHelp),
            severityColor: severityColorFromPeopleCount(requests[i].peopleNeedingHelp),
          ),
          if (i != requests.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _HeatmapPreview extends StatefulWidget {
  const _HeatmapPreview();

  @override
  State<_HeatmapPreview> createState() => _HeatmapPreviewState();
}

class _HeatmapPreviewState extends State<_HeatmapPreview> {
  PredictionBundle? _bundle;
  List<RescueRequestModel> _activeRequests = const [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchData();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final dependencies = AppDependenciesScope.of(context);
      final results = await Future.wait([
        dependencies.predictionRepository.fetchHomePredictions(),
        dependencies.rescueRepository.fetchRequests(),
      ]);
      if (!mounted) return;
      final bundle = results[0] as PredictionBundle;
      final requests = results[1] as List<RescueRequestModel>;
      setState(() {
        _bundle = bundle;
        _activeRequests = requests
            .where(
              (r) =>
                  r.status != RescueStatus.resolved &&
                  r.status != RescueStatus.cancelled &&
                  r.latitude != null &&
                  r.longitude != null,
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load risk data: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, Object?>> get _hazardZones {
    final bundle = _bundle;
    if (bundle == null) return const [];
    return [
      for (final node in [bundle.flood, bundle.landslide])
        if (node != null && node.latitude != null && node.longitude != null)
          {
            'lat': node.latitude,
            'lon': node.longitude,
            'alert_level': node.alertLevel,
          },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;

    // Count active alerts from predictions
    int activeAlerts = 0;
    int highRiskAreas = 0;
    String floodStatus = 'N/A';
    String landslideStatus = 'N/A';

    if (bundle != null) {
      if (bundle.flood != null) {
        if (bundle.flood!.alert) activeAlerts++;
        if (bundle.flood!.alertLevel.toLowerCase().contains('high') ||
            bundle.flood!.alertLevel.toLowerCase().contains('critical')) {
          highRiskAreas++;
        }
        floodStatus = bundle.flood!.alertLevel;
      }
      if (bundle.landslide != null) {
        if (bundle.landslide!.alert) activeAlerts++;
        if (bundle.landslide!.alertLevel.toLowerCase().contains('high') ||
            bundle.landslide!.alertLevel.toLowerCase().contains('critical')) {
          highRiskAreas++;
        }
        landslideStatus = bundle.landslide!.alertLevel;
      }
    }

    final String title;
    final String subtitle;

    if (_isLoading && bundle == null) {
      title = 'Loading risk assessment...';
      subtitle = 'Fetching prediction data from backend.';
    } else if (_errorMessage != null && bundle == null) {
      title = 'Risk layer unavailable';
      subtitle = _errorMessage!;
    } else if (bundle == null) {
      title = 'No prediction data';
      subtitle = 'Backend has not returned risk data yet.';
    } else {
      title =
          '$activeAlerts active alert${activeAlerts == 1 ? '' : 's'}, '
          '$highRiskAreas high-risk area${highRiskAreas == 1 ? '' : 's'}';
      subtitle =
          'Flood: $floodStatus  |  Landslide: $landslideStatus  |  '
          'Rainfall: ${bundle.rainfallMm.toStringAsFixed(0)} mm';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh risk map',
                  onPressed: _isLoading ? null : _fetchData,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ResponderLiveMapScreen(),
              ),
            ),
            child: _ResponderMapPreview(
              height: 170,
              sosRequests: _activeRequests,
              hazardZones: _hazardZones,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _RiskLegendDot(color: AppTheme.safeGreen, label: 'Low'),
                SizedBox(width: 18),
                _RiskLegendDot(color: AppTheme.warningAmber, label: 'Medium'),
                SizedBox(width: 18),
                _RiskLegendDot(color: AppTheme.dangerRed, label: 'High'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskLegendDot extends StatelessWidget {
  const _RiskLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ResponderMapPreview extends StatelessWidget {
  const _ResponderMapPreview({
    required this.height,
    this.mapController,
    this.responderLocation,
    this.residentLocation,
    this.route,
    this.sosRequests = const [],
    this.shelters = const [],
    this.teamMembers = const [],
    this.hazardZones = const [],
    this.onSosRequestTap,
    this.onShelterTap,
  });

  final double height;
  final MapController? mapController;
  final GeoPoint? responderLocation;
  final GeoPoint? residentLocation;
  final RouteModel? route;
  final List<RescueRequestModel> sosRequests;
  final List<EvacuationCenterModel> shelters;
  final List<TeamMemberModel> teamMembers;
  final List<Map<String, Object?>> hazardZones;
  final void Function(RescueRequestModel)? onSosRequestTap;
  final void Function(EvacuationCenterModel)? onShelterTap;

  static const _center = LatLng(kDefaultLatitude, kDefaultLongitude);

  static double? _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final responderPoint = responderLocation == null
        ? null
        : LatLng(responderLocation!.latitude, responderLocation!.longitude);
    final residentPoint = residentLocation == null
        ? null
        : LatLng(residentLocation!.latitude, residentLocation!.longitude);
    final routePoints =
        route?.waypoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList() ??
        const <LatLng>[];

    return SizedBox(
      height: height,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: residentPoint ?? responderPoint ?? _center,
          initialZoom: responderPoint == null && residentPoint == null
              ? 12.4
              : 15,
          minZoom: 4,
          maxZoom: 18,
          interactionOptions: const InteractionOptions(),
        ),
        children: [
          TileLayer(
            urlTemplate: MapTileConfig.mapboxSatelliteStreetsUrl,
            tileProvider: MapTileConfig.cachedTileProvider,
            userAgentPackageName: 'com.example.sentrymesh_frontend',
          ),
          if (routePoints.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 8,
                  color: Colors.white,
                ),
                Polyline(
                  points: routePoints,
                  strokeWidth: 4,
                  color: AppTheme.safeGreen,
                ),
              ],
            ),
          if (hazardZones.isNotEmpty)
            CircleLayer(
              circles: [
                for (final zone in hazardZones)
                  if (_parseDouble(zone['lat']) != null &&
                      _parseDouble(zone['lon']) != null)
                    CircleMarker(
                      point: LatLng(
                        _parseDouble(zone['lat'])!,
                        _parseDouble(zone['lon'])!,
                      ),
                      radius: 500,
                      useRadiusInMeter: true,
                      color: riskTierColor(
                        zone['alert_level'] ?? zone['alertLevel'],
                      ).withValues(alpha: 0.2),
                      borderColor: riskTierColor(
                        zone['alert_level'] ?? zone['alertLevel'],
                      ).withValues(alpha: 0.6),
                      borderStrokeWidth: 2,
                    ),
              ],
            ),
          MarkerLayer(
            markers: [
              // Evacuation center markers
              for (final shelter in shelters)
                Marker(
                  point: LatLng(shelter.latitude, shelter.longitude),
                  width: 72,
                  height: 76,
                  child: GestureDetector(
                    onTap: () => onShelterTap?.call(shelter),
                    child: _ShelterMarker(shelter: shelter),
                  ),
                ),
              // SOS request markers
              for (final request in sosRequests)
                if (request.latitude != null && request.longitude != null)
                  Marker(
                    point: LatLng(request.latitude!, request.longitude!),
                    width: 68,
                    height: 76,
                    child: GestureDetector(
                      onTap: () => onSosRequestTap?.call(request),
                      child: _SosRequestMarker(request: request),
                    ),
                  ),
              // Team member markers
              for (final member in teamMembers)
                if (member.hasLocation)
                  Marker(
                    point: LatLng(member.latitude!, member.longitude!),
                    width: 84,
                    height: 76,
                    child: _TeamMemberMarker(member: member),
                  ),
              // Responder / base marker
              if (responderPoint == null)
                const Marker(
                  point: _center,
                  width: 84,
                  height: 68,
                  child: _CommandCenterMarker(),
                )
              else
                Marker(
                  point: responderPoint,
                  width: 84,
                  height: 76,
                  child: const _ResponderLocationMarker(),
                ),
              if (residentPoint != null)
                Marker(
                  point: residentPoint,
                  width: 64,
                  height: 72,
                  child: const _ResidentLocationMarker(),
                ),
            ],
          ),
          const RichAttributionWidget(
            showFlutterMapAttribution: false,
            attributions: [
              TextSourceAttribution('Mapbox, OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavigationFetchStatus extends StatelessWidget {
  const _NavigationFetchStatus({
    required this.isLoading,
    required this.hasResidentLocation,
    required this.hasRoute,
    required this.message,
  });

  final bool isLoading;
  final bool hasResidentLocation;
  final bool hasRoute;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final color = isLoading
        ? AppTheme.signalBlue
        : hasRoute
        ? AppTheme.safeGreen
        : hasResidentLocation
        ? AppTheme.warningAmber
        : AppTheme.dangerRed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                hasRoute
                    ? Icons.route
                    : hasResidentLocation
                    ? Icons.location_on
                    : Icons.cloud_off,
                color: color,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isLoading
                    ? 'Fetching resident GPS and safe route from backend...'
                    : message ?? 'Waiting for backend response.',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResidentRoutePanel extends StatelessWidget {
  const _ResidentRoutePanel({
    required this.incident,
    required this.residentLocation,
    required this.navigation,
    required this.route,
    required this.onRefresh,
    required this.onNavigate,
    required this.isLoading,
    required this.responderLocation,
  });

  final _Incident incident;
  final RescueLocationModel? residentLocation;
  final RescueNavigationModel? navigation;
  final RouteModel? route;
  final VoidCallback onRefresh;
  final VoidCallback onNavigate;
  final bool isLoading;
  final GeoPoint? responderLocation;

  @override
  Widget build(BuildContext context) {
    final location = residentLocation;
    final hasRoute = route != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _IconBubble(icon: incident.icon, color: incident.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        location == null
                            ? 'Waiting for resident GPS'
                            : '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    value: navigation != null
                        ? '${navigation!.directDistanceKm.toStringAsFixed(1)} km'
                        : hasRoute
                        ? '${route!.distanceKm.toStringAsFixed(1)} km'
                        : '--',
                    label: 'Distance',
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    value: hasRoute ? '${route!.estimatedMinutes} min' : '--',
                    label: 'ETA',
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    value: navigation != null
                        ? '${navigation!.bearingDegrees.round()} deg'
                        : '--',
                    label: 'Bearing',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SentryButton(
                label: 'Show Route on Map',
                icon: Icons.route,
                backgroundColor: AppTheme.safeGreen,
                onPressed: onNavigate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, this.onReturn});

  final _Incident incident;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: incident.color.withValues(alpha: 0.07),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  _ResponderIncidentDetailScreen(incident: incident),
            ),
          );
          onReturn?.call();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _IconBubble(icon: incident.icon, color: incident.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      incident.location,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      incident.meta,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (incident.assignedTeamName != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF7B1FA2,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shield_rounded,
                              size: 10,
                              color: Color(0xFF7B1FA2),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Team ${incident.assignedTeamName}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7B1FA2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (incident.priorityRank != null)
                _SeverityPill(
                  label: '#${incident.priorityRank}',
                  color: riskTierColor(incident.riskLevel),
                )
              else
                _SeverityPill(label: incident.severity, color: incident.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _Incident {
  const _Incident({
    required this.id,
    required this.icon,
    required this.title,
    required this.location,
    required this.meta,
    required this.severity,
    required this.color,
    required this.people,
    required this.status,
    required this.rawStatus,
    required this.hazardType,
    this.latitude,
    this.longitude,
    this.assignedTeamName,
    this.riskLevel,
    this.priorityRank,
  });

  factory _Incident.fromRescueRequest(RescueRequestModel request) {
    final severityLabel = severityLabelFromPeopleCount(request.peopleNeedingHelp);
    final riskLevel = request.riskLevel;
    final metaParts = [
      '${request.peopleNeedingHelp} people',
      _timeAgoLabel(request.createdAt),
      if (riskLevel != null && riskLevel.isNotEmpty) '$riskLevel risk',
      _rescueStatusLabel(request.status),
    ];

    return _Incident(
      id: request.id,
      icon: _incidentIcon(request.emergencyType),
      title: _hazardTitle(request.emergencyType),
      location: request.locationLabel ?? request.description,
      meta: metaParts.join(' - '),
      severity: severityLabel,
      color: severityColorFromPeopleCount(request.peopleNeedingHelp),
      people: request.peopleNeedingHelp,
      status: _rescueStatusLabel(request.status),
      rawStatus: request.status,
      hazardType: request.emergencyType,
      latitude: request.latitude,
      longitude: request.longitude,
      assignedTeamName: request.assignedTeamName,
      riskLevel: riskLevel,
      priorityRank: request.priorityRank,
    );
  }

  final String id;
  final IconData icon;
  final String title;
  final String location;
  final String meta;
  final String severity;
  final Color color;
  final int people;
  final String status;
  final RescueStatus rawStatus;
  final HazardType hazardType;
  final double? latitude;
  final double? longitude;
  final String? assignedTeamName;
  final String? riskLevel;
  final int? priorityRank;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.action,
    this.chip,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final String? chip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        if (action != null)
          Text(
            action!,
            style: const TextStyle(
              color: AppTheme.signalBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (chip != null)
          _SeverityPill(label: chip!, color: AppTheme.dangerRed),
      ],
    );
  }
}

/// Status a queue tab maps to. `null` means "All".
const Map<String, List<RescueStatus>?> _incidentTabStatuses = {
  'All': null,
  'Pending': [RescueStatus.pending],
  'Dispatched': [RescueStatus.acknowledged],
  'En Route': [RescueStatus.inProgress],
  'Done': [RescueStatus.resolved, RescueStatus.cancelled],
};

class _IncidentFilters extends StatelessWidget {
  const _IncidentFilters({
    required this.incidents,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final List<_Incident> incidents;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  int _countFor(List<RescueStatus>? statuses) {
    if (statuses == null) return incidents.length;
    return incidents.where((i) => statuses.contains(i.rawStatus)).length;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in _incidentTabStatuses.entries)
            _FilterChip(
              label: '${entry.key} (${_countFor(entry.value)})',
              selected: selectedFilter == entry.key,
              onTap: () => onFilterChanged(entry.key),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.signalBlue.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.signalBlue : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.signalBlue : AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _CompactIncidentTile extends StatelessWidget {
  const _CompactIncidentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.severityColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String severity;
  final Color severityColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _IconBubble(icon: icon, color: severityColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: _SeverityPill(label: severity, color: severityColor),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _SeverityPill extends StatelessWidget {
  const _SeverityPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BellBadge extends StatelessWidget {
  const _BellBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () {
            Navigator.of(context).pushNamed(AppRouter.alerts);
          },
          tooltip: 'View alerts',
          icon: const Icon(Icons.notifications, color: Colors.white),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: CircleAvatar(
            radius: 9,
            backgroundColor: AppTheme.dangerRed,
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({required this.peopleNeedingHelp});

  final int peopleNeedingHelp;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const _FilterChip(label: 'Overview', selected: true),
          const SizedBox(width: 8),
          _FilterChip(label: 'Victims ($peopleNeedingHelp)'),
          const SizedBox(width: 8),
          const _FilterChip(label: 'Updates'),
          const SizedBox(width: 8),
          const _FilterChip(label: 'Media'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: AppTheme.textMuted),
      title: Text(label, style: Theme.of(context).textTheme.labelMedium),
      trailing: Text(value, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: AppTheme.dangerRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          'Live',
          style: TextStyle(
            color: AppTheme.dangerRed,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MapLayerMenu extends StatelessWidget {
  const _MapLayerMenu({
    required this.showIncidents,
    required this.showTeams,
    required this.showShelters,
    required this.showHazardZones,
    required this.onToggleIncidents,
    required this.onToggleTeams,
    required this.onToggleShelters,
    required this.onToggleHazardZones,
  });

  final bool showIncidents;
  final bool showTeams;
  final bool showShelters;
  final bool showHazardZones;
  final VoidCallback onToggleIncidents;
  final VoidCallback onToggleTeams;
  final VoidCallback onToggleShelters;
  final VoidCallback onToggleHazardZones;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LayerButton(
          icon: Icons.crisis_alert,
          label: 'Incidents',
          color: AppTheme.dangerRed,
          active: showIncidents,
          onTap: onToggleIncidents,
        ),
        _LayerButton(
          icon: Icons.groups,
          label: 'Teams',
          color: AppTheme.signalBlue,
          active: showTeams,
          onTap: onToggleTeams,
        ),
        _LayerButton(
          icon: Icons.home,
          label: 'Shelters',
          color: AppTheme.signalBlue,
          active: showShelters,
          onTap: onToggleShelters,
        ),
        _LayerButton(
          icon: Icons.route,
          label: 'Hazard Zones',
          color: AppTheme.safeGreen,
          active: showHazardZones,
          onTap: onToggleHazardZones,
        ),
      ],
    );
  }
}

class _LayerButton extends StatelessWidget {
  const _LayerButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 112,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? color : AppTheme.textMuted, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? AppTheme.textPrimary : AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponderGpsBadge extends StatelessWidget {
  const _ResponderGpsBadge({required this.location, required this.isTracking});

  final GeoPoint? location;
  final bool isTracking;

  @override
  Widget build(BuildContext context) {
    final hasLocation = location != null;
    final title = hasLocation
        ? isTracking
              ? 'GPS live'
              : 'GPS locked'
        : 'GPS off';
    final subtitle = hasLocation
        ? '${location!.latitude.toStringAsFixed(4)}, ${location!.longitude.toStringAsFixed(4)}'
        : 'Tap locate';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasLocation ? Icons.gps_fixed : Icons.gps_off,
              color: hasLocation ? AppTheme.safeGreen : AppTheme.textMuted,
              size: 18,
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponderLocateButton extends StatelessWidget {
  const _ResponderLocateButton({
    required this.isLoading,
    required this.hasLocation,
    required this.onPressed,
  });

  final bool isLoading;
  final bool hasLocation;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        onPressed: isLoading ? null : onPressed,
        tooltip: hasLocation ? 'Recenter responder GPS' : 'Find responder GPS',
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                hasLocation ? Icons.gps_fixed : Icons.my_location,
                color: AppTheme.signalBlue,
              ),
      ),
    );
  }
}

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.hasLiveLocation,
    required this.isTracking,
    required this.onLocate,
  });

  final bool hasLiveLocation;
  final bool isTracking;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route Guidance',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color:
                    (hasLiveLocation ? AppTheme.safeGreen : AppTheme.signalBlue)
                        .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      (hasLiveLocation
                              ? AppTheme.safeGreen
                              : AppTheme.signalBlue)
                          .withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasLiveLocation ? Icons.gps_fixed : Icons.my_location,
                    color: hasLiveLocation
                        ? AppTheme.safeGreen
                        : AppTheme.signalBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasLiveLocation
                          ? isTracking
                                ? 'Your responder position is updating live.'
                                : 'Your responder position is shown on the map.'
                          : 'Tap locate so the map shows where you are.',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                Expanded(
                  child: Text(
                    hasLiveLocation
                        ? 'Responder position active'
                        : 'No route selected',
                  ),
                ),
                Text('—', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Expanded(
                  child: _MiniMetric(value: '—', label: 'Est. time'),
                ),
                const Expanded(
                  child: _MiniMetric(value: '—', label: 'Distance'),
                ),
                SizedBox(
                  width: 126,
                  child: SentryButton(
                    label: hasLiveLocation ? 'Recenter' : 'Locate',
                    icon: hasLiveLocation ? Icons.gps_fixed : Icons.my_location,
                    onPressed: onLocate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: _IconBubble(icon: icon, color: AppTheme.signalBlue),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _CommandCenterMarker extends StatelessWidget {
  const _CommandCenterMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppTheme.deepNavy,
          borderRadius: BorderRadius.circular(8),
          elevation: 3,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              'Base',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Material(
          color: AppTheme.deepNavy,
          shape: const CircleBorder(),
          elevation: 3,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.local_police,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponderLocationMarker extends StatelessWidget {
  const _ResponderLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppTheme.signalBlue,
          borderRadius: BorderRadius.circular(8),
          elevation: 3,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              'You',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.signalBlue.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: AppTheme.signalBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.signalBlue.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.navigation,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SosRequestMarker extends StatelessWidget {
  const _SosRequestMarker({required this.request});

  final RescueRequestModel request;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE53935);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          borderRadius: BorderRadius.circular(8),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Text(
              'SOS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: const Icon(
              Icons.person_pin_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShelterMarker extends StatelessWidget {
  const _ShelterMarker({required this.shelter});

  final EvacuationCenterModel shelter;

  @override
  Widget build(BuildContext context) {
    final isFull = shelter.availableSlots <= 0;
    final color = isFull ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          borderRadius: BorderRadius.circular(8),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Text(
              isFull ? 'FULL' : '${shelter.availableSlots}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 3,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.home_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResidentLocationMarker extends StatelessWidget {
  const _ResidentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppTheme.dangerRed,
          borderRadius: BorderRadius.circular(8),
          elevation: 3,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              'Resident',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Material(
          color: AppTheme.dangerRed,
          shape: const CircleBorder(),
          elevation: 3,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(
              Icons.person_pin_circle_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _TeamMemberMarker extends StatelessWidget {
  const _TeamMemberMarker({required this.member});

  final TeamMemberModel member;

  @override
  Widget build(BuildContext context) {
    final label = member.firstName.isNotEmpty ? member.firstName : 'Member';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppTheme.violet,
          borderRadius: BorderRadius.circular(8),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.violet.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppTheme.violet,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.violet.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ── SOS request bottom sheet ─────────────────────────────────────────────────

class _SosRequestSheet extends StatefulWidget {
  const _SosRequestSheet({
    required this.request,
    required this.shelters,
    required this.onShelterAssigned,
    required this.onNavigate,
  });

  final RescueRequestModel request;
  final List<EvacuationCenterModel> shelters;
  final Future<void> Function(String id, String name, String? address)
  onShelterAssigned;
  final VoidCallback onNavigate;

  @override
  State<_SosRequestSheet> createState() => _SosRequestSheetState();
}

class _SosRequestSheetState extends State<_SosRequestSheet> {
  bool _showPicker = false;
  bool _isAssigning = false;

  @override
  Widget build(BuildContext context) {
    if (_showPicker) {
      return _ShelterPickerView(
        shelters: widget.shelters,
        isAssigning: _isAssigning,
        onBack: () => setState(() => _showPicker = false),
        onSelect: (shelter) async {
          setState(() => _isAssigning = true);
          try {
            await widget.onShelterAssigned(
              shelter.id,
              shelter.name,
              shelter.address,
            );
          } finally {
            // Always reset regardless of how onShelterAssigned resolves —
            // it currently handles its own errors internally, but this
            // guards against a stuck spinner if that ever changes.
            if (mounted) setState(() => _isAssigning = false);
          }
        },
      );
    }

    final request = widget.request;
    final incident = _Incident.fromRescueRequest(request);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _IconBubble(icon: incident.icon, color: incident.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${request.peopleNeedingHelp} people · ${request.status.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _SeverityPill(label: incident.severity, color: incident.color),
            ],
          ),
          if (request.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              request.description,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (request.assignedShelterName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.safeGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.safeGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.home_rounded,
                    color: AppTheme.safeGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shelter: ${request.assignedShelterName}',
                      style: const TextStyle(
                        color: AppTheme.safeGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SentryButton(
                  label: 'Navigate',
                  icon: Icons.navigation,
                  backgroundColor: AppTheme.safeGreen,
                  onPressed: widget.onNavigate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SentryButton(
                  label: 'Assign Shelter',
                  icon: Icons.home_rounded,
                  onPressed: widget.shelters.isEmpty
                      ? null
                      : () => setState(() => _showPicker = true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShelterPickerView extends StatelessWidget {
  const _ShelterPickerView({
    required this.shelters,
    required this.isAssigning,
    required this.onBack,
    required this.onSelect,
  });

  final List<EvacuationCenterModel> shelters;
  final bool isAssigning;
  final VoidCallback onBack;
  final void Function(EvacuationCenterModel) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                'Assign Shelter',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isAssigning)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: shelters.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final shelter = shelters[i];
                  final isFull = shelter.availableSlots <= 0;
                  final color = isFull
                      ? const Color(0xFFE65100)
                      : const Color(0xFF2E7D32);
                  return ListTile(
                    leading: Icon(Icons.home_rounded, color: color),
                    title: Text(
                      shelter.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${shelter.address} · ${shelter.availableSlots} slots available',
                    ),
                    trailing: isFull
                        ? const Text(
                            'FULL',
                            style: TextStyle(
                              color: Color(0xFFE65100),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: isFull ? null : () => onSelect(shelter),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shelter info bottom sheet ─────────────────────────────────────────────────

class _ShelterInfoSheet extends StatelessWidget {
  const _ShelterInfoSheet({required this.shelter});

  final EvacuationCenterModel shelter;

  @override
  Widget build(BuildContext context) {
    final isFull = shelter.availableSlots <= 0;
    final color = isFull ? const Color(0xFFE65100) : const Color(0xFF2E7D32);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.home_rounded, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shelter.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      shelter.address,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ShelterStat(
                  label: 'Capacity',
                  value: '${shelter.capacity}',
                ),
              ),
              Expanded(
                child: _ShelterStat(
                  label: 'Occupied',
                  value: '${shelter.currentOccupancy}',
                ),
              ),
              Expanded(
                child: _ShelterStat(
                  label: 'Available',
                  value: '${shelter.availableSlots}',
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              shelter.status.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelterStat extends StatelessWidget {
  const _ShelterStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color ?? AppTheme.deepNavy,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF607895)),
        ),
      ],
    );
  }
}
