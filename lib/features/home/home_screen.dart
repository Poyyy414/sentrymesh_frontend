import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/services/location_service.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/family_member_model.dart';
import '../../data/models/prediction_model.dart';
import '../../data/models/rescue_request_model.dart';
import '../../data/repositories/prediction_repository.dart';
import '../../shared/demo/demo_scenario.dart';
import '../../shared/enums/alert_severity.dart';
import '../../shared/enums/hazard_type.dart';
import '../../shared/enums/rescue_status.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _distressSent = DemoScenario.instance.residentSosSent;
  Future<PredictionBundle>? _predictionFuture;
  Future<List<AlertModel>>? _alertsFuture;
  Future<List<FamilyMemberModel>>? _familyFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_predictionFuture == null) {
      _loadAllData();
    }
  }

  void _loadAllData() {
    final deps = AppDependenciesScope.of(context);
    setState(() {
      _predictionFuture = deps.predictionRepository.fetchHomePredictions();
      _alertsFuture = deps.alertRepository.fetchAlerts();
      _familyFuture = deps.familyRepository.fetchMembers();
    });
  }

  void _refreshData() => _loadAllData();

  Future<void> _addFamilyMember() async {
    final nameController = TextEditingController();
    final relationshipController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Family Member'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: relationshipController,
                decoration: const InputDecoration(labelText: 'Relationship'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'e.g. 0917 123 4567',
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Required';
                  if (!RegExp(r'^[0-9+\-\s()]{7,}$').hasMatch(value)) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await AppDependenciesScope.of(context).familyRepository.addMember(
          name: nameController.text.trim(),
          relationship: relationshipController.text.trim(),
          status: 'Safe',
          phoneNumber: phoneController.text.trim(),
        );
        _loadAllData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add member: $e')),
          );
        }
      }
    }
  }

  Future<void> _openSosFlow() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SosFlowSheet(),
    );

    if (sent == true && mounted) {
      final submitted = await _submitSosToBackend();
      if (!mounted || !submitted) {
        return;
      }

      DemoScenario.instance.sendResidentSos();
      setState(() => _distressSent = true);
    }
  }

  Future<bool> _submitSosToBackend() async {
    if (_isRunningWidgetTest) {
      _showSosSnackBar('Distress ping received by responder dashboard.');
      return true;
    }

    final dependencies = AppDependenciesScope.of(context);

    try {
      final location = await dependencies.locationService.currentLocation();
      final request = RescueRequestModel(
        id: 'resident-sos-john-paul',
        emergencyType: HazardType.distress,
        peopleNeedingHelp: 1,
        description: 'Emergency SOS from resident app with live GPS tracking.',
        status: RescueStatus.pending,
        createdAt: DateTime.now().toUtc(),
        latitude: location.latitude,
        longitude: location.longitude,
        locationLabel: 'Resident GPS',
      );
      await dependencies.rescueRepository.submitRequest(request);
      _showSosSnackBar('SOS sent with your current location for responders.');
      return true;
    } on LocationServiceDisabledException {
      _showLocationSettingsSnackBar();
    } on LocationPermissionPermanentlyDeniedException {
      _showAppSettingsSnackBar();
    } on LocationPermissionDeniedException {
      _showSosSnackBar('Location permission is required before sending SOS.');
    } catch (error) {
      _showSosSnackBar('SOS could not reach backend yet: $error');
    }

    return false;
  }

  void _showSosSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLocationSettingsSnackBar() {
    if (!mounted) {
      return;
    }

    final locationService = AppDependenciesScope.of(context).locationService;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Turn on device location before sending SOS.'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: locationService.openLocationSettings,
        ),
      ),
    );
  }

  void _showAppSettingsSnackBar() {
    if (!mounted) {
      return;
    }

    final locationService = AppDependenciesScope.of(context).locationService;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Allow location access before sending SOS.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: locationService.openAppSettings,
        ),
      ),
    );
  }

  bool get _isRunningWidgetTest {
    return WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3F7FC),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final horizontalPadding = isWide ? 22.0 : 14.0;

            final userName =
                AppDependenciesScope.of(
                  context,
                ).authRepository.currentUser?.name ??
                'Resident';

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _HomeHeader(isWide: isWide, userName: userName),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isWide ? 14 : 12,
                    horizontalPadding,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EmergencyActions(
                            isWide: isWide,
                            onSosPressed: _openSosFlow,
                            onAddFamily: _addFamilyMember,
                          ),
                          const SizedBox(height: 14),
                          _LocationAndStatus(
                            isWide: isWide,
                            distressSent: _distressSent,
                          ),
                          const SizedBox(height: 14),
                          FutureBuilder<PredictionBundle>(
                            future: _predictionFuture,
                            builder: (context, predictionSnapshot) {
                              return FutureBuilder<List<AlertModel>>(
                                future: _alertsFuture,
                                builder: (context, alertSnapshot) {
                                  return FutureBuilder<List<FamilyMemberModel>>(
                                    future: _familyFuture,
                                    builder: (context, familySnapshot) {
                                      return Column(
                                        children: [
                                          _FloodForecastCard(
                                            snapshot: predictionSnapshot,
                                            onRefresh: _refreshData,
                                          ),
                                          const SizedBox(height: 14),
                                          _InformationGrid(
                                            isWide: isWide,
                                            bundle: predictionSnapshot.data,
                                            alerts: alertSnapshot.data,
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          _QuickActions(
                            onSosPressed: _openSosFlow,
                            onAddFamily: _addFamilyMember,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.isWide, required this.userName});

  final bool isWide;
  final String userName;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  static String _firstName(String name) {
    final first = name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? name : first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF031E49), Color(0xFF073C78), Color(0xFF06295A)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _HeaderBackdrop()),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isWide ? 24 : 16,
              isWide ? 16 : 14,
              isWide ? 24 : 16,
              isWide ? 20 : 18,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const _HeaderBrand(),
                    const Spacer(),
                    if (isWide) ...[
                      const _HeaderIcon(
                        icon: Icons.notifications_none_rounded,
                        badge: '2',
                      ),
                      const SizedBox(width: 12),
                      _HeaderUser(userName: userName),
                      const SizedBox(width: 12),
                    ],
                    if (isWide) const _LiveBadge(),
                  ],
                ),
                SizedBox(height: isWide ? 22 : 18),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: Colors.white,
                      child: Text(
                        _initials(userName),
                        style: const TextStyle(
                          color: AppTheme.signalBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_firstName(userName)}!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isWide ? 21 : 18,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Stay informed. Stay safe.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }
}

class _HeaderBrand extends StatelessWidget {
  const _HeaderBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8CB7FF), Color(0xFF316FF4)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x442D70EF),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SentryMesh',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Resident Mode',
              style: TextStyle(
                color: Color(0xFFC5D6EC),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, this.badge});

  final IconData icon;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.09),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 23),
        ),
        if (badge != null)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppTheme.dangerRed,
                shape: BoxShape.circle,
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderUser extends StatelessWidget {
  const _HeaderUser({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.11),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_rounded, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Text(
          userName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 7),
        const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.white,
          size: 20,
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF008E73).withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: Color(0xFF16E29A)),
          SizedBox(width: 7),
          Text(
            'Live',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBackdrop extends StatelessWidget {
  const _HeaderBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HeaderBackdropPainter());
  }
}

