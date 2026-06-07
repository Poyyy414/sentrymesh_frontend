import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets/custom_button.dart';
import 'widgets/family_member_tile.dart';
import 'widgets/family_status_card.dart';

class FamilySafetyScreen extends StatelessWidget {
  const FamilySafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 60,
              color: AppTheme.navy,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Family Safety Check',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const FamilyStatusCard(),
                  const SizedBox(height: 20),
                  Text(
                    'Family Members',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const FamilyMemberTile(
                    initials: 'ML',
                    name: 'Maria Lopez',
                    relationship: 'Wife',
                    status: 'Safe',
                    updated: 'Updated: 5m ago',
                    color: AppTheme.safeGreen,
                  ),
                  const SizedBox(height: 8),
                  const FamilyMemberTile(
                    initials: 'AD',
                    name: 'Antonio Dela Cruz',
                    relationship: 'Son',
                    status: 'Waiting',
                    updated: 'Updated: 15m ago',
                    color: AppTheme.warningAmber,
                  ),
                  const SizedBox(height: 8),
                  const FamilyMemberTile(
                    initials: 'CP',
                    name: 'Carmen Paul',
                    relationship: 'Mother',
                    status: 'Needs Help',
                    updated: 'Updated: 20m ago',
                    color: AppTheme.dangerRed,
                  ),
                  const SizedBox(height: 8),
                  const FamilyMemberTile(
                    initials: 'BD',
                    name: 'Bea Dela Cruz',
                    relationship: 'Daughter',
                    status: 'Safe',
                    updated: 'Updated: 1h ago',
                    color: AppTheme.safeGreen,
                  ),
                  const SizedBox(height: 20),
                  SentryButton(
                    label: 'Check-In All Family',
                    icon: Icons.fact_check_outlined,
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.navy,
                    onPressed: () {},
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Send My Location'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Emergency Message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerRed,
                      side: const BorderSide(color: Color(0xFFF0C5C5)),
                    ),
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
