import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Color for a rescue request based on how many people need help — was
/// previously copy-pasted with matching magic numbers (>=5 / >=2) across
/// responder_shell.dart and admin_shell.dart.
Color severityColorFromPeopleCount(int people) {
  if (people >= 5) return AppTheme.dangerRed;
  if (people >= 2) return AppTheme.warningAmber;
  return AppTheme.safeGreen;
}

/// Label to go with [severityColorFromPeopleCount]'s thresholds.
String severityLabelFromPeopleCount(int people) {
  if (people >= 5) return 'High';
  if (people >= 2) return 'Medium';
  return 'Low';
}

/// Maps an AI alert level (CRITICAL/HIGH/MODERATE/LOW/SAFE/WATCH) to the
/// three-tier Low/Medium/High legend shown on risk map previews — was
/// previously copy-pasted identically across responder_shell.dart and
/// responder_map_3d_view.dart.
Color riskTierColor(Object? alertLevel) {
  final level = alertLevel?.toString().toLowerCase() ?? '';
  if (level.contains('critical') || level.contains('high')) {
    return AppTheme.dangerRed;
  }
  if (level.contains('moderate') || level.contains('medium')) {
    return AppTheme.warningAmber;
  }
  return AppTheme.safeGreen;
}
