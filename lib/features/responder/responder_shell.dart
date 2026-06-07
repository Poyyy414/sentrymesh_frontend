import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/widgets/custom_button.dart';

Future<void> _logout(BuildContext context) async {
  await AppDependenciesScope.of(context).authRepository.logout();
  if (!context.mounted) {
    return;
  }

  Navigator.of(context).pushNamedAndRemoveUntil(
    AppRouter.login,
    (_) => false,
  );
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
        title: 'SentryMesh Responder',
        trailing: _BellBadge(count: 3),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white,
              child: Icon(Icons.engineering, color: AppTheme.navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, Responder Team',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Naga City Command Center',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white70,
                        ),
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
                        'Online',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      children: const [
        _SectionTitle(title: 'Situation Overview', subtitle: 'Today, June 1 - 9:41 AM'),
        SizedBox(height: 10),
        _ResponderStatsGrid(),
        SizedBox(height: 18),
        _SectionTitle(title: 'Severity Heatmap (Live)', chip: 'High'),
        SizedBox(height: 10),
        _HeatmapPreview(),
        SizedBox(height: 18),
        _SectionTitle(title: 'Recent Incidents', action: 'View all'),
        SizedBox(height: 10),
        _CompactIncidentTile(
          icon: Icons.flood,
          title: 'Flooding - San Felipe',
          subtitle: '15 min ago - 12 people',
          severity: 'High',
          severityColor: AppTheme.dangerRed,
        ),
        SizedBox(height: 8),
        _CompactIncidentTile(
          icon: Icons.warning_amber_rounded,
          title: 'Landslide - Concepcion Pequena',
          subtitle: '35 min ago - 7 people',
          severity: 'Medium',
          severityColor: AppTheme.warningAmber,
        ),
      ],
    );
  }
}

class ActiveIncidentsScreen extends StatelessWidget {
  const ActiveIncidentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final incidents = [
      _Incident(
        icon: Icons.flood,
        title: 'Flooding',
        location: 'San Felipe, Naga City',
        meta: '12 people - 15 min ago',
        severity: 'High',
        color: AppTheme.dangerRed,
      ),
      _Incident(
        icon: Icons.warning_amber_rounded,
        title: 'Landslide',
        location: 'Concepcion Pequena',
        meta: '7 people - 35 min ago',
        severity: 'Medium',
        color: AppTheme.warningAmber,
      ),
      _Incident(
        icon: Icons.personal_injury,
        title: 'Trapped Individuals',
        location: 'Pacol, Naga City',
        meta: '3 people - 45 min ago',
        severity: 'High',
        color: AppTheme.dangerRed,
      ),
      _Incident(
        icon: Icons.water_drop,
        title: 'Flooding',
        location: 'Tambo, Naga City',
        meta: '5 people - 1 hr ago',
        severity: 'Medium',
        color: AppTheme.warningAmber,
      ),
      _Incident(
        icon: Icons.car_crash,
        title: 'Road Blocked',
        location: 'Cararayan, Naga City',
        meta: 'Reported 2 hrs ago',
        severity: 'Low',
        color: AppTheme.safeGreen,
      ),
    ];

    return _ResponderPage(
      header: const _SimpleResponderHeader(
        title: 'Active Incidents',
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
                      '${incident.title} - ${incident.severity} Severity',
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
              children: const [
                _InfoRow(icon: Icons.person, label: 'Reported by', value: 'Community User'),
                _InfoRow(icon: Icons.groups, label: 'People Need Help', value: '12'),
                _InfoRow(icon: Icons.schedule, label: 'Status', value: 'Active'),
                _InfoRow(icon: Icons.signal_cellular_alt, label: 'Signal Strength', value: 'Good'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SentryButton(
            label: 'Dispatch Team',
            icon: Icons.airport_shuttle,
            onPressed: () {},
          ),
          const SizedBox(height: 10),
          SentryButton(
            label: 'Navigate to Location',
            icon: Icons.navigation,
            backgroundColor: AppTheme.safeGreen,
            onPressed: () {},
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.flag),
            label: const Text('Mark as On-Route'),
          ),
        ],
      ),
    );
  }
}

