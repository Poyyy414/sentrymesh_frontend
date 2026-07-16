import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../data/models/alert_model.dart';
import '../../shared/enums/alert_severity.dart';
import '../../shared/enums/hazard_type.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<AlertModel> _alerts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final alerts =
          await AppDependenciesScope.of(context).alertRepository.fetchAlerts();
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load messages: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
            children: [
              Text(
                'Messages',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Official updates and alerts from SentryMesh.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (_alerts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No messages at this time.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                )
              else
                for (final alert in _alerts) ...[
                  _MessageTile(
                    icon: _hazardIcon(alert.hazardType),
                    title: alert.title,
                    subtitle: alert.message.isNotEmpty
                        ? alert.message
                        : '${alert.location} — ${_severityLabel(alert.severity)}',
                    color: _severityColor(alert.severity),
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRouter.alertDetails,
                      arguments: alert,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _hazardIcon(HazardType type) {
  return switch (type) {
    HazardType.flood => Icons.flood_rounded,
    HazardType.landslide => Icons.terrain_rounded,
    HazardType.typhoon => Icons.cyclone_rounded,
    HazardType.medical => Icons.medical_services_rounded,
    HazardType.distress => Icons.sos_rounded,
    HazardType.infrastructure => Icons.car_crash_rounded,
  };
}

Color _severityColor(AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.critical || AlertSeverity.high => AppTheme.dangerRed,
    AlertSeverity.medium => AppTheme.warningAmber,
    AlertSeverity.low => AppTheme.safeGreen,
  };
}

String _severityLabel(AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.critical => 'Critical',
    AlertSeverity.high => 'High',
    AlertSeverity.medium => 'Medium',
    AlertSeverity.low => 'Low',
  };
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
