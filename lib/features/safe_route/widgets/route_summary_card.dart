import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/route_model.dart';

class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    required this.countryName,
    required this.userLocation,
    this.route,
    this.isLoading = false,
    this.message,
    super.key,
  });

  final String countryName;
  final GeoPoint? userLocation;
  final RouteModel? route;
  final bool isLoading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final ready = userLocation != null;
    final hasRoute = route != null;

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
                        isLoading
                            ? 'Checking Route'
                            : hasRoute
                            ? 'Backend Route Ready'
                            : 'Route Waiting',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isLoading
                            ? 'Fetching route waypoints from the backend.'
                            : hasRoute
                            ? route!.label.isEmpty
                                  ? 'Route waypoints loaded from backend.'
                                  : route!.label
                            : message ??
                                  (ready
                                      ? 'No backend route returned yet.'
                                      : 'Choose $countryName or tap locate to request a route.'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RouteMetric(
                    value: hasRoute
                        ? '${route!.distanceKm.toStringAsFixed(1)} km'
                        : '--',
                    label: 'Distance',
                  ),
                ),
                Expanded(
                  child: _RouteMetric(
                    value: hasRoute ? '${route!.estimatedMinutes} min' : '--',
                    label: 'Est. time',
                  ),
                ),
                Expanded(
                  child: _RouteMetric(
                    value: hasRoute ? route!.riskLevel : '--',
                    label: 'Risk',
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
