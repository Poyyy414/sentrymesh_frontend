import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../core/config/map_tile_config.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/evacuation_center_model.dart';
import '../../../data/models/hazard_zone_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/severity_colors.dart';
import '../state/asean_country.dart';

class MapLayerVisibility {
  const MapLayerVisibility({
    this.incidents = true,
    this.hazards = true,
    this.safeRoute = true,
    this.evacuationCenters = true,
    this.loraNodes = true,
    this.location = true,
    this.teams = true,
  });

  final bool incidents;
  final bool hazards;
  final bool safeRoute;
  final bool evacuationCenters;
  final bool loraNodes;
  final bool location;
  final bool teams;

  MapLayerVisibility copyWith({
    bool? incidents,
    bool? hazards,
    bool? safeRoute,
    bool? evacuationCenters,
    bool? loraNodes,
    bool? location,
    bool? teams,
  }) {
    return MapLayerVisibility(
      incidents: incidents ?? this.incidents,
      hazards: hazards ?? this.hazards,
      safeRoute: safeRoute ?? this.safeRoute,
      evacuationCenters: evacuationCenters ?? this.evacuationCenters,
      loraNodes: loraNodes ?? this.loraNodes,
      location: location ?? this.location,
      teams: teams ?? this.teams,
    );
  }
}

class MapView extends StatefulWidget {
  const MapView({
    required this.country,
    required this.layers,
    this.route,
    this.userLocation,
    this.isDaytime = true,
    this.rainfallMmPh = 0.0,
    this.evacuationCenters = const [],
    this.teamLocations = const [],
    this.hazardZones = const [],
    this.selectedCenterId,
    this.onEvacuationCenterTap,
    this.onCenteredChanged,
    super.key,
  });

  final AseanCountry country;
  final GeoPoint? userLocation;
  final MapLayerVisibility layers;
  final RouteModel? route;
  final bool isDaytime;
  final double rainfallMmPh;
  final List<EvacuationCenterModel> evacuationCenters;
  final List<TeamModel> teamLocations;
  final List<HazardZone> hazardZones;
  final String? selectedCenterId;
  final ValueChanged<EvacuationCenterModel>? onEvacuationCenterTap;
  // Fires whenever the map transitions between "centered on the resident's
  // location" and "panned away from it" (by gesture or programmatically) -
  // lets the recenter FAB dim/brighten the way Google Maps' does, instead
  // of always looking active regardless of where the camera actually is.
  final ValueChanged<bool>? onCenteredChanged;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final _mapController = MapController();
  bool _mapReady = false;
  StreamSubscription<MapEvent>? _mapEventSub;
  bool? _lastReportedCentered;

  @override
  void initState() {
    super.initState();
    _mapEventSub = _mapController.mapEventStream.listen(_onMapEvent);
  }