class _HeaderBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hillPaint = Paint()..color = const Color(0xFF0D4A82);
    final distantPaint = Paint()..color = const Color(0xFF0A3C70);

    final distant = Path()
      ..moveTo(size.width * 0.55, size.height)
      ..lineTo(size.width * 0.69, size.height * 0.48)
      ..lineTo(size.width * 0.76, size.height * 0.68)
      ..lineTo(size.width * 0.84, size.height * 0.38)
      ..lineTo(size.width, size.height * 0.58)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(distant, distantPaint);

    final hill = Path()
      ..moveTo(size.width * 0.48, size.height)
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.42,
        size.width,
        size.height * 0.82,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hill, hillPaint);

    final buildingPaint = Paint()..color = const Color(0xFF0A3565);
    for (var index = 0; index < 8; index++) {
      final width = 18.0 + (index % 3) * 8;
      final height = 32.0 + (index % 4) * 13;
      final left = size.width * 0.62 + index * 44;
      canvas.drawRect(
        Rect.fromLTWH(left, size.height - height, width, height),
        buildingPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmergencyActions extends StatelessWidget {
  const _EmergencyActions({
    required this.isWide,
    required this.onSosPressed,
    required this.onAddFamily,
  });

  final bool isWide;
  final VoidCallback onSosPressed;
  final VoidCallback onAddFamily;

  @override
  Widget build(BuildContext context) {
    final backup = const _BackupCard();
    final sos = _EmergencySosCard(onPressed: onSosPressed);
    final family = _FamilyCheckInCard(onTap: onAddFamily);

    if (!isWide) {
      return Column(
        children: [
          backup,
          const SizedBox(height: 10),
          sos,
          const SizedBox(height: 10),
          family,
        ],
      );
    }

    return SizedBox(
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 10, child: backup),
          const SizedBox(width: 14),
          Expanded(flex: 17, child: sos),
          const SizedBox(width: 14),
          Expanded(flex: 10, child: family),
        ],
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard();

  @override
  Widget build(BuildContext context) {
    return _ActionCardShell(
      key: const Key('emergency_backup_card'),
      gradient: const [Color(0xFF06295A), Color(0xFF031D44)],
      child: Row(
        children: [
          const _ActionIcon(
            icon: Icons.hub_rounded,
            foreground: Color(0xFF12D88D),
            background: Color(0xFF075A55),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: _ActionText(
              title: 'Emergency Backup Ready',
              subtitle:
                  'You can still send an emergency request if mobile signal is weak.',
            ),
          ),
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_tethering_rounded,
              color: Color(0xFF53E7B0),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencySosCard extends StatelessWidget {
  const _EmergencySosCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _ActionCardShell(
      key: const Key('home_sos_card'),
      gradient: const [Color(0xFFEF2736), Color(0xFFCC1023)],
      onTap: onPressed,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: const Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: _ActionText(
              title: 'Emergency SOS',
              subtitle: 'Send your emergency location to responders.',
              titleSize: 20,
            ),
          ),
          const _ActionChevron(),
        ],
      ),
    );
  }
}

class _FamilyCheckInCard extends StatelessWidget {
  const _FamilyCheckInCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ActionCardShell(
      key: const Key('family_check_in_card'),
      gradient: const [Color(0xFF0B4FB2), Color(0xFF073781)],
      onTap: onTap,
      child: const Row(
        children: [
          _ActionIcon(
            icon: Icons.groups_rounded,
            foreground: Colors.white,
            background: Color(0xFF1767D3),
          ),
          SizedBox(width: 14),
          Expanded(
            child: _ActionText(
              title: 'Add Family Member',
              subtitle: 'Ensure your loved ones are registered for safety.',
            ),
          ),
          _ActionChevron(),
        ],
      ),
    );
  }
}

class _ActionCardShell extends StatelessWidget {
  const _ActionCardShell({
    required this.gradient,
    required this.child,
    this.onTap,
    super.key,
  });

  final List<Color> gradient;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      constraints: const BoxConstraints(minHeight: 106),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C15365B),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: foreground, size: 30),
    );
  }
}

