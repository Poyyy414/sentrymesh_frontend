import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class AlertListCard extends StatelessWidget {
  const AlertListCard({
    required this.title,
    required this.location,
    required this.description,
    required this.severity,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.onTap,
    super.key,
  });

  final String title;
  final String location;
  final String description;
  final String severity;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _Badge(label: severity, color: color),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          location,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onTap ?? () {},
                style: OutlinedButton.styleFrom(
                  backgroundColor: backgroundColor.withValues(alpha: 0.55),
                  foregroundColor: const Color(0xFF0A3A68),
                  side: BorderSide(color: color.withValues(alpha: 0.18)),
                  minimumSize: const Size.fromHeight(42),
                ),
                child: const Text('View Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
