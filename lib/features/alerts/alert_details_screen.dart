import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../data/models/alert_model.dart';
import '../../shared/enums/alert_severity.dart';
import '../../shared/enums/hazard_type.dart';

class AlertDetailsScreen extends StatelessWidget {
  const AlertDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alert = ModalRoute.of(context)?.settings.arguments as AlertModel?;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        leading: IconButton(
          key: const Key('alert_details_back_button'),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(alert?.title ?? 'Alert Details'),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1456B7), Color(0xFF073B88)],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              wide ? 30 : 14,
              20,
              wide ? 30 : 14,
              24,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AlertSummaryCard(alert: alert),
                      const SizedBox(height: 18),
                      _OverviewSection(message: alert?.message),
                      const SizedBox(height: 17),
                      const _PotentialImpactCard(),
                      const SizedBox(height: 19),
                      _TakeActionSection(alert: alert),
                      const SizedBox(height: 17),
                      const _EmergencySosAction(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

IconData _hazardIcon(HazardType? type) {
  return switch (type) {
    HazardType.flood => Icons.flood_rounded,
    HazardType.landslide => Icons.terrain_rounded,
    HazardType.typhoon => Icons.cyclone_rounded,
    HazardType.medical => Icons.medical_services_rounded,
    HazardType.distress => Icons.sos_rounded,
    HazardType.infrastructure => Icons.car_crash_rounded,
    null => Icons.warning_amber_rounded,
  };
}

Color _severityColor(AlertSeverity? severity) {
  return switch (severity) {
    AlertSeverity.critical => AppTheme.dangerRed,
    AlertSeverity.high => AppTheme.dangerRed,
    AlertSeverity.medium => AppTheme.warningAmber,
    AlertSeverity.low => AppTheme.safeGreen,
    null => AppTheme.warningAmber,
  };
}

String _severityLabel(AlertSeverity? severity) {
  return switch (severity) {
    AlertSeverity.critical => 'Critical Severity',
    AlertSeverity.high => 'High Severity',
    AlertSeverity.medium => 'Medium Severity',
    AlertSeverity.low => 'Low Severity',
    null => 'Unknown Severity',
  };
}

String _formatDate(DateTime dt) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $ampm\n${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

class _AlertSummaryCard extends StatelessWidget {
  const _AlertSummaryCard({required this.alert});

  final AlertModel? alert;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert?.severity);
    final bgStart = Color.lerp(color.withValues(alpha: 0.05), Colors.white, 0.4)!;
    final bgEnd = color.withValues(alpha: 0.08);
    final borderColor = color.withValues(alpha: 0.22);

    return Container(
      key: const Key('alert_summary_card'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgStart, bgEnd],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  _hazardIcon(alert?.hazardType),
                  color: color,
                  size: 43,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert?.title ?? 'Hazard Alert',
                      style: const TextStyle(
                        color: Color(0xFF102E58),
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 9),
                    _OutlinedSeverityBadge(
                      label: _severityLabel(alert?.severity),
                      color: color,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 640;
              final items = [
                _SummaryMetadata(
                  icon: Icons.location_on_outlined,
                  label: alert?.location.isNotEmpty == true
                      ? alert!.location
                      : 'Location not specified',
                ),
                _SummaryMetadata(
                  icon: Icons.schedule_rounded,
                  label: alert != null
                      ? _formatDate(alert!.issuedAt)
                      : 'Time unknown',
                ),
                const _SummaryMetadata(
                  icon: Icons.notifications_none_rounded,
                  label: 'Source\nSentryMesh System',
                ),
              ];

              if (!horizontal) {
                return Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    children: [
                      items[0],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Color(0xFFE1E8F0)),
                      ),
                      items[1],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Color(0xFFE1E8F0)),
                      ),
                      items[2],
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    Expanded(child: items[0]),
                    const _MetadataDivider(),
                    Expanded(child: items[1]),
                    const _MetadataDivider(),
                    Expanded(child: items[2]),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OutlinedSeverityBadge extends StatelessWidget {
  const _OutlinedSeverityBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SummaryMetadata extends StatelessWidget {
  const _SummaryMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF607895), size: 22),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF546A84),
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataDivider extends StatelessWidget {
  const _MetadataDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 15),
      color: const Color(0xFFE1E8F0),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(label: 'Overview'),
        const SizedBox(height: 7),
        Text(
          message?.isNotEmpty == true
              ? message!
              : 'Monitor local conditions and follow responder guidance. '
                  'Avoid affected areas and keep emergency contacts ready.',
          style: const TextStyle(
            color: Color(0xFF425B79),
            fontSize: 12,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PotentialImpactCard extends StatelessWidget {
  const _PotentialImpactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('potential_impact_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE7F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(label: 'Potential Impact'),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              const items = [
                _ImpactItem(
                  icon: Icons.water_rounded,
                  label: 'Flooding in low-lying\nareas and roads',
                ),
                _ImpactItem(
                  icon: Icons.directions_car_rounded,
                  label: 'Possible road\nclosures',
                ),
                _ImpactItem(
                  icon: Icons.home_rounded,
                  label: 'Risk to homes and\nproperties',
                ),
              ];

              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    items[0],
                    const SizedBox(height: 12),
                    items[1],
                    const SizedBox(height: 12),
                    items[2],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: items[0]),
                  const _ImpactDivider(),
                  Expanded(child: items[1]),
                  const _ImpactDivider(),
                  Expanded(child: items[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ImpactItem extends StatelessWidget {
  const _ImpactItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.signalBlue, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF425B79),
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImpactDivider extends StatelessWidget {
  const _ImpactDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 17),
      color: const Color(0xFFDCE5F2),
    );
  }
}

class _TakeActionSection extends StatelessWidget {
  const _TakeActionSection({required this.alert});

  final AlertModel? alert;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(label: 'Take Action'),
        const SizedBox(height: 9),
        Container(
          key: const Key('alert_actions_card'),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE5EE)),
          ),
          child: Column(
            children: [
              _ActionRow(
                key: const Key('open_safe_route_action'),
                icon: Icons.map_outlined,
                title: 'Open Safe Route Map',
                subtitle: 'View recommended safe evacuation routes',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.safeRoute),
              ),
              const Divider(height: 1, color: Color(0xFFE3E9F0)),
              _ActionRow(
                key: const Key('community_report_action'),
                icon: Icons.groups_outlined,
                title: 'Send Rescue Request',
                subtitle: 'Request help and share your location',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.rescueRequest),
              ),
              const Divider(height: 1, color: Color(0xFFE3E9F0)),
              const _UpdatesRow(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.signalBlue, size: 25),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF173A68),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF71849A),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF4C6786),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdatesRow extends StatelessWidget {
  const _UpdatesRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppTheme.signalBlue,
            size: 25,
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get Updates',
                  style: TextStyle(
                    color: Color(0xFF173A68),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Receive notifications for this alert',
                  style: TextStyle(
                    color: Color(0xFF71849A),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('alert_updates_switch'),
            value: true,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

class _EmergencySosAction extends StatelessWidget {
  const _EmergencySosAction();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('alert_emergency_sos_action'),
        onTap: () => Navigator.of(context).pushNamed(AppRouter.rescueRequest),
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF02E3C), Color(0xFFE51B29)],
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24E03A3E),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.call_rounded, color: Colors.white, size: 27),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Contact responders immediately',
                      style: TextStyle(
                        color: Color(0xFFFFE8EA),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white, size: 25),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF102E58),
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
