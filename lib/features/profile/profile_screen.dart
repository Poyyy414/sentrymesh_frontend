import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Profile',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('JP')),
              title: Text('John Paul A. Cambiado'),
              subtitle: Text('NCF-ApexNode'),
            ),
          ),
        ],
      ),
    );
  }
}
