import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AlertDetailsScreen extends StatelessWidget {
  const AlertDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFFFFF1F1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flood, color: AppTheme.dangerRed, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Flood Warning',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'High',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('San Felipe, Naga City and nearby areas'),
                  const SizedBox(height: 8),
                  Text('Today, 6:30 AM', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  const Text(
                    'Rising water has been reported near low-lying barangays. Avoid flooded roads and monitor local responder updates.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.location_on_outlined),
            label: const Text('Open Safe Route Map'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Send Community Report'),
          ),
        ],
      ),
    );
  }
}
