import 'dart:async';
import 'dart:ui' as ui;

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
import '../../shared/demo/demo_scenario.dart';

Future<void> _logout(BuildContext context) async {
  await AppDependenciesScope.of(context).authRepository.logout();
  if (!context.mounted) {
    return;
  }

  Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
}

IconData _incidentIcon(DemoIncidentType type) {
  return switch (type) {
    DemoIncidentType.flood => Icons.flood,
    DemoIncidentType.landslide => Icons.warning_amber_rounded,
    DemoIncidentType.trapped => Icons.personal_injury,
    DemoIncidentType.roadBlocked => Icons.car_crash,
    DemoIncidentType.sos => Icons.sos,
  };
}

Color _severityColor(String severity) {
  return switch (severity) {
    'High' => AppTheme.dangerRed,
    'Medium' => AppTheme.warningAmber,
    'Low' => AppTheme.safeGreen,
    _ => AppTheme.signalBlue,
  };
}

String _statusLabel(DemoIncidentStatus status) {
  return switch (status) {
    DemoIncidentStatus.active => 'Active',
    DemoIncidentStatus.dispatched => 'Dispatched',
    DemoIncidentStatus.enRoute => 'En Route',
    DemoIncidentStatus.resolved => 'Resolved',
  };
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

class ResponderDashboardScreen extends StatelessWidget {
  const ResponderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ResponderPage(
      header: _ResponderHeader(
        title: 'Responder Console',
        trailing: _BellBadge(count: 3),
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
                    'Naga City Response Team',
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
        const _ResponderStatusBanner(),
        const SizedBox(height: 14),
        const _SectionTitle(
          title: 'Situation Overview',
          subtitle: 'Updated 9:41 AM',
        ),
        const SizedBox(height: 10),
        const _ResponderStatsGrid(),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Live Risk Map', chip: 'High'),
        const SizedBox(height: 10),
        const _HeatmapPreview(),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Recent Incidents', action: 'View all'),
        const SizedBox(height: 10),
        const _RecentIncidentsList(),
      ],
    );
  }
}

