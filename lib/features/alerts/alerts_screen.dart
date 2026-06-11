import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
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
      color: const Color(0xFFF7F9FC),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _AlertsHeader(),
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
                              const _LatestAlertsHeading(),
                              const SizedBox(height: 14),
                              AlertListCard(
                                key: const Key('flood_alert_card'),
                                title: 'Flood Warning',
                                location:
                                    'San Felipe, Naga City and nearby areas',
                                description: 'Today, 6:30 AM',
                                severity: 'High',
                                icon: Icons.flood_rounded,
                                color: AppTheme.dangerRed,
                                backgroundColor: const Color(0xFFFFF7F7),
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed(AppRouter.alertDetails),
                              ),
                              const SizedBox(height: 14),
                              const AlertListCard(
                                key: Key('landslide_alert_card'),
                                title: 'Landslide Alert',
                                location:
                                    'Panicuason, Naga City and nearby areas',
                                description: 'Today, 5:15 AM',
                                severity: 'Medium',
                                icon: Icons.warning_amber_rounded,
                                color: AppTheme.warningAmber,
                                backgroundColor: Color(0xFFFFFBF2),
                              ),
                              const SizedBox(height: 14),
                              const AlertListCard(
                                key: Key('typhoon_alert_card'),
                                title: 'Typhoon Advisory',
                                location: 'Bicol Region Weather System',
                                description: 'Today, 4:45 AM',
                                severity: 'Critical',
                                icon: Icons.cyclone_rounded,
                                color: AppTheme.violet,
                                backgroundColor: Color(0xFFFAF7FF),
                              ),
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
  const _AlertsHeader();

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
            onPressed: () {},
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
}

class _LatestAlertsHeading extends StatelessWidget {
  const _LatestAlertsHeading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Text(
            'Latest Alerts',
            style: TextStyle(
              color: Color(0xFF102E58),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          'Updated just now',
          style: TextStyle(
            color: Color(0xFF71849A),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 8),
        Icon(Icons.refresh_rounded, color: Color(0xFF607895), size: 18),
      ],
    );
  }
}
