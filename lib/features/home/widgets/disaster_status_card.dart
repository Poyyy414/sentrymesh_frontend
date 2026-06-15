import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class DisasterStatusCard extends StatelessWidget {
  const DisasterStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minHeight: 126),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFEFFAF3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -14,
              child: Icon(
                Icons.landscape_rounded,
                color: AppTheme.safeGreen.withValues(alpha: 0.16),
                size: 92,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: AppTheme.safeGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'DISASTER STATUS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'SAFE',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.safeGreen,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No significant threats in your area',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
