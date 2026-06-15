import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class SosButton extends StatelessWidget {
  const SosButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Emergency SOS',
      child: Material(
        color: AppTheme.dangerRed,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppTheme.dangerRed.withValues(alpha: 0.35),
        elevation: 3,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 126),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'EMERGENCY',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          'SOS',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.white, fontSize: 31),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Press and hold to send distress signal',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
