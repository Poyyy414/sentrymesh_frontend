import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../core/config/map_tile_config.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/evacuation_center_model.dart';
import '../../../data/models/rescue_request_model.dart';
import '../../../data/models/route_model.dart';
import '../state/asean_country.dart';

class MapLayerVisibility {
  const MapLayerVisibility({
    this.incidents = true,
    this.hazards = true,
    this.safeRoute = true,
    this.evacuationCenters = true,
    this.loraNodes = true,
    this.location = true,
  });

  final bool incidents;
  final bool hazards;
  final bool safeRoute;
  final bool evacuationCenters;
  final bool loraNodes;
  final bool location;

  MapLayerVisibility copyWith({
    bool? incidents,
    bool? hazards,
    bool? safeRoute,
    bool? evacuationCenters,
    bool? loraNodes,
    bool? location,
  }) {
    return MapLayerVisibility(
      incidents: incidents ?? this.incidents,
      hazards: hazards ?? this.hazards,
      safeRoute: safeRoute ?? this.safeRoute,
      evacuationCenters: evacuationCenters ?? this.evacuationCenters,
      loraNodes: loraNodes ?? this.loraNodes,
      location: location ?? this.location,
    );
  }
}

class MapView extends StatefulWidget {
  const MapView({
    required this.country,
    required this.layers,
    this.route,
    this.userLocation,
    this.evacuationCenters = const [],
    this.incidents = const [],
    this.heatPoints = const [],
    this.isDaytime = true,
    this.rainfallMmPh = 0.0,
    super.key,
  });

  final AseanCountry country;
  final GeoPoint? userLocation;
  final MapLayerVisibility layers;
  final RouteModel? route;
  final List<EvacuationCenterModel> evacuationCenters;
  final List<RescueRequestModel> incidents;
  final List<SeverityHeatPoint> heatPoints;
  final bool isDaytime;
  final double rainfallMmPh;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final _mapController = MapController();
  bool _mapReady = false;

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
              userAgentPackageName: 'com.example.sentrymesh_frontend',
              maxZoom: 18,
            ),
            if (widget.layers.hazards && widget.heatPoints.isNotEmpty)
              CircleLayer(
                circles: [
                  for (final point in widget.heatPoints)
                    CircleMarker(
                      point: LatLng(
                        point.location.latitude,
                        point.location.longitude,
                      ),
                      radius: 260 + (point.severity * 760),
                      useRadiusInMeter: true,
                      color: point.color.withValues(alpha: 0.2),
                      borderColor: point.color.withValues(alpha: 0.42),
                      borderStrokeWidth: 1.2,
                    ),
                ],
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
            if (widget.layers.location && userPoint != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: userPoint,
                    radius: 120,
                    useRadiusInMeter: true,
                    color: AppTheme.signalBlue.withValues(alpha: 0.18),
                    borderColor: AppTheme.signalBlue.withValues(alpha: 0.45),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (widget.layers.evacuationCenters)
                  for (final center in widget.evacuationCenters)
                    Marker(
                      point: LatLng(center.latitude, center.longitude),
                      width: 78,
                      height: 76,
                      child: _EvacuationCenterMarker(center: center),
                    ),
                if (widget.layers.incidents)
                  for (final request in widget.incidents)
                    if (request.latitude != null && request.longitude != null)
                      Marker(
                        point: LatLng(request.latitude!, request.longitude!),
                        width: 72,
                        height: 76,
                        child: _IncidentMarker(request: request),
                      ),
                if (widget.layers.loraNodes)
                  for (final request in widget.incidents)
                    if (request.latitude != null &&
                        request.longitude != null &&
                        request.assignedTeamName != null)
                      Marker(
                        point: _teamPointForRequest(request),
                        width: 90,
                        height: 72,
                        child: _AssignedTeamMarker(request: request),
                      ),
                if (widget.layers.location)
                  if (userPoint != null)
                    Marker(
                      point: userPoint,
                      width: 44,
                      height: 44,
                      child: const _UserLocationMarker(),
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

class SeverityHeatPoint {
  const SeverityHeatPoint({
    required this.location,
    required this.label,
    required this.severity,
  });

  final GeoPoint location;
  final String label;
  final double severity;

  Color get color {
    if (severity >= 0.7) return AppTheme.dangerRed;
    if (severity >= 0.35) return AppTheme.warningAmber;
    return AppTheme.safeGreen;
  }
}

LatLng _teamPointForRequest(RescueRequestModel request) {
  final seed = request.id.codeUnits.fold<int>(0, (sum, code) => sum + code);
  final latOffset = 0.0012 + (seed % 5) * 0.00022;
  final lonOffset = 0.0012 + (seed % 7) * 0.00018;

  return LatLng(request.latitude! + latOffset, request.longitude! + lonOffset);
}

// ── Night overlay ──────────────────────────────────────────────────────────

class _NightOverlay extends StatelessWidget {
  const _NightOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: const ColoredBox(color: Color(0x88000B20), child: _StarField()),
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
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        paint,
      );
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
  const _RainPainter({required this.progress, required this.intensityMmPh});

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

      canvas.drawLine(Offset(x, y), Offset(x + len * 0.18, y + len), dropPaint);

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

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.signalBlue.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: DecoratedBox(
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

class _EvacuationCenterMarker extends StatelessWidget {
  const _EvacuationCenterMarker({required this.center});

  final EvacuationCenterModel center;

  @override
  Widget build(BuildContext context) {
    final isFull = center.availableSlots <= 0;
    final color = isFull ? AppTheme.warningAmber : AppTheme.safeGreen;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapMarkerLabel(
          label: isFull ? 'FULL' : '${center.availableSlots} slots',
          color: color,
        ),
        const SizedBox(height: 3),
        _MapMarkerBubble(icon: Icons.home_rounded, color: color),
      ],
    );
  }
}

class _IncidentMarker extends StatelessWidget {
  const _IncidentMarker({required this.request});

  final RescueRequestModel request;

  @override
  Widget build(BuildContext context) {
    final color = _severityColorForPeople(request.peopleNeedingHelp);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapMarkerLabel(
          label: 'SOS ${request.peopleNeedingHelp}',
          color: color,
        ),
        const SizedBox(height: 3),
        _MapMarkerBubble(icon: Icons.person_pin_rounded, color: color),
      ],
    );
  }
}

class _AssignedTeamMarker extends StatelessWidget {
  const _AssignedTeamMarker({required this.request});

  final RescueRequestModel request;

  @override
  Widget build(BuildContext context) {
    final name = request.assignedTeamName ?? 'Team';
    final shortName = name
        .replaceAll(' Response', '')
        .replaceAll(' Rescue', '')
        .replaceAll(' Evacuation', '');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapMarkerLabel(label: shortName, color: AppTheme.signalBlue),
        const SizedBox(height: 3),
        _MapMarkerBubble(
          icon: Icons.groups_rounded,
          color: AppTheme.signalBlue,
        ),
      ],
    );
  }
}

class _MapMarkerLabel extends StatelessWidget {
  const _MapMarkerLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MapMarkerBubble extends StatelessWidget {
  const _MapMarkerBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 3,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

Color _severityColorForPeople(int people) {
  if (people >= 5) return AppTheme.dangerRed;
  if (people >= 2) return AppTheme.warningAmber;
  return AppTheme.safeGreen;
}
