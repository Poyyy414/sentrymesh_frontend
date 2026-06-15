import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class EmergencyContactsList extends StatelessWidget {
  const EmergencyContactsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency Contacts',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              const _ContactTile(
                initials: 'ML',
                name: 'Maria Lopez',
                relationship: 'Wife',
                phone: '+63 917 123 4567',
              ),
              const Divider(height: 1),
              const _ContactTile(
                initials: 'JD',
                name: 'Juan dela Cruz',
                relationship: 'Brother',
                phone: '+63 912 987 6543',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.initials,
    required this.name,
    required this.relationship,
    required this.phone,
  });

  final String initials;
  final String name;
  final String relationship;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.signalBlue.withValues(alpha: 0.12),
        child: Text(
          initials,
          style: const TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        '$name ($relationship)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(phone, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        onPressed: () {},
        tooltip: 'Call $name',
        icon: const Icon(Icons.phone, color: AppTheme.textMuted),
      ),
    );
  }
}
