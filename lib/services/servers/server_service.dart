import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sono/data/database/database_helper.dart';
import 'package:sono/data/models/music_server_model.dart';
import 'package:sono/services/servers/server_protocol.dart';
import 'package:sono/services/servers/subsonic_protocol.dart';

enum ServerReachability { unknown, checking, reachable, unreachable }

/// Manages custom music server configurations and active connections
class MusicServerService with ChangeNotifier {
  static final MusicServerService instance = MusicServerService._internal();
  MusicServerService._internal();

  List<MusicServerModel> _servers = [];
  MusicServerModel? _activeServer;
  MusicServerProtocol? _activeProtocol;

  final Map<int, ServerReachability> _reachability = {};
  Timer? _pingTimer;
  static const Duration _pingInterval = Duration(seconds: 60);

  List<MusicServerModel> get servers => List.unmodifiable(_servers);
  MusicServerModel? get activeServer => _activeServer;
  MusicServerProtocol? get activeProtocol => _activeProtocol;
  bool get hasActiveServer => _activeServer != null && _activeProtocol != null;

  ServerReachability reachabilityOf(int serverId) =>
      _reachability[serverId] ?? ServerReachability.unknown;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('MusicServerService: $message');
    }
  }

  /// Load all servers from database. Call during app init
  Future<void> loadServers() async {
    try {
      final db = await SonoDatabaseHelper.instance.database;
      final rows = await db.query('music_servers', orderBy: 'name ASC');
      _servers = rows.map((r) => MusicServerModel.fromMap(r)).toList();

      //restore active server if any
      final activeServers = _servers.where((s) => s.isActive);
      if (activeServers.isNotEmpty) {
        final active = activeServers.first;
        _activeServer = active;
        _activeProtocol = createProtocol(active);
        _log('Restored active server: ${active.name}');
      }

      notifyListeners();
      _startPingMonitor();
    } catch (e) {
      _log('Error loading servers: $e');
    }
  }

  void _startPingMonitor() {
    _pingAll();
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _pingAll());
  }

  Future<void> _pingAll() async {
    if (_servers.isEmpty) return;

    //mark all as checking
    for (final s in _servers) {
      _reachability[s.id!] = ServerReachability.checking;
    }
    notifyListeners();

    //ping concurrently
    await Future.wait(_servers.map((s) async {
      final protocol = createProtocol(s);
      final error = await protocol.ping();
      _reachability[s.id!] =
          error == null ? ServerReachability.reachable : ServerReachability.unreachable;
    }));

    notifyListeners();
  }

  /// Add a new server. Validates connection via ping() before saving
  /// Returns null on success, error message on failure
  Future<String?> addServer(MusicServerModel server) async {
    try {
      //validate connection first
      final protocol = createProtocol(server);
      final pingError = await protocol.ping();
      if (pingError != null) {
        return 'Connection failed: $pingError';
      }

      final db = await SonoDatabaseHelper.instance.database;
      final id = await db.insert('music_servers', server.toMap());
      final saved = server.copyWith(id: id);
      _servers.add(saved);

      _log('Added server: ${saved.name} (id: $id)');
      _reachability[id] = ServerReachability.reachable; //just passed ping
      _startPingMonitor();
      notifyListeners();
      return null;
    } catch (e) {
      _log('Error adding server: $e');
      return e.toString();
    }
  }

  /// Remove a server by ID
  Future<void> removeServer(int serverId) async {
    try {
      final db = await SonoDatabaseHelper.instance.database;
      await db.delete('music_servers', where: 'id = ?', whereArgs: [serverId]);
      _servers.removeWhere((s) => s.id == serverId);
      _reachability.remove(serverId);

      //if this was the active server, disconnect
      if (_activeServer?.id == serverId) {
        _activeServer = null;
        _activeProtocol = null;
      }

      _log('Removed server id: $serverId');
      notifyListeners();
    } catch (e) {
      _log('Error removing server: $e');
    }
  }

  /// Set a server as active. Creates the appropriate protocol instance
  Future<String?> setActiveServer(int serverId) async {
    try {
      final server = _servers.firstWhere((s) => s.id == serverId);
      final protocol = createProtocol(server);

      //validate connection
      final pingError = await protocol.ping();
      if (pingError != null) {
        return 'Connection failed: $pingError';
      }

      //deactivate all servers in DB, then activate this one
      final db = await SonoDatabaseHelper.instance.database;
      await db.update('music_servers', {'is_active': 0});
      await db.update(
        'music_servers',
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [serverId],
      );

      //update local state
      _servers = _servers.map((s) {
        return s.copyWith(isActive: s.id == serverId);
      }).toList();

      _activeServer = server.copyWith(isActive: true);
      _activeProtocol = protocol;

      _log('Activated server: ${server.name}');
      notifyListeners();
      return null;
    } catch (e) {
      _log('Error activating server: $e');
      return e.toString();
    }
  }

  /// Disconnect from the active server
  Future<void> disconnectServer() async {
    if (_activeServer == null) return;

    try {
      final db = await SonoDatabaseHelper.instance.database;
      await db.update('music_servers', {'is_active': 0});

      _servers = _servers.map((s) => s.copyWith(isActive: false)).toList();
      _activeServer = null;
      _activeProtocol = null;

      _log('Disconnected from active server');
      notifyListeners();
    } catch (e) {
      _log('Error disconnecting: $e');
    }
  }

  /// Create a protocol instance for a server. Public for connection testing
  MusicServerProtocol createProtocol(MusicServerModel server) {
    switch (server.type) {
      case MusicServerType.subsonic:
        return SubsonicProtocol(server);
    }
  }
}
