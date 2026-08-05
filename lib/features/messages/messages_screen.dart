import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/family_invite_model.dart';
import '../../data/models/notification_model.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<FamilyInviteModel> _invites = [];
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _respondingInviteIds = {};

  StreamSubscription<Map<String, Object?>>? _inviteSub;
  StreamSubscription<Map<String, Object?>>? _inviteAcceptedSub;
  StreamSubscription<Map<String, Object?>>? _sosStatusSub;
  StreamSubscription<Map<String, Object?>>? _familyStatusSub;
  StreamSubscription<void>? _reconnectSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _load();
      final socket = AppDependenciesScope.of(context).towerSocket;
      _inviteSub ??= socket.onFamilyInvite.listen((_) => _load());
      _inviteAcceptedSub ??= socket.onFamilyInviteAccepted.listen(
        (_) => _load(),
      );
      // Rescue-status and family-status updates used to only ever reach the
      // user as a one-shot socket event (tray popup / snackbar) - refetch so
      // they land in the persisted Notifications list too, not just a popup
      // you could've missed.
      _sosStatusSub ??= socket.onSosStatus.listen((_) => _load());
      _familyStatusSub ??= socket.onFamilyStatusUpdate.listen((_) => _load());
      // The socket disconnects and reconnects periodically (Render resets
      // idle connections roughly every minute) - anything broadcast during
      // that few-second gap is otherwise lost, so refetch on every
      // reconnect rather than trusting push events alone.
      _reconnectSub ??= socket.onConnected.listen((_) => _load());
    }
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    _inviteAcceptedSub?.cancel();
    _sosStatusSub?.cancel();
    _familyStatusSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final deps = AppDependenciesScope.of(context);
      final invites = await deps.familyRepository.fetchInvites();
      final notifications = await deps.notificationRepository
          .fetchNotifications();
      if (!mounted) return;
      setState(() {
        _invites = invites;
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load messages: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _respondToInvite(FamilyInviteModel invite, bool accept) async {
    setState(() => _respondingInviteIds.add(invite.id));
    try {
      final deps = AppDependenciesScope.of(context);
      if (accept) {
        await deps.familyRepository.acceptInvite(invite.id);
      } else {
        await deps.familyRepository.declineInvite(invite.id);
      }
      if (!mounted) return;
      setState(() {
        _invites = _invites.where((i) => i.id != invite.id).toList();
        _respondingInviteIds.remove(invite.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Added ${invite.fromName} to your family list'
                : 'Declined ${invite.fromName}\'s invite',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _respondingInviteIds.remove(invite.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not respond to invite: $e')),
      );
    }
  }

  Future<void> _openNotification(NotificationModel notification) async {
    if (notification.read) return;
    setState(() {
      _notifications = _notifications
          .map(
            (n) => n.id == notification.id
                ? NotificationModel(
                    id: n.id,
                    type: n.type,
                    title: n.title,
                    message: n.message,
                    read: true,
                    createdAt: n.createdAt,
                  )
                : n,
          )
          .toList();
    });
    try {
      await AppDependenciesScope.of(
        context,
      ).notificationRepository.markRead(notification.id);
    } catch (_) {
      // Best-effort — the item still shows as read locally for this session.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
            children: [
              Text(
                'Messages',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Family invites and updates about your requests.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              if (!_isLoading && _invites.isNotEmpty) ...[
                Text(
                  'Family Invites',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                for (final invite in _invites) ...[
                  _InviteTile(
                    invite: invite,
                    isResponding: _respondingInviteIds.contains(invite.id),
                    onAccept: () => _respondToInvite(invite, true),
                    onDecline: () => _respondToInvite(invite, false),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
              ],
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (_notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                )
              else
                for (final notification in _notifications) ...[
                  _NotificationTile(
                    notification: notification,
                    onTap: () => _openNotification(notification),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.invite,
    required this.isResponding,
    required this.onAccept,
    required this.onDecline,
  });

  final FamilyInviteModel invite;
  final bool isResponding;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF4F8FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.signalBlue.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFDCE8FF),
              child: Icon(Icons.person_add_alt_1_rounded,
                  color: AppTheme.signalBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${invite.fromName} wants to add you as a family member',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            if (isResponding)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              IconButton(
                onPressed: onDecline,
                icon: const Icon(Icons.close_rounded, color: AppTheme.dangerRed),
                tooltip: 'Decline',
              ),
              IconButton(
                onPressed: onAccept,
                icon: const Icon(Icons.check_rounded, color: AppTheme.safeGreen),
                tooltip: 'Accept',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  IconData get _icon {
    return switch (notification.type) {
      'rescue_status' => Icons.local_shipping_rounded,
      'family_status' => Icons.groups_rounded,
      _ => Icons.notifications_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: notification.read ? null : const Color(0xFFF4F8FF),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.signalBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_icon, color: AppTheme.signalBlue),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.read ? FontWeight.w600 : FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${notification.message} · ${DateFormatter.compact(notification.createdAt.toLocal())}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}
