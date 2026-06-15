class ApiEndpoints {
  const ApiEndpoints._();

  static const authLogin = '/auth/login';
  static const authRegister = '/auth/register';
  static const alerts = '/alerts';
  static const rescueRequests = '/rescue-requests';
  static const safeRoutes = '/safe-routes';
  static const floodPrediction = '/predictions/flood';
  static const landslidePrediction = '/predictions/landslide';
  static const predictions = '/predictions';
  static const familyMembers = '/family/members';
  static const dashboard = '/dashboard';

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