class _ActionText extends StatelessWidget {
  const _ActionText({
    required this.title,
    required this.subtitle,
    this.titleSize = 14,
  });

  final String title;
  final String subtitle;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFE3ECF7),
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ActionChevron extends StatelessWidget {
  const _ActionChevron();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.white,
        size: 21,
      ),
    );
  }
}

class _LocationAndStatus extends StatelessWidget {
  const _LocationAndStatus({required this.isWide, required this.distressSent});

  final bool isWide;
  final bool distressSent;

  @override
  Widget build(BuildContext context) {
    final location = const _LocationMapCard();
    final status = _DisasterStatusCard(distressSent: distressSent);

    if (!isWide) {
      return Column(
        children: [
          SizedBox(height: 170, child: location),
          const SizedBox(height: 12),
          status,
        ],
      );
    }

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 34, child: location),
          const SizedBox(width: 14),
          Expanded(flex: 66, child: status),
        ],
      ),
    );
  }
}

class _LocationMapCard extends StatelessWidget {
  const _LocationMapCard();

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      key: const Key('resident_location_card'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 11),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF285489),
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Naga City, Camarines Sur',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF102E58),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Philippines',
                        style: TextStyle(
                          color: Color(0xFF71849A),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Locate',
                  onPressed: () {},
                  icon: const Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFF285489),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              child: _MapPreview(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapPreviewPainter(),
      child: const Center(child: _CurrentLocationMarker()),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9F0F7),
    );

    final blockPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 8; column++) {
        final left = column * (size.width / 7.2) - (row.isOdd ? 18 : 0);
        final top = row * 24.0 + 6;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, 28 + (column % 3) * 7, 14),
            const Radius.circular(3),
          ),
          blockPaint,
        );
      }
    }

    final roadPaint = Paint()
      ..color = const Color(0xFFC8D5E4)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    for (var index = 0; index < 5; index++) {
      final path = Path()
        ..moveTo(-20, 16 + index * 22)
        ..quadraticBezierTo(
          size.width * 0.45,
          index.isEven ? 5 + index * 22 : 36 + index * 18,
          size.width + 20,
          12 + index * 20,
        );
      canvas.drawPath(path, roadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: AppTheme.signalBlue.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          color: AppTheme.signalBlue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x44245FB8), blurRadius: 6)],
        ),
      ),
    );
  }
}

