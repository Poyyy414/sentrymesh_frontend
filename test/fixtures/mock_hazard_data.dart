import 'package:sentrymesh_frontend/data/models/hazard_model.dart';
import 'package:sentrymesh_frontend/shared/enums/hazard_type.dart';

final mockHazards = [
  HazardModel(
    id: 'hazard-flood-001',
    type: HazardType.flood,
    confidence: 0.89,
    severityScore: 0.76,
    updatedAt: DateTime(2026, 6, 2, 6, 45),
    locationLabel: 'Naga River Basin',
  ),
];
