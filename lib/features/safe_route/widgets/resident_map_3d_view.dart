import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/services/geo_bounds.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/evacuation_center_model.dart';
import '../../../data/models/hazard_zone_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/severity_colors.dart';
import '../../responder/widgets/marker_icon_renderer.dart';

const _iconYou = 'resident-3d-icon-you';
const _iconShelterOpen = 'resident-3d-icon-shelter-open';
const _iconShelterFull = 'resident-3d-icon-shelter-full';
const _iconShelterSelected = 'resident-3d-icon-shelter-selected';
const _iconTeam = 'resident-3d-icon-team';

/// Resident-facing 3D map option (tilted-camera Mapbox GL with built-in 3D
/// buildings via [MapboxStyles.STANDARD]) — the same technique already
/// proven on the responder side (see ResponderMap3DView), scoped to what a
/// resident should actually see: their own position, the safe-route
/// polyline, evacuation centers (with slot counts and selection highlight),
/// and responder team locations. Deliberately no SOS markers - residents
/// shouldn't see other residents' raw distress-request locations.
///
/// Requires a live connection or a downloaded offline pack for this area -
/// callers should gate visibility the same way the 2D map's own online/
/// offline-pack check already does.
///
/// mapbox_maps_flutter 2.26.0's transitively-resolved
/// com.mapbox.common:common-ndk27:24.26.0 was missing the ResultCallback
/// class its own android-ndk27:11.26.0 Maps SDK needed, breaking
/// StyleManager.addStyleImage entirely (no custom icon could register, so
/// none of this file's annotations appeared). Fixed by the 2.27.0 bump
/// (common-ndk27 24.27.0) - the ResultCallback class is still genuinely
/// absent (harmless warning in logcat), but the SDK no longer treats that
/// as fatal. See renderCircleIcon for a second, unrelated 2.27.0 bug this
/// also uncovered (addStyleImage needs PNG-encoded bytes now, not raw
/// RGBA).
class ResidentMap3DView extends StatefulWidget {
  const ResidentMap3DView({
    this.userLocation,
    this.route,
    this.evacuationCenters = const [],
    this.teamLocations = const [],
    this.hazardZones = const [],
    this.selectedCenterId,
    this.onEvacuationCenterTap,
    super.key,
  });

  final GeoPoint? userLocation;
  final RouteModel? route;
  final List<EvacuationCenterModel> evacuationCenters;
  final List<TeamModel> teamLocations;
  final List<HazardZone> hazardZones;
  final String? selectedCenterId;
  final ValueChanged<EvacuationCenterModel>? onEvacuationCenterTap;

  @override
  State<ResidentMap3DView> createState() => _ResidentMap3DViewState();
}

