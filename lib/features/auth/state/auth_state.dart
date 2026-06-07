class AuthState {
  const AuthState({
    required this.email,
    required this.isSubmitting,
    this.errorMessage,
  });

  final String email;
  final bool isSubmitting;
  final String? errorMessage;
}
