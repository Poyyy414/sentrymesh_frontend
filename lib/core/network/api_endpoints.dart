class ApiEndpoints {
  const ApiEndpoints._();

  static const authLogin = '/auth/login';
  static const authMe = '/auth/me';
  static const authRegister = '/auth/register';
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
  static const familyMessages = '/family/messages';
  static const familyInvites = '/family/invites';
  static const notifications = '/notifications';

  static String notificationRead(String id) => '/notifications/$id/read';

  static String familyMemberById(String id) => '/family/members/$id';

  static String familyMemberStatus(String id) => '/family/members/$id/status';

  static String familyInviteAccept(String id) => '/family/invites/$id/accept';

  static String familyInviteDecline(String id) =>
      '/family/invites/$id/decline';

  static String evacuationCenterById(String id) => '/evacuation-centers/$id';

  static String evacuationCenterOccupancy(String id) =>
      '/evacuation-centers/$id/occupancy';

  static String rescueRequestResponder(String id) =>
      '/rescue-requests/$id/responder';

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

  static const teams = '/teams';
  static const teamAllLocations = '/teams/all-locations';

  static String teamById(String id) => '/teams/$id';

  static String teamJoin(String id) => '/teams/$id/join';

  static String teamLeave(String id) => '/teams/$id/leave';

  static String teamLocation(String id) => '/teams/$id/location';

  static String teamLocations(String id) => '/teams/$id/locations';

  static const aiHealth = '/';
  static const aiModelInfo = '/model/info';
  static const aiPredict = '/predict';
  static const aiDemoPrediction = '/predict/demo';

  static String predictionById(String id) {
    return '/predictions/$id';
  }
}
