import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class FamilyStatusCard extends StatelessWidget {
  const FamilyStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your Status',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  'Updated 7:45 AM',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppTheme.safeGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are Safe',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.safeGreen,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        'Your family can see your status.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Update Status'),
            ),
          ],
        ),
      ),
    );
  }
}