class ActiveIncidentsScreen extends StatelessWidget {
  const ActiveIncidentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DemoScenario.instance,
      builder: (context, _) {
        final incidents = DemoScenario.instance.incidents
            .map(_Incident.fromDemo)
            .toList();

        return _ResponderPage(
          header: const _SimpleResponderHeader(
            title: 'Priority Incidents',
            leadingIcon: Icons.arrow_back,
            trailingIcon: Icons.filter_alt,
          ),
          children: [
            const _IncidentFilters(),
            const SizedBox(height: 12),
            for (final incident in incidents) ...[
              _IncidentCard(incident: incident),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class ResponderIncidentDetailScreen extends StatelessWidget {
  const ResponderIncidentDetailScreen({required this.incident, super.key});

  final _Incident incident;

  @override
  Widget build(BuildContext context) {
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
          const _ResponderMapPreview(height: 170),
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
                const _InfoRow(
                  icon: Icons.signal_cellular_alt,
                  label: 'Signal Quality',
                  value: 'Good',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _AiReasoningCard(),
          const SizedBox(height: 16),
          Text('Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SentryButton(
            label: 'Dispatch Team',
            icon: Icons.airport_shuttle,
            onPressed: () {
              DemoScenario.instance.dispatchTeam(incident.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Team dispatched to ${incident.location}.'),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          SentryButton(
            label: 'Navigate to Location',
            icon: Icons.navigation,
            backgroundColor: AppTheme.safeGreen,
            onPressed: () {
              DemoScenario.instance.markEnRoute(incident.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Safe route opened for the response team.'),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              DemoScenario.instance.markEnRoute(incident.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Incident marked as on-route.')),
              );
            },
            icon: const Icon(Icons.flag),
            label: const Text('Mark as On-Route'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              DemoScenario.instance.resolveIncident(incident.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Incident marked resolved.')),
              );
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

class ResponderLiveMapScreen extends StatefulWidget {
  const ResponderLiveMapScreen({super.key});

  @override
  State<ResponderLiveMapScreen> createState() => _ResponderLiveMapScreenState();
}

class _ResponderLiveMapScreenState extends State<ResponderLiveMapScreen> {
  final _mapController = MapController();

  StreamSubscription<GeoPoint>? _locationSubscription;
  GeoPoint? _responderLocation;
  bool _isLocating = false;
  bool _isTracking = false;

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
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

class ResponderTeamsScreen extends StatelessWidget {
  const ResponderTeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ResponderPage(
      header: const _SimpleResponderHeader(title: 'Team Coordination'),
      children: const [
        _SegmentedHeader(left: 'Teams', right: 'Messages', badge: '2'),
        SizedBox(height: 18),
        _SectionTitle(title: 'Deployed Teams (8)', action: 'View all'),
        SizedBox(height: 10),
        _TeamTile(
          name: 'Team Alpha',
          area: 'San Felipe - 12 min ago',
          status: 'On Mission',
          members: 4,
        ),
        _TeamTile(
          name: 'Team Bravo',
          area: 'Concepcion - 18 min ago',
          status: 'On Mission',
          members: 4,
        ),
        _TeamTile(
          name: 'Team Charlie',
          area: 'Pacol - 5 min ago',
          status: 'En Route',
          members: 3,
        ),
        _TeamTile(
          name: 'Team Delta',
          area: 'Command Center',
          status: 'Standby',
          members: 5,
        ),
        SizedBox(height: 18),
        _SectionTitle(title: 'Quick Actions'),
        SizedBox(height: 10),
        _QuickActionGrid(),
      ],
    );
  }
}

class ResponderReportsScreen extends StatelessWidget {
  const ResponderReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ResponderPage(
      header: const _SimpleResponderHeader(title: 'Reports'),
      children: const [
        _SectionTitle(
          title: 'Response Reports',
          subtitle: 'Brief updates for the team',
        ),
        SizedBox(height: 12),
        _ReportTile(
          title: 'Situation Report',
          subtitle: '23 active incidents - 9:41 AM',
          icon: Icons.summarize,
        ),
        _ReportTile(
          title: 'Team Status',
          subtitle: '8 teams deployed - network healthy',
          icon: Icons.inventory_2,
        ),
        _ReportTile(
          title: 'Message History',
          subtitle: 'Advisories and team updates',
          icon: Icons.forum,
        ),
      ],
    );
  }
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

class _ResponderStatusBanner extends StatelessWidget {
  const _ResponderStatusBanner();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DemoScenario.instance,
      builder: (context, _) {
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
                        DemoScenario.instance.lastResponderAction,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const _SeverityPill(label: 'Live', color: AppTheme.safeGreen),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AiReasoningCard extends StatelessWidget {
  const _AiReasoningCard();

  @override
  Widget build(BuildContext context) {
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
                    'Flood Forecast Priority',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const _SeverityPill(
                  label: 'High Priority',
                  color: AppTheme.dangerRed,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _ReasonLine(
              label: 'Arrival',
              value: 'Floodwater may reach San Felipe in about 45 min',
            ),
            const _ReasonLine(
              label: 'Peak',
              value: 'Water may rise up to 1.4 m in low-lying streets',
            ),
            const _ReasonLine(
              label: 'Warning',
              value: 'Flash flood risk is elevated for the next hour',
            ),
            const _ReasonLine(
              label: 'Action',
              value: 'Dispatch before the main access road becomes unsafe',
            ),
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

class _ResponderStatsGrid extends StatelessWidget {
  const _ResponderStatsGrid();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DemoScenario.instance,
      builder: (context, _) {
        final scenario = DemoScenario.instance;

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
              value: '${scenario.activeIncidentCount}',
              label: 'Active Incidents',
              color: AppTheme.dangerRed,
            ),
            _StatTile(
              icon: Icons.personal_injury,
              value: '${scenario.peopleNeedHelp}',
              label: 'People Need Help',
              color: AppTheme.warningAmber,
            ),
            _StatTile(
              icon: Icons.groups,
              value: '${scenario.deployedTeams}',
              label: 'Teams Deployed',
              color: AppTheme.signalBlue,
            ),
            const _StatTile(
              icon: Icons.shield,
              value: '92%',
              label: 'Signal Health',
              color: AppTheme.safeGreen,
            ),
          ],
        );
      },
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

class _RecentIncidentsList extends StatelessWidget {
  const _RecentIncidentsList();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DemoScenario.instance,
      builder: (context, _) {
        final incidents = DemoScenario.instance.incidents.take(3).toList();

        return Column(
          children: [
            for (var index = 0; index < incidents.length; index++) ...[
              _CompactIncidentTile(
                icon: _incidentIcon(incidents[index].type),
                title:
                    '${incidents[index].title} - ${incidents[index].location}',
                subtitle:
                    '${incidents[index].timeLabel} - ${incidents[index].people} people - ${_statusLabel(incidents[index].status)}',
                severity: incidents[index].severity,
                severityColor: _severityColor(incidents[index].severity),
              ),
              if (index != incidents.length - 1) const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _HeatmapPreview extends StatelessWidget {
  const _HeatmapPreview();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A3A35), Color(0xFF163F5A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _HeatmapPainter())),
          const Positioned(left: 28, top: 38, child: _MapLabel('San Felipe')),
          const Positioned(right: 26, top: 44, child: _MapLabel('Concepcion')),
          const Positioned(right: 50, bottom: 28, child: _MapLabel('Pacol')),
          const Positioned(
            left: 16,
            top: 18,
            child: _HeatSpot(size: 74, color: AppTheme.warningAmber),
          ),
          const Positioned(
            left: 42,
            bottom: 28,
            child: _HeatSpot(size: 48, color: AppTheme.dangerRed),
          ),
          const Positioned(
            left: 92,
            top: 56,
            child: _HeatSpot(size: 64, color: AppTheme.warningAmber),
          ),
          const Positioned(
            right: 76,
            top: 46,
            child: _HeatSpot(size: 52, color: AppTheme.dangerRed),
          ),
          const Positioned(
            right: 20,
            bottom: 20,
            child: _HeatSpot(size: 62, color: AppTheme.warningAmber),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'dashboard-location',
              onPressed: () {},
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.signalBlue,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  const _HeatmapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final routePaint = Paint()
      ..color = AppTheme.safeGreen.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final riverPaint = Paint()
      ..color = AppTheme.signalBlue.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final river = ui.Path()
      ..moveTo(size.width * 0.05, size.height * 0.2)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.05,
        size.width * 0.34,
        size.height * 0.72,
        size.width * 0.52,
        size.height * 0.55,
      )
      ..cubicTo(
        size.width * 0.7,
        size.height * 0.38,
        size.width * 0.76,
        size.height * 0.88,
        size.width * 0.95,
        size.height * 0.64,
      );
    canvas.drawPath(river, riverPaint);

    for (final y in [0.28, 0.48, 0.68]) {
      final road = ui.Path()
        ..moveTo(size.width * 0.04, size.height * y)
        ..quadraticBezierTo(
          size.width * 0.42,
          size.height * (y - 0.08),
          size.width * 0.96,
          size.height * (y + 0.04),
        );
      canvas.drawPath(road, roadPaint);
    }

    final route = ui.Path()
      ..moveTo(size.width * 0.12, size.height * 0.78)
      ..lineTo(size.width * 0.28, size.height * 0.66)
      ..lineTo(size.width * 0.38, size.height * 0.5)
      ..lineTo(size.width * 0.55, size.height * 0.46)
      ..lineTo(size.width * 0.68, size.height * 0.32)
      ..lineTo(size.width * 0.86, size.height * 0.26);
    canvas.drawPath(route, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResponderMapPreview extends StatelessWidget {
  const _ResponderMapPreview({
    required this.height,
    this.mapController,
    this.responderLocation,
  });

  final double height;
  final MapController? mapController;
  final GeoPoint? responderLocation;

  static const _center = LatLng(13.6218, 123.1948);

  @override
  Widget build(BuildContext context) {
    final responderPoint = responderLocation == null
        ? null
        : LatLng(responderLocation!.latitude, responderLocation!.longitude);
    final routePoints = const <LatLng>[
      LatLng(13.590, 123.175),
      LatLng(13.598, 123.184),
      LatLng(13.606, 123.187),
      LatLng(13.612, 123.198),
      LatLng(13.6218, 123.1948),
      LatLng(13.628, 123.204),
      LatLng(13.636, 123.210),
      LatLng(13.642, 123.224),
      LatLng(13.652, 123.220),
    ];

    return SizedBox(
      height: height,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: responderPoint ?? _center,
          initialZoom: responderPoint == null ? 12.4 : 15,
          minZoom: 4,
          maxZoom: 18,
          interactionOptions: const InteractionOptions(),
        ),
        children: [
          TileLayer(
            urlTemplate: MapTileConfig.mapboxSatelliteStreetsUrl,
            userAgentPackageName: 'com.example.sentrymesh_frontend',
          ),
          PolygonLayer(
            polygons: [
              Polygon(
                points: const [
                  LatLng(13.640, 123.165),
                  LatLng(13.628, 123.198),
                  LatLng(13.650, 123.230),
                  LatLng(13.675, 123.205),
                ],
                color: AppTheme.dangerRed.withValues(alpha: 0.26),
                borderColor: AppTheme.dangerRed,
                borderStrokeWidth: 2,
              ),
              Polygon(
                points: const [
                  LatLng(13.595, 123.205),
                  LatLng(13.580, 123.238),
                  LatLng(13.608, 123.260),
                  LatLng(13.630, 123.228),
                ],
                color: AppTheme.dangerRed.withValues(alpha: 0.22),
                borderColor: AppTheme.dangerRed,
                borderStrokeWidth: 2,
              ),
              Polygon(
                points: const [
                  LatLng(13.615, 123.150),
                  LatLng(13.602, 123.176),
                  LatLng(13.626, 123.188),
                  LatLng(13.642, 123.170),
                ],
                color: AppTheme.warningAmber.withValues(alpha: 0.18),
                borderColor: AppTheme.warningAmber.withValues(alpha: 0.72),
                borderStrokeWidth: 2,
              ),
            ],
          ),
          CircleLayer(
            circles: [
              CircleMarker(
                point: const LatLng(13.650, 123.202),
                radius: 82,
                color: AppTheme.dangerRed.withValues(alpha: 0.12),
                borderColor: AppTheme.dangerRed.withValues(alpha: 0.25),
                borderStrokeWidth: 1,
                useRadiusInMeter: false,
              ),
              CircleMarker(
                point: const LatLng(13.610, 123.230),
                radius: 68,
                color: AppTheme.warningAmber.withValues(alpha: 0.14),
                borderColor: AppTheme.warningAmber.withValues(alpha: 0.28),
                borderStrokeWidth: 1,
                useRadiusInMeter: false,
              ),
            ],
          ),
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
          MarkerLayer(
            markers: [
              if (responderPoint == null)
                const Marker(
                  point: _center,
                  width: 84,
                  height: 58,
                  child: _CommandCenterMarker(),
                )
              else
                Marker(
                  point: responderPoint,
                  width: 84,
                  height: 68,
                  child: const _ResponderLocationMarker(),
                ),
              const Marker(
                point: LatLng(13.652, 123.220),
                width: 42,
                height: 42,
                child: _IncidentMarker(icon: Icons.personal_injury),
              ),
              Marker(
                point: LatLng(13.611, 123.238),
                width: 42,
                height: 42,
                child: _IncidentMarker(icon: Icons.flood),
              ),
              Marker(
                point: LatLng(13.590, 123.175),
                width: 40,
                height: 40,
                child: _EvacMarker(),
              ),
              Marker(
                point: LatLng(13.640, 123.160),
                width: 40,
                height: 40,
                child: _EvacMarker(),
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

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});

  final _Incident incident;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: incident.color.withValues(alpha: 0.07),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ResponderIncidentDetailScreen(incident: incident),
            ),
          );
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
  });

  factory _Incident.fromDemo(DemoIncident incident) {
    return _Incident(
      id: incident.id,
      icon: _incidentIcon(incident.type),
      title: incident.title,
      location: incident.location,
      meta:
          '${incident.people} people - ${incident.timeLabel} - ${_statusLabel(incident.status)}',
      severity: incident.severity,
      color: _severityColor(incident.severity),
      people: incident.people,
      status: _statusLabel(incident.status),
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

class _HeatSpot extends StatelessWidget {
  const _HeatSpot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.9),
            AppTheme.warningAmber.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        shadows: [Shadow(blurRadius: 4)],
      ),
    );
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _FilterChip(label: 'Overview', selected: true),
        _FilterChip(label: 'Victims (12)'),
        _FilterChip(label: 'Updates'),
        _FilterChip(label: 'Media'),
      ],
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
                const Expanded(child: Text('San Felipe response area')),
                Text('4.2 km', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Expanded(
                  child: _MiniMetric(value: '12 min', label: 'Est. time'),
                ),
                const Expanded(
                  child: _MiniMetric(value: 'Low', label: 'Traffic'),
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

class _SegmentedHeader extends StatelessWidget {
  const _SegmentedHeader({
    required this.left,
    required this.right,
    required this.badge,
  });

  final String left;
  final String right;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.signalBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                left,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  right,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AppTheme.dangerRed,
                  child: Text(
                    badge,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
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

class _TeamTile extends StatelessWidget {
  const _TeamTile({
    required this.name,
    required this.area,
    required this.status,
    required this.members,
  });

  final String name;
  final String area;
  final String status;
  final int members;

  @override
  Widget build(BuildContext context) {
    final active = status == 'On Mission';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (active ? AppTheme.safeGreen : AppTheme.signalBlue)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              active ? Icons.person_pin_circle : Icons.engineering,
              color: active ? AppTheme.safeGreen : AppTheme.signalBlue,
            ),
          ),
          title: Text(name),
          subtitle: Text(area),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SeverityPill(
                label: status,
                color: active ? AppTheme.safeGreen : AppTheme.signalBlue,
              ),
              const SizedBox(height: 5),
              Text('$members', style: Theme.of(context).textTheme.labelSmall),
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

class _IncidentMarker extends StatelessWidget {
  const _IncidentMarker({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.dangerRed,
      shape: const CircleBorder(),
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _EvacMarker extends StatelessWidget {
  const _EvacMarker();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.signalBlue,
      shape: const CircleBorder(),
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.home, color: Colors.white, size: 20),
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