  @override
  void dispose() {
    _mapEventSub?.cancel();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    final userPoint = _userPoint;
    final isCentered = userPoint == null ||
        (event.camera.projectAtZoom(event.camera.center) -
                    event.camera.projectAtZoom(userPoint))
                .distance <
            40;
    if (isCentered != _lastReportedCentered) {
      _lastReportedCentered = isCentered;
      widget.onCenteredChanged?.call(isCentered);
    }
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cameraTargetChanged(oldWidget)) {
      _syncCamera();
    }
  }

  bool _cameraTargetChanged(MapView oldWidget) {
    final oldLocation = oldWidget.userLocation;
    final newLocation = widget.userLocation;

    return oldWidget.country.code != widget.country.code ||
        oldLocation?.latitude != newLocation?.latitude ||
        oldLocation?.longitude != newLocation?.longitude;
  }

  void _onMapReady() {
    _mapReady = true;
    _syncCamera();
  }

  void _syncCamera() {
    if (!_mapReady) {
      return;
    }

    _mapController.move(_targetPoint, _targetZoom);
  }

  LatLng get _targetPoint {
    final location = widget.userLocation;

    return LatLng(
      location?.latitude ?? widget.country.latitude,
      location?.longitude ?? widget.country.longitude,
    );
  }

  double get _targetZoom {
    return widget.userLocation == null ? widget.country.zoom : 15;
  }

  LatLng get _countryPoint {
    return LatLng(widget.country.latitude, widget.country.longitude);
  }

  LatLng? get _userPoint {
    final location = widget.userLocation;
    if (location == null) {
      return null;
    }

    return LatLng(location.latitude, location.longitude);
  }

  // The zoom threshold in _EvacuationCenterMarker handles "too far out to
  // read anything," but nearby real-world shelters (a couple hundred
  // meters apart - common for barangay halls in the same cluster) can
  // still land within a pill-width of each other even when reasonably
  // zoomed in. This projects each (non-selected) center to its actual
  // screen position and hides the label on whichever of a colliding pair
  // comes later in the list - the selected center is never hidden since
  // that's the one place name the resident actually needs.
  static const _centerLabelCollisionPx = 90.0;

  Set<String> _collidingCenterLabelIds(MapCamera camera) {
    final centers = widget.evacuationCenters;
    if (centers.length < 2) return const {};

    final offsets = {
      for (final c in centers)
        c.id: camera.latLngToScreenOffset(LatLng(c.latitude, c.longitude)),
    };
    final suppressed = <String>{};
    for (var i = 0; i < centers.length; i++) {
      final a = centers[i];
      if (a.id == widget.selectedCenterId || suppressed.contains(a.id)) {
        continue;
      }
      for (var j = i + 1; j < centers.length; j++) {
        final b = centers[j];
        if (b.id == widget.selectedCenterId || suppressed.contains(b.id)) {
          continue;
        }
        if ((offsets[a.id]! - offsets[b.id]!).distance <
            _centerLabelCollisionPx) {
          suppressed.add(b.id);
        }
      }
    }
    return suppressed;
  }

  @override
  Widget build(BuildContext context) {
    final userPoint = _userPoint;
    final routePoints =
        widget.route?.waypoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList() ??
        const <LatLng>[];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _targetPoint,
            initialZoom: _targetZoom,
            minZoom: 3,
            maxZoom: 18,
            backgroundColor: const Color(0xFFE6ECF2),
            keepAlive: false,
            onMapReady: _onMapReady,
          ),
          children: [
            TileLayer(
              urlTemplate: MapTileConfig.mapboxStreetsUrl,
              tileProvider: MapTileConfig.cachedTileProvider,
              userAgentPackageName: 'com.example.sentrymesh_frontend',
              maxZoom: 18,
            ),
            if (widget.layers.safeRoute && routePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 7,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  Polyline(
                    points: routePoints,
                    strokeWidth: 4,
                    color: AppTheme.safeGreen,
                  ),
                ],
              ),
            if (widget.layers.hazards && widget.hazardZones.isNotEmpty)
              CircleLayer(
                circles: [
                  for (final zone in widget.hazardZones)
                    CircleMarker(
                      point: LatLng(zone.latitude, zone.longitude),
                      radius: 600,
                      useRadiusInMeter: true,
                      color: riskTierColor(
                        zone.alertLevel,
                      ).withValues(alpha: 0.16),
                      borderColor: riskTierColor(zone.alertLevel),
                      borderStrokeWidth: 2,
                    ),
                ],
              ),
            if (widget.layers.location && userPoint != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: userPoint,
                    // GPS accuracy varies a lot (dense buildings, indoors,
                    // cold fix) - showing the real radius instead of a
                    // fixed one tells residents how much to trust the pin,
                    // same idea as Google Maps' accuracy halo. Clamped so
                    // a great fix isn't an invisible speck and a terrible
                    // one doesn't blot out the whole neighborhood.
                    radius: (widget.userLocation?.accuracyMeters ?? 30)
                        .clamp(15, 150),
                    useRadiusInMeter: true,
                    color: AppTheme.signalBlue.withValues(alpha: 0.18),
                    borderColor: AppTheme.signalBlue.withValues(alpha: 0.45),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
            Builder(
              // A Builder (not just inlining this in _MapViewState.build)
              // so MapCamera.of(context) here is a real descendant of
              // FlutterMap - that's what makes this rebuild live on every
              // pinch/pan/zoom gesture, not just when SafeRouteMapScreen
              // happens to rebuild this widget for an unrelated reason.
              builder: (context) {
                final camera = MapCamera.of(context);
                final suppressedCenterIds = _collidingCenterLabelIds(camera);
                return MarkerLayer(
                  markers: [
                if (widget.layers.hazards)
                  for (final zone in widget.hazardZones)
                    Marker(
                      point: LatLng(zone.latitude, zone.longitude),
                      width: 80,
                      height: 50,
                      // A hazard zone shares its coordinate with the
                      // evacuation center it's monitoring, whose own marker
                      // (name + slots pill) is also anchored there -
                      // anchoring this box's bottom edge (not center) at the
                      // point, with the label pinned to the box's top, lifts
                      // it clear of that stack instead of drawing on top.
                      alignment: Alignment.bottomCenter,
                      child: _HazardZoneLabel(zone: zone),
                    ),
                if (widget.layers.evacuationCenters)
                  for (final center in widget.evacuationCenters)
                    Marker(
                      point: LatLng(center.latitude, center.longitude),
                      width: 120,
                      height: 48,
                      child: _EvacuationCenterMarker(
                        center: center,
                        isSelected: center.id == widget.selectedCenterId,
                        forceHideLabel: suppressedCenterIds.contains(center.id),
                        onTap: () => widget.onEvacuationCenterTap?.call(center),
                      ),
                    ),
                if (widget.layers.teams)
                  for (final team in widget.teamLocations)
                    for (final member in team.members)
                      if (member.hasLocation)
                        Marker(
                          point: LatLng(member.latitude!, member.longitude!),
                          width: 100,
                          height: 44,
                          child: _TeamMemberMapMarker(
                            teamName: team.name,
                            memberName: member.firstName,
                            status: team.status,
                          ),
                        ),
                if (widget.layers.location)
                  if (userPoint != null)
                    Marker(
                      point: userPoint,
                      width: 44,
                      height: 44,
                      child: _UserLocationMarker(
                        heading: widget.userLocation?.heading,
                        speedMps: widget.userLocation?.speedMps,
                      ),
                    )
                  else
                    Marker(
                      point: _countryPoint,
                      width: 42,
                      height: 42,
                      child: _CountryCenterMarker(
                        countryCode: widget.country.code,
                      ),
                    ),
                  ],
                );
              },
            ),
            const RichAttributionWidget(
              showFlutterMapAttribution: false,
              attributions: [
                TextSourceAttribution('Mapbox, OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        // Night overlay — dark blue tint when it's nighttime
        if (!widget.isDaytime) const _NightOverlay(),
        // Rain particle animation overlay
        if (widget.rainfallMmPh > 0.5)
          _RainOverlay(intensityMmPh: widget.rainfallMmPh),
      ],
    );
  }
}

