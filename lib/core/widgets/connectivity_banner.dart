import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../services/connectivity_service.dart';

/// Shown whenever the shell isn't fully online, so offline/limited state and
/// any operations still waiting to sync are visible instead of silent.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({
    required this.status,
    required this.pendingCount,
    super.key,
  });

  final ConnectivityStatus status;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final isOffline = status == ConnectivityStatus.offline;
    final color = isOffline ? AppTheme.dangerRed : const Color(0xFFE8A317);
    final icon = isOffline
        ? Icons.cloud_off_rounded
        : Icons.cloud_queue_rounded;
    final label = isOffline ? 'Offline' : 'Limited connection';
    final queueLabel = pendingCount > 0 ? ' - $pendingCount queued' : '';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 4,
        bottom: 4,
        left: 16,
        right: 16,
      ),
      color: color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$label$queueLabel',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
