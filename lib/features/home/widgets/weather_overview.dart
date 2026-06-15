import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class WeatherOverview extends StatelessWidget {
  const WeatherOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weather & Hazard Overview',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          'Today, June 1 - 7:45 AM',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(
              child: _MetricTile(
                icon: Icons.water_drop,
                label: 'Flood Risk',
                value: 'Low',
                color: AppTheme.safeGreen,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                icon: Icons.cloudy_snowing,
                label: 'Rainfall',
                value: '1.2 mm/hr',
                color: AppTheme.signalBlue,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                icon: Icons.thermostat,
                label: 'Temp',
                value: '28C',
                color: AppTheme.dangerRed,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
