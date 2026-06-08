import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
          children: [
            Text('Messages', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Official updates and family check-ins.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            _MessageTile(
              icon: Icons.campaign_outlined,
              title: 'Responder Advisory',
              subtitle: 'Evacuation route remains open.',
              color: AppTheme.signalBlue,
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRouter.messageDetails),
            ),
            const SizedBox(height: 10),
            const _MessageTile(
              icon: Icons.home_rounded,
              title: 'Evacuation Center',
              subtitle: 'Naga City Coliseum has available shelter space.',
              color: AppTheme.safeGreen,
            ),
            const SizedBox(height: 10),
            const _MessageTile(
              icon: Icons.water_drop_outlined,
              title: 'Flood Watch',
              subtitle: 'Avoid low roads near San Felipe for the next hour.',
              color: AppTheme.warningAmber,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap ?? () {},
      ),
    );
  }
}
