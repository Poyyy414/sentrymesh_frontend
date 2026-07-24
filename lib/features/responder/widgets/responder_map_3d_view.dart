import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/services/geo_bounds.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/evacuation_center_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/rescue_request_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/severity_colors.dart';
import 'marker_icon_renderer.dart';

// Icon ids match the 2D map's marker widgets — same colors, same glyphs
// (_ResponderLocationMarker, _SosRequestMarker, _ShelterMarker,
// _ResidentLocationMarker, _TeamMemberMarker in responder_shell.dart).
const _iconYou = 'responder-3d-icon-you';
const _iconSos = 'responder-3d-icon-sos';
const _iconShelterOpen = 'responder-3d-icon-shelter-open';
const _iconShelterFull = 'responder-3d-icon-shelter-full';
const _iconResident = 'responder-3d-icon-resident';
const _iconTeam = 'responder-3d-icon-team';

/// Responder-only 3D map view — a tilted-camera Mapbox GL widget with
/// built-in 3D buildings (via [MapboxStyles.STANDARD]), showing the same
/// operational data as the 2D `_ResponderMapPreview` (SOS requests, team
/// members, shelters, hazard zones, route).
///
/// Requires a live connection: there is no offline tile pack for the native
/// Mapbox SDK in this pass (see the offline-maps plan) — this widget should
/// only be shown when connectivity is confirmed, with a fallback to the 2D
/// map otherwise.
class ResponderMap3DView extends StatefulWidget {
  const ResponderMap3DView({
    this.responderLocation,
    this.residentLocation,
    this.route,
    this.sosRequests = const [],
    this.shelters = const [],
    this.teamMembers = const [],
    this.hazardZones = const [],
    this.onSosRequestTap,
    this.onShelterTap,
    super.key,
  });

  final GeoPoint? responderLocation;
  final GeoPoint? residentLocation;
  final RouteModel? route;
  final List<RescueRequestModel> sosRequests;
  final List<EvacuationCenterModel> shelters;
  final List<TeamMemberModel> teamMembers;
  final List<Map<String, Object?>> hazardZones;
  final void Function(RescueRequestModel)? onSosRequestTap;
  final void Function(EvacuationCenterModel)? onShelterTap;

  @override
  State<ResponderMap3DView> createState() => _ResponderMap3DViewState();
}

