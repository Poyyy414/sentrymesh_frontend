class ProfileState {
  const ProfileState({
    required this.displayName,
    required this.teamName,
    required this.isSaving,
  });

  final String displayName;
  final String teamName;
  final bool isSaving;
}
