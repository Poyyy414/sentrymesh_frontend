import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/services/location_service.dart';

class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    required this.countryName,
    required this.userLocation,
    super.key,
  });

  final String countryName;
  final GeoPoint? userLocation;

  @override
  Widget build(BuildContext context) {
    final ready = userLocation != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (ready ? AppTheme.safeGreen : AppTheme.signalBlue)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    ready ? Icons.gps_fixed : Icons.route_outlined,
                    color: ready ? AppTheme.safeGreen : AppTheme.signalBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ready ? 'Location Ready' : 'Route Preview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ready
                            ? 'FastAPI can replace the preview line with live evacuation routing.'
                            : 'Tap locate to center on your GPS position in $countryName.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(child: _RouteMetric(value: '4.2 km', label: 'Distance')),
                Expanded(child: _RouteMetric(value: '12 min', label: 'Est. time')),
                Expanded(child: _RouteMetric(value: 'Low', label: 'Risk')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