class _ResponderMap3DViewState extends State<ResponderMap3DView> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotations;
  CircleAnnotationManager? _circleAnnotations;
  PolylineAnnotationManager? _polylineAnnotations;
  bool _iconsReady = false;

  @override
  void didUpdateWidget(covariant ResponderMap3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Guard against a widget rebuild landing between onMapCreated and
    // onStyleLoaded — refreshing before icons are registered would draw
    // annotations referencing images that don't exist yet.
    if (_mapboxMap != null && _iconsReady) _refreshAnnotations();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    final center = widget.residentLocation ??
        widget.responderLocation ??
        kDefaultMapCenter;
    await mapboxMap.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(center.longitude, center.latitude),
        ),
        zoom: 16,
        pitch: 55,
        bearing: 0,
      ),
    );

    _pointAnnotations = await mapboxMap.annotations
        .createPointAnnotationManager();
    _circleAnnotations = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _polylineAnnotations = await mapboxMap.annotations
        .createPolylineAnnotationManager();
  }

  // Style-dependent calls (custom images, import config) need the style to
  // have actually finished loading — calling them from onMapCreated (which
  // fires once the map exists, not once its style is ready) let addStyleImage
  // silently fail to register, so iconImage referenced nothing and Mapbox
  // fell back to showing only the text label with no icon graphic at all.
  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    // Dense barangay/POI naming in this region causes place labels to
    // visually overlap at this pitch — drop the lower-priority POI/transit
    // labels so place names have room, without losing them entirely.
    await mapboxMap.style.setStyleImportConfigProperties('basemap', {
      'showPointOfInterestLabels': false,
      'showTransitLabels': false,
      'showPlaceLabels': true,
    });

    await _registerIcons(mapboxMap);
    _iconsReady = true;
    await _refreshAnnotations();
  }

  // PointAnnotation's `iconColor` does nothing without an actual registered
  // image — this rasterizes one circle+glyph icon per marker type (matching
  // the 2D map's widgets) and registers each with the style, once.
  Future<void> _registerIcons(MapboxMap mapboxMap) async {
    final icons = {
      _iconYou: (AppTheme.signalBlue, Icons.navigation),
      _iconSos: (const Color(0xFFE53935), Icons.person_pin_rounded),
      _iconShelterOpen: (const Color(0xFF2E7D32), Icons.home_rounded),
      _iconShelterFull: (const Color(0xFFE65100), Icons.home_rounded),
      _iconResident: (AppTheme.dangerRed, Icons.person_pin_circle_rounded),
      _iconTeam: (AppTheme.violet, Icons.person),
    };

    for (final entry in icons.entries) {
      final (color, icon) = entry.value;
      final rendered = await renderCircleIcon(
        icon: icon,
        backgroundColor: color,
      );
      await mapboxMap.style.addStyleImage(
        entry.key,
        1,
        MbxImage(
          width: rendered.width,
          height: rendered.height,
          data: rendered.rgba,
        ),
        false,
        [],
        [],
        null,
      );
    }
  }

  Future<void> _refreshAnnotations() async {
    final points = _pointAnnotations;
    final circles = _circleAnnotations;
    final polylines = _polylineAnnotations;
    if (points == null || circles == null || polylines == null) return;

    await Future.wait([
      points.deleteAll(),
      circles.deleteAll(),
      polylines.deleteAll(),
    ]);

    // Hazard zones — fixed-radius circles color-coded by risk level.
    final hazardOptions = <CircleAnnotationOptions>[];
    for (final zone in widget.hazardZones) {
      final lat = _asDouble(zone['lat']);
      final lon = _asDouble(zone['lon']);
      if (lat == null || lon == null) continue;
      final color = riskTierColor(
        zone['alert_level'] ?? zone['alertLevel'],
      ).toARGB32();
      hazardOptions.add(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(lon, lat)),
          circleRadius: 60,
          circleColor: color,
          circleOpacity: 0.25,
          circleStrokeColor: color,
          circleStrokeWidth: 2,
        ),
      );
    }
    if (hazardOptions.isNotEmpty) await circles.createMulti(hazardOptions);

    // Route polyline.
    final waypoints = widget.route?.waypoints ?? const [];
    if (waypoints.length > 1) {
      await polylines.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: waypoints
                .map((p) => Position(p.longitude, p.latitude))
                .toList(),
          ),
          lineColor: AppTheme.safeGreen.toARGB32(),
          lineWidth: 4,
        ),
      );
    }

    // Point markers: shelters, SOS requests, team members, responder/resident.
    final pointOptions = <PointAnnotationOptions>[];
    for (final shelter in widget.shelters) {
      final isFull = shelter.availableSlots <= 0;
      pointOptions.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(shelter.longitude, shelter.latitude),
          ),
          iconImage: isFull ? _iconShelterFull : _iconShelterOpen,
          iconSize: 0.45,
          textField: shelter.name,
          textOffset: [0, 1.8],
          textSize: 11,
        ),
      );
    }
    for (final request in widget.sosRequests) {
      if (request.latitude == null || request.longitude == null) continue;
      pointOptions.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(request.longitude!, request.latitude!),
          ),
          iconImage: _iconSos,
          iconSize: 0.5,
          textField: 'SOS',
          textOffset: [0, 1.8],
          textSize: 11,
        ),
      );
    }
    for (final member in widget.teamMembers) {
      if (!member.hasLocation) continue;
      pointOptions.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(member.longitude!, member.latitude!),
          ),
          iconImage: _iconTeam,
          iconSize: 0.4,
          textField: member.firstName,
          textOffset: [0, 1.8],
          textSize: 10,
        ),
      );
    }
    final responderLocation = widget.responderLocation;
    if (responderLocation != null) {
      pointOptions.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              responderLocation.longitude,
              responderLocation.latitude,
            ),
          ),
          iconImage: _iconYou,
          iconSize: 0.55,
          textField: 'You',
          textOffset: [0, 1.8],
          textSize: 12,
          textColor: AppTheme.signalBlue.toARGB32(),
        ),
      );
    }
    final residentLocation = widget.residentLocation;
    if (residentLocation != null) {
      pointOptions.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              residentLocation.longitude,
              residentLocation.latitude,
            ),
          ),
          iconImage: _iconResident,
          iconSize: 0.55,
          textField: 'Resident',
          textOffset: [0, 1.8],
          textSize: 12,
          textColor: AppTheme.dangerRed.toARGB32(),
        ),
      );
    }
    if (pointOptions.isNotEmpty) await points.createMulti(pointOptions);
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('responder_3d_map'),
      styleUri: MapboxStyles.STANDARD,
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}
