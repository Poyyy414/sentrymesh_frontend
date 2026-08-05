import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../state/turn_by_turn.dart';

String formatTurnDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Top HUD card shown while guidance is active - a big current-maneuver
/// arrow with live distance, plus an "and then" preview of the step after
/// it. No street names: see computeTurnSteps for why that isn't available.
class TurnByTurnInstructionCard extends StatelessWidget {
  const TurnByTurnInstructionCard({
    required this.currentStep,
    required this.nextStep,
    super.key,
  });

  final TurnStep? currentStep;
  final TurnStep? nextStep;

  @override
  Widget build(BuildContext context) {
    final step = currentStep;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            color: Colors.black,
            child: Row(
              children: [
                Icon(
                  step != null
                      ? iconForManeuver(step.maneuver)
                      : Icons.flag_rounded,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step != null
                            ? formatTurnDistance(step.legDistanceMeters)
                            : 'Arriving',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        step != null
                            ? labelForManeuver(step.maneuver)
                            : labelForManeuver(ManeuverType.arrive),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (nextStep != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              color: const Color(0xFF1C1C1E),
              child: Row(
                children: [
                  Text(
                    'and then',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    iconForManeuver(nextStep!.maneuver),
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 20,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom HUD bar shown while guidance is active - speed, remaining
/// distance/ETA, and a Stop button. Replaces the plain _RouteSummaryCard
/// for the duration of guidance.
class TurnByTurnSummaryBar extends StatelessWidget {
  const TurnByTurnSummaryBar({
    required this.remainingDistanceKm,
    required this.etaMinutes,
    required this.onStop,
    this.speedKmh,
    super.key,
  });

  final double? speedKmh;
  final double remainingDistanceKm;
  final int etaMinutes;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            _SpeedBadge(speedKmh: speedKmh),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$etaMinutes min',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                  Text(
                    '${remainingDistanceKm.toStringAsFixed(1)} km remaining',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onStop,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.dangerRed,
                side: const BorderSide(color: AppTheme.dangerRed),
              ),
              child: const Text('Stop'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedBadge extends StatelessWidget {
  const _SpeedBadge({required this.speedKmh});

  final double? speedKmh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              speedKmh != null ? speedKmh!.round().toString() : '0',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
            Text(
              'km/h',
              style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
