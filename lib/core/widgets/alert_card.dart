import 'package:flutter/material.dart';

import '../../data/models/alert_model.dart';
import '../../shared/enums/alert_severity.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({required this.alert, this.onTap, super.key});

  final AlertModel alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_rounded, color: color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        _SeverityBadge(
                          label: alert.severity.label,
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(alert.location),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _severityColor(AlertSeverity severity) {
    return switch (severity) {
      AlertSeverity.low => const Color(0xFF18A957),
      AlertSeverity.medium => const Color(0xFFF5A524),
      AlertSeverity.high => const Color(0xFFE53935),
      AlertSeverity.critical => const Color(0xFF7B3FC7),
    };
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