class ResponderLiveMapScreen extends StatelessWidget {
  const ResponderLiveMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            height: 60,
            color: AppTheme.navy,
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
              children: const [
                _ResponderMapPreview(height: double.infinity),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _MapLayerMenu(),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _NavigationPanel(),
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
      header: const _SimpleResponderHeader(title: 'Teams & Communication'),
      children: const [
        _SegmentedHeader(left: 'Teams', right: 'Messages', badge: '2'),
        SizedBox(height: 18),
        _SectionTitle(title: 'Deployed Teams (8)', action: 'View all'),
        SizedBox(height: 10),
        _TeamTile(name: 'Team Alpha', area: 'San Felipe - 12 min ago', status: 'On Mission', members: 4),
        _TeamTile(name: 'Team Bravo', area: 'Concepcion - 18 min ago', status: 'On Mission', members: 4),
        _TeamTile(name: 'Team Charlie', area: 'Pacol - 5 min ago', status: 'En Route', members: 3),
        _TeamTile(name: 'Team Delta', area: 'Command Center', status: 'Standby', members: 5),
        SizedBox(height: 18),
        _SectionTitle(title: 'Quick Communication'),
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
        _SectionTitle(title: 'Operational Reports', subtitle: 'Responder logs and field summaries'),
        SizedBox(height: 12),
        _ReportTile(title: 'Situation Report', subtitle: '23 active incidents - 9:41 AM', icon: Icons.summarize),
        _ReportTile(title: 'Resource Status', subtitle: '8 teams deployed - 92% network status', icon: Icons.inventory_2),
        _ReportTile(title: 'Communication Log', subtitle: 'Responder advisories and team updates', icon: Icons.forum),
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
      color: AppTheme.navy,
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
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
      color: AppTheme.navy,
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

class _ResponderStatsGrid extends StatelessWidget {
  const _ResponderStatsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.25,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: const [
        _StatTile(icon: Icons.crisis_alert, value: '23', label: 'Active Incidents', color: AppTheme.dangerRed),
        _StatTile(icon: Icons.personal_injury, value: '157', label: 'People Need Help', color: AppTheme.warningAmber),
        _StatTile(icon: Icons.groups, value: '8', label: 'Teams Deployed', color: AppTheme.signalBlue),
        _StatTile(icon: Icons.shield, value: '92%', label: 'Network Status', color: AppTheme.safeGreen),
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
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _IconBubble(icon: icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
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
          const Positioned(left: 28, top: 38, child: _MapLabel('San Felipe')),
          const Positioned(right: 26, top: 44, child: _MapLabel('Concepcion')),
          const Positioned(right: 50, bottom: 28, child: _MapLabel('Pacol')),
          const Positioned(left: 42, bottom: 28, child: _HeatSpot(size: 48, color: AppTheme.dangerRed)),
          const Positioned(left: 92, top: 56, child: _HeatSpot(size: 64, color: AppTheme.warningAmber)),
          const Positioned(right: 76, top: 46, child: _HeatSpot(size: 52, color: AppTheme.dangerRed)),
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

class _ResponderMapPreview extends StatelessWidget {
  const _ResponderMapPreview({required this.height});

  final double height;

  static const _center = LatLng(13.6218, 123.1948);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: _center,
          initialZoom: 12.4,
          minZoom: 4,
          maxZoom: 18,
          interactionOptions: InteractionOptions(),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
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
            ],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: const [
                  LatLng(13.590, 123.175),
                  LatLng(13.610, 123.190),
                  LatLng(13.622, 123.205),
                  LatLng(13.646, 123.230),
                ],
                strokeWidth: 6,
                color: Colors.white,
              ),
              Polyline(
                points: const [
                  LatLng(13.590, 123.175),
                  LatLng(13.610, 123.190),
                  LatLng(13.622, 123.205),
                  LatLng(13.646, 123.230),
                ],
                strokeWidth: 4,
                color: AppTheme.safeGreen,
              ),
            ],
          ),
          MarkerLayer(
            markers: const [
              Marker(
                point: LatLng(13.6218, 123.1948),
                width: 40,
                height: 40,
                child: _UserDot(),
              ),
              Marker(
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
              TextSourceAttribution('OpenStreetMap contributors, CARTO'),
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
                    Text(incident.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(incident.location, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(incident.meta, style: Theme.of(context).textTheme.labelSmall),
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
    required this.icon,
    required this.title,
    required this.location,
    required this.meta,
    required this.severity,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String location;
  final String meta;
  final String severity;
  final Color color;
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
          Text(action!, style: const TextStyle(color: AppTheme.signalBlue, fontWeight: FontWeight.w700)),
        if (chip != null) _SeverityPill(label: chip!, color: AppTheme.dangerRed),
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
        color: selected ? AppTheme.signalBlue.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? AppTheme.signalBlue : AppTheme.border),
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
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.12),
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
        _LayerButton(icon: Icons.crisis_alert, label: 'Incidents', color: AppTheme.dangerRed),
        _LayerButton(icon: Icons.groups, label: 'Teams', color: AppTheme.signalBlue),
        _LayerButton(icon: Icons.home, label: 'Evac Centers', color: AppTheme.signalBlue),
        _LayerButton(icon: Icons.route, label: 'Safe Route', color: AppTheme.safeGreen),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
          ),
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

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Navigation', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                const Expanded(child: Text('To: San Felipe Incident')),
                Text('4.2 km', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Expanded(child: _MiniMetric(value: '12 min', label: 'Est. time')),
                const Expanded(child: _MiniMetric(value: 'Low', label: 'Traffic')),
                SizedBox(
                  width: 126,
                  child: SentryButton(
                    label: 'Start',
                    icon: Icons.navigation,
                    onPressed: () {},
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(right, style: const TextStyle(fontWeight: FontWeight.w700)),
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
          leading: CircleAvatar(
            backgroundColor:
                (active ? AppTheme.safeGreen : AppTheme.signalBlue).withValues(alpha: 0.12),
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
        _QuickAction(icon: Icons.campaign, title: 'Broadcast Message', color: AppTheme.signalBlue),
        _QuickAction(icon: Icons.chat, title: 'Team Chat', color: AppTheme.violet),
        _QuickAction(icon: Icons.sos, title: 'SOS Requests', color: AppTheme.dangerRed),
        _QuickAction(icon: Icons.inventory, title: 'Resource Request', color: AppTheme.safeGreen),
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
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
    return CircleAvatar(
      backgroundColor: AppTheme.dangerRed,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _EvacMarker extends StatelessWidget {
  const _EvacMarker();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      backgroundColor: AppTheme.signalBlue,
      child: Icon(Icons.home, color: Colors.white, size: 20),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.signalBlue.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.signalBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
        ),
      ),
    );
  }
}
