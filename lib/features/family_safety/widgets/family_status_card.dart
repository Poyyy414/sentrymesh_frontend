import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class FamilyStatusCard extends StatelessWidget {
  const FamilyStatusCard({
    required this.status,
    required this.updatedAt,
    required this.onUpdateStatus,
    super.key,
  });

  final String status;
  final DateTime updatedAt;
  final VoidCallback onUpdateStatus;

  static String _label(String status) {
    return switch (status) {
      'safe' => 'You are Safe',
      'need_help' => 'Need Help!',
      _ => 'Status Unknown',
    };
  }

  static Color _color(String status) {
    return switch (status) {
      'safe' => AppTheme.safeGreen,
      'need_help' => AppTheme.dangerRed,
      _ => AppTheme.warningAmber,
    };
  }

  static String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _color(status);
    return Container(
      key: const Key('family_status_card'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFDCE5EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1015365B),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/family_safety_background.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    color: Colors.white.withValues(alpha: 0.18),
                    colorBlendMode: BlendMode.srcOver,
                  ),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white,
                        Color(0xF5FFFFFF),
                        Color(0x72FFFFFF),
                      ],
                      stops: [0, 0.5, 1],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Status',
                          style: TextStyle(
                            color: Color(0xFF102E58),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _StatusShield(status: status),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _label(status),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 22,
                                      height: 1.1,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Last updated: ${_timeLabel(updatedAt)}',
                                    style: const TextStyle(
                                      color: Color(0xFF687B92),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1268D6), Color(0xFF07479E)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x221268D6),
                      blurRadius: 9,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  key: const Key('update_family_status_button'),
                  onPressed: onUpdateStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  label: const Text(
                    'Update My Status',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusShield extends StatelessWidget {
  const _StatusShield({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (gradient, icon) = switch (status) {
      'safe' => (
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF20C576), Color(0xFF079954)],
        ),
        Icons.shield_rounded,
      ),
      'need_help' => (
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF4C5E), Color(0xFFCC1627)],
        ),
        Icons.sos_rounded,
      ),
      _ => (
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        Icons.help_outline_rounded,
      ),
    };

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x2514A267),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 32),
    );
  }
}
