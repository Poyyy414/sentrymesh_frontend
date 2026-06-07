class SafeRouteState {
  const SafeRouteState({
    required this.destinationQuery,
    required this.isUsingOfflineMap,
    required this.isLoading,
  });

  final String destinationQuery;
  final bool isUsingOfflineMap;
  final bool isLoading;
}