// ── Night overlay ──────────────────────────────────────────────────────────

class _NightOverlay extends StatelessWidget {
  const _NightOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: const ColoredBox(
        color: Color(0x88000B20),
        child: _StarField(),
      ),
    );
  }
}

class _StarField extends StatelessWidget {
  const _StarField();

  static final _rand = math.Random(7);
  static final _stars = List.generate(
    40,
    (_) => (
      x: _rand.nextDouble(),
      y: _rand.nextDouble() * 0.5, // stars only in upper half
      r: 0.8 + _rand.nextDouble() * 1.4,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarPainter(_stars),
      child: const SizedBox.expand(),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.stars);

  final List<({double x, double y, double r})> stars;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (final s in stars) {
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}

// ── Rain overlay ───────────────────────────────────────────────────────────

class _RainOverlay extends StatefulWidget {
  const _RainOverlay({required this.intensityMmPh});

  final double intensityMmPh;

  @override
  State<_RainOverlay> createState() => _RainOverlayState();
}

class _RainOverlayState extends State<_RainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => CustomPaint(
          painter: _RainPainter(
            progress: _ctrl.value,
            intensityMmPh: widget.intensityMmPh,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  const _RainPainter({
    required this.progress,
    required this.intensityMmPh,
  });

  final double progress;
  final double intensityMmPh;

  // Fixed-seed random so particles are stable across frames
  static final _rand = math.Random(42);
  static final _xFracs = List.generate(120, (_) => _rand.nextDouble());
  static final _phases = List.generate(120, (_) => _rand.nextDouble());
  static final _speeds = List.generate(
    120,
    (_) => 0.55 + _rand.nextDouble() * 0.9,
  );
  static final _lengths = List.generate(
    120,
    (_) => 10.0 + _rand.nextDouble() * 8,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final count = intensityMmPh < 5
        ? 28
        : intensityMmPh < 15
        ? 60
        : 110;

    final dropPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final splashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 0.8;

    for (var i = 0; i < count; i++) {
      final t = (progress * _speeds[i] + _phases[i]) % 1.0;
      // slight rightward angle (wind-driven rain)
      final x = _xFracs[i] * size.width + t * size.height * 0.12;
      final y = t * (size.height + 30) - 15;
      final len = _lengths[i];

      canvas.drawLine(
        Offset(x, y),
        Offset(x + len * 0.18, y + len),
        dropPaint,
      );

      // tiny splash when drop hits bottom
      if (t > 0.92) {
        final splashY = size.height - 4;
        canvas.drawLine(
          Offset(x - 3, splashY),
          Offset(x + 3, splashY),
          splashPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) => old.progress != progress;
}

// ── Standard map markers ───────────────────────────────────────────────────

// Below this, course-over-ground is GPS noise, not a real direction -
// Geolocator derives heading from successive fixes rather than a
// compass, so it's meaningless while standing still or walking slowly.
const kMovingSpeedThresholdMps = 0.8;

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker({this.heading, this.speedMps});

  final double? heading;
  final double? speedMps;

  @override
  Widget build(BuildContext context) {
    final isMoving = (speedMps ?? 0) >= kMovingSpeedThresholdMps;
    final showHeading = isMoving && heading != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.signalBlue.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: showHeading
            ? Transform.rotate(
                angle: heading! * math.pi / 180,
                child: Icon(
                  Icons.navigation_rounded,
                  color: AppTheme.signalBlue,
                  size: 30,
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.9),
                      blurRadius: 1,
                    ),
                    const Shadow(color: Colors.white, blurRadius: 4),
                  ],
                ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.signalBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.signalBlue.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const SizedBox(width: 24, height: 24),
              ),
      ),
    );
  }
}

class _CountryCenterMarker extends StatelessWidget {
  const _CountryCenterMarker({required this.countryCode});

