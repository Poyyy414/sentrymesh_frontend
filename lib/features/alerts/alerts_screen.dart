import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/alert_model.dart';
import '../../shared/enums/alert_severity.dart';
import '../../shared/enums/hazard_type.dart';
import 'widgets/alert_filter_tabs.dart';
import 'widgets/alert_list_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _selectedFilter = 0;
  List<AlertModel> _alerts = const [];
  bool _isLoading = true;
  String? _error;
  Set<AlertSeverity> _severityFilter = {...AlertSeverity.values};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && _alerts.isEmpty && _error == null) {
      _loadAlerts();
    }
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final alerts = await AppDependenciesScope.of(
        context,
      ).alertRepository.fetchAlerts();
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  List<AlertModel> get _visibleAlerts {
    final tabFiltered = switch (_selectedFilter) {
      1 =>
        _alerts
            .where(
              (alert) =>
                  alert.severity == AlertSeverity.high ||
                  alert.severity == AlertSeverity.critical,
            )
            .toList(),
      2 =>
        _alerts
            .where(
              (alert) =>
                  alert.severity == AlertSeverity.low ||
                  alert.severity == AlertSeverity.medium,
            )
            .toList(),
      _ => _alerts,
    };

    if (_severityFilter.length == AlertSeverity.values.length) {
      return tabFiltered;
    }

    return tabFiltered
        .where((alert) => _severityFilter.contains(alert.severity))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F9FC),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AlertsHeader(
              onFilterSelected: (severities) => setState(() => _severityFilter = severities),
            ),
            AlertFilterTabs(
              selectedIndex: _selectedFilter,
              onChanged: (index) => setState(() => _selectedFilter = index),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 960;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 28 : 16,
                      18,
                      wide ? 28 : 16,
                      24,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LatestAlertsHeading(onRefresh: _loadAlerts),
                              const SizedBox(height: 14),
                              if (_isLoading)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (_error != null)
                                _LoadError(
                                  message: _error!,
                                  onRetry: _loadAlerts,
                                )
                              else if (_visibleAlerts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: Text('No alerts in this category.'),
                                  ),
                                )
                              else
                                for (final alert in _visibleAlerts) ...[
                                  _BackendAlertCard(alert: alert),
                                  const SizedBox(height: 14),
                                ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsHeader extends StatelessWidget {
  const _AlertsHeader({this.onFilterSelected});

  final ValueChanged<Set<AlertSeverity>>? onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1456B7), Color(0xFF073B88)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const SizedBox(width: 46),
          const Expanded(
            child: Text(
              'Alerts',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            key: const Key('alerts_filter_button'),
            onPressed: () => _showFilterDialog(context),
            tooltip: 'Filter alerts',
            icon: const Icon(
              Icons.filter_alt_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final selected = <AlertSeverity>{...AlertSeverity.values};

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Filter by Severity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AlertSeverity.values.map((severity) {
              return CheckboxListTile(
                title: Text(severity.label),
                value: selected.contains(severity),
                onChanged: (checked) {
                  setDialogState(() {
                    if (checked ?? false) {
                      selected.add(severity);
                    } else {
                      selected.remove(severity);
                    }
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onFilterSelected?.call(selected);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestAlertsHeading extends StatelessWidget {
  const _LatestAlertsHeading({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Latest Alerts',
            style: TextStyle(
              color: Color(0xFF102E58),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Text(
          'Updated just now',
          style: TextStyle(
            color: Color(0xFF71849A),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: 'Refresh alerts',
          onPressed: onRefresh,
          icon: const Icon(
            Icons.refresh_rounded,
            color: Color(0xFF607895),
            size: 18,
          ),
        ),
      ],
    );
  }
}

class _BackendAlertCard extends StatelessWidget {
  const _BackendAlertCard({required this.alert});

  final AlertModel alert;

  @override
  Widget build(BuildContext context) {
    final color = switch (alert.severity) {
      AlertSeverity.critical => AppTheme.violet,
      AlertSeverity.high => AppTheme.dangerRed,
      AlertSeverity.medium => AppTheme.warningAmber,
      AlertSeverity.low => AppTheme.safeGreen,
    };
    final icon = switch (alert.hazardType) {
      HazardType.flood => Icons.flood_rounded,
      HazardType.landslide => Icons.warning_amber_rounded,
      HazardType.typhoon => Icons.cyclone_rounded,
      HazardType.medical => Icons.medical_services_rounded,
      HazardType.distress => Icons.sos_rounded,
      HazardType.infrastructure => Icons.car_crash_rounded,
    };

    return AlertListCard(
      key: ValueKey('alert_${alert.id}'),
      title: alert.title,
      location: alert.location,
      description: DateFormatter.compact(alert.issuedAt.toLocal()),
      severity: alert.severity.label,
      icon: icon,
      color: color,
      backgroundColor: color.withValues(alpha: 0.05),
      onTap: () => Navigator.of(
        context,
      ).pushNamed(AppRouter.alertDetails, arguments: alert),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text('Could not load alerts: $message', textAlign: TextAlign.center),
          const SizedBox(height: 10),
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
