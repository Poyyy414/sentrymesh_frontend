import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/widgets/custom_button.dart';
import '../../data/models/evacuation_center_model.dart';
import '../../data/models/rescue_request_model.dart';
import '../../shared/enums/hazard_type.dart';
import '../../shared/enums/rescue_status.dart';
import '../responder/responder_shell.dart' show ResponderLiveMapScreen;

/// Super-admin console. The super admin has the widest view of the platform:
/// every rescue report (active and historical) and the ability to dispatch
/// teams or change an incident's status.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  StreamSubscription<ConnectivityStatus>? _connectivitySub;

  static const _screens = [
    _AdminOverviewScreen(),
    _AdminReportsScreen(historyMode: false),
    _AdminReportsScreen(historyMode: true),
    ResponderLiveMapScreen(),
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
    deps.connectivityService.currentStatus().then((status) {
      if (!mounted) return;
      // The service may have already resolved tower-vs-cloud and fired its
      // one status-change event before this listener subscribed (broadcast
      // streams don't replay), so apply the resolved backend explicitly here
      // instead of waiting for a future change that may never come.
      _switchBackendIfNeeded();
      _reconnectSocket();
    });

    _connectivitySub =
        deps.connectivityService.onStatusChanged.listen((status) {
      if (!mounted) return;
      _switchBackendIfNeeded();
      _reconnectSocket();
    });
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
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Live Map',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

class _AdminStats {
  const _AdminStats({
    required this.total,
    required this.active,
    required this.resolved,
    required this.peopleNeedingHelp,
    required this.barangays,
    required this.recent,
  });

  final int total;
  final int active;
  final int resolved;
  final int peopleNeedingHelp;
  final List<_BarangayOpsSummary> barangays;
  final List<RescueRequestModel> recent;
}

class _BarangayOpsSummary {
  const _BarangayOpsSummary({
    required this.name,
    required this.activeReports,
    required this.peopleNeedingRescue,
    required this.peopleRescued,
    required this.shelterCount,
    required this.shelterCapacity,
    required this.shelterOccupancy,
    required this.shelterAvailable,
  });

  final String name;
  final int activeReports;
  final int peopleNeedingRescue;
  final int peopleRescued;
  final int shelterCount;
  final int shelterCapacity;
  final int shelterOccupancy;
  final int shelterAvailable;
}

class _MutableBarangayOpsSummary {
  _MutableBarangayOpsSummary(this.name);

  final String name;
  int activeReports = 0;
  int peopleNeedingRescue = 0;
  int peopleRescued = 0;
  int shelterCount = 0;
  int shelterCapacity = 0;
  int shelterOccupancy = 0;
  int shelterAvailable = 0;

  _BarangayOpsSummary freeze() {
    return _BarangayOpsSummary(
      name: name,
      activeReports: activeReports,
      peopleNeedingRescue: peopleNeedingRescue,
      peopleRescued: peopleRescued,
      shelterCount: shelterCount,
      shelterCapacity: shelterCapacity,
      shelterOccupancy: shelterOccupancy,
      shelterAvailable: shelterAvailable,
    );
  }
}

class _AdminOverviewScreen extends StatefulWidget {
  const _AdminOverviewScreen();

  @override
  State<_AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<_AdminOverviewScreen> {
  _AdminStats? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rescueRepository = AppDependenciesScope.of(
        context,
      ).rescueRepository;
      final results = await Future.wait([
        rescueRepository.fetchRequests(),
        rescueRepository.fetchEvacuationCenters(),
      ]);
      final requests = results[0] as List<RescueRequestModel>;
      final shelters = results[1] as List<EvacuationCenterModel>;
      if (!mounted) return;

      final active = requests.where(_isActive).toList();
      final resolved = requests
          .where((r) => r.status == RescueStatus.resolved)
          .length;

      setState(() {
        _stats = _AdminStats(
          total: requests.length,
          active: active.length,
          resolved: resolved,
          peopleNeedingHelp: active.fold(
            0,
            (sum, r) => sum + r.peopleNeedingHelp,
          ),
          barangays: _buildBarangayOpsSummaries(requests, shelters),
          recent: requests.take(5).toList(),
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load platform data: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Super Admin Console'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              _ErrorBanner(message: _error!, onRetry: _load)
            else ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(
                    label: 'Total Reports',
                    value: stats?.total,
                    icon: Icons.summarize_outlined,
                    color: AppTheme.signalBlue,
                    isLoading: _isLoading,
                  ),
                  _StatCard(
                    label: 'Active',
                    value: stats?.active,
                    icon: Icons.notification_important_outlined,
                    color: AppTheme.dangerRed,
                    isLoading: _isLoading,
                  ),
                  _StatCard(
                    label: 'Resolved',
                    value: stats?.resolved,
                    icon: Icons.verified_outlined,
                    color: AppTheme.safeGreen,
                    isLoading: _isLoading,
                  ),
                  _StatCard(
                    label: 'People Needing Help',
                    value: stats?.peopleNeedingHelp,
                    icon: Icons.groups_outlined,
                    color: AppTheme.warningAmber,
                    isLoading: _isLoading,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _BarangayOpsSection(
                summaries: stats?.barangays ?? const [],
                isLoading: _isLoading,
              ),
              const SizedBox(height: 22),
              Text(
                'Recent Reports',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if ((stats?.recent ?? const []).isEmpty)
                const _EmptyState(message: 'No reports yet.')
              else
                for (final request in stats!.recent) ...[
                  _ReportCard(request: request, onChanged: _load),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reports / History
// ---------------------------------------------------------------------------

class _AdminReportsScreen extends StatefulWidget {
  const _AdminReportsScreen({required this.historyMode});

  /// When true, shows resolved/cancelled reports (the audit trail). Otherwise
  /// shows the current active queue.
  final bool historyMode;

  @override
  State<_AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<_AdminReportsScreen> {
  List<RescueRequestModel> _reports = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final requests = await AppDependenciesScope.of(
        context,
      ).rescueRepository.fetchRequests();
      if (!mounted) return;

      final filtered =
          requests
              .where((r) => widget.historyMode ? !_isActive(r) : _isActive(r))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _reports = filtered;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load reports: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.historyMode ? 'Report History' : 'All Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  _ErrorBanner(message: _error!, onRetry: _load),
                ],
              )
            : _reports.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  _EmptyState(
                    message: widget.historyMode
                        ? 'No resolved or cancelled reports yet.'
                        : 'No active reports right now.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _reports.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) =>
                    _ReportCard(request: _reports[index], onChanged: _load),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Report detail
// ---------------------------------------------------------------------------

class _AdminReportDetailScreen extends StatefulWidget {
  const _AdminReportDetailScreen({required this.request});

  final RescueRequestModel request;

  @override
  State<_AdminReportDetailScreen> createState() =>
      _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<_AdminReportDetailScreen> {
  late RescueRequestModel _request = widget.request;
  bool _isBusy = false;
  bool _didChange = false;

  Future<void> _updateStatus(RescueStatus status, String message) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final updated = await AppDependenciesScope.of(
        context,
      ).rescueRepository.updateRequestStatus(id: _request.id, status: status);
      if (!mounted) return;
      setState(() {
        _request = updated ?? _request;
        _didChange = true;
        _isBusy = false;
      });
      _showSnack(message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      _showSnack('Action failed: $error');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final canDispatch = request.status == RescueStatus.pending;
    final canResolve = _isActive(request);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_didChange);
      },
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(title: const Text('Report Details')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _severityColor(
                            request.peopleNeedingHelp,
                          ).withValues(alpha: 0.14),
                          child: Icon(
                            _hazardIcon(request.emergencyType),
                            color: _severityColor(request.peopleNeedingHelp),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hazardTitle(request.emergencyType),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _timeAgo(request.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        _StatusChip(status: request.status),
                      ],
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      icon: Icons.groups_outlined,
                      label: 'People needing help',
                      value: '${request.peopleNeedingHelp}',
                    ),
                    _DetailRow(
                      icon: Icons.place_outlined,
                      label: 'Location',
                      value: request.locationLabel?.isNotEmpty == true
                          ? request.locationLabel!
                          : (request.latitude != null &&
                                    request.longitude != null
                                ? '${request.latitude!.toStringAsFixed(5)}, '
                                      '${request.longitude!.toStringAsFixed(5)}'
                                : 'Not available'),
                    ),
                    if (request.assignedTeamName?.isNotEmpty == true)
                      _DetailRow(
                        icon: Icons.engineering_outlined,
                        label: 'Assigned team',
                        value: request.assignedTeamName!,
                      ),
                    if (request.assignedShelterName?.isNotEmpty == true)
                      _DetailRow(
                        icon: Icons.home_work_outlined,
                        label: 'Shelter',
                        value: request.assignedShelterName!,
                      ),
                    if (request.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (canDispatch)
              SentryButton(
                label: 'Dispatch Team',
                icon: Icons.airport_shuttle,
                isLoading: _isBusy,
                onPressed: () => _updateStatus(
                  RescueStatus.acknowledged,
                  'Team dispatched.',
                ),
              ),
            if (canDispatch) const SizedBox(height: 10),
            if (canResolve)
              SentryButton(
                label: 'Mark as En Route',
                icon: Icons.directions_run,
                backgroundColor: AppTheme.signalBlue,
                isLoading: _isBusy,
                onPressed: () => _updateStatus(
                  RescueStatus.inProgress,
                  'Incident marked as en route.',
                ),
              ),
            if (canResolve) const SizedBox(height: 10),
            if (canResolve)
              SentryButton(
                label: 'Resolve Incident',
                icon: Icons.check_circle_outline,
                backgroundColor: AppTheme.safeGreen,
                isLoading: _isBusy,
                onPressed: () =>
                    _updateStatus(RescueStatus.resolved, 'Incident resolved.'),
              ),
            if (!canResolve)
              _EmptyState(
                message:
                    'This report is ${_statusLabel(request.status)}. '
                    'No further actions available.',
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _BarangayOpsSection extends StatelessWidget {
  const _BarangayOpsSection({required this.summaries, required this.isLoading});

  final List<_BarangayOpsSummary> summaries;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Barangay Operations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!isLoading && summaries.isNotEmpty)
              Text(
                '${summaries.length} areas',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (summaries.isEmpty)
          const _EmptyState(
            message: 'No barangay-level rescue or shelter data yet.',
          )
        else
          for (final summary in summaries.take(6)) ...[
            _BarangayOpsCard(summary: summary),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _BarangayOpsCard extends StatelessWidget {
  const _BarangayOpsCard({required this.summary});

  final _BarangayOpsSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasShelters = summary.shelterCount > 0;
    final shelterColor = !hasShelters
        ? AppTheme.textMuted
        : summary.shelterAvailable <= 0
        ? AppTheme.dangerRed
        : summary.shelterAvailable < summary.peopleNeedingRescue
        ? AppTheme.warningAmber
        : AppTheme.safeGreen;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.signalBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_city_outlined,
                    color: AppTheme.signalBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _MiniMetric(
                  label: 'Active',
                  value: '${summary.activeReports}',
                  color: AppTheme.dangerRed,
                ),
              ],
            ),
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: _OpsMetric(
                    label: 'Need rescue',
                    value: '${summary.peopleNeedingRescue}',
                    icon: Icons.sos_outlined,
                    color: AppTheme.dangerRed,
                  ),
                ),
                Expanded(
                  child: _OpsMetric(
                    label: 'Rescued',
                    value: '${summary.peopleRescued}',
                    icon: Icons.verified_outlined,
                    color: AppTheme.safeGreen,
                  ),
                ),
                Expanded(
                  child: _OpsMetric(
                    label: hasShelters ? 'Slots free' : 'No shelters',
                    value: hasShelters ? '${summary.shelterAvailable}' : '--',
                    icon: Icons.home_work_outlined,
                    color: shelterColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasShelters
                  ? '${summary.shelterCount} shelter(s) - '
                        '${summary.shelterOccupancy}/${summary.shelterCapacity} occupied'
                  : 'No shelter availability reported for this barangay.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _OpsMetric extends StatelessWidget {
  const _OpsMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: color),
              ),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isLoading,
  });

  final String label;
  final int? value;
  final IconData icon;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            isLoading
                ? const SizedBox(
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(
                    '${value ?? 0}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.request, required this.onChanged});

  final RescueRequestModel request;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(request.peopleNeedingHelp);

    return Card(
      child: InkWell(
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => _AdminReportDetailScreen(request: request),
            ),
          );
          if (changed == true) await onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_hazardIcon(request.emergencyType), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hazardTitle(request.emergencyType),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${request.peopleNeedingHelp} person(s) · '
                      '${_timeAgo(request.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: request.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RescueStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 40, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _unknownBarangay = 'Unmapped Barangay';

List<_BarangayOpsSummary> _buildBarangayOpsSummaries(
  List<RescueRequestModel> requests,
  List<EvacuationCenterModel> shelters,
) {
  final byBarangay = <String, _MutableBarangayOpsSummary>{};

  _MutableBarangayOpsSummary bucket(String name) {
    return byBarangay.putIfAbsent(name, () => _MutableBarangayOpsSummary(name));
  }

  for (final request in requests) {
    final summary = bucket(_barangayFromRequest(request));
    if (_isActive(request)) {
      summary.activeReports += 1;
      summary.peopleNeedingRescue += request.peopleNeedingHelp;
    } else if (request.status == RescueStatus.resolved) {
      summary.peopleRescued += request.peopleNeedingHelp;
    }
  }

  for (final shelter in shelters) {
    final summary = bucket(_barangayFromShelter(shelter));
    summary.shelterCount += 1;
    summary.shelterCapacity += shelter.capacity;
    summary.shelterOccupancy += shelter.currentOccupancy;
    if (shelter.isOpen) {
      summary.shelterAvailable += shelter.availableSlots;
    }
  }

  final summaries =
      byBarangay.values
          .where(
            (summary) =>
                summary.activeReports > 0 ||
                summary.peopleRescued > 0 ||
                summary.shelterCount > 0,
          )
          .map((summary) => summary.freeze())
          .toList()
        ..sort((a, b) {
          final needCompare = b.peopleNeedingRescue.compareTo(
            a.peopleNeedingRescue,
          );
          if (needCompare != 0) return needCompare;

          final activeCompare = b.activeReports.compareTo(a.activeReports);
          if (activeCompare != 0) return activeCompare;

          if (a.name == _unknownBarangay) return 1;
          if (b.name == _unknownBarangay) return -1;
          return a.name.compareTo(b.name);
        });

  return summaries;
}

String _barangayFromRequest(RescueRequestModel request) {
  final candidates = [
    request.locationLabel,
    request.assignedShelterAddress,
    request.description,
  ];
  for (final candidate in candidates) {
    final barangay = _barangayFromText(candidate);
    if (barangay != null) return barangay;
  }
  return _unknownBarangay;
}

String _barangayFromShelter(EvacuationCenterModel shelter) {
  return _barangayFromText(shelter.address, allowFallbackSegment: true) ??
      _barangayFromText(shelter.name, allowFallbackSegment: true) ??
      _unknownBarangay;
}

String? _barangayFromText(String? raw, {bool allowFallbackSegment = false}) {
  final text = raw?.trim();
  if (text == null || text.isEmpty || _isGenericLocationLabel(text)) {
    return null;
  }

  final explicitMatch = RegExp(
    r"\b(?:barangay|brgy\.?|bgy\.?)\s+([a-z0-9 .'-]+)",
    caseSensitive: false,
  ).firstMatch(text);
  if (explicitMatch != null) {
    return _formatBarangayName(explicitMatch.group(1)!);
  }

  final segments = text
      .split(RegExp(r'[,;|]'))
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList();

  for (final segment in segments) {
    final lower = segment.toLowerCase();
    if (lower.startsWith('barangay ') ||
        lower.startsWith('brgy ') ||
        lower.startsWith('brgy. ')) {
      return _formatBarangayName(segment);
    }
  }

  if (!allowFallbackSegment || segments.length < 2) {
    return null;
  }

  final fallback = segments.firstWhere(
    (segment) => !_isGenericLocationLabel(segment),
    orElse: () => '',
  );
  if (fallback.isEmpty) return null;
  return _formatBarangayName(fallback);
}

bool _isGenericLocationLabel(String text) {
  final lower = text.toLowerCase().trim();
  return lower == 'resident gps' ||
      lower == 'incident location' ||
      lower == 'unknown location' ||
      lower == 'naga city' ||
      lower == 'camarines sur' ||
      lower == 'philippines' ||
      lower.contains('gps coordinates');
}

String _formatBarangayName(String text) {
  var cleaned = text
      .replaceAll(RegExp(r'\bbarangay\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bbrgy\.?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bbgy\.?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (cleaned.isEmpty) return _unknownBarangay;

  cleaned = cleaned
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        if (word.length <= 2 && word == word.toUpperCase()) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
  return 'Barangay $cleaned';
}

Future<void> _logout(BuildContext context) async {
  await AppDependenciesScope.of(context).authRepository.logout();
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
}

bool _isActive(RescueRequestModel request) {
  return request.status == RescueStatus.pending ||
      request.status == RescueStatus.acknowledged ||
      request.status == RescueStatus.inProgress;
}

String _statusLabel(RescueStatus status) {
  return switch (status) {
    RescueStatus.pending => 'Active',
    RescueStatus.acknowledged => 'Dispatched',
    RescueStatus.inProgress => 'En Route',
    RescueStatus.resolved => 'Resolved',
    RescueStatus.cancelled => 'Cancelled',
  };
}

Color _statusColor(RescueStatus status) {
  return switch (status) {
    RescueStatus.pending => AppTheme.dangerRed,
    RescueStatus.acknowledged => AppTheme.warningAmber,
    RescueStatus.inProgress => AppTheme.signalBlue,
    RescueStatus.resolved => AppTheme.safeGreen,
    RescueStatus.cancelled => AppTheme.textMuted,
  };
}

Color _severityColor(int people) {
  if (people >= 5) return AppTheme.dangerRed;
  if (people >= 2) return AppTheme.warningAmber;
  return AppTheme.safeGreen;
}

IconData _hazardIcon(HazardType type) {
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

String _timeAgo(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return '${diff.inDays} d ago';
}
