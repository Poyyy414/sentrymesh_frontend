enum AlertSeverity {
  low,
  medium,
  high,
  critical,
}

extension AlertSeverityLabel on AlertSeverity {
  String get label {
    return switch (this) {
      AlertSeverity.low => 'Low',
      AlertSeverity.medium => 'Medium',
      AlertSeverity.high => 'High',
      AlertSeverity.critical => 'Critical',
    };
  }
}
