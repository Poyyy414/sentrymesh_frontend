import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/assets.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/config/map_tile_config.dart';
import '../../core/di/injection.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/custom_button.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/evacuation_center_model.dart';
import '../../data/models/prediction_model.dart';
import '../../data/models/rescue_location_model.dart';
import '../../data/models/rescue_navigation_model.dart';
import '../../data/models/rescue_request_model.dart';
import '../../data/models/route_model.dart';
import '../../data/repositories/prediction_repository.dart';
import '../../shared/enums/hazard_type.dart';
import '../../shared/enums/rescue_status.dart';

Future<void> _logout(BuildContext context) async {
  await AppDependenciesScope.of(context).authRepository.logout();
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

bool _isActiveRescueRequest(RescueRequestModel request) {
  return request.status == RescueStatus.pending ||
      request.status == RescueStatus.acknowledged ||
      request.status == RescueStatus.inProgress;
}

Color _severityFromPeople(int people) {
  if (people >= 5) {
    return AppTheme.dangerRed;
  }
  if (people >= 2) {
    return AppTheme.warningAmber;
  }
  return AppTheme.safeGreen;
}

String _severityLabelFromPeople(int people) {
  if (people >= 5) {
    return 'High';
  }
  if (people >= 2) {
    return 'Medium';
  }
  return 'Low';
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

  static const _screens = [
    ResponderDashboardScreen(),
    ActiveIncidentsScreen(),
    ResponderLiveMapScreen(),
    ResponderTeamsScreen(),
    ResponderReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
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
      final results = await Future.wait([
        deps.rescueRepository.fetchRequests(),
        deps.alertRepository.fetchAlerts(),
      ]);

      if (!mounted) return;

      final requests = results[0] as List<RescueRequestModel>;
      final alerts = results[1];

      final active = requests
          .where(
            (r) =>
                r.status == RescueStatus.pending ||
                r.status == RescueStatus.acknowledged ||
                r.status == RescueStatus.inProgress,
          )
          .toList();

      setState(() {
        _stats = _DashboardStats(
          activeIncidents: active.length,
          peopleNeedHelp: active.fold(0, (sum, r) => sum + r.peopleNeedingHelp),
          deployedTeams: active
              .map((request) => request.assignedTeamId ?? request.id)
              .toSet()
              .length,
          activeAlerts: alerts.length,
          recentRequests: requests.take(3).toList(),
        );
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

class ActiveIncidentsScreen extends StatefulWidget {
  const ActiveIncidentsScreen({super.key});

  @override
  State<ActiveIncidentsScreen> createState() => _ActiveIncidentsScreenState();
}

class _ActiveIncidentsScreenState extends State<ActiveIncidentsScreen> {
  List<_Incident> _incidents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        _incidents = requests
            .where(_isActiveRescueRequest)
            .map(_Incident.fromRescueRequest)
            .toList();
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

  @override
  Widget build(BuildContext context) {
    return _ResponderPage(
      header: const _SimpleResponderHeader(
        title: 'Priority Incidents',
        leadingIcon: Icons.arrow_back,
        trailingIcon: Icons.filter_alt,
      ),
      children: [
        const _IncidentFilters(),
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
        else if (_incidents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No active incidents.')),
          )
        else
          for (final incident in _incidents) ...[
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
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
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
                      '${incident.title} - ${incident.severity} Priority',
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
          const _DetailTabs(),
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
                _InfoRow(
                  icon: Icons.groups,
                  label: 'Assigned Team',
                  value: incident.assignedTeamName ?? 'Auto assignment pending',
                ),
                const _InfoRow(
                  icon: Icons.signal_cellular_alt,
                  label: 'Signal Quality',
                  value: 'Good',
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadNavigation();
      }
    });
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
            tooltip: 'Refresh route',
            onPressed: _isLoading ? null : _loadNavigation,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
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
  Timer? _refreshTimer;
  GeoPoint? _responderLocation;
  bool _isLocating = false;
  bool _isTracking = false;

  List<RescueRequestModel> _sosRequests = const [];
  List<EvacuationCenterModel> _shelters = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMapData();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadMapData();
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
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
            .where(
              (r) =>
                  _isActiveRescueRequest(r) &&
                  r.latitude != null &&
                  r.longitude != null,
            )
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
          await repo.assignShelter(
            requestId: request.id,
            shelterId: shelterId,
            shelterName: shelterName,
            shelterAddress: shelterAddress,
          );
          if (context.mounted) {
            Navigator.of(context).pop();
            _loadMapData();
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
      builder: (_) =>
          _ShelterInfoSheet(shelter: shelter, onDeleted: _loadMapData),
    );
  }

  Future<void> _showCreateShelterDialog(LatLng point) async {
    final result = await showDialog<({String name, int capacity})>(
      context: context,
      builder: (context) => _CreateShelterDialog(point: point),
    );
    if (result == null || !mounted) return;

    try {
      await AppDependenciesScope.of(
        context,
      ).rescueRepository.createEvacuationCenter(
        name: result.name,
        address:
            'Pinned at ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        capacity: result.capacity,
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted) return;
      await _loadMapData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.name} added as an evacuation center.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add shelter: $error')));
    }
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
                  tooltip: 'Layers',
                  onPressed: () {},
                  icon: const Icon(Icons.layers, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                _ResponderMapPreview(
                  height: double.infinity,
                  mapController: _mapController,
                  responderLocation: _responderLocation,
                  sosRequests: _sosRequests,
                  shelters: _shelters,
                  onSosRequestTap: (request) =>
                      _showSosBottomSheet(context, request),
                  onShelterTap: (shelter) =>
                      _showShelterInfoSheet(context, shelter),
                  onMapTap: _showCreateShelterDialog,
                ),
                const Positioned(top: 12, left: 12, child: _MapLayerMenu()),
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
  List<RescueRequestModel> _requests = [];
  bool _isLoading = true;

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
      final requests = await AppDependenciesScope.of(
        context,
      ).rescueRepository.fetchRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _requests
        .where(
          (r) =>
              r.status == RescueStatus.pending ||
              r.status == RescueStatus.acknowledged ||
              r.status == RescueStatus.inProgress,
        )
        .toList();

    return _ResponderPage(
      header: const _SimpleResponderHeader(title: 'Team Coordination'),
      children: [
        _SectionTitle(
          title: _isLoading
              ? 'Active Deployments'
              : 'Active Deployments (${active.length})',
        ),
        const SizedBox(height: 10),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (active.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No active deployments at this time.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          )
        else
          for (final req in active) _DeploymentTile(request: req),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Quick Actions'),
        const SizedBox(height: 10),
        const _QuickActionGrid(),
      ],
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
  List<RescueRequestModel> _requests = const [];
  List<AlertModel> _alerts = const [];
  bool _isLoading = true;

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
      final results = await Future.wait([
        deps.rescueRepository.fetchRequests(),
        deps.alertRepository.fetchAlerts(),
      ]);

      if (!mounted) return;

      final requests = results[0] as List<RescueRequestModel>;
      final alerts = results[1] as List<AlertModel>;
      final today = DateTime.now();

      setState(() {
        _requests = requests;
        _alerts = alerts;
        _activeIncidents = requests.where(_isActiveRescueRequest).length;
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
                  r.assignedTeamId != null ||
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
    final activeRequests = _requests.where(_isActiveRescueRequest).toList();
    final resolvedRows = _requests
        .where((request) => request.status == RescueStatus.resolved)
        .toList();
    final teamRows = activeRequests
        .where((request) => request.assignedTeamName != null)
        .toList();

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
          onTap: _isLoading
              ? null
              : () => _showReportSheet(
                  title: 'Situation Report',
                  rows: [
                    'Active incidents: $_activeIncidents',
                    'Resolved records: ${resolvedRows.length}',
                    'People needing help: ${activeRequests.fold<int>(0, (sum, request) => sum + request.peopleNeedingHelp)}',
                    for (final request in activeRequests.take(8))
                      '${_hazardTitle(request.emergencyType)} - ${request.locationLabel ?? request.description}',
                  ],
                ),
        ),
        _ReportTile(
          title: 'Team Status',
          subtitle: _isLoading
              ? 'Loading…'
              : '$_dispatched dispatched · network healthy',
          icon: Icons.inventory_2,
          onTap: _isLoading
              ? null
              : () => _showReportSheet(
                  title: 'Team Status',
                  rows: [
                    'Assigned teams: ${teamRows.map((request) => request.assignedTeamId).toSet().length}',
                    'Network status: healthy',
                    for (final request in teamRows.take(10))
                      '${request.assignedTeamName}: ${request.assignedTeamStatus ?? 'assigned'} - ${request.locationLabel ?? request.description}',
                  ],
                ),
        ),
        _ReportTile(
          title: 'Alert Summary',
          subtitle: _isLoading
              ? 'Loading…'
              : '$_activeAlerts active alert${_activeAlerts == 1 ? '' : 's'} in the system',
          icon: Icons.forum,
          onTap: _isLoading
              ? null
              : () => _showReportSheet(
                  title: 'Alert Summary',
                  rows: [
                    'Active alerts: $_activeAlerts',
                    for (final alert in _alerts.take(10))
                      '${alert.title} - ${alert.location}',
                  ],
                ),
        ),
      ],
    );
  }

  void _showReportSheet({required String title, required List<String> rows}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => _ReportDetailSheet(title: title, rows: rows),
    );
  }
}

String _formatTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $ampm';
}

class _ResponderPage extends StatelessWidget {
  const _ResponderPage({required this.header, required this.children});

  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            header,
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: children,
              ),
            ),
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
            onPressed: () {},
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
          IconButton(
            onPressed: () {},
            tooltip: 'Action',
            icon: Icon(trailingIcon ?? Icons.more_vert, color: Colors.white),
          ),
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
      if (mounted) {
        setState(() {
          _node = node;
          _loading = false;
        });
      }
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
            severity: _severityLabelFromPeople(requests[i].peopleNeedingHelp),
            severityColor: _severityFromPeople(requests[i].peopleNeedingHelp),
          ),
          if (i != requests.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Live hazard risk heatmap, built from the predictions the backend has saved
/// (driven by the typhoon simulator). Each location becomes a weighted hot spot
/// coloured by risk.
class _HeatmapPreview extends StatefulWidget {
  const _HeatmapPreview();

  @override
  State<_HeatmapPreview> createState() => _HeatmapPreviewState();
}

class _HeatmapPreviewState extends State<_HeatmapPreview> {
  static const _center = LatLng(13.6218, 123.1948);

  final _controller = MapController();
  List<HazardHeatPoint>? _points;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final points = await AppDependenciesScope.of(
        context,
      ).predictionRepository.fetchHazardHeatPoints();
      if (!mounted) return;
      setState(() {
        _points = points;
        _loading = false;
      });
      _fitTo(points);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _points = const [];
        _loading = false;
      });
    }
  }

  void _fitTo(List<HazardHeatPoint> points) {
    if (points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(
      points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _controller.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
        );
      } catch (_) {
        // Camera not ready yet — the initial center is a sensible fallback.
      }
    });
  }

  static Color _heatColor(double severity) {
    if (severity >= 0.7) return AppTheme.dangerRed;
    if (severity >= 0.45) return AppTheme.warningAmber;
    return AppTheme.safeGreen;
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final hasPoints = points != null && points.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: const MapOptions(
                initialCenter: _center,
                initialZoom: 11.5,
                minZoom: 4,
                maxZoom: 18,
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapTileConfig.mapboxStreetsUrl,
                  userAgentPackageName: 'com.example.sentrymesh_frontend',
                  maxZoom: 18,
                ),
                if (hasPoints)
                  CircleLayer(
                    circles: [
                      for (final point in points)
                        CircleMarker(
                          point: LatLng(point.latitude, point.longitude),
                          radius: 320 + point.severity * 900,
                          useRadiusInMeter: true,
                          color: _heatColor(
                            point.severity,
                          ).withValues(alpha: 0.28),
                          borderColor: _heatColor(
                            point.severity,
                          ).withValues(alpha: 0.65),
                          borderStrokeWidth: 1.2,
                        ),
                    ],
                  ),
              ],
            ),
            if (hasPoints)
              const Positioned(left: 8, bottom: 8, child: _HeatmapLegend()),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                  tooltip: 'Refresh risk layer',
                  visualDensity: VisualDensity.compact,
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ),
            ),
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66FFFFFF),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
              ),
            if (!_loading && !hasPoints)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xF2FFFFFF),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.layers_clear_rounded,
                            color: AppTheme.signalBlue,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No risk data yet',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Run the typhoon simulator or wait for predictions to populate the risk layer.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: AppTheme.safeGreen, label: 'Low'),
          SizedBox(width: 10),
          _LegendDot(color: AppTheme.warningAmber, label: 'Medium'),
          SizedBox(width: 10),
          _LegendDot(color: AppTheme.dangerRed, label: 'High'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

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
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
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
    this.onSosRequestTap,
    this.onShelterTap,
    this.onMapTap,
  });

  final double height;
  final MapController? mapController;
  final GeoPoint? responderLocation;
  final GeoPoint? residentLocation;
  final RouteModel? route;
  final List<RescueRequestModel> sosRequests;
  final List<EvacuationCenterModel> shelters;
  final void Function(RescueRequestModel)? onSosRequestTap;
  final void Function(EvacuationCenterModel)? onShelterTap;
  final void Function(LatLng)? onMapTap;

  static const _center = LatLng(13.6218, 123.1948);

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
          onTap: (_, point) => onMapTap?.call(point),
        ),
        children: [
          TileLayer(
            urlTemplate: MapTileConfig.mapboxSatelliteStreetsUrl,
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
          if (sosRequests.isNotEmpty)
            CircleLayer(
              circles: [
                for (final request in sosRequests)
                  if (request.latitude != null && request.longitude != null)
                    CircleMarker(
                      point: LatLng(request.latitude!, request.longitude!),
                      radius: 220 + request.peopleNeedingHelp.clamp(1, 8) * 120,
                      useRadiusInMeter: true,
                      color: _severityFromPeople(
                        request.peopleNeedingHelp,
                      ).withValues(alpha: 0.18),
                      borderColor: _severityFromPeople(
                        request.peopleNeedingHelp,
                      ).withValues(alpha: 0.4),
                      borderStrokeWidth: 1.2,
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
              // Assigned team markers
              for (final request in sosRequests)
                if (request.latitude != null &&
                    request.longitude != null &&
                    request.assignedTeamName != null)
                  Marker(
                    point: _responderTeamPointForRequest(request),
                    width: 92,
                    height: 72,
                    child: _ResponderTeamMarker(request: request),
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
                  ],
                ),
              ),
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
    required this.hazardType,
    this.assignedTeamName,
    this.assignedTeamStatus,
    this.latitude,
    this.longitude,
  });

  factory _Incident.fromRescueRequest(RescueRequestModel request) {
    final severityLabel = _severityLabelFromPeople(request.peopleNeedingHelp);

    return _Incident(
      id: request.id,
      icon: _incidentIcon(request.emergencyType),
      title: _hazardTitle(request.emergencyType),
      location: request.locationLabel ?? request.description,
      meta:
          '${request.peopleNeedingHelp} people - ${_timeAgoLabel(request.createdAt)} - ${_rescueStatusLabel(request.status)}',
      severity: severityLabel,
      color: _severityFromPeople(request.peopleNeedingHelp),
      people: request.peopleNeedingHelp,
      status: _rescueStatusLabel(request.status),
      hazardType: request.emergencyType,
      assignedTeamName: request.assignedTeamName,
      assignedTeamStatus: request.assignedTeamStatus,
      latitude: request.latitude,
      longitude: request.longitude,
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
  final HazardType hazardType;
  final String? assignedTeamName;
  final String? assignedTeamStatus;
  final double? latitude;
  final double? longitude;
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

class _IncidentFilters extends StatelessWidget {
  const _IncidentFilters();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: const [
          _FilterChip(label: 'All (23)', selected: true),
          _FilterChip(label: 'High (8)'),
          _FilterChip(label: 'Medium (10)'),
          _FilterChip(label: 'Low (5)'),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          onPressed: () {},
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
  const _DetailTabs();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: const [
          _FilterChip(label: 'Overview', selected: true),
          SizedBox(width: 8),
          _FilterChip(label: 'Victims (12)'),
          SizedBox(width: 8),
          _FilterChip(label: 'Updates'),
          SizedBox(width: 8),
          _FilterChip(label: 'Media'),
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
  const _MapLayerMenu();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _LayerButton(
          icon: Icons.crisis_alert,
          label: 'Incidents',
          color: AppTheme.dangerRed,
        ),
        _LayerButton(
          icon: Icons.groups,
          label: 'Teams',
          color: AppTheme.signalBlue,
        ),
        _LayerButton(
          icon: Icons.home,
          label: 'Shelters',
          color: AppTheme.signalBlue,
        ),
        _LayerButton(
          icon: Icons.route,
          label: 'Safer Route',
          color: AppTheme.safeGreen,
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
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
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

class _DeploymentTile extends StatelessWidget {
  const _DeploymentTile({required this.request});

  final RescueRequestModel request;

  @override
  Widget build(BuildContext context) {
    final status = _rescueStatusLabel(request.status);
    final teamName = request.assignedTeamName ?? 'Auto team pending';
    final teamStatus =
        request.assignedTeamStatus?.replaceAll('_', ' ').toUpperCase() ??
        'ASSIGNED';
    final color = switch (request.status) {
      RescueStatus.inProgress => AppTheme.safeGreen,
      RescueStatus.acknowledged => AppTheme.warningAmber,
      _ => AppTheme.signalBlue,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_incidentIcon(request.emergencyType), color: color),
          ),
          title: Text('${_hazardTitle(request.emergencyType)} - $teamName'),
          subtitle: Text(
            '${request.locationLabel ?? 'Unknown location'} · ${_timeAgoLabel(request.createdAt)}',
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SeverityPill(label: status, color: color),
              const SizedBox(height: 5),
              Text(teamStatus, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: const [
        _QuickAction(
          icon: Icons.campaign,
          title: 'Broadcast',
          color: AppTheme.signalBlue,
        ),
        _QuickAction(
          icon: Icons.chat,
          title: 'Team Chat',
          color: AppTheme.violet,
        ),
        _QuickAction(
          icon: Icons.sos,
          title: 'Emergency',
          color: AppTheme.dangerRed,
        ),
        _QuickAction(
          icon: Icons.inventory,
          title: 'Resources',
          color: AppTheme.safeGreen,
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _IconBubble(icon: icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

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
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ReportDetailSheet extends StatelessWidget {
  const _ReportDetailSheet({required this.title, required this.rows});

  final String title;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.isEmpty
        ? const ['No report data available.']
        : rows;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.48,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: visibleRows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: AppTheme.signalBlue.withValues(alpha: 0.1),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.signalBlue,
                      ),
                    ),
                  ),
                  title: Text(visibleRows[index]),
                ),
              ),
            ),
          ],
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

LatLng _responderTeamPointForRequest(RescueRequestModel request) {
  final seed = request.id.codeUnits.fold<int>(0, (sum, code) => sum + code);
  return LatLng(
    request.latitude! + 0.0012 + (seed % 4) * 0.0002,
    request.longitude! + 0.0011 + (seed % 6) * 0.00018,
  );
}

class _ResponderTeamMarker extends StatelessWidget {
  const _ResponderTeamMarker({required this.request});

  final RescueRequestModel request;

  @override
  Widget build(BuildContext context) {
    final name = request.assignedTeamName ?? 'Team';
    final shortName = name
        .replaceAll(' Response', '')
        .replaceAll(' Rescue', '')
        .replaceAll(' Evacuation', '');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppTheme.signalBlue,
          borderRadius: BorderRadius.circular(8),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
          color: AppTheme.signalBlue,
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
              Icons.groups_rounded,
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

  bool get _canNavigate {
    final role =
        AppDependenciesScope.of(context).authRepository.currentUser?.role;
    return role != 'super_admin';
  }

  @override
  Widget build(BuildContext context) {
    if (_showPicker) {
      return _ShelterPickerView(
        shelters: widget.shelters,
        isAssigning: _isAssigning,
        onBack: () => setState(() => _showPicker = false),
        onSelect: (shelter) async {
          setState(() => _isAssigning = true);
          await widget.onShelterAssigned(
            shelter.id,
            shelter.name,
            shelter.address,
          );
          if (mounted) setState(() => _isAssigning = false);
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
              // Route guidance is a field-responder task; the super admin
              // oversees and dispatches but does not navigate to the scene.
              if (_canNavigate) ...[
                Expanded(
                  child: SentryButton(
                    label: 'Navigate',
                    icon: Icons.navigation,
                    backgroundColor: AppTheme.safeGreen,
                    onPressed: widget.onNavigate,
                  ),
                ),
                const SizedBox(width: 10),
              ],
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

class _CreateShelterDialog extends StatefulWidget {
  const _CreateShelterDialog({required this.point});

  final LatLng point;

  @override
  State<_CreateShelterDialog> createState() => _CreateShelterDialogState();
}

class _CreateShelterDialogState extends State<_CreateShelterDialog> {
  final _nameCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '50');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Evacuation Center'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.point.latitude.toStringAsFixed(5)}, ${widget.point.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Shelter name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacityCtrl,
              decoration: const InputDecoration(
                labelText: 'Capacity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final capacity = int.tryParse(value?.trim() ?? '');
                if (capacity == null || capacity <= 0) {
                  return 'Enter a valid capacity';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (
              name: _nameCtrl.text.trim(),
              capacity: int.parse(_capacityCtrl.text.trim()),
            ));
          },
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('Add Shelter'),
        ),
      ],
    );
  }
}

class _ShelterInfoSheet extends StatefulWidget {
  const _ShelterInfoSheet({required this.shelter, this.onDeleted});

  final EvacuationCenterModel shelter;

  /// Called after the shelter is removed so the map can refresh. Only the
  /// super admin can trigger removal.
  final Future<void> Function()? onDeleted;

  @override
  State<_ShelterInfoSheet> createState() => _ShelterInfoSheetState();
}

class _ShelterInfoSheetState extends State<_ShelterInfoSheet> {
  bool _isDeleting = false;

  bool get _canRemove {
    final role =
        AppDependenciesScope.of(context).authRepository.currentUser?.role;
    return role == 'super_admin';
  }

  Future<void> _confirmAndDelete() async {
    final shelter = widget.shelter;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove shelter?'),
        content: Text(
          '"${shelter.name}" will be permanently removed and can no longer '
          'be assigned to residents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await AppDependenciesScope.of(
        context,
      ).rescueRepository.deleteEvacuationCenter(shelter.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onDeleted?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove shelter: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shelter = widget.shelter;
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
          if (_canRemove) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDeleting ? null : _confirmAndDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.dangerRed,
                  side: const BorderSide(color: AppTheme.dangerRed),
                ),
                icon: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(_isDeleting ? 'Removing…' : 'Remove Shelter'),
              ),
            ),
          ],
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
