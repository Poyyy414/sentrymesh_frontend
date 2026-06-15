import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../data/models/family_member_model.dart';
import 'widgets/family_member_tile.dart';
import 'widgets/family_status_card.dart';

class FamilySafetyScreen extends StatefulWidget {
  const FamilySafetyScreen({super.key});

  @override
  State<FamilySafetyScreen> createState() => _FamilySafetyScreenState();
}

class _FamilySafetyScreenState extends State<FamilySafetyScreen> {
  List<FamilyMemberModel> _members = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && _members.isEmpty && _error == null) {
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final members = await AppDependenciesScope.of(
        context,
      ).familyRepository.fetchMembers();
      if (!mounted) return;
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F9FC),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _FamilySafetyHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 30 : 14,
                      18,
                      wide ? 30 : 14,
                      24,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const FamilyStatusCard(),
                              const SizedBox(height: 20),
                              _FamilyMembersHeading(count: _members.length),
                              const SizedBox(height: 10),
                              if (_isLoading)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (_error != null)
                                Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        'Could not load family members: $_error',
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: _loadMembers,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                )
                              else if (_members.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Center(
                                    child: Text('No family members added yet.'),
                                  ),
                                )
                              else
                                for (final member in _members) ...[
                                  _MemberTile(member: member),
                                  const SizedBox(height: 8),
                                ],
                              const SizedBox(height: 16),
                              const _FamilyActionRow(
                                key: Key('check_in_all_family_action'),
                                icon: Icons.groups_rounded,
                                title: 'Check-in All Family',
                                subtitle:
                                    'Send a check-in request to all family members',
                                color: AppTheme.signalBlue,
                              ),
                              const SizedBox(height: 8),
                              const _FamilyActionRow(
                                key: Key('send_family_location_action'),
                                icon: Icons.location_on_rounded,
                                title: 'Send My Location',
                                subtitle:
                                    'Share your current location with your family',
                                color: AppTheme.signalBlue,
                              ),
                              const SizedBox(height: 8),
                              const _FamilyActionRow(
                                key: Key('family_emergency_message_action'),
                                icon: Icons.sos_rounded,
                                title: 'Emergency Message',
                                subtitle:
                                    'Send an emergency alert to notify your family',
                                color: AppTheme.dangerRed,
                                emergency: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilySafetyHeader extends StatelessWidget {
  const _FamilySafetyHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1456B7), Color(0xFF073B88)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: const Row(
        children: [
          SizedBox(
            width: 48,
            child: IconButton(
              key: Key('family_back_button'),
              onPressed: _ignoreTap,
              tooltip: 'Back',
              icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              'Family Safety Check',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _FamilyMembersHeading extends StatelessWidget {
  const _FamilyMembersHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Family Members',
            style: TextStyle(
              color: Color(0xFF102E58),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Icon(Icons.groups_outlined, color: AppTheme.signalBlue, size: 18),
        const SizedBox(width: 7),
        Text(
          '$count ${count == 1 ? 'Member' : 'Members'}',
          style: const TextStyle(
            color: Color(0xFF607895),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final FamilyMemberModel member;

  @override
  Widget build(BuildContext context) {
    final normalized = member.status.toLowerCase();
    final color = normalized.contains('help')
        ? AppTheme.dangerRed
        : normalized.contains('safe')
        ? AppTheme.safeGreen
        : AppTheme.warningAmber;
    final words = member.name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();

    return FamilyMemberTile(
      key: ValueKey('family_member_${member.id}'),
      initials: initials.isEmpty ? '?' : initials,
      name: member.name,
      relationship: member.relationship,
      status: member.status,
      updated: 'Updated: ${_relativeTime(member.updatedAt)}',
      color: color,
    );
  }
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}

class _FamilyActionRow extends StatelessWidget {
  const _FamilyActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.emergency = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool emergency;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emergency ? const Color(0xFFFFF3F4) : const Color(0xFFF4F8FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        onTap: _ignoreTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: emergency
                      ? AppTheme.dangerRed
                      : color.withValues(alpha: 0.09),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: emergency ? Colors.white : color,
                  size: emergency ? 23 : 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: emergency
                            ? AppTheme.dangerRed
                            : const Color(0xFF103B72),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF687B92),
                        fontSize: 10,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: emergency ? AppTheme.dangerRed : color,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _ignoreTap() {}
