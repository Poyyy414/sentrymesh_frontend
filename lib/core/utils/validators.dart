class Validators {
  const Validators._();

  static bool isPhoneNumber(String value) {
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value.trim());
  }

  static bool isRequired(String value) {
    return value.trim().isNotEmpty;
  }
}
