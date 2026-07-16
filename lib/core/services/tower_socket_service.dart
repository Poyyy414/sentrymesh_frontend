import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env.dart';

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

  Stream<JsonMap> get onSosNew => _sosNewController.stream;
  Stream<JsonMap> get onSosStatus => _sosStatusController.stream;
  Stream<JsonMap> get onSosLocation => _sosLocationController.stream;
  Stream<JsonMap> get onTeamLocation => _teamLocationController.stream;
  Stream<JsonMap> get onTeamMemberJoined => _teamMemberJoinedController.stream;
  Stream<JsonMap> get onTeamMemberLeft => _teamMemberLeftController.stream;
  Stream<JsonMap> get onHazardWarning => _hazardWarningController.stream;
  Stream<JsonMap> get onTeamAssignment => _teamAssignmentController.stream;

  bool get isConnected => _socket?.connected ?? false;

  String? _lastRole;
  String? _lastUserId;

  void connect({String? role, String? userId, String? baseUrl}) {
    _lastRole = role;
    _lastUserId = userId;
    final url = baseUrl ?? Env.apiBaseUrl;

    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _socket!.emit('join', {'role': role, 'userId': userId});
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

    _socket!.on('team:assignment', (data) {
      if (data is Map) {
        _teamAssignmentController.add(Map<String, Object?>.from(data));
      }
    });

    _socket!.connect();
  }

  void reconnect({String? role, String? userId, String? baseUrl}) {
    disconnect();
    connect(
      role: role ?? _lastRole,
      userId: userId ?? _lastUserId,
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
  }
}
