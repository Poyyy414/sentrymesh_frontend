import 'package:sentrymesh_frontend/data/models/alert_model.dart';
import 'package:sentrymesh_frontend/shared/enums/alert_severity.dart';
import 'package:sentrymesh_frontend/shared/enums/hazard_type.dart';

final mockAlerts = [
  AlertModel(
    id: 'alert-flood-001',
    title: 'Flood Warning',
    location: 'San Felipe, Naga City',
    message: 'Rising water reported near low-lying barangays.',
    severity: AlertSeverity.high,
    hazardType: HazardType.flood,
    issuedAt: DateTime(2026, 6, 2, 6, 30),
  ),
  AlertModel(
    id: 'alert-landslide-001',
    title: 'Landslide Alert',
    location: 'Panicuason, Naga City',
    message: 'Slope movement risk increased after heavy rainfall.',
    severity: AlertSeverity.medium,
    hazardType: HazardType.landslide,
    issuedAt: DateTime(2026, 6, 2, 5, 15),
  ),
];
