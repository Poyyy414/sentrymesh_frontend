import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/services/location_service.dart';
import '../../data/models/family_member_model.dart';
import 'widgets/add_member_dialog.dart';
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
    final userName = deps.authRepository.currentUser?.name ?? 'Resident';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Status updated')));
    }
  }

  Future<void> _showAddMemberDialog() async {
    final result = await showDialog<AddMemberResult>(
      context: context,
      builder: (ctx) => const AddMemberDialog(),
    );
    if (result == null || !mounted) return;

    try {
      await AppDependenciesScope.of(context).familyRepository.addMember(
        name: result.name,
        relationship: result.relationship,
        status: 'waiting',
        phoneNumber: result.phone,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} added to your family')),
      );
      _loadMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add member: $e')));
    }
  }

  Future<void> _removeMember(FamilyMemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Family Member'),
        content: Text(
          'Remove ${member.name} from your family? They will no longer share their safety status with you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await AppDependenciesScope.of(
        context,
      ).familyRepository.removeMember(member.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} removed from your family')),
      );
      _loadMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove member: $e')));
    }
  }

  Future<void> _sendMyLocation() async {
    final deps = AppDependenciesScope.of(context);
    final locationService = deps.locationService;
    final userName = deps.authRepository.currentUser?.name ?? 'Resident';
    try {
      final location = await locationService.currentLocation();
      if (!mounted) return;
      final lat = location.latitude.toStringAsFixed(6);
      final lng = location.longitude.toStringAsFixed(6);
      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      await deps.familyRepository.updateMyStatus(
        name: userName,
        status: 'Location shared: $lat, $lng - $mapsUrl',
      );
      if (!mounted) return;
      setState(() {
        _myStatus = 'safe';
        _statusUpdatedAt = DateTime.now();
      });
      _loadMembers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sent to your family in the app.'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
    }
  }

  /// Members that can actually be reached (have a phone number).
  List<FamilyMemberModel> get _reachableMembers => _members
      .where((m) => (m.phoneNumber ?? '').trim().isNotEmpty)
      .toList();

  /// Sends [body] to every reachable family member and reports the outcome.
  Future<void> _broadcastToFamily(String body, {bool emergency = false}) async {
    final deps = AppDependenciesScope.of(context);
    final fromName = deps.authRepository.currentUser?.name ?? 'Resident';
    final recipients = _reachableMembers;

    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No family member has a phone number saved yet'),
        ),
      );
      return;
    }

    var online = 0;
    var failed = 0;
    for (final member in recipients) {
      try {
        await deps.familyRepository.sendMessage(
          toNumber: member.phoneNumber!.trim(),
          body: body,
          toName: member.name,
          fromName: fromName,
        );
        online++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;

    final parts = <String>[
      if (online > 0) '$online sent',
      if (failed > 0) '$failed failed (no connection)',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: emergency && failed == 0 ? AppTheme.dangerRed : null,
        content: Text(parts.join(' · ')),
      ),
    );
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
          'Send a check-in request to all ${_reachableMembers.length} family member(s) with a phone number?',
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
    final name = AppDependenciesScope.of(
      context,
    ).authRepository.currentUser?.name ?? 'A family member';
    await _broadcastToFamily(
      '$name is checking in — please reply with your safety status.',
    );
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
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final name = AppDependenciesScope.of(
      context,
    ).authRepository.currentUser?.name ?? 'A family member';
    await _broadcastToFamily(
      'SOS: $name needs help immediately. Please check on them now.',
      emergency: true,
    );
  }

  Future<void> _messageMember(FamilyMemberModel member) async {
    final number = (member.phoneNumber ?? '').trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} has no phone number saved')),
      );
      return;
    }
    final body = await showDialog<String>(
      context: context,
      builder: (ctx) => _ComposeMessageDialog(member: member),
    );
    if (body == null || body.trim().isEmpty || !mounted) return;

    final deps = AppDependenciesScope.of(context);
    final fromName = deps.authRepository.currentUser?.name ?? 'Resident';
    try {
      await deps.familyRepository.sendMessage(
        toNumber: number,
        body: body.trim(),
        toName: member.name,
        fromName: fromName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message sent to ${member.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send message to ${member.name} — no connection'),
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
                                  _MemberTile(
                                    member: member,
                                    onRemove: () => _removeMember(member),
                                    onMessage: () => _messageMember(member),
                                  ),
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
  const _FamilyMembersHeading({required this.count, required this.onAdd});

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
  const _MemberTile({
    required this.member,
    required this.onRemove,
    required this.onMessage,
  });

  final FamilyMemberModel member;
  final VoidCallback onRemove;
  final VoidCallback onMessage;

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
      phoneNumber: member.phoneNumber,
      status: member.status,
      updated: 'Updated: ${_relativeTime(member.updatedAt)}',
      color: color,
      onRemove: onRemove,
      onMessage: onMessage,
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
      ('need_help', 'I Need Help!', Icons.sos_rounded, AppTheme.dangerRed),
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

class _ComposeMessageDialog extends StatefulWidget {
  const _ComposeMessageDialog({required this.member});

  final FamilyMemberModel member;

  @override
  State<_ComposeMessageDialog> createState() => _ComposeMessageDialogState();
}

class _ComposeMessageDialogState extends State<_ComposeMessageDialog> {
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    return AlertDialog(
      title: Text('Message ${member.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.phone_rounded,
                  size: 14,
                  color: Color(0xFF4E6885),
                ),
                const SizedBox(width: 6),
                Text(
                  member.phoneNumber ?? '',
                  style: const TextStyle(
                    color: Color(0xFF4E6885),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyCtrl,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Type your message…',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a message' : null,
            ),
            const Text(
              'Sent over the internet. Requires a connection.',
              style: TextStyle(fontSize: 11, color: Color(0xFF687B92)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _bodyCtrl.text.trim());
            }
          },
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Send'),
        ),
      ],
    );
  }
}
