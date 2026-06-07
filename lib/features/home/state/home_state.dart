class HomeState {
  const HomeState({
    required this.locationLabel,
    required this.isSafe,
    required this.activeAlertCount,
  });

  final String locationLabel;
  final bool isSafe;
  final int activeAlertCount;
}
