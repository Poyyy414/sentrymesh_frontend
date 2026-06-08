import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/router.dart';
import 'widgets/alert_filter_tabs.dart';
import 'widgets/alert_list_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 64,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.deepNavy, AppTheme.navy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      'Alerts',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    tooltip: 'Filter alerts',
                    icon: const Icon(Icons.tune, color: Colors.white),
                  ),
                ],
              ),
            ),
            AlertFilterTabs(
              selectedIndex: _selectedFilter,
              onChanged: (index) => setState(() => _selectedFilter = index),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  Text(
                    'For Your Area',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  AlertListCard(
                    title: 'Flood Warning',
                    location: 'San Felipe, Naga City and nearby areas',
                    description: 'Today, 6:30 AM',
                    severity: 'High',
                    icon: Icons.flood,
                    color: AppTheme.dangerRed,
                    backgroundColor: const Color(0xFFFFF1F1),
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRouter.alertDetails),
                  ),
                  const SizedBox(height: 12),
                  const AlertListCard(
                    title: 'Landslide Alert',
                    location: 'Panicuason, Naga City and nearby areas',
                    description: 'Today, 5:15 AM',
                    severity: 'Medium',
                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.warningAmber,
                    backgroundColor: Color(0xFFFFF8E8),
                  ),
                  const SizedBox(height: 12),
                  const AlertListCard(
                    title: 'Typhoon Advisory',
                    location: 'Bicol Region Weather System',
                    description: 'Today, 4:45 AM',
                    severity: 'Critical',
                    icon: Icons.cyclone,
                    color: AppTheme.violet,
                    backgroundColor: Color(0xFFF5EFFF),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
