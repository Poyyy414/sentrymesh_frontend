import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'widgets/family_member_tile.dart';
import 'widgets/family_status_card.dart';

class FamilySafetyScreen extends StatelessWidget {
  const FamilySafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F9FC),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _FamilySafetyHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 30 : 14,
                      18,
                      wide ? 30 : 14,
                      24,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FamilyStatusCard(),
                              SizedBox(height: 20),
                              _FamilyMembersHeading(),
                              SizedBox(height: 10),
                              FamilyMemberTile(
                                key: Key('family_member_maria'),
                                initials: 'ML',
                                name: 'Maria Lopez',
                                relationship: 'Wife',
                                status: 'Safe',
                                updated: 'Updated: 5m ago',
                                color: AppTheme.safeGreen,
                              ),
                              SizedBox(height: 8),
                              FamilyMemberTile(
                                key: Key('family_member_antonio'),
                                initials: 'AD',
                                name: 'Antonio Dela Cruz',
                                relationship: 'Son',
                                status: 'Waiting',
                                updated: 'Updated: 15m ago',
                                color: AppTheme.warningAmber,
                              ),
                              SizedBox(height: 8),
                              FamilyMemberTile(
                                key: Key('family_member_carmen'),
                                initials: 'CP',
                                name: 'Carmen Paul',
                                relationship: 'Mother',
                                status: 'Needs Help',
                                updated: 'Updated: 20m ago',
                                color: AppTheme.dangerRed,
                              ),
                              SizedBox(height: 8),
                              FamilyMemberTile(
                                key: Key('family_member_bea'),
                                initials: 'BD',
                                name: 'Bea Dela Cruz',
                                relationship: 'Daughter',
                                status: 'Safe',
                                updated: 'Updated: 1h ago',
                                color: AppTheme.safeGreen,
                              ),
                              SizedBox(height: 16),
                              _FamilyActionRow(
                                key: Key('check_in_all_family_action'),
                                icon: Icons.groups_rounded,
                                title: 'Check-in All Family',
                                subtitle:
                                    'Send a check-in request to all family members',
                                color: AppTheme.signalBlue,
                              ),
                              SizedBox(height: 8),
                              _FamilyActionRow(
                                key: Key('send_family_location_action'),
                                icon: Icons.location_on_rounded,
                                title: 'Send My Location',
                                subtitle:
                                    'Share your current location with your family',
                                color: AppTheme.signalBlue,
                              ),
                              SizedBox(height: 8),
                              _FamilyActionRow(
                                key: Key('family_emergency_message_action'),
                                icon: Icons.sos_rounded,
                                title: 'Emergency Message',
                                subtitle:
                                    'Send an emergency alert to notify your family',
                                color: AppTheme.dangerRed,
                                emergency: true,
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

class _FamilySafetyHeader extends StatelessWidget {
  const _FamilySafetyHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1456B7), Color(0xFF073B88)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: const Row(
        children: [
          SizedBox(
            width: 48,
            child: IconButton(
              key: Key('family_back_button'),
              onPressed: _ignoreTap,
              tooltip: 'Back',
              icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              'Family Safety Check',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _FamilyMembersHeading extends StatelessWidget {
  const _FamilyMembersHeading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Text(
            'Family Members',
            style: TextStyle(
              color: Color(0xFF102E58),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Icon(Icons.groups_outlined, color: AppTheme.signalBlue, size: 18),
        SizedBox(width: 7),
        Text(
          '4 Members',
          style: TextStyle(
            color: Color(0xFF607895),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FamilyActionRow extends StatelessWidget {
  const _FamilyActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.emergency = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool emergency;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emergency ? const Color(0xFFFFF3F4) : const Color(0xFFF4F8FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        onTap: _ignoreTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: emergency
                      ? AppTheme.dangerRed
                      : color.withValues(alpha: 0.09),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: emergency ? Colors.white : color,
                  size: emergency ? 23 : 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: emergency
                            ? AppTheme.dangerRed
                            : const Color(0xFF103B72),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF687B92),
                        fontSize: 10,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: emergency ? AppTheme.dangerRed : color,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _ignoreTap() {}
