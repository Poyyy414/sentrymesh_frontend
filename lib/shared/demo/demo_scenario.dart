import 'package:flutter/foundation.dart';

enum DemoIncidentType { flood, landslide, trapped, roadBlocked, sos }

enum DemoIncidentStatus { active, dispatched, enRoute, resolved }

class DemoIncident {
  const DemoIncident({
    required this.id,
    required this.type,
    required this.title,
    required this.location,
    required this.severity,
    required this.people,
    required this.timeLabel,
    this.status = DemoIncidentStatus.active,
    this.fromResidentSos = false,
  });

  final String id;
  final DemoIncidentType type;
  final String title;
  final String location;
  final String severity;
  final int people;
  final String timeLabel;
  final DemoIncidentStatus status;
  final bool fromResidentSos;

  DemoIncident copyWith({
    String? id,
    DemoIncidentType? type,
    String? title,
    String? location,
    String? severity,
    int? people,
    String? timeLabel,
    DemoIncidentStatus? status,
    bool? fromResidentSos,
  }) {
    return DemoIncident(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      location: location ?? this.location,
      severity: severity ?? this.severity,
      people: people ?? this.people,
      timeLabel: timeLabel ?? this.timeLabel,
      status: status ?? this.status,
      fromResidentSos: fromResidentSos ?? this.fromResidentSos,
    );
  }
}

class DemoScenario extends ChangeNotifier {
  DemoScenario._();

  static final DemoScenario instance = DemoScenario._();

  bool residentSosSent = false;
  String lastResponderAction = 'Monitoring active incidents';

  final List<DemoIncident> _incidents = [
    const DemoIncident(
      id: 'flood-san-felipe',
      type: DemoIncidentType.flood,
      title: 'Flooding',
      location: 'San Felipe, Naga City',
      severity: 'High',
      people: 12,
      timeLabel: '15 min ago',
    ),
    const DemoIncident(
      id: 'landslide-concepcion',
      type: DemoIncidentType.landslide,
      title: 'Landslide',
      location: 'Concepcion Pequena',
      severity: 'Medium',
      people: 7,
      timeLabel: '35 min ago',
    ),
    const DemoIncident(
      id: 'trapped-pacol',
      type: DemoIncidentType.trapped,
      title: 'Trapped Individuals',
      location: 'Pacol, Naga City',
      severity: 'High',
      people: 3,
      timeLabel: '45 min ago',
    ),
    const DemoIncident(
      id: 'flood-tambo',
      type: DemoIncidentType.flood,
      title: 'Flooding',
      location: 'Tambo, Naga City',
      severity: 'Medium',
      people: 5,
      timeLabel: '1 hr ago',
    ),
    const DemoIncident(
      id: 'road-cararayan',
      type: DemoIncidentType.roadBlocked,
      title: 'Road Blocked',
      location: 'Cararayan, Naga City',
      severity: 'Low',
      people: 0,
      timeLabel: '2 hrs ago',
    ),
  ];

  List<DemoIncident> get incidents => List.unmodifiable(_incidents);

  int get activeIncidentCount {
    return _incidents
        .where((incident) => incident.status != DemoIncidentStatus.resolved)
        .length;
  }

  int get highIncidentCount {
    return _incidents.where((incident) => incident.severity == 'High').length;
  }

  int get peopleNeedHelp {
    return _incidents.fold(0, (total, incident) => total + incident.people);
  }

  int get deployedTeams {
    final dispatched = _incidents.where((incident) {
      return incident.status == DemoIncidentStatus.dispatched ||
          incident.status == DemoIncidentStatus.enRoute;
    }).length;

    return 8 + dispatched;
  }

  void sendResidentSos() {
    residentSosSent = true;

    final existingIndex = _incidents.indexWhere((incident) {
      return incident.id == 'resident-sos-john-paul';
    });

    final sosIncident = const DemoIncident(
      id: 'resident-sos-john-paul',
      type: DemoIncidentType.sos,
      title: 'Resident SOS',
      location: 'Naga City, Camarines Sur',
      severity: 'High',
      people: 1,
      timeLabel: 'Just now',
      fromResidentSos: true,
    );

    if (existingIndex == -1) {
      _incidents.insert(0, sosIncident);
    } else {
      _incidents[existingIndex] = sosIncident;
    }

    lastResponderAction = 'Resident emergency request received';
    notifyListeners();
  }

  void dispatchTeam(String incidentId) {
    _updateIncidentStatus(incidentId, DemoIncidentStatus.dispatched);
    lastResponderAction = 'Team Alpha dispatched to incident';
    notifyListeners();
  }

  void markEnRoute(String incidentId) {
    _updateIncidentStatus(incidentId, DemoIncidentStatus.enRoute);
    lastResponderAction = 'Team marked on-route';
    notifyListeners();
  }

  void resolveIncident(String incidentId) {
    _updateIncidentStatus(incidentId, DemoIncidentStatus.resolved);
    lastResponderAction = 'Incident marked resolved';
    notifyListeners();
  }

  void _updateIncidentStatus(String incidentId, DemoIncidentStatus status) {
    final index = _incidents.indexWhere(
      (incident) => incident.id == incidentId,
    );
    if (index == -1) {
      return;
    }

    _incidents[index] = _incidents[index].copyWith(status: status);
  }
}
