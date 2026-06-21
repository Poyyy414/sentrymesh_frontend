import '../../shared/enums/hazard_type.dart';
import '../models/prediction_model.dart';
import '../sources/remote/prediction_api.dart';

class PredictionBundle {
  const PredictionBundle({
    required this.modelInfo,
    required this.flood,
    required this.landslide,
    required this.fetchedAt,
  });

  final AiModelInfo modelInfo;
  final NodePredictionModel? flood;
  final NodePredictionModel? landslide;
  final DateTime fetchedAt;

  Map<String, Object?> get _weatherSource {
    final input = flood?.raw['input'];
    if (input is Map<String, Object?>) return input;
    if (input is Map) return input.map((k, v) => MapEntry(k.toString(), v as Object?));
    return const {};
  }

  double get rainfallMm => _asDouble(_weatherSource['rainfall_mm']) ?? 0;
  double get pressureHpa => _asDouble(_weatherSource['pressure']) ?? 1013;
  double get temperatureC => _asDouble(_weatherSource['temperature']) ?? 27;

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class PredictionRepository {
  const PredictionRepository({required PredictionApi remote})
    : _remote = remote;

  final PredictionApi _remote;

  Future<NodePredictionModel?> fetchIncidentPrediction({
    required double latitude,
    required double longitude,
    required HazardType hazardType,
  }) async {
    final hour = DateTime.now().hour;
    final isLandslide = hazardType == HazardType.landslide;
    final payload = <String, Object?>{
      'latitude': latitude,
      'longitude': longitude,
      'hour': hour,
      'hazard_type': isLandslide ? 2 : 1,
      'rainfall_mm': 0,
      'wind_speed_kph': 0,
      'water_level_m': 0,
      'river_level_m': 0,
      'slope': isLandslide ? 15.0 : 0.05,
      'soil_moisture': 0.5,
      'surface_runoff': 0.3,
      'upstream_water_level': 0,
      'ground_movement': 0,
      'humidity': 75,
      'pressure': 1010,
      'temperature': 27,
      'elevation': isLandslide ? 80.0 : 20.0,
      'distance_to_river': 1.0,
      'recent_reports': 1,
      'location_label': 'Incident location',
    };

    final response = isLandslide
        ? await _remote.predictLandslide(payload: payload)
        : await _remote.predictFlood(payload: payload);
    return response.firstNode;
  }

  /// Reads the latest hazard predictions the backend has saved.
  ///
  /// The typhoon simulator POSTs escalating rainfall per barangay to the
  /// backend (`/predictions/flood`), which stores them in Postgres. The app
  /// surfaces those by reading `GET /predictions` and showing the highest-risk
  /// barangay from the most recent batch — so whatever the simulator injects
  /// shows up here. If nothing has been saved yet (no simulator run), a live
  /// baseline prediction is computed so the card isn't blank.
  Future<PredictionBundle> fetchHomePredictions() async {
    final floodNodes = await _recentNodes('flood');
    final landslideNodes = await _recentNodes('landslide');

    var flood = _worstRecent(floodNodes);
    final landslide = _worstRecent(landslideNodes);

    // No saved flood prediction yet — compute a live baseline (the backend
    // enriches it from current weather + sensors). Throws if the backend is
    // unreachable, which surfaces the error state on the home card.
    flood ??= (await _remote.predictFlood(payload: _baselineFloodPayload))
        .firstNode;

    return PredictionBundle(
      modelInfo: const AiModelInfo(featureColumns: _fallbackFeatureColumns),
      flood: flood,
      landslide: landslide,
      fetchedAt: DateTime.now(),
    );
  }

  /// Builds the responder risk heatmap from the backend's saved predictions.
  ///
  /// Each saved flood/landslide prediction carries a location and a risk level,
  /// so the typhoon simulator's per-barangay rows become weighted hot spots.
  /// Only the newest reading per location is kept so escalating ticks replace,
  /// rather than stack on, earlier ones.
  Future<List<HazardHeatPoint>> fetchHazardHeatPoints() async {
    final flood = await _recentNodes('flood');
    final landslide = await _recentNodes('landslide');

    final points = <HazardHeatPoint>[];
    final seen = <String>{};
    for (final node in [...flood, ...landslide]) {
      final point = _heatPointFrom(node);
      if (point == null) {
        continue;
      }
      final key =
          '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';
      if (!seen.add(key)) {
        continue;
      }
      points.add(point);
    }
    return points;
  }

  /// Fetches saved predictions for [hazardType], returning an empty list rather
  /// than throwing so a missing hazard (e.g. no landslide rows) is non-fatal.
  Future<List<NodePredictionModel>> _recentNodes(String hazardType) async {
    try {
      final response = await _remote.fetchPredictions(hazardType: hazardType);
      return response.nodes;
    } catch (_) {
      return const [];
    }
  }
}

/// A weighted hot spot for the responder risk heatmap.
class HazardHeatPoint {
  const HazardHeatPoint({
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.label,
    required this.hazardType,
  });

