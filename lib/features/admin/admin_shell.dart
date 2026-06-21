import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/widgets/custom_button.dart';
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

  static const _screens = [
    _AdminOverviewScreen(),
    _AdminReportsScreen(historyMode: false),
    _AdminReportsScreen(historyMode: true),
    ResponderLiveMapScreen(),
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
    required this.recent,
  });

  final int total;
  final int active;
  final int resolved;
  final int peopleNeedingHelp;
  final List<RescueRequestModel> recent;
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
      final requests =
          await AppDependenciesScope.of(context).rescueRepository.fetchRequests();
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
          peopleNeedingHelp:
              active.fold(0, (sum, r) => sum + r.peopleNeedingHelp),
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
      final requests =
          await AppDependenciesScope.of(context).rescueRepository.fetchRequests();
      if (!mounted) return;

      final filtered = requests
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
                itemBuilder: (_, index) => _ReportCard(
                  request: _reports[index],
                  onChanged: _load,
                ),
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
      final updated = await AppDependenciesScope.of(context)
          .rescueRepository
          .updateRequestStatus(id: _request.id, status: status);
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
                onPressed: () => _updateStatus(
                  RescueStatus.resolved,
                  'Incident resolved.',
                ),
              ),
            if (!canResolve)
              _EmptyState(
                message: 'This report is ${_statusLabel(request.status)}. '
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
