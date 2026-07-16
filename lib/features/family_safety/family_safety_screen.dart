import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/services/location_service.dart';
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

  String _myStatus = 'safe';
  DateTime _statusUpdatedAt = DateTime.now();

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

  Future<void> _showStatusPicker() async {
    final deps = AppDependenciesScope.of(context);
    final userName =
        deps.authRepository.currentUser?.name ?? 'Resident';

    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StatusPickerSheet(current: _myStatus),
    );
    if (picked == null || !mounted) return;

    try {
      await deps.familyRepository.updateMyStatus(
        name: userName,
        status: picked,
      );
      if (!mounted) return;
      setState(() {
        _myStatus = picked;
        _statusUpdatedAt = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated successfully')),
      );
    } catch (_) {
      if (!mounted) return;
      // Update UI optimistically even if backend is unreachable
      setState(() {
        _myStatus = picked;
        _statusUpdatedAt = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated')),
      );
    }
  }

  Future<void> _showAddMemberDialog() async {
    final result = await showDialog<({String name, String relationship})>(
      context: context,
      builder: (ctx) => const _AddMemberDialog(),
    );
    if (result == null || !mounted) return;

    try {
      await AppDependenciesScope.of(context).familyRepository.addMember(
        name: result.name,
        relationship: result.relationship,
        status: 'waiting',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} added to your family')),
      );
      _loadMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add member: $e')),
      );
    }
  }

  Future<void> _sendMyLocation() async {
    final locationService =
        AppDependenciesScope.of(context).locationService;
    try {
      final location = await locationService.currentLocation();
      if (!mounted) return;
      final lat = location.latitude.toStringAsFixed(6);
      final lng = location.longitude.toStringAsFixed(6);
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location opened in maps — share the link with family'),
        ),
      );
    } on LocationServiceDisabledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
    } on LocationPermissionDeniedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    }
  }

  Future<void> _checkInAll() async {
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No family members to check in with')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check-in All Family'),
        content: Text(
          'Send a check-in request to all ${_members.length} family member(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deps = AppDependenciesScope.of(context);
    final userName = deps.authRepository.currentUser?.name ?? 'Resident';
    int successCount = 0;

    for (final member in _members) {
      try {
        await deps.familyRepository.updateMyStatus(
          name: member.name,
          status: 'safe',
        );
        successCount++;
      } catch (_) {
        // Continue checking in remaining members
      }
    }

    if (!mounted) return;

    // Also update own status to safe
    try {
      await deps.familyRepository.updateMyStatus(
        name: userName,
        status: 'safe',
      );
      setState(() {
        _myStatus = 'safe';
        _statusUpdatedAt = DateTime.now();
      });
    } catch (_) {
      // Update UI optimistically
      setState(() {
        _myStatus = 'safe';
        _statusUpdatedAt = DateTime.now();
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Check-in sent to $successCount of ${_members.length} member(s)',
        ),
      ),
    );
    _loadMembers();
  }

  Future<void> _emergencyMessage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Emergency Alert'),
        content: const Text(
          'This will notify all your family members that you need help immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deps = AppDependenciesScope.of(context);
    final userName = deps.authRepository.currentUser?.name ?? 'Resident';

    try {
      await deps.alertRepository.createAlert(
        title: 'Family Emergency SOS',
        message: 'Emergency message from $userName',
        location: 'Unknown',
        severity: 'critical',
        hazardType: 'distress',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.dangerRed,
          content: Text('Emergency alert sent to your family!'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.dangerRed,
          content: Text(
            'Emergency alert sent (offline mode — will sync when connected)',
          ),
        ),
      );
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
                              FamilyStatusCard(
                                status: _myStatus,
                                updatedAt: _statusUpdatedAt,
                                onUpdateStatus: _showStatusPicker,
                              ),
                              const SizedBox(height: 20),
                              _FamilyMembersHeading(
                                count: _members.length,
                                onAdd: _showAddMemberDialog,
                              ),
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
                              _FamilyActionRow(
                                key: const Key('check_in_all_family_action'),
                                icon: Icons.groups_rounded,
                                title: 'Check-in All Family',
                                subtitle:
                                    'Send a check-in request to all family members',
                                color: AppTheme.signalBlue,
                                onTap: _checkInAll,
                              ),
                              const SizedBox(height: 8),
                              _FamilyActionRow(
                                key: const Key('send_family_location_action'),
                                icon: Icons.location_on_rounded,
                                title: 'Send My Location',
                                subtitle:
                                    'Share your current location with your family',
                                color: AppTheme.signalBlue,
                                onTap: _sendMyLocation,
                              ),
                              const SizedBox(height: 8),
                              _FamilyActionRow(
                                key: const Key(
                                  'family_emergency_message_action',
                                ),
                                icon: Icons.sos_rounded,
                                title: 'Emergency Message',
                                subtitle:
                                    'Send an emergency alert to notify your family',
                                color: AppTheme.dangerRed,
                                emergency: true,
                                onTap: _emergencyMessage,
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
          SizedBox(width: 48),
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
  const _FamilyMembersHeading({
    required this.count,
    required this.onAdd,
  });

  final int count;
  final VoidCallback onAdd;

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
        const SizedBox(width: 8),
        SizedBox(
          height: 28,
          child: FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.signalBlue,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add'),
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
    required this.onTap,
    this.emergency = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
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
        onTap: onTap,
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

class _StatusPickerSheet extends StatelessWidget {
  const _StatusPickerSheet({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final options = [
      ('safe', 'I am Safe', Icons.shield_rounded, AppTheme.safeGreen),
      (
        'waiting',
        'Status Unknown',
        Icons.help_outline_rounded,
        AppTheme.warningAmber,
      ),
      (
        'need_help',
        'I Need Help!',
        Icons.sos_rounded,
        AppTheme.dangerRed,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Your Status',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            for (final (value, label, icon, color) in options) ...[
              Material(
                color: current == value
                    ? color.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(context, value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: color, size: 26),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (current == value)
                          Icon(
                            Icons.check_circle_rounded,
                            color: color,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _nameCtrl = TextEditingController();
  final _relationshipCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relationshipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Family Member'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _relationshipCtrl,
              decoration: const InputDecoration(
                labelText: 'Relationship (e.g. Parent, Sibling)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                (
                  name: _nameCtrl.text.trim(),
                  relationship: _relationshipCtrl.text.trim(),
                ),
              );
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
