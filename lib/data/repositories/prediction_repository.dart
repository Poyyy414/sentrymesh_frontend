import '../../core/services/geo_bounds.dart';
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

  // Used only when a real device location isn't available (permission
  // denied / GPS off), so the home screen still shows a plausible reading
  // instead of nothing. See kDefaultMapCenter for why this one constant.
  static const _fallbackLatitude = kDefaultLatitude;
  static const _fallbackLongitude = kDefaultLongitude;

  Future<NodePredictionModel?> fetchIncidentPrediction({
    required double latitude,
    required double longitude,
    required HazardType hazardType,
  }) async {
    final isLandslide = hazardType == HazardType.landslide;
    final payload = <String, Object?>{
      'latitude': latitude,
      'longitude': longitude,
      'hazard_type': isLandslide ? 2 : 1,
      'location_label': 'Incident location',
    };

    final response = isLandslide
        ? await _remote.predictLandslide(payload: payload)
        : await _remote.predictFlood(payload: payload);
    return response.firstNode;
  }

  /// The AI service fetches its own live rainfall/terrain data for whatever
  /// coordinates are sent — pass the resident's real device location when
  /// known, rather than a fixed reference point, so the risk shown actually
  /// reflects where they are.
  Future<PredictionBundle> fetchHomePredictions({
    double? latitude,
    double? longitude,
    String? locationLabel,
  }) async {
    final lat = latitude ?? _fallbackLatitude;
    final lon = longitude ?? _fallbackLongitude;
    final label = locationLabel ?? 'Naga City, Camarines Sur';

    final responses = await Future.wait([
      _remote.predictFlood(
        payload: {
          'latitude': lat,
          'longitude': lon,
          'hazard_type': 1,
          'location_label': label,
        },
      ),
      _remote.predictLandslide(
        payload: {
          'latitude': lat,
          'longitude': lon,
          'hazard_type': 2,
          'location_label': label,
        },
      ),
    ]);

    return PredictionBundle(
      modelInfo: const AiModelInfo(featureColumns: _fallbackFeatureColumns),
      flood: responses[0].firstNode,
      landslide: responses[1].firstNode,
      fetchedAt: DateTime.now(),
    );
  }
}

const _fallbackFeatureColumns = [
  'latitude',
  'longitude',
  'hazard_type',
];
