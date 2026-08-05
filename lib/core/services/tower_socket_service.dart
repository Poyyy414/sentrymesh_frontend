import 'dart:async';
import 'dart:developer' as developer;

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env.dart';

void _log(String message) => developer.log(message, name: 'TowerSocket');

typedef JsonMap = Map<String, Object?>;

class TowerSocketService {
  TowerSocketService();

  io.Socket? _socket;
  final _sosNewController = StreamController<JsonMap>.broadcast();
  final _sosStatusController = StreamController<JsonMap>.broadcast();
  final _sosLocationController = StreamController<JsonMap>.broadcast();
  final _teamLocationController = StreamController<JsonMap>.broadcast();
  final _teamMemberJoinedController = StreamController<JsonMap>.broadcast();
  final _teamMemberLeftController = StreamController<JsonMap>.broadcast();
  final _hazardWarningController = StreamController<JsonMap>.broadcast();
  final _teamAssignmentController = StreamController<JsonMap>.broadcast();
  final _sosAssignedController = StreamController<JsonMap>.broadcast();
  final _typhoonAlertController = StreamController<JsonMap>.broadcast();
  final _familyStatusUpdateController = StreamController<JsonMap>.broadcast();
  final _familyInviteController = StreamController<JsonMap>.broadcast();
  final _familyInviteAcceptedController = StreamController<JsonMap>.broadcast();
  final _evacuationCenterUpdateController =
      StreamController<JsonMap>.broadcast();
  final _connectedController = StreamController<void>.broadcast();

  Stream<JsonMap> get onSosNew => _sosNewController.stream;
  Stream<JsonMap> get onSosStatus => _sosStatusController.stream;
  Stream<JsonMap> get onSosLocation => _sosLocationController.stream;
  Stream<JsonMap> get onTeamLocation => _teamLocationController.stream;
  Stream<JsonMap> get onTeamMemberJoined => _teamMemberJoinedController.stream;
  Stream<JsonMap> get onTeamMemberLeft => _teamMemberLeftController.stream;
  Stream<JsonMap> get onHazardWarning => _hazardWarningController.stream;
  Stream<JsonMap> get onTeamAssignment => _teamAssignmentController.stream;
  // Broadcast to every connected responder (unlike team:assignment, which is
  // scoped to a `team:<id>` socket room this client never actually joins) —
  // this is the reliable way to learn "a team just got a new assignment"
  // regardless of dispatch timing.
  Stream<JsonMap> get onSosAssigned => _sosAssignedController.stream;
  Stream<JsonMap> get onTyphoonAlert => _typhoonAlertController.stream;
  Stream<JsonMap> get onFamilyStatusUpdate => _familyStatusUpdateController.stream;
  Stream<JsonMap> get onFamilyInvite => _familyInviteController.stream;
  Stream<JsonMap> get onFamilyInviteAccepted =>
      _familyInviteAcceptedController.stream;
  Stream<JsonMap> get onEvacuationCenterUpdate =>
      _evacuationCenterUpdateController.stream;
  // Fires on every successful connect, including automatic reconnects (e.g.
  // after Render's infrastructure resets an idle connection, which happens
  // roughly every 60s in practice). Any broadcast event that lands during
  // the few-second reconnect gap is otherwise lost - screens showing
  // time-sensitive data should treat this as "refetch, you may have missed
  // something" rather than relying on push events alone.
  Stream<void> get onConnected => _connectedController.stream;

  bool get isConnected => _socket?.connected ?? false;

  String? _lastRole;
  String? _lastUserId;
  String? _lastToken;

  void connect({String? role, String? userId, String? token, String? baseUrl}) {
    _lastRole = role;
    _lastUserId = userId;
    _lastToken = token;
    final url = baseUrl ?? Env.apiBaseUrl;

    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _log('connected to $url, emitting join');
      _socket!.emit('join', {});
    });

    _socket!.onConnectError((data) {
      _log('connect_error: $data');
    });

    _socket!.onError((data) {
      _log('error: $data');
    });

    _socket!.onDisconnect((data) {
      _log('disconnected: $data');
    });

    _socket!.on('connect_error_detail', (data) {
      _log('server rejected connection: $data');
    });

    _socket!.on('joined', (data) {
      _log('server acked join: $data');
      _connectedController.add(null);
    });

    _socket!.on('sos:new', (data) {
      if (data is Map) {
        _sosNewController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('sos:status', (data) {
      if (data is Map) {
        _sosStatusController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('sos:location', (data) {
      if (data is Map) {
        _sosLocationController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('team:location', (data) {
      if (data is Map) {
        _teamLocationController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('team:joined', (data) {
      if (data is Map) {
        _teamMemberJoinedController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('team:left', (data) {
      if (data is Map) {
        _teamMemberLeftController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('hazard:warning', (data) {
      if (data is Map) {
        _hazardWarningController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('typhoon:alert', (data) {
      if (data is Map) {
        _typhoonAlertController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('family:status_update', (data) {
      if (data is Map) {
        _familyStatusUpdateController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('family:invite', (data) {
      if (data is Map) {
        _familyInviteController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('family:invite_accepted', (data) {
      if (data is Map) {
        _familyInviteAcceptedController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('evacuation_center:updated', (data) {
      if (data is Map) {
        _evacuationCenterUpdateController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('team:assignment', (data) {
      if (data is Map) {
        _teamAssignmentController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.on('sos:assigned', (data) {
      if (data is Map) {
        _sosAssignedController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.connect();
  }

  void reconnect({String? role, String? userId, String? token, String? baseUrl}) {
    disconnect();
    connect(
      role: role ?? _lastRole,
      userId: userId ?? _lastUserId,
      token: token ?? _lastToken,
      baseUrl: baseUrl,
    );
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void emitLocationUpdate(String teamId, double latitude, double longitude) {
    _socket?.emit('team:location', {
      'team_id': teamId,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  // Reported independent of any active rescue request — lets the server
  // scope hazard/typhoon broadcasts to people actually near the event
  // instead of notifying every connected device regardless of distance.
  void emitMyLocation(double latitude, double longitude) {
    _socket?.emit('location:update', {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  void dispose() {
    disconnect();
    _sosNewController.close();
    _sosStatusController.close();
    _sosLocationController.close();
    _teamLocationController.close();
    _teamMemberJoinedController.close();
    _teamMemberLeftController.close();
    _hazardWarningController.close();
    _teamAssignmentController.close();
    _sosAssignedController.close();
    _typhoonAlertController.close();
    _familyStatusUpdateController.close();
    _familyInviteController.close();
    _familyInviteAcceptedController.close();
    _evacuationCenterUpdateController.close();
    _connectedController.close();
  }
}