  final String countryCode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: Center(
        child: Text(
          countryCode,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Hazard zone label ──────────────────────────────────────────────────────

// flutter_map's MarkerLayer has no built-in label collision avoidance (the
// way Mapbox's native symbol layers do) - below this zoom, nearby shelter/
// hazard/team pills draw right on top of each other and turn into an
// unreadable stack. Collapsing to icon-only below the threshold keeps
// positions visible without the mess; zooming in far enough to tell
// markers apart also brings the names back.
const kMarkerLabelZoomThreshold = 14.0;

class _HazardZoneLabel extends StatelessWidget {
  const _HazardZoneLabel({required this.zone});

  final HazardZone zone;

  @override
  Widget build(BuildContext context) {
    final color = riskTierColor(zone.alertLevel);
    final showLabel = MapCamera.of(context).zoom >= kMarkerLabelZoomThreshold;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 8 : 4,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
              if (showLabel) ...[
                const SizedBox(width: 3),
                Text(
                  zone.alertLevel,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Evacuation center marker ──────────────────────────────────────────────

class _EvacuationCenterMarker extends StatelessWidget {
  const _EvacuationCenterMarker({
    required this.center,
    required this.isSelected,
    required this.onTap,
    this.forceHideLabel = false,
  });

  final EvacuationCenterModel center;
  final bool isSelected;
  final VoidCallback onTap;
  // Set when this center's pill collides on-screen with a nearby one (see
  // _MapViewState._collidingCenterLabelIds) - distinct from the zoom
  // threshold below, which is about being too far out to read anything.
  final bool forceHideLabel;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppTheme.signalBlue
        : center.isOpen
            ? AppTheme.safeGreen
            : Colors.grey;
    // A selected center is the one the resident is actually headed to -
    // always naming it (even zoomed out) matters more than decluttering.
    final showLabel = isSelected ||
        (!forceHideLabel &&
            MapCamera.of(context).zoom >= kMarkerLabelZoomThreshold);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: showLabel ? 6 : 4,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.home_rounded, size: 13, color: Colors.white),
                if (showLabel) ...[
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      center.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showLabel)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                center.availableSlots > 0
                    ? '${center.availableSlots} slots'
                    : 'FULL',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: center.availableSlots > 0
                      ? AppTheme.safeGreen
                      : AppTheme.dangerRed,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Team member marker ────────────────────────────────────────────────────

class _TeamMemberMapMarker extends StatelessWidget {
  const _TeamMemberMapMarker({
    required this.teamName,
    required this.memberName,
    required this.status,
  });

  final String teamName;
  final String memberName;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'active'
        ? AppTheme.safeGreen
        : const Color(0xFFE8A317);
    final showLabel = MapCamera.of(context).zoom >= kMarkerLabelZoomThreshold;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 5 : 3,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_rounded, size: 11, color: Colors.white),
              if (showLabel) ...[
                const SizedBox(width: 2),
                Text(
                  teamName,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showLabel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              memberName,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
      ],
    );
  }
}
