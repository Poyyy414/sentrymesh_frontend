import 'package:flutter/material.dart';

import '../../app/constants.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import 'widgets/disaster_status_card.dart';
import 'widgets/nearby_alerts_list.dart';
import 'widgets/sos_button.dart';
import 'widgets/weather_overview.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _HomeHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              sliver: SliverList.list(
                children: [
                  const _LocationTile(),
                  const SizedBox(height: 12),
                  const DisasterStatusCard(),
                  const SizedBox(height: 12),
                  SosButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRouter.rescueRequest),
                  ),
                  const SizedBox(height: 18),
                  const WeatherOverview(),
                  const SizedBox(height: 18),
                  const NearbyAlertsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.navy,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SentryLogo(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                    ),
                    Text(
                      AppConstants.appTagline,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () {},
                    tooltip: 'Notifications',
                    icon: const Icon(
                      Icons.notifications_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 7,
                    child: Container(
                      width: 17,
                      height: 17,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppTheme.dangerRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  'JP',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, John Paul',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Stay safe and look out for your community.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentryLogo extends StatelessWidget {
  const _SentryLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: AppTheme.textMuted, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.defaultLocation,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text('Philippines', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            IconButton(
              onPressed: () {},
              tooltip: 'Refresh location',
              icon: const Icon(Icons.my_location, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
