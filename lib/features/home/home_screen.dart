import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/demo/demo_scenario.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _distressSent = DemoScenario.instance.residentSosSent;

  Future<void> _openSosFlow() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SosFlowSheet(),
    );

    if (sent == true && mounted) {
      DemoScenario.instance.sendResidentSos();
      setState(() => _distressSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Distress ping received by responder dashboard.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _HomeHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _EmergencyStatusBanner(),
                  const SizedBox(height: 12),
                  _SosButton(onPressed: _openSosFlow),
                  const SizedBox(height: 12),
                  const _LocationCard(),
                  const SizedBox(height: 12),
                  _DisasterStatusCard(distressSent: _distressSent),
                  const SizedBox(height: 18),
                  const _FloodPredictionCard(),
                  const SizedBox(height: 18),
                  const _SectionHeader(
                    title: 'Weather & Hazard Overview',
                    subtitle: 'Updated 2 min ago',
                  ),
                  const SizedBox(height: 10),
                  const _HazardMetrics(),
                  const SizedBox(height: 18),
                  const _SectionHeader(
                    title: 'Nearby Alerts',
                    action: 'View all',
                  ),
                  const SizedBox(height: 10),
                  const _AlertTile(
                    icon: Icons.flood,
                    title: 'Flood Warning',
                    subtitle: 'San Felipe - 12 people affected',
                    label: 'High',
                    color: AppTheme.dangerRed,
                  ),
                  const SizedBox(height: 8),
                  const _AlertTile(
                    icon: Icons.warning_amber_rounded,
                    title: 'Landslide Watch',
                    subtitle: 'Concepcion Pequena - sensor confidence 87%',
                    label: 'Medium',
                    color: AppTheme.warningAmber,
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.navy,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SentryMesh',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    Text(
                      'Resident Mode',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const _RoleBadge(label: 'Demo Live'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  'JP',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, John Paul',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Typhoon response simulation active.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
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

class _EmergencyStatusBanner extends StatelessWidget {
  const _EmergencyStatusBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.deepNavy,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.safeGreen.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub, color: AppTheme.safeGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Backup Ready',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'You can still send an emergency request if mobile signal is weak.',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white70),
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

class _LocationCard extends StatelessWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on, color: AppTheme.textMuted),
        title: const Text('Naga City, Camarines Sur'),
        subtitle: const Text('Philippines'),
        trailing: IconButton(
          tooltip: 'Locate',
          onPressed: () {},
          icon: const Icon(Icons.my_location),
        ),
      ),
    );
  }
}

class _DisasterStatusCard extends StatelessWidget {
  const _DisasterStatusCard({required this.distressSent});

  final bool distressSent;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: distressSent
          ? AppTheme.warningAmber.withValues(alpha: 0.08)
          : AppTheme.safeGreen.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: distressSent
                    ? AppTheme.warningAmber
                    : AppTheme.safeGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                distressSent ? Icons.outgoing_mail : Icons.verified_user,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    distressSent ? 'DISTRESS PING SENT' : 'DISASTER STATUS',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    distressSent ? 'Responder notified' : 'SAFE',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: distressSent
                          ? AppTheme.warningAmber
                          : AppTheme.safeGreen,
                    ),
                  ),
                  Text(
                    distressSent
                        ? 'Your location and emergency request were sent to responders.'
                        : 'No significant threats at your exact location.',
                    style: Theme.of(context).textTheme.bodySmall,
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

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.dangerRed,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency SOS',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send your emergency location to responders.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosFlowSheet extends StatefulWidget {
  const _SosFlowSheet();

  @override
  State<_SosFlowSheet> createState() => _SosFlowSheetState();
}

class _SosFlowSheetState extends State<_SosFlowSheet> {
  int _step = 0;

  static const _steps = [
    ('Location found', 'Your current area is attached to the request.'),
    ('Signal checked', 'The app is choosing the strongest available path.'),
    (
      'Emergency backup ready',
      'Nearby relay points can help send your request.',
    ),
    ('Responder notified', 'Your request appears in the responder dashboard.'),
  ];

  Future<void> _send() async {
    for (var index = 0; index < _steps.length; index++) {
      if (!mounted) {
        return;
      }
      setState(() => _step = index);
      await Future<void>.delayed(const Duration(milliseconds: 420));
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sos, color: AppTheme.dangerRed),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Send Disaster Distress Ping',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < _steps.length; index++) ...[
            _SosStepTile(
              title: _steps[index].$1,
              subtitle: _steps[index].$2,
              active: index <= _step,
            ),
            if (index != _steps.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _send,
            icon: const Icon(Icons.hub),
            label: const Text('Send Emergency Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _SosStepTile extends StatelessWidget {
  const _SosStepTile({
    required this.title,
    required this.subtitle,
    required this.active,
  });

  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          active ? Icons.check_circle : Icons.radio_button_unchecked,
          color: active ? AppTheme.safeGreen : AppTheme.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _HazardMetrics extends StatelessWidget {
  const _HazardMetrics();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _MetricCard(
            icon: Icons.water_drop,
            label: 'Flood Risk',
            value: 'Low',
            color: AppTheme.safeGreen,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.cloudy_snowing,
            label: 'Rainfall',
            value: '1.2 mm/h',
            color: AppTheme.signalBlue,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.thermostat,
            label: 'Temp',
            value: '28 C',
            color: AppTheme.dangerRed,
          ),
        ),
      ],
    );
  }
}

class _FloodPredictionCard extends StatelessWidget {
  const _FloodPredictionCard();

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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.signalBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_graph,
                    color: AppTheme.signalBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Flood Forecast',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Plain-language warning for nearby barangays',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _PredictionRow(
              icon: Icons.schedule,
              title: 'Arrival time',
              value: 'San Felipe: about 45 min',
              color: AppTheme.warningAmber,
            ),
            const SizedBox(height: 10),
            const _PredictionRow(
              icon: Icons.height,
              title: 'Expected peak level',
              value: 'Up to 1.4 m in low areas',
              color: AppTheme.signalBlue,
            ),
            const SizedBox(height: 10),
            const _PredictionRow(
              icon: Icons.flash_on,
              title: 'Early warning',
              value: 'Flash flood risk in 30-60 min',
              color: AppTheme.dangerRed,
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (action != null)
          Text(
            action!,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppTheme.signalBlue),
          ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _IconBox(icon: icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: _StatusPill(label: label, color: color),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
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

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    );
  }
}
