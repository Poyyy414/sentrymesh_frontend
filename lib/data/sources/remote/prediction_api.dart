import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/prediction_model.dart';

class PredictionApi {
  const PredictionApi(this._client);

  final ApiClient _client;

  Future<AiModelInfo> fetchModelInfo() async {
    try {
      final response = await _client.get(ApiEndpoints.aiModelInfo);
      return AiModelInfo.fromJson(response as Map<String, dynamic>);
    } catch (_) {
      // Backend not ready yet — return empty so fallback columns are used
      return const AiModelInfo(featureColumns: []);
    }
  }

  Future<PredictionResponseModel> predictNodes({
    required List<Map<String, Object?>> nodes,
  }) async {
    final response = await _client.post(
      ApiEndpoints.aiPredict,
      body: {'nodes': nodes},
    );
    return PredictionResponseModel.fromJson(response);
  }

  Future<PredictionResponseModel> predictFlood({
    required Map<String, Object?> payload,
  }) async {
    final response = await _client.post(
      ApiEndpoints.floodPrediction,
      body: payload,
    );
    return PredictionResponseModel.fromJson(response);
  }

  Future<PredictionResponseModel> predictLandslide({
    required Map<String, Object?> payload,
  }) async {
    final response = await _client.post(
      ApiEndpoints.landslidePrediction,
      body: payload,
    );
    return PredictionResponseModel.fromJson(response);
  }

  Future<PredictionResponseModel> fetchPredictions({String? hazardType}) async {
    final response = await _client.get(
      ApiEndpoints.predictions,
      queryParameters: hazardType != null ? {'hazard_type': hazardType} : {},
    );
    return PredictionResponseModel.fromJson(response);
  }
}