import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class NearbyAlertsList extends StatelessWidget {
  const NearbyAlertsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Nearby Alerts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(onPressed: () {}, child: const Text('View all')),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.warningAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.warningAmber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Landslide Alert',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'San Felipe, Naga City',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Medium',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.warningAmber,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1h ago',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