  final double latitude;
  final double longitude;

  /// Normalised risk in the range 0..1.
  final double severity;
  final String label;
  final String hazardType;
}

HazardHeatPoint? _heatPointFrom(NodePredictionModel node) {
  final latitude = _coord(node.raw['latitude'] ?? node.raw['lat']);
  final longitude = _coord(
    node.raw['longitude'] ?? node.raw['lng'] ?? node.raw['lon'],
  );
  if (latitude == null || longitude == null) {
    return null;
  }

  return HazardHeatPoint(
    latitude: latitude,
    longitude: longitude,
    severity: _severity01(node),
    label: node.raw['location_label']?.toString() ?? node.nodeId,
    hazardType: node.raw['hazard_type']?.toString() ?? 'flood',
  );
}

/// Risk on a 0..1 scale, taking the stronger of the model probability and a
/// floor implied by the alert level.
double _severity01(NodePredictionModel node) {
  final level = node.alertLevel.toLowerCase();
  final base = level.contains('critical')
      ? 0.92
      : level.contains('high')
      ? 0.72
      : (level.contains('medium') ||
            level.contains('moderate') ||
            level.contains('watch'))
      ? 0.5
      : (level.contains('low') || level.contains('safe'))
      ? 0.25
      : 0.15;
  final probability = (node.eventProbability ?? 0).clamp(0, 1).toDouble();
  return probability > base ? probability : base;
}

double? _coord(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

/// Picks the highest-risk prediction from the most recent batch.
///
/// The backend returns rows newest-first; one simulator tick is ~7 barangays,
/// so we look at the latest few and surface the worst one for the summary card.
NodePredictionModel? _worstRecent(List<NodePredictionModel> nodes) {
  if (nodes.isEmpty) {
    return null;
  }

  final recent = nodes.take(7).toList()
    ..sort((a, b) => _severityRank(b).compareTo(_severityRank(a)));
  return recent.first;
}

double _severityRank(NodePredictionModel node) {
  final level = node.alertLevel.toLowerCase();
  final base = level.contains('critical')
      ? 4.0
      : level.contains('high')
      ? 3.0
      : (level.contains('medium') ||
            level.contains('moderate') ||
            level.contains('watch'))
      ? 2.0
      : (level.contains('low') || level.contains('safe'))
      ? 1.0
      : 0.0;
  final probability = (node.eventProbability ?? 0).clamp(0, 1).toDouble();
  return base + probability;
}

const _fallbackFeatureColumns = [
  'latitude',
  'longitude',
  'hour',
  'rainfall_mm',
  'wind_speed_kph',
  'hazard_type',
  'water_level_m',
  'river_level_m',
  'slope',
  'soil_moisture',
  'surface_runoff',
  'upstream_water_level',
  'ground_movement',
  'humidity',
  'pressure',
  'temperature',
  'elevation',
  'distance_to_river',
  'recent_reports',
];

/// Minimal location-only payload for the baseline flood prediction (Naga City
/// centro), used when the backend has no saved predictions yet. Mirrors the
/// field style the typhoon simulator uses; the backend fills in live weather
/// and sensor values, so no storm conditions are faked here.
const _baselineFloodPayload = {
  'location_label': 'Naga City, Camarines Sur',
  'latitude': 13.6218,
  'longitude': 123.1948,
  'elev': 5,
  'slope_deg': 0.5,
  'relief': 12,
};
