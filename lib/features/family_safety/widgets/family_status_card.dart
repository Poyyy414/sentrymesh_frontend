import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class FamilyStatusCard extends StatelessWidget {
  const FamilyStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
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
                const DecoratedBox(
                  decoration: BoxDecoration(
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
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Status',
                          style: TextStyle(
                            color: Color(0xFF102E58),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 14),
                        Row(
                          children: [
                            _SafeShield(),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You are Safe',
                                    style: TextStyle(
                                      color: AppTheme.safeGreen,
                                      fontSize: 22,
                                      height: 1.1,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Last updated: Today, 7:45 AM',
                                    style: TextStyle(
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
                  onPressed: _ignoreTap,
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

class _SafeShield extends StatelessWidget {
  const _SafeShield();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF20C576), Color(0xFF079954)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x2514A267),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
    );
  }
}

void _ignoreTap() {}
