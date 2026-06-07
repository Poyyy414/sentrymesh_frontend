class RescueRequestState {
  const RescueRequestState({
    required this.emergencyType,
    required this.peopleNeedingHelp,
    required this.description,
    required this.isSubmitting,
  });

  final String emergencyType;
  final int peopleNeedingHelp;
  final String description;
  final bool isSubmitting;
}
