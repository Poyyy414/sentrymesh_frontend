import 'package:flutter/material.dart';

class FamilyMemberTile extends StatelessWidget {
  const FamilyMemberTile({
    required this.initials,
    required this.name,
    required this.relationship,
    required this.status,
    required this.updated,
    required this.color,
    super.key,
  });

  final String initials;
  final String name;
  final String relationship;
  final String status;
  final String updated;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Text(
            initials,
            style: const TextStyle(
              color: Color(0xFF172437),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text('$name ($relationship)'),
        subtitle: Text(updated),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
