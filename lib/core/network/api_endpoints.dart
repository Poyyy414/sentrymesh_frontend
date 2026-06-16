class ApiEndpoints {
  const ApiEndpoints._();

  static const authLogin = '/auth/login';
  static const authMe = '/auth/me';
  static const authRegister = '/api/v1/auth/register';
  static const alerts = '/alerts';
  static const rescueRequests = '/rescue-requests';
  static const safeRoutes = '/safe-routes';
  static const floodPrediction = '/predictions/flood';
  static const landslidePrediction = '/predictions/landslide';
  static const predictions = '/predictions';
  static const familyMembers = '/family/members';
  static const familyMyStatus = '/family/my-status';
  static const dashboard = '/dashboard';
  static const weatherSubscriptions = '/weather/subscriptions';
  static const typhoonStatus = '/weather/typhoon-status';
  static const typhoonAlerts = '/weather/typhoon-alerts';
  static const weatherCurrent = '/weather/current';
  static const evacuationCenters = '/evacuation-centers';

  static String rescueRequestShelter(String id) {
    return '/rescue-requests/$id/shelter';
  }

  static String rescueRequestById(String id) {
    return '/rescue-requests/$id';
  }

  static String rescueRequestLocation(String id) {
    return '/rescue-requests/$id/location';
  }

  static String rescueRequestStatus(String id) {
    return '/rescue-requests/$id/status';
  }

  static String rescueRequestNavigation(String id) {
    return '/rescue-requests/$id/navigation';
  }

  static const aiHealth = '/';
  static const aiModelInfo = '/model/info';
  static const aiPredict = '/predict';
  static const aiDemoPrediction = '/predict/demo';

  static String predictionById(String id) {
    return '/predictions/$id';
  }
}
