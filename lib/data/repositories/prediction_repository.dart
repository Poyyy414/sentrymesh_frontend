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

  Map<String, Object?> get _weatherSource =>
      (flood?.raw['input'] as Map<String, Object?>?) ?? const {};

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

  Future<PredictionBundle> fetchHomePredictions() async {
    final responses = await Future.wait([
      _remote.predictFlood(payload: _predictionPayload(_nagaFloodSignals)),
      _remote.predictLandslide(
        payload: _predictionPayload(_nagaLandslideSignals),
      ),
    ]);

    return PredictionBundle(
      modelInfo: const AiModelInfo(featureColumns: _fallbackFeatureColumns),
      flood: responses[0].firstNode,
      landslide: responses[1].firstNode,
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, Object?> _predictionPayload(Map<String, num> signals) {
    return {
      for (final entry in signals.entries) entry.key: entry.value,
      'location_label': 'Naga City, Camarines Sur',
    };
  }
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

const _nagaFloodSignals = {
  'latitude': 13.6218,
  'longitude': 123.1948,
  'hour': 9,
  'rainfall_mm': 162,
  'wind_speed_kph': 42,
  'hazard_type': 1,
  'water_level_m': 1.42,
  'river_level_m': 1.68,
  'slope': 0.18,
  'soil_moisture': 0.74,
  'surface_runoff': 0.58,
  'upstream_water_level': 1.91,
  'ground_movement': 0.03,
  'humidity': 88,
  'pressure': 988,
  'temperature': 27,
  'elevation': 21,
  'distance_to_river': 0.7,
  'recent_reports': 6,
};

const _nagaLandslideSignals = {
  'latitude': 13.6502,
  'longitude': 123.2477,
  'hour': 9,
  'rainfall_mm': 118,
  'wind_speed_kph': 38,
  'hazard_type': 2,
  'water_level_m': 0.34,
  'river_level_m': 0.52,
  'slope': 31,
  'soil_moisture': 0.86,
  'surface_runoff': 0.44,
  'upstream_water_level': 0.61,
  'ground_movement': 0.21,
  'humidity': 91,
  'pressure': 986,
  'temperature': 26,
  'elevation': 126,
  'distance_to_river': 2.4,
  'recent_reports': 4,
};
