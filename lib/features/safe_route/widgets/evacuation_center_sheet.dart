import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/evacuation_center_model.dart';

class EvacuationCenterSheet extends StatelessWidget {
  const EvacuationCenterSheet({
    required this.center,
    required this.distanceKm,
    required this.onNavigate,
    super.key,
  });

  final EvacuationCenterModel center;
  final double? distanceKm;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final capacityFraction =
        center.capacity > 0 ? center.currentOccupancy / center.capacity : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: center.isOpen
                      ? AppTheme.safeGreen.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.home_rounded,
                  color: center.isOpen ? AppTheme.safeGreen : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      center.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                    Text(
                      center.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: center.isOpen
                      ? AppTheme.safeGreen.withValues(alpha: 0.12)
                      : AppTheme.dangerRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  center.isOpen ? 'OPEN' : 'CLOSED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: center.isOpen
                        ? AppTheme.safeGreen
                        : AppTheme.dangerRed,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Capacity bar
          Row(
            children: [
              const Text(
                'Capacity',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.navy,
                ),
              ),
              const Spacer(),
              Text(
                '${center.currentOccupancy} / ${center.capacity}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: capacityFraction > 0.9
                      ? AppTheme.dangerRed
                      : AppTheme.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: capacityFraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                capacityFraction > 0.9
                    ? AppTheme.dangerRed
                    : capacityFraction > 0.7
                        ? const Color(0xFFE8A317)
                        : AppTheme.safeGreen,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${center.availableSlots} slots available',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: center.availableSlots > 0
                  ? AppTheme.safeGreen
                  : AppTheme.dangerRed,
            ),
          ),

          if (distanceKm != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.straighten_rounded, size: 14, color: AppTheme.navy),
                const SizedBox(width: 6),
                Text(
                  '${distanceKm!.toStringAsFixed(1)} km away',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navy,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Navigate button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: center.isOpen ? onNavigate : null,
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: const Text('Navigate here'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.signalBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