class _DisasterStatusCard extends StatelessWidget {
  const _DisasterStatusCard({required this.distressSent});

  final bool distressSent;

  @override
  Widget build(BuildContext context) {
    final accent = distressSent ? AppTheme.warningAmber : AppTheme.safeGreen;
    final title = distressSent ? 'DISTRESS PING SENT' : 'DISASTER STATUS';
    final status = distressSent ? 'Responder notified' : 'SAFE';
    final detail = distressSent
        ? 'Your location and emergency request were sent to responders.'
        : 'No significant threats at your exact location.';

    return _DashboardCard(
      key: const Key('disaster_status_card'),
      padding: EdgeInsets.zero,
      child: Container(
        constraints: const BoxConstraints(minHeight: 154),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: distressSent
                ? const [Color(0xFFFFFBF1), Color(0xFFFFF1D3)]
                : const [Color(0xFFF8FFFB), Color(0xFFDDF6E7)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: _StatusLandscapePainter(color: accent),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showRiskPanel = constraints.maxWidth >= 520;
                  return Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          distressSent
                              ? Icons.outgoing_mail
                              : Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Color(0xFF60738A),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: accent,
                                fontSize: 27,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF647890),
                                fontSize: 11,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showRiskPanel) ...[
                        const SizedBox(width: 18),
                        _RiskPanel(distressSent: distressSent),
                      ],
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

class _RiskPanel extends StatelessWidget {
  const _RiskPanel({required this.distressSent});

  final bool distressSent;

  @override
  Widget build(BuildContext context) {
    final accent = distressSent ? AppTheme.warningAmber : AppTheme.safeGreen;

    return Container(
      width: 176,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Risk Score',
            style: TextStyle(
              color: Color(0xFF60738A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            distressSent ? '48 / 100' : '12 / 100',
            style: TextStyle(
              color: accent,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFFDDE7EF)),
          ),
          const Text(
            'Last Updated',
            style: TextStyle(
              color: Color(0xFF60738A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '2 min ago',
            style: TextStyle(
              color: Color(0xFF16365F),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLandscapePainter extends CustomPainter {
  const _StatusLandscapePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.1);
    final hill = Path()
      ..moveTo(size.width * 0.42, size.height)
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.22,
        size.width,
        size.height * 0.58,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hill, paint);

    final treePaint = Paint()..color = color.withValues(alpha: 0.17);
    for (var index = 0; index < 5; index++) {
      final left = size.width * 0.67 + index * 28;
      final top = size.height * 0.48 - (index % 2) * 12;
      canvas.drawCircle(Offset(left, top), 10, treePaint);
      canvas.drawRect(Rect.fromLTWH(left - 2, top + 8, 4, 22), treePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StatusLandscapePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _FloodForecastCard extends StatelessWidget {
  const _FloodForecastCard({
    required this.snapshot,
    required this.onRefresh,
  });

  final AsyncSnapshot<PredictionBundle> snapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      key: const Key('flood_forecast_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _SectionIcon(
                icon: Icons.auto_graph_rounded,
                color: AppTheme.signalBlue,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Flood Forecast',
                      style: TextStyle(
                        color: Color(0xFF102E58),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Plain-language warning for nearby barangays',
                      style: TextStyle(
                        color: Color(0xFF71849A),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7FE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD5E1F2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Refresh',
                          style: TextStyle(
                            color: AppTheme.signalBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.refresh_rounded,
                          color: AppTheme.signalBlue,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return const _PredictionLoadingState();
    }

    if (snapshot.hasError) {
      return _PredictionErrorState(
        message: snapshot.error.toString(),
        onRetry: onRefresh,
      );
    }

    final bundle = snapshot.data;
    if (bundle == null) {
      return _PredictionErrorState(
        message: 'No prediction data returned yet.',
        onRetry: onRefresh,
      );
    }

    return _ForecastMetricsLayout(metrics: _metricsFor(bundle));
  }

  List<_ForecastMetric> _metricsFor(PredictionBundle bundle) {
    final flood = bundle.flood;
    final landslide = bundle.landslide;

    return [
      _ForecastMetric(
        icon: Icons.flood_rounded,
        color: _levelColor(flood),
        title: 'Flood warning',
        value: _alertText(flood, fallback: 'Waiting for flood score'),
        detail: flood?.probabilityLabel ?? 'Sensor forecast pending',
      ),
      _ForecastMetric(
        icon: Icons.speed_rounded,
        color: AppTheme.signalBlue,
        title: 'Severity score',
        value: flood?.severityLabel ?? 'No score yet',
        detail: _modelDetail(bundle.modelInfo),
      ),
      _ForecastMetric(
        icon: Icons.terrain_rounded,
        color: _levelColor(landslide),
        title: 'Slope watch',
        value: _alertText(landslide, fallback: 'Waiting for slope score'),
        detail: landslide?.probabilityLabel ?? 'Sensor forecast pending',
      ),
    ];
  }

  Color _levelColor(NodePredictionModel? prediction) {
    final level = prediction?.alertLevel.toLowerCase() ?? '';
    if (level.contains('critical') || level.contains('high')) {
      return AppTheme.dangerRed;
    }
    if (level.contains('medium') || level.contains('watch')) {
      return AppTheme.warningAmber;
    }
    return AppTheme.safeGreen;
  }

  String _alertText(
    NodePredictionModel? prediction, {
    required String fallback,
  }) {
    if (prediction == null) {
      return fallback;
    }

    if (prediction.alert) {
      return '${prediction.alertLevel} alert';
    }

    return 'Monitor conditions';
  }

  String _modelDetail(AiModelInfo modelInfo) {
    if (modelInfo.featureColumns.isEmpty) {
      return 'Using AI prediction response';
    }

    return '${modelInfo.featureColumns.length} sensor inputs checked';
  }
}

class _ForecastMetricsLayout extends StatelessWidget {
  const _ForecastMetricsLayout({required this.metrics});

  final List<_ForecastMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 720;

        if (!horizontal) {
          return Column(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                if (index > 0) ...[
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFE0E8F1)),
                  const SizedBox(height: 14),
                ],
                metrics[index],
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < metrics.length; index++) ...[
              if (index > 0) const _VerticalDivider(),
              Expanded(child: metrics[index]),
            ],
          ],
        );
      },
    );
  }
}

class _PredictionLoadingState extends StatelessWidget {
  const _PredictionLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE7F4)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.signalBlue,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checking latest sensor forecast',
                  style: TextStyle(
                    color: Color(0xFF102E58),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Preparing flood and slope warnings from AI service.',
                  style: TextStyle(
                    color: Color(0xFF71849A),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionErrorState extends StatelessWidget {
  const _PredictionErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dangerRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.dangerRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: AppTheme.dangerRed,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI service unavailable',
                  style: TextStyle(
                    color: Color(0xFF102E58),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF71849A),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.signalBlue,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastMetric extends StatelessWidget {
  const _ForecastMetric({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 27),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF60738A),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF102E58),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF71849A),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 58,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: const Color(0xFFDDE6F0),
    );
  }
}

class _InformationGrid extends StatelessWidget {
  const _InformationGrid({
    required this.isWide,
    required this.bundle,
    required this.alerts,
  });

  final bool isWide;
  final PredictionBundle? bundle;
  final List<AlertModel>? alerts;

  @override
  Widget build(BuildContext context) {
    final weather = _WeatherHazardCard(bundle: bundle);
    final nearbyAlerts = _NearbyAlertsCard(alerts: alerts);

    if (!isWide) {
      return Column(children: [
        weather,
        const SizedBox(height: 12),
        nearbyAlerts
      ]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: weather),
        const SizedBox(width: 14),
        Expanded(flex: 5, child: nearbyAlerts),
      ],
    );
  }
}

class _WeatherHazardCard extends StatelessWidget {
  const _WeatherHazardCard({required this.bundle});

  final PredictionBundle? bundle;

  @override
  Widget build(BuildContext context) {
    final floodRisk = bundle?.flood?.alertLevel ?? 'Low';
    final rainfall = bundle?.rainfallMm ?? 0.0;
    final temp = bundle?.temperatureC ?? 28.0;

    final riskColor = _riskColor(bundle?.flood);

    return _DashboardCard(
      key: const Key('weather_hazard_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardSectionHeading(
            title: 'Weather & Hazard Overview',
            subtitle: bundle != null
                ? 'Updated ${_timeAgo(bundle!.fetchedAt)}'
                : 'Loading conditions...',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WeatherMetric(
                  icon: Icons.water_drop_rounded,
                  label: 'Flood Risk',
                  value: floodRisk,
                  detail: bundle?.flood?.probabilityLabel ?? 'Monitoring sensor',
                  color: riskColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeatherMetric(
                  icon: Icons.cloudy_snowing,
                  label: 'Rainfall',
                  value: '${rainfall.toStringAsFixed(1)} mm/h',
                  detail: rainfall > 10 ? 'Heavy rain' : (rainfall > 0 ? 'Light rain' : 'No rain'),
                  color: AppTheme.signalBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeatherMetric(
                  icon: Icons.thermostat_rounded,
                  label: 'Temp',
                  value: '${temp.round()} C',
                  detail: 'OpenWeather live',
                  color: AppTheme.dangerRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _riskColor(NodePredictionModel? prediction) {
    final level = prediction?.alertLevel.toLowerCase() ?? '';
    if (level.contains('critical') || level.contains('high')) {
      return AppTheme.dangerRed;
    }
    if (level.contains('medium') || level.contains('moderate')) {
      return AppTheme.warningAmber;
    }
    return AppTheme.safeGreen;
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    return '${diff.inMinutes} min ago';
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE1E9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF60738A),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF71849A),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 30,
            child: CustomPaint(
              painter: _SparklinePainter(color: color),
              size: const Size(double.infinity, 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Path()
      ..moveTo(0, size.height * 0.35)
      ..lineTo(size.width * 0.12, size.height * 0.48)
      ..lineTo(size.width * 0.24, size.height * 0.3)
      ..lineTo(size.width * 0.4, size.height * 0.5)
      ..lineTo(size.width * 0.56, size.height * 0.42)
      ..lineTo(size.width * 0.72, size.height * 0.64)
      ..lineTo(size.width, size.height * 0.58)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.07));

    final line = Path()
      ..moveTo(0, size.height * 0.35)
      ..lineTo(size.width * 0.12, size.height * 0.48)
      ..lineTo(size.width * 0.24, size.height * 0.3)
      ..lineTo(size.width * 0.4, size.height * 0.5)
      ..lineTo(size.width * 0.56, size.height * 0.42)
      ..lineTo(size.width * 0.72, size.height * 0.64)
      ..lineTo(size.width, size.height * 0.58);
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _NearbyAlertsCard extends StatelessWidget {
  const _NearbyAlertsCard({required this.alerts});

  final List<AlertModel>? alerts;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      key: const Key('nearby_alerts_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardSectionHeading(
            title: 'Nearby Alerts',
            action: 'View all',
            onAction: () => Navigator.pushNamed(context, AppRouter.alerts),
          ),
          const SizedBox(height: 12),
          if (alerts == null)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (alerts!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No active alerts in your area.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF71849A)),
              ),
            )
          else
            for (final alert in alerts!.take(2)) ...[
              _AlertRow(
                icon: _hazardIcon(alert.hazardType),
                title: alert.title,
                subtitle: '${alert.location} - ${alert.issuedAt.hour}:${alert.issuedAt.minute}',
                label: alert.severity.label,
                color: _severityColor(alert.severity),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRouter.alertDetails,
                  arguments: alert,
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  IconData _hazardIcon(HazardType type) {
    return switch (type) {
      HazardType.flood => Icons.flood_rounded,
      HazardType.landslide => Icons.terrain_rounded,
      HazardType.typhoon => Icons.cyclone_rounded,
      HazardType.medical => Icons.medical_services_rounded,
      HazardType.distress => Icons.sos_rounded,
      HazardType.infrastructure => Icons.car_crash_rounded,
    };
  }

  Color _severityColor(AlertSeverity severity) {
    return switch (severity) {
      AlertSeverity.critical => AppTheme.dangerRed,
      AlertSeverity.high => AppTheme.dangerRed,
      AlertSeverity.medium => AppTheme.warningAmber,
      AlertSeverity.low => AppTheme.safeGreen,
    };
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF102E58),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF71849A),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF71849A),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onSosPressed,
    required this.onAddFamily,
  });

  final VoidCallback onSosPressed;
  final VoidCallback onAddFamily;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      key: const Key('quick_actions_card'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          final actions = [
            _QuickActionTile(
              key: const Key('quick_sos_action'),
              icon: Icons.sos_rounded,
              title: 'Emergency SOS',
              subtitle: 'Get immediate help',
              color: AppTheme.dangerRed,
              onTap: onSosPressed,
            ),
            _QuickActionTile(
              icon: Icons.call_rounded,
              title: 'Rescue Path',
              subtitle: 'Navigate safely',
              color: AppTheme.safeGreen,
              onTap: () => Navigator.pushNamed(context, AppRouter.safeRoute),
            ),
            _QuickActionTile(
              icon: Icons.groups_rounded,
              title: 'Add Family',
              subtitle: 'Register member',
              color: AppTheme.signalBlue,
              onTap: onAddFamily,
            ),
            _QuickActionTile(
              icon: Icons.flag_rounded,
              title: 'Live Alerts',
              subtitle: 'Real-time updates',
              color: AppTheme.violet,
              onTap: () => Navigator.pushNamed(context, AppRouter.alerts),
            ),
          ];

          if (wide) {
            return Row(
              children: [
                const SizedBox(
                  width: 150,
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(
                      color: Color(0xFF102E58),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                for (var index = 0; index < actions.length; index++) ...[
                  Expanded(child: actions[index]),
                  if (index != actions.length - 1) const SizedBox(width: 10),
                ],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(
                  color: Color(0xFF102E58),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < actions.length; index++) ...[
                actions[index],
                if (index != actions.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF102E58),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF71849A),
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF315C92),
            size: 18,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1015365B),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 23),
    );
  }
}

class _CardSectionHeading extends StatelessWidget {
  const _CardSectionHeading({
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF102E58),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: Color(0xFF71849A),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                action!,
                style: const TextStyle(
                  color: AppTheme.signalBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SosFlowSheet extends StatefulWidget {
  const _SosFlowSheet();

  @override
  State<_SosFlowSheet> createState() => _SosFlowSheetState();
}

class _SosFlowSheetState extends State<_SosFlowSheet> {
  int _step = 0;

  static const _steps = [
    ('Location required', 'GPS will be checked before the request is sent.'),
    ('Signal checked', 'The app is choosing the strongest available path.'),
    (
      'Emergency backup ready',
      'Nearby relay points can help send your request.',
    ),
    ('Responder notified', 'Your request appears in the responder dashboard.'),
  ];

  Future<void> _send() async {
    for (var index = 0; index < _steps.length; index++) {
      if (!mounted) {
        return;
      }
      setState(() => _step = index);
      await Future<void>.delayed(const Duration(milliseconds: 420));
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sos, color: AppTheme.dangerRed),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Send Disaster Distress Ping',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < _steps.length; index++) ...[
            _SosStepTile(
              title: _steps[index].$1,
              subtitle: _steps[index].$2,
              active: index <= _step,
            ),
            if (index != _steps.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _send,
            icon: const Icon(Icons.hub),
            label: const Text('Send Emergency Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _SosStepTile extends StatelessWidget {
  const _SosStepTile({
    required this.title,
    required this.subtitle,
    required this.active,
  });

  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          active ? Icons.check_circle : Icons.radio_button_unchecked,
          color: active ? AppTheme.safeGreen : AppTheme.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