class _ResidentMap3DViewState extends State<ResidentMap3DView> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotations;
  PolylineAnnotationManager? _polylineAnnotations;
  CircleAnnotationManager? _circleAnnotations;
  PointAnnotation? _userAnnotation;
  bool _iconsReady = false;
  // _refreshAnnotations deletes and recreates every annotation via several
  // awaited platform-channel round-trips - fine for occasional route/
  // center updates, but didUpdateWidget fires on every rebuild, including
  // ones now driven by a live, unthrottled GPS stream during guidance. A
  // full rebuild on every single GPS tick kept the channel continuously
  // busy fighting the map's own gesture handling for the same platform
  // view, which looked exactly like a freeze (pan/tap unresponsive) even
  // though nothing had crashed. The fix is two-pronged: (1) below, only
  // do the expensive full rebuild when something other than location
  // actually changed: (2) the in-flight guard still coalesces the rare
  // case a full rebuild is still running when another is requested.
  bool _refreshInFlight = false;
  bool _refreshQueued = false;

  @override
  void didUpdateWidget(covariant ResidentMap3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapboxMap == null || !_iconsReady) return;

    final oldLoc = oldWidget.userLocation;
    final newLoc = widget.userLocation;
    final locationChanged =
        oldLoc?.latitude != newLoc?.latitude ||
        oldLoc?.longitude != newLoc?.longitude;

    // route: a fresh fetch (every 5s during guidance) always creates a new
    // RouteModel instance even if the path is unchanged, so reference
    // inequality is the right signal here - it fires far less often than
    // raw GPS ticks. evacuationCenters/teamLocations are stable references
    // unless actually reassigned. hazardZones is rebuilt fresh from a Map
    // every single build regardless of content, so reference equality
    // would always read as "changed" - length is used as a proxy instead.
    final somethingElseChanged =
        !identical(widget.route, oldWidget.route) ||
        !identical(widget.evacuationCenters, oldWidget.evacuationCenters) ||
        !identical(widget.teamLocations, oldWidget.teamLocations) ||
        widget.hazardZones.length != oldWidget.hazardZones.length ||
        widget.selectedCenterId != oldWidget.selectedCenterId;

    if (somethingElseChanged) {
      _requestRefresh();
    } else if (locationChanged && newLoc != null) {
      _updateUserLocation(newLoc);
    }
  }

  // Cheap path for the common case (a GPS tick during guidance, or the
  // recenter button): moves just the "you" marker, instead of tearing
  // down and recreating every annotation on the map for what's usually a
  // few-meter position change.
  Future<void> _updateUserLocation(GeoPoint location) async {
    final points = _pointAnnotations;
    if (points == null) return;
    final position = Position(location.longitude, location.latitude);

    final existing = _userAnnotation;
    if (existing == null) {
      // First fix after a full refresh already drew the "you" marker as
      // part of that batch - nothing to move yet until the next refresh
      // recreates it and populates _userAnnotation (see _refreshAnnotations).
      return;
    }
    existing.geometry = Point(coordinates: position);
    await points.update(existing);
    // No camera-follow here (deliberately) - even throttled to once every
    // 3s, calling mapboxMap.easeTo() during guidance left the map
    // unresponsive to pan/tap for the rest of the session (see git history
    // on this file). This view is currently unreachable in the UI
    // (SafeRouteMapScreen._handleToggle3D shows a "coming soon" dialog
    // instead of switching to it) until that's root-caused.
  }

  void _requestRefresh() {
    if (_refreshInFlight) {
      _refreshQueued = true;
      return;
    }
    _refreshInFlight = true;
    _refreshAnnotations().whenComplete(() {
      _refreshInFlight = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        _requestRefresh();
      }
    });
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    final center = widget.userLocation ?? kDefaultMapCenter;
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
    _polylineAnnotations = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    _circleAnnotations = await mapboxMap.annotations
        .createCircleAnnotationManager();

    _pointAnnotations!.tapEvents(
      onTap: (annotation) => _handleAnnotationTap(annotation),
    );
  }

  void _handleAnnotationTap(PointAnnotation annotation) {
    final onTap = widget.onEvacuationCenterTap;
    if (onTap == null) return;
    final coords = annotation.geometry.coordinates;
    for (final center in widget.evacuationCenters) {
      if ((center.longitude - coords.lng).abs() < 0.00001 &&
          (center.latitude - coords.lat).abs() < 0.00001) {
        onTap(center);
        return;
      }
    }
  }

  // Style-dependent calls (custom images, import config) need the style to
  // have actually finished loading — calling them from onMapCreated (which
  // fires once the map exists, not once its style is ready) let addStyleImage
  // silently fail to register, so iconImage referenced nothing.
  //
  // Every await below is followed by a `mounted` check: toggling 2D/3D
  // quickly disposes this State while this chain is still in flight
  // (rasterizing + registering 5 icons isn't instant), and calling back into
  // a torn-down platform view throws a channel PlatformException instead of
  // just failing quietly.
  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null || !mounted) return;

    // Dense barangay/POI naming in this region causes place labels to
    // visually overlap at this pitch — drop the lower-priority POI/transit
    // labels so place names have room, without losing them entirely.
    await mapboxMap.style.setStyleImportConfigProperties('basemap', {
      'showPointOfInterestLabels': false,
      'showTransitLabels': false,
      'showPlaceLabels': true,
    });
    if (!mounted) return;

    await _registerIcons(mapboxMap);
    if (!mounted) return;
    _iconsReady = true;
    await _refreshAnnotations();
  }

  // PointAnnotation's `iconColor` does nothing without an actual registered
  // image — this rasterizes one circle+glyph icon per marker type (matching
  // the 2D map's marker widgets) and registers each with the style, once.
  Future<void> _registerIcons(MapboxMap mapboxMap) async {
    final icons = {
      _iconYou: (AppTheme.signalBlue, Icons.navigation),
      _iconShelterOpen: (AppTheme.safeGreen, Icons.home_rounded),
      _iconShelterFull: (const Color(0xFF9E9E9E), Icons.home_rounded),
      _iconShelterSelected: (AppTheme.signalBlue, Icons.home_rounded),
      _iconTeam: (AppTheme.violet, Icons.shield_rounded),
    };

    for (final entry in icons.entries) {
      if (!mounted) return;
      final (color, icon) = entry.value;
      final rendered = await renderCircleIcon(
        icon: icon,
        backgroundColor: color,
      );
      if (!mounted) return;
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
    if (!mounted) return;
    final points = _pointAnnotations;
    final polylines = _polylineAnnotations;
    final circles = _circleAnnotations;
    if (points == null || polylines == null || circles == null) return;

    _userAnnotation = null;
    await Future.wait([
      points.deleteAll(),
      polylines.deleteAll(),
      circles.deleteAll(),
    ]);
    if (!mounted) return;

    // Flood/landslide hazard zones — fixed-radius circles color-coded by
    // risk level, one per monitored evacuation center currently flagged.
    if (widget.hazardZones.isNotEmpty) {
      await circles.createMulti([
        for (final zone in widget.hazardZones)
          CircleAnnotationOptions(
            geometry: Point(
              coordinates: Position(zone.longitude, zone.latitude),
            ),
            circleRadius: 60,
            circleColor: riskTierColor(zone.alertLevel).toARGB32(),
            circleOpacity: 0.25,
            circleStrokeColor: riskTierColor(zone.alertLevel).toARGB32(),
            circleStrokeWidth: 2,
          ),
      ]);
      if (!mounted) return;
    }

    // Safe-route polyline.
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

    final pointOptions = <PointAnnotationOptions>[];
    for (final center in widget.evacuationCenters) {
      final isSelected = center.id == widget.selectedCenterId;
      final iconImage = isSelected
          ? _iconShelterSelected
          : center.availableSlots > 0
              ? _iconShelterOpen
              : _iconShelterFull;
      pointOptions.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(center.longitude, center.latitude),
          ),
          iconImage: iconImage,
          iconSize: isSelected ? 0.55 : 0.45,
          textField:
              '${center.name} (${center.availableSlots > 0 ? '${center.availableSlots} slots' : 'FULL'})',
          textOffset: [0, 1.8],
          textSize: 11,
        ),
      );
    }
    for (final team in widget.teamLocations) {
      for (final member in team.members) {
        if (!member.hasLocation) continue;
        pointOptions.add(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(member.longitude!, member.latitude!),
            ),
            iconImage: _iconTeam,
            iconSize: 0.4,
            textField: '${team.name} · ${member.firstName}',
            textOffset: [0, 1.8],
            textSize: 10,
          ),
        );
      }
    }
    final userLocation = widget.userLocation;
    if (userLocation != null) {
      pointOptions.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              userLocation.longitude,
              userLocation.latitude,
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
    if (pointOptions.isNotEmpty && mounted) {
      final created = await points.createMulti(pointOptions);
      if (userLocation != null && created.isNotEmpty) {
        // Added last above, so it's always the last created annotation -
        // kept so the next location-only tick can move it directly
        // instead of going through a full rebuild (see _updateUserLocation).
        _userAnnotation = created.last;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('resident_3d_map'),
      styleUri: MapboxStyles.STANDARD,
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}
