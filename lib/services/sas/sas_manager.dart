import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:mime/mime.dart';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Connection quality levels for stream health
enum ConnectionQuality { excellent, good, fair, poor, critical }

/// Stream health status data class
class StreamHealthStatus {
  final ConnectionQuality quality;
  final int rebufferCount;
  final Duration averageLatency;
  final DateTime lastUpdate;
  final double bufferHealth;

  StreamHealthStatus({
    required this.quality,
    this.rebufferCount = 0,
    this.averageLatency = Duration.zero,
    DateTime? lastUpdate,
    this.bufferHealth = 1.0,
  }) : lastUpdate = lastUpdate ?? DateTime.now();

  StreamHealthStatus copyWith({
    ConnectionQuality? quality,
    int? rebufferCount,
    Duration? averageLatency,
    DateTime? lastUpdate,
    double? bufferHealth,
  }) {
    return StreamHealthStatus(
      quality: quality ?? this.quality,
      rebufferCount: rebufferCount ?? this.rebufferCount,
      averageLatency: averageLatency ?? this.averageLatency,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      bufferHealth: bufferHealth ?? this.bufferHealth,
    );
  }
}

/// Stream health monitor class
class _StreamHealthMonitor {
  final List<int> _latencySamples = [];
  int _rebufferEvents = 0;
  DateTime _sessionStart = DateTime.now();
  static const int _maxSamples = 20;

  final ValueNotifier<StreamHealthStatus> healthStatus = ValueNotifier(
    StreamHealthStatus(quality: ConnectionQuality.excellent),
  );

  void recordLatency(int milliseconds) {
    _latencySamples.add(milliseconds);
    if (_latencySamples.length > _maxSamples) {
      _latencySamples.removeAt(0);
    }
    _updateHealth();
  }

  void recordRebuffer() {
    _rebufferEvents++;
    _updateHealth();
  }

  void recordBufferHealth(double health) {
    final current = healthStatus.value;
    healthStatus.value = current.copyWith(bufferHealth: health);
    _updateHealth();
  }

  void _updateHealth() {
    if (_latencySamples.isEmpty) return;

    final avgLatency = Duration(
      milliseconds:
          _latencySamples.reduce((a, b) => a + b) ~/ _latencySamples.length,
    );

    final sessionDuration = DateTime.now().difference(_sessionStart);
    final rebufferRate =
        sessionDuration.inMinutes > 0
            ? _rebufferEvents / sessionDuration.inMinutes
            : 0.0;

    ConnectionQuality quality;
    if (avgLatency.inMilliseconds < 50 && rebufferRate < 0.5) {
      quality = ConnectionQuality.excellent;
    } else if (avgLatency.inMilliseconds < 100 && rebufferRate < 1.0) {
      quality = ConnectionQuality.good;
    } else if (avgLatency.inMilliseconds < 200 && rebufferRate < 2.0) {
      quality = ConnectionQuality.fair;
    } else if (avgLatency.inMilliseconds < 500 && rebufferRate < 5.0) {
      quality = ConnectionQuality.poor;
    } else {
      quality = ConnectionQuality.critical;
    }

    healthStatus.value = StreamHealthStatus(
      quality: quality,
      rebufferCount: _rebufferEvents,
      averageLatency: avgLatency,
      bufferHealth: healthStatus.value.bufferHealth,
    );
  }

  void reset() {
    _latencySamples.clear();
    _rebufferEvents = 0;
    _sessionStart = DateTime.now();
    healthStatus.value = StreamHealthStatus(
      quality: ConnectionQuality.excellent,
    );
  }

  void dispose() {
    healthStatus.dispose();
  }
}

/// Data class for session info
class SASInfo {
  final String host;
  final int port;
  final String sessionId;

  SASInfo({required this.host, required this.port, required this.sessionId});

  String get deepLink =>
      'sonoapp://jam?host=$host&port=$port&session=$sessionId';
  String get webUrl => 'http://$host:$port';
}

//host: SonoPlayer plays local files
//client: SonoPlayer loads and plays stream URL from host
class SASManager {
  static final SASManager _instance = SASManager._internal();
  factory SASManager() => _instance;
  SASManager._internal();

  HttpServer? _server;
  int? _port;
  String? _sessionId;
  final List<WebSocket> _clients = [];
  Timer? _clientCleanupTimer; //periodic cleanup of dead clients

  StreamSubscription? _clientSubscription;
  WebSocket? _clientSocket;
  StreamSubscription<ProcessingState>? _streamCompletionSubscription;
  Timer? _clientPingTimer; //keep client connection alive

  bool _isHost = false;
  bool _isConnected = false;
  SASInfo? _sessionInfo;

  bool _isTransitioning = false;
  Timer? _bufferHealthTimer;
  int _lastPositionBroadcast = 0;
  Map<String, dynamic>? _deviceInfo;
  int _streamDelayMs = 0; //fault 0ms for minimal latency

  final SonoPlayer _sonoPlayer = SonoPlayer();

  VoidCallback? _hostPlayingListener;
  VoidCallback? _hostSongListener;
  VoidCallback? _hostPositionListener;
  VoidCallback? _hostQueueListener;

  bool get isHost => _isHost;
  bool get isConnected => _isConnected;
  SASInfo? get sessionInfo => _sessionInfo;
  int get connectedClientsCount => _clients.length;
  bool get isTransitioning => _isTransitioning;

  //==========================================================================
  // FILE-BASED PERMISSION HELPERS
  //==========================================================================

  /// Returns true if current device can control playback
  /// Host can always control. Non-connected devices can control locally
  /// Connected clients CANNOT control
  bool get canControlPlayback => _isHost || (!_isHost && !_isConnected);

  /// Returns true if device is in client mode (connected but not host)
  bool get isInClientMode => !_isHost && _isConnected;

  /// Checks if playback control is allowed. Returns false and logs if blocked
  bool checkPlaybackControl() {
    if (isInClientMode) {
      if (kDebugMode) {
        debugPrint('[SAS] Playback control blocked - device is in client mode');
      }
      return false;
    }
    return true;
  }

  //==========================================================================
  // STREAM DELAY CONTROL
  //==========================================================================

  /// Gets the current stream delay in milliseconds
  int get streamDelayMs => _streamDelayMs;

  /// Gets the stream delay (clamped between 0-5000ms)
  void setStreamDelay(int delayMs) {
    _streamDelayMs = delayMs.clamp(0, 5000);
    if (kDebugMode) {
      debugPrint('[SAS] Stream delay set to ${_streamDelayMs}ms');
    }
  }

  //error tracking and retry state
  final ValueNotifier<String?> connectionError = ValueNotifier(null);
  final ValueNotifier<bool> isRetrying = ValueNotifier(false);

  //client-side queue state
  final ValueNotifier<List<Map<String, dynamic>>> clientQueue = ValueNotifier(
    [],
  );
  final ValueNotifier<int> clientCurrentIndex = ValueNotifier(0);

  //client-side current song metadata
  final ValueNotifier<String?> clientSongTitle = ValueNotifier(null);
  final ValueNotifier<String?> clientSongArtist = ValueNotifier(null);
  final ValueNotifier<String?> clientSongAlbum = ValueNotifier(null);
  final ValueNotifier<String?> clientArtworkUrl = ValueNotifier(null);
  final ValueNotifier<int?> clientSongDuration = ValueNotifier(null);

  //message queue for handling messages during transitions
  final List<Map<String, dynamic>> _messageQueue = [];
  static const int _maxQueueSize = 50;

  //drift correction thresholds (tightened for 250ms position updates)
  static const Duration _driftThreshold = Duration(milliseconds: 150);
  static const Duration _majorDriftThreshold = Duration(milliseconds: 500);
  static const Duration _codecDelayEstimate = Duration(milliseconds: 50);

  //stream health monitoring
  final _StreamHealthMonitor _healthMonitor = _StreamHealthMonitor();
  ValueNotifier<StreamHealthStatus> get streamHealth =>
      _healthMonitor.healthStatus;

  //=============== HOST METHODS =================

  Future<SASInfo> startHost() async {
    if (_isHost) {
      await stopHost();
    }

    if (_isConnected) {
      await leaveSession();
    }

    try {
      //collect device information for diagnostics
      _deviceInfo = await _collectDeviceInfo();

      //random port
      _port = 30000 + Random().nextInt(10000);
      _sessionId = _generateSessionId();

      //get local ip
      final ip = await _getLocalIP();

      //start http server
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port!);
      _server!.listen(_handleRequest);

      _isHost = true;
      _sessionInfo = SASInfo(host: ip, port: _port!, sessionId: _sessionId!);

      //setup listeners to broadcast SonopPlayer changes to clients
      _setupHostListeners();

      //start periodic cleanup of dead clients (every 30 seconds)
      _startClientCleanup();

      if (kDebugMode) {
        debugPrint('[SAS Host] Starting on ${_deviceInfo?['platform']} device');
        debugPrint(
          '[SAS Host] Device: ${_deviceInfo?['manufacturer']} ${_deviceInfo?['model']}',
        );
        debugPrint(
          '[SAS Host] Android SDK: ${_deviceInfo?['sdkInt']} (${_deviceInfo?['release']})',
        );
        debugPrint('[SAS Host] Server address: $ip:$_port');
        debugPrint('[SAS Host] Session ID: $_sessionId');
        debugPrint('[SAS Host] Deep link: ${_sessionInfo!.deepLink}');
      }

      return _sessionInfo!;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS Host] Failed to start: $e');
        if (_deviceInfo != null) {
          debugPrint('[SAS Host] Device info: $_deviceInfo');
        }
      }
      rethrow;
    }
  }

  /// Stop hosting
  Future<void> stopHost() async {
    if (!_isHost) return;

    try {
      _broadcastToClients({'type': 'session_ended', 'data': {}});

      for (var client in _clients) {
        await client.close();
      }
      _clients.clear();

      await _server?.close(force: true);
      _server = null;

      _removeHostListeners();

      //stop cleanup timer
      _clientCleanupTimer?.cancel();
      _clientCleanupTimer = null;

      _isHost = false;
      _port = null;
      _sessionId = null;
      _sessionInfo = null;

      if (kDebugMode) {
        debugPrint('Jam Session stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error stopping host: $e');
      }
    }
  }

  //handle incoming http requests
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set(
        'Access-Control-Allow-Methods',
        'GET, POST, OPTIONS',
      );
      request.response.headers.set(
        'Access-Control-Allow-Headers',
        'Origin, Content-Type, Range',
      );

      if (request.method == 'OPTIONS') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }

      if (request.uri.path == '/stream') {
        await _handleStreamRequest(request);
      } else if (request.uri.path == '/artwork') {
        await _handleArtworkRequest(request);
      } else if (request.uri.path == '/ws') {
        await _handleWebSocketUpgrade(request);
      } else if (request.uri.path == '/ping') {
        request.response.statusCode = 200;
        request.response.write('pong');
        await request.response.close();
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Request handling error: $e');
      }
      try {
        request.response.statusCode = 500;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleStreamRequest(HttpRequest request) async {
    final currentSong = _sonoPlayer.currentSong.value;

    if (currentSong == null || currentSong.data.isEmpty) {
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }

    try {
      final file = File(currentSong.data);

      if (!await file.exists()) {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }

      final mimeType = _getMimeType(currentSong.data);

      request.response.headers.set('Content-Type', mimeType);
      request.response.headers.set('Accept-Ranges', 'bytes');
      request.response.headers.set('Connection', 'keep-alive');

      request.response.headers.set('Cache-Control', 'public, max-age=3600');

      if (kDebugMode) {
        debugPrint('Streaming: ${currentSong.title} ($mimeType)');
      }

      final range = request.headers.value('range');
      if (range != null) {
        await _handleRangeRequest(request, file, range);
      } else {
        final fileLength = await file.length();
        request.response.headers.set('Content-Length', fileLength.toString());

        await file.openRead().pipe(request.response);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Stream error: $e');
      }
      try {
        request.response.statusCode = 500;
        await request.response.close();
      } catch (_) {}
    }
  }

  //handle artwork requests
  Future<void> _handleArtworkRequest(HttpRequest request) async {
    final currentSong = _sonoPlayer.currentSong.value;

    if (currentSong == null) {
      request.response.statusCode = 404;
      request.response.write('No song playing');
      await request.response.close();
      return;
    }

    try {
      //query artwork using on_audio_query
      final audioQuery = OnAudioQuery();
      final artworkBytes = await audioQuery.queryArtwork(
        currentSong.id,
        ArtworkType.AUDIO,
        quality: 100,
      );

      if (artworkBytes == null || artworkBytes.isEmpty) {
        request.response.statusCode = 404;
        request.response.write('No artwork available');
        await request.response.close();
        return;
      }

      //artwork from on_audio_query is typically JPEG
      request.response.headers.set('Content-Type', 'image/jpeg');
      request.response.headers.set(
        'Content-Length',
        artworkBytes.length.toString(),
      );
      request.response.headers.set('Cache-Control', 'public, max-age=3600');

      request.response.add(artworkBytes);
      await request.response.close();

      if (kDebugMode) {
        debugPrint(
          'Served artwork: ${currentSong.title} (${artworkBytes.length} bytes)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Artwork serving error: $e');
      }
      try {
        request.response.statusCode = 500;
        await request.response.close();
      } catch (_) {}
    }
  }

  String _getMimeType(String filePath) {
    final mimeType = lookupMimeType(filePath);

    if (mimeType != null) {
      return mimeType;
    }

    final extension = filePath.toLowerCase().split('.').last;

    String? fallbackType;
    switch (extension) {
      case 'mp3':
        fallbackType = 'audio/mpeg';
        break;
      case 'm4a':
      case 'mp4':
        fallbackType = 'audio/mp4';
        break;
      case 'aac':
        fallbackType = 'audio/aac';
        break;
      case 'flac':
        fallbackType = 'audio/flac';
        break;
      case 'wav':
        fallbackType = 'audio/wav';
        break;
      case 'ogg':
        fallbackType = 'audio/ogg';
        break;
      case 'opus':
        fallbackType = 'audio/opus';
        break;
      case 'weba':
        fallbackType = 'audio/webm';
        break;
      default:
        if (kDebugMode) {
          debugPrint(
            'WARNING: Unknown audio extension ".$extension" for $filePath - using audio/mpeg fallback',
          );
        }
        fallbackType = 'audio/mpeg';
    }

    return fallbackType;
  }

  //handle range requests for seeking
  Future<void> _handleRangeRequest(
    HttpRequest request,
    File file,
    String range,
  ) async {
    try {
      final fileLength = await file.length();

      //parse range header
      if (!range.startsWith('bytes=')) {
        request.response.statusCode = 400;
        await request.response.close();
        return;
      }

      final parts = range.replaceAll('bytes=', '').split('-');
      if (parts.isEmpty) {
        request.response.statusCode = 400;
        await request.response.close();
        return;
      }

      //parse start position
      final start = int.tryParse(parts[0]);
      if (start == null || start < 0 || start >= fileLength) {
        request.response.statusCode = 416;
        request.response.headers.set('Content-Range', 'bytes */$fileLength');
        await request.response.close();
        return;
      }

      //parse end position
      final end =
          (parts.length > 1 && parts[1].isNotEmpty)
              ? int.tryParse(parts[1]) ?? (fileLength - 1)
              : fileLength - 1;

      //validate end position
      final clampedEnd = end.clamp(start, fileLength - 1);

      if (clampedEnd < start) {
        request.response.statusCode = 416;
        request.response.headers.set('Content-Range', 'bytes */$fileLength');
        await request.response.close();
        return;
      }

      //successful range response
      request.response.statusCode = 206;
      request.response.headers.set(
        'Content-Range',
        'bytes $start-$clampedEnd/$fileLength',
      );
      request.response.headers.set(
        'Content-Length',
        (clampedEnd - start + 1).toString(),
      );

      if (kDebugMode) {
        debugPrint(
          'Range: $start-$clampedEnd/$fileLength (${clampedEnd - start + 1} bytes)',
        );
      }

      await file.openRead(start, clampedEnd + 1).pipe(request.response);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Range request error: $e');
      }
      try {
        request.response.statusCode = 500;
        await request.response.close();
      } catch (_) {}
    }
  }

  //upgrade HTTP to WebSocket
  Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    _clients.add(socket);

    if (kDebugMode) {
      debugPrint('Client connected. Total: ${_clients.length}');
    }

    _sendCurrentState(socket);

    socket.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          final type = data['type'] as String?;

          //handle ping messages silently
          if (type == 'ping') {
            //send pong back
            try {
              socket.add(jsonEncode({'type': 'pong', 'data': {}}));
            } catch (_) {}
            return;
          }

          if (kDebugMode) {
            debugPrint('Client message: $type');
          }
        } catch (e) {
          //ignore malformed messages
        }
      },
      onDone: () {
        _clients.remove(socket);
        if (kDebugMode) {
          debugPrint('Client disconnected. Total: ${_clients.length}');
        }
      },
      onError: (error) {
        _clients.remove(socket);
        if (kDebugMode) {
          debugPrint('Client error: $error');
        }
      },
    );
  }

  //setup listeners to broadcast SonoPlayer changes
  void _setupHostListeners() {
    _hostPlayingListener = () {
      _broadcastToClients({
        'type': _sonoPlayer.isPlaying.value ? 'play' : 'pause',
        'data': {'timestamp': DateTime.now().millisecondsSinceEpoch},
      });
    };

    _hostSongListener = () {
      final song = _sonoPlayer.currentSong.value;
      if (song != null) {
        final host = _sessionInfo!.host;
        final port = _sessionInfo!.port;

        _broadcastToClients({
          'type': 'song_changed',
          'data': {
            'songId': song.id,
            'title': song.title,
            'artist': song.artist ?? 'Unknown Artist',
            'album': song.album ?? 'Unknown Album',
            'duration': song.duration ?? 0,
            'streamUrl': 'http://$host:$port/stream',
            'artworkUrl': 'http://$host:$port/artwork',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        });
      }
    };

    _hostPositionListener = () {
      final position = _sonoPlayer.position.value;
      final now = DateTime.now().millisecondsSinceEpoch;

      //send position updates every 250ms using timestamp comparison (more reliable)
      if (now - _lastPositionBroadcast >= 250) {
        _lastPositionBroadcast = now;
        _broadcastToClients({
          'type': 'position_update',
          'data': {'position': position.inMilliseconds, 'timestamp': now},
        });
      }
    };

    _hostQueueListener = () {
      _broadcastQueue();
    };

    _sonoPlayer.isPlaying.addListener(_hostPlayingListener!);
    _sonoPlayer.currentSong.addListener(_hostSongListener!);
    _sonoPlayer.position.addListener(_hostPositionListener!);
    _sonoPlayer.queueNotifier.addListener(_hostQueueListener!);
  }

  /// Immediately broadcast position (for seek events)
  void broadcastPosition(Duration position) {
    if (!_isHost) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _broadcastToClients({
      'type': 'position_update',
      'data': {'position': position.inMilliseconds, 'timestamp': now},
    });
    _lastPositionBroadcast = now;

    if (kDebugMode) {
      debugPrint('[SAS Host] Broadcasting seek position: ${position.inMilliseconds}ms');
    }
  }

  /// Start periodic cleanup of dead clients to prevent memory leaks
  void _startClientCleanup() {
    _clientCleanupTimer?.cancel();
    _clientCleanupTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (!_isHost) return;

      final deadClients = <WebSocket>[];
      for (var client in _clients) {
        //try to send a ping message
        try {
          client.add(jsonEncode({'type': 'ping', 'data': {}}));
        } catch (e) {
          deadClients.add(client);
          if (kDebugMode) {
            debugPrint('[SAS Host] Found dead client, marking for removal');
          }
        }
      }

      //remove dead clients
      for (var client in deadClients) {
        _clients.remove(client);
        try {
          client.close();
        } catch (_) {}
      }

      if (deadClients.isNotEmpty && kDebugMode) {
        debugPrint('[SAS Host] Cleaned up ${deadClients.length} dead clients');
        debugPrint('[SAS Host] Active clients: ${_clients.length}');
      }
    });
  }

  //remove host listeners
  void _removeHostListeners() {
    if (_hostPlayingListener != null) {
      _sonoPlayer.isPlaying.removeListener(_hostPlayingListener!);
      _hostPlayingListener = null;
    }
    if (_hostSongListener != null) {
      _sonoPlayer.currentSong.removeListener(_hostSongListener!);
      _hostSongListener = null;
    }
    if (_hostPositionListener != null) {
      _sonoPlayer.position.removeListener(_hostPositionListener!);
      _hostPositionListener = null;
    }
    if (_hostQueueListener != null) {
      _sonoPlayer.queueNotifier.removeListener(_hostQueueListener!);
      _hostQueueListener = null;
    }
  }

  //send current state to specific client
  void _sendCurrentState(WebSocket client) {
    final song = _sonoPlayer.currentSong.value;
    if (song == null) return;

    final host = _sessionInfo!.host;
    final port = _sessionInfo!.port;

    try {
      client.add(
        jsonEncode({
          'type': 'state_sync',
          'data': {
            'songId': song.id,
            'title': song.title,
            'artist': song.artist ?? 'Unknown Artist',
            'album': song.album ?? 'Unknown Album',
            'duration': song.duration ?? 0,
            'isPlaying': _sonoPlayer.isPlaying.value,
            'position': _sonoPlayer.position.value.inMilliseconds,
            'streamUrl': 'http://$host:$port/stream',
            'artworkUrl': 'http://$host:$port/artwork',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        }),
      );

      //to send the queue to the newly connected client
      _sendQueueToClient(client);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending state: $e');
      }
    }
  }

  //send queue to a specific client
  void _sendQueueToClient(WebSocket client) {
    final queue = _sonoPlayer.queueNotifier.value;
    final currentSong = _sonoPlayer.currentSong.value;

    int currentIndex = 0;
    if (currentSong != null) {
      currentIndex = queue.indexWhere(
        (item) => item.id == currentSong.id.toString(),
      );
      if (currentIndex == -1) currentIndex = 0;
    }

    final host = _sessionInfo!.host;
    final port = _sessionInfo!.port;

    final queueData =
        queue.map((item) {
          return {
            'songId': item.id,
            'title': item.title,
            'artist': item.artist ?? 'Unknown Artist',
            'album': item.album ?? 'Unknown Album',
            'duration': item.duration?.inMilliseconds ?? 0,
            'artworkUrl': 'http://$host:$port/artwork',
          };
        }).toList();

    try {
      client.add(
        jsonEncode({
          'type': 'queue_update',
          'data': {
            'queue': queueData,
            'currentIndex': currentIndex,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        }),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending queue to client: $e');
      }
    }
  }

  //broadcast current queue to all clients
  void _broadcastQueue() {
    if (!_isHost || _clients.isEmpty) return;

    final queue = _sonoPlayer.queueNotifier.value;
    final currentSong = _sonoPlayer.currentSong.value;

    //send current song index in queue
    int currentIndex = 0;
    if (currentSong != null) {
      currentIndex = queue.indexWhere(
        (item) => item.id == currentSong.id.toString(),
      );
      if (currentIndex == -1) currentIndex = 0;
    }

    final host = _sessionInfo!.host;
    final port = _sessionInfo!.port;

    //convert queue to simplified data structure
    final queueData =
        queue.map((item) {
          return {
            'songId': item.id,
            'title': item.title,
            'artist': item.artist ?? 'Unknown Artist',
            'album': item.album ?? 'Unknown Album',
            'duration': item.duration?.inMilliseconds ?? 0,
            'artworkUrl': 'http://$host:$port/artwork',
          };
        }).toList();

    _broadcastToClients({
      'type': 'queue_update',
      'data': {
        'queue': queueData,
        'currentIndex': currentIndex,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    });

    if (kDebugMode) {
      debugPrint(
        'Queue broadcast: ${queueData.length} songs, current: $currentIndex',
      );
    }
  }

  //broadcast message to all connected clients
  void _broadcastToClients(Map<String, dynamic> message) {
    final json = jsonEncode(message);
    final deadClients = <WebSocket>[];

    for (var client in _clients) {
      try {
        client.add(json);
      } catch (e) {
        deadClients.add(client);
      }
    }

    for (var client in deadClients) {
      _clients.remove(client);
    }
  }

  //=============== CLIENT METHODS =================

  //CLIENT uses SonoPlayer to play the stream url
  Future<void> joinSession(String host, int port) async {
    if (_isConnected) {
      await leaveSession();
    }

    if (_isHost) {
      await stopHost();
    }

    try {
      //collect device information for diagnostics
      _deviceInfo = await _collectDeviceInfo();

      final wsUri = Uri.parse('ws://$host:$port/ws');

      if (kDebugMode) {
        debugPrint(
          '[SAS Client] Joining from ${_deviceInfo?['platform']} device',
        );
        debugPrint(
          '[SAS Client] Device: ${_deviceInfo?['manufacturer']} ${_deviceInfo?['model']}',
        );
        debugPrint(
          '[SAS Client] Android SDK: ${_deviceInfo?['sdkInt']} (${_deviceInfo?['release']})',
        );
        debugPrint('[SAS Client] Connecting to: $host:$port');
      }

      _clientSocket = await WebSocket.connect(wsUri.toString());

      _clientSubscription = _clientSocket!.listen(
        (message) => _handleHostMessage(message),
        onError: (error) {
          if (kDebugMode) {
            debugPrint('[SAS Client] WebSocket error: $error');
            if (_deviceInfo != null) {
              debugPrint('[SAS Client] Device info: $_deviceInfo');
            }
          }
          leaveSession();
        },
        onDone: () {
          if (kDebugMode) {
            debugPrint('[SAS Client] Disconnected from session');
          }
          leaveSession();
        },
      );

      _isConnected = true;

      //ensure SonoPlayer is initialized for SAS mode
      //safe to call multiple times => has internal guard
      if (kDebugMode) {
        debugPrint(
          '[SAS Client] Ensuring SonoPlayer is initialized for SAS mode',
        );
      }
      _sonoPlayer.initialize();

      //set and start health monitoring
      _healthMonitor.reset();
      _startBufferHealthMonitoring();

      //start ping timer to keep connection alive
      _startClientPingTimer();

      if (kDebugMode) {
        debugPrint(
          '[SAS Client] Successfully connected to session at $host:$port',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS Client] Failed to join session: $e');
        if (_deviceInfo != null) {
          debugPrint('[SAS Client] Device info: $_deviceInfo');
        }
      }
      rethrow;
    }
  }

  /// Start periodic buffer health monitoring
  void _startBufferHealthMonitoring() {
    _bufferHealthTimer?.cancel();
    _bufferHealthTimer = Timer.periodic(Duration(seconds: 2), (_) {
      //monitor player processing state for rebuffer events
      final processingState = _sonoPlayer.player.processingState;

      if (processingState == ProcessingState.buffering) {
        _healthMonitor.recordRebuffer();
        _healthMonitor.recordBufferHealth(0.0);
      } else if (processingState == ProcessingState.ready) {
        _healthMonitor.recordBufferHealth(1.0);
      }
    });
  }

  /// Start periodic ping to keep client connection alive
  void _startClientPingTimer() {
    _clientPingTimer?.cancel();
    _clientPingTimer = Timer.periodic(Duration(seconds: 15), (_) {
      if (_clientSocket != null) {
        try {
          _clientSocket!.add(jsonEncode({'type': 'ping', 'data': {}}));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[SAS Client] Ping failed: $e');
          }
        }
      }
    });
  }

  //leave the current session
  Future<void> leaveSession() async {
    if (!_isConnected) return;

    try {
      if (kDebugMode) {
        debugPrint('[SAS Client] Leaving session - starting cleanup');
      }

      //exit SAS mode completely (stops AudioPlayer, clears metadata, resets state)
      await _sonoPlayer.exitSASMode();

      //close WebSocket connection
      await _clientSocket?.close();
      await _clientSubscription?.cancel();
      _clientSocket = null;
      _clientSubscription = null;

      //cancel completion listener
      await _streamCompletionSubscription?.cancel();
      _streamCompletionSubscription = null;

      //stop health monitoring
      _bufferHealthTimer?.cancel();
      _bufferHealthTimer = null;
      _healthMonitor.reset();

      //stop ping timer
      _clientPingTimer?.cancel();
      _clientPingTimer = null;

      //clear client metadata (keep for reference/debugging if needed)
      clientSongTitle.value = null;
      clientSongArtist.value = null;
      clientSongAlbum.value = null;
      clientSongDuration.value = null;
      clientArtworkUrl.value = null;
      clientQueue.value = [];
      clientCurrentIndex.value = 0;

      //clear message queue
      _messageQueue.clear();
      _isTransitioning = false;

      _isConnected = false;

      if (kDebugMode) {
        debugPrint('[SAS Client] Session cleanup complete');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS Client] Error during session cleanup: $e');
      }
    }
  }

  //handle messages from host
  Future<void> _handleHostMessage(dynamic message) async {
    try {
      final data = jsonDecode(message);
      final type = data['type'] as String;
      final payload = data['data'] as Map<String, dynamic>;

      //queue all messages except position updates
      if (_isTransitioning) {
        if (type != 'position_update') {
          if (_messageQueue.length < _maxQueueSize) {
            _messageQueue.add({'type': type, 'data': payload});
            if (kDebugMode) {
              debugPrint('Queued $type (queue size: ${_messageQueue.length})');
            }
          } else {
            if (kDebugMode) {
              debugPrint('Queue full, dropping $type message');
            }
          }
        }
        return;
      }

      //process message immediately
      await _processMessage(type, payload);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error handling message: $e');
      }
    }
  }

  /// Process a single message by type
  Future<void> _processMessage(
    String type,
    Map<String, dynamic> payload,
  ) async {
    switch (type) {
      case 'ping':
        //host sent ping => ignore (already send own pings)
        break;
      case 'pong':
        //host acknowledged ping => connection is alive
        break;
      case 'state_sync':
        await _handleStateSync(payload);
        break;
      case 'song_changed':
        await _handleSongChanged(payload);
        break;
      case 'play':
        await _handlePlayCommand();
        break;
      case 'pause':
        await _handlePauseCommand();
        break;
      case 'position_update':
        await _handlePositionUpdate(payload);
        break;
      case 'queue_update':
        await _handleQueueUpdate(payload);
        break;
      case 'session_ended':
        await leaveSession();
        break;
    }
  }

  /// Process all queued messages after transition completes
  Future<void> _processQueuedMessages() async {
    if (_messageQueue.isEmpty) return;

    if (kDebugMode) {
      debugPrint('Processing ${_messageQueue.length} queued messages');
    }

    final messages = List<Map<String, dynamic>>.from(_messageQueue);
    _messageQueue.clear();

    for (final msg in messages) {
      try {
        await _processMessage(
          msg['type'] as String,
          msg['data'] as Map<String, dynamic>,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error processing queued message: $e');
        }
      }
    }
  }

  /// Loads a network stream with exponential backoff retry logic
  Future<bool> _loadStreamWithRetry(
    String streamUrl, {
    Duration? initialPosition,
    bool autoPlay = false,
    int maxAttempts = 5,
  }) async {
    isRetrying.value = true;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final timeout = Duration(seconds: attempt == 0 ? 10 : 15);

        await _sonoPlayer
            .loadNetworkStream(
              streamUrl,
              initialPosition: initialPosition,
              autoPlay: false,
            )
            .timeout(timeout);

        connectionError.value = null;
        isRetrying.value = false;

        if (autoPlay) {
          await _sonoPlayer.play();
        }

        return true;
      } catch (e) {
        connectionError.value = 'Connection error: ${e.toString()}';

        if (kDebugMode) {
          debugPrint('Load attempt ${attempt + 1}/$maxAttempts failed: $e');
        }

        if (attempt < maxAttempts - 1) {
          //500ms, 1s, 2s, 4s, 8s
          final delay = Duration(milliseconds: 500 * (1 << attempt));
          if (kDebugMode) {
            debugPrint('Retrying in ${delay.inMilliseconds}ms...');
          }
          await Future.delayed(delay);
        }
      }
    }

    isRetrying.value = false;
    connectionError.value = 'Failed to load stream after $maxAttempts attempts';
    return false;
  }

  /// Handle initial state sync from host
  Future<void> _handleStateSync(Map<String, dynamic> data) async {
    _isTransitioning = true;

    try {
      final streamUrl = data['streamUrl'] as String;
      final isPlaying = data['isPlaying'] as bool;
      final position = data['position'] as int;
      final title = data['title'] as String?;
      final artist = data['artist'] as String?;
      final album = data['album'] as String?;
      final duration = data['duration'] as int?;
      final artworkUrl = data['artworkUrl'] as String?;
      final timestamp = data['timestamp'] as int;

      if (kDebugMode) {
        debugPrint('[SAS Client] State sync - URL: $streamUrl');
        debugPrint('[SAS Client] Song: $title by $artist');
        debugPrint(
          '[SAS Client] Position: ${Duration(milliseconds: position)}, Playing: $isPlaying',
        );
      }

      //update SonoPlayer with SAS metadata FIRST so UI shows correct info immediately
      _sonoPlayer.setSASMetadata(
        title: title ?? 'Unknown',
        artist: artist ?? 'Unknown Artist',
        album: album ?? 'Unknown Album',
        durationMs: duration ?? 0,
        artworkUrl: artworkUrl,
        songId: data['songId'] as int?,
      );

      //update local SASManager state for queue management
      clientSongTitle.value = title;
      clientSongArtist.value = artist;
      clientSongAlbum.value = album;
      clientSongDuration.value = duration;
      clientArtworkUrl.value = artworkUrl;

      //timestamp to URL to prevent caching
      final freshUrl = '$streamUrl?t=$timestamp';

      //stream url into SonoPlayer with retry logic
      //streamDelayMs is handled separately for song changes, not initial sync
      final success = await _loadStreamWithRetry(
        freshUrl,
        initialPosition: Duration(milliseconds: position),
        autoPlay: false,
      );

      if (!success) {
        throw Exception('Failed to load stream after retries');
      }

      //setup completion listener for auto-advance detection
      _setupStreamCompletionListener();

      if (kDebugMode) {
        debugPrint('[SAS Client] Stream loaded into sono_player');
      }

      if (isPlaying) {
        //wait for player to be ready before starting playback
        await Future.delayed(Duration(milliseconds: 300));

        //ensure player is in ready state before playing
        final processingState = _sonoPlayer.player.processingState;
        if (processingState == ProcessingState.ready ||
            processingState == ProcessingState.buffering) {
          await _sonoPlayer.play();
          if (kDebugMode) {
            debugPrint('[SAS Client] Started playback');
          }
        } else {
          if (kDebugMode) {
            debugPrint('[SAS Client] Player not ready, waiting for ready state');
          }
          //wait for player to become ready
          try {
            await _sonoPlayer.player.processingStateStream
                .firstWhere((state) =>
                    state == ProcessingState.ready ||
                    state == ProcessingState.buffering)
                .timeout(Duration(seconds: 8));
            await _sonoPlayer.play();
            if (kDebugMode) {
              debugPrint('[SAS Client] Started playback after ready');
            }
          } catch (timeoutError) {
            if (kDebugMode) {
              debugPrint('[SAS Client] Timeout waiting for ready state: $timeoutError');
            }
            //try to play anyway
            try {
              await _sonoPlayer.play();
            } catch (_) {}
          }
        }
      }

      if (kDebugMode) {
        debugPrint('[SAS Client] State synced successfully: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS Client] State sync error: $e');
      }
      connectionError.value = 'State sync failed: ${e.toString()}';
    } finally {
      _isTransitioning = false;
      await _processQueuedMessages();
    }
  }

  //handle song change from host
  Future<void> _handleSongChanged(Map<String, dynamic> data) async {
    _isTransitioning = true;

    try {
      final streamUrl = data['streamUrl'] as String;
      final title = data['title'] as String?;
      final artist = data['artist'] as String?;
      final album = data['album'] as String?;
      final duration = data['duration'] as int?;
      final artworkUrl = data['artworkUrl'] as String?;
      final timestamp = data['timestamp'] as int;

      if (kDebugMode) {
        debugPrint('[SAS Client] Song changing to: $title by $artist');
      }

      //update SonoPlayer with SAS metadata FIRST so UI shows correct info immediately
      _sonoPlayer.setSASMetadata(
        title: title ?? 'Unknown',
        artist: artist ?? 'Unknown Artist',
        album: album ?? 'Unknown Album',
        durationMs: duration ?? 0,
        artworkUrl: artworkUrl,
        songId: data['songId'] as int?,
      );

      //update local SASManager state for queue management
      clientSongTitle.value = title;
      clientSongArtist.value = artist;
      clientSongAlbum.value = album;
      clientSongDuration.value = duration;
      clientArtworkUrl.value = artworkUrl;

      //stop current playback completely to release the stream
      await _sonoPlayer.player.stop();

      //apply configured stream delay (if set) to allow host buffering
      //only delay if explicitly configured by user (default should be 0)
      if (_streamDelayMs > 0) {
        if (kDebugMode) {
          debugPrint(
            '[SAS Client] Applying ${_streamDelayMs}ms sync delay for new song',
          );
        }
        await Future.delayed(Duration(milliseconds: _streamDelayMs));
      }

      //add timestamp to URL to force fresh connection and prevent caching
      final freshUrl = '$streamUrl?t=$timestamp';

      //add new song with retry logic
      final success = await _loadStreamWithRetry(
        freshUrl,
        initialPosition: Duration.zero,
        autoPlay: true,
      );

      if (!success) {
        throw Exception('Failed to load stream after retries');
      }

      //setup completion listener for auto-advance detection
      _setupStreamCompletionListener();

      if (kDebugMode) {
        debugPrint('[SAS Client] Now playing: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS Client] Song change error: $e');
      }
      connectionError.value = 'Song change failed: ${e.toString()}';
    } finally {
      _isTransitioning = false;
      await _processQueuedMessages();
    }
  }

  /// Starts up listener to detect when the client's network stream completes
  /// and prepares client to receive the next song from host
  void _setupStreamCompletionListener() {
    //cancel any existing listener
    _streamCompletionSubscription?.cancel();

    //listen for stream completion events
    _streamCompletionSubscription = _sonoPlayer.player.processingStateStream.listen((
      state,
    ) {
      //only handle completion when in client mode
      if (state == ProcessingState.completed && _isConnected && !_isHost) {
        if (kDebugMode) {
          debugPrint(
            '[SAS Client] Stream completed, waiting for host to send next song',
          );
        }

        //check if there's a next song expected in queue
        final currentIdx = clientCurrentIndex.value;
        final queueLength = clientQueue.value.length;

        if (currentIdx < queueLength - 1) {
          if (kDebugMode) {
            debugPrint(
              '[SAS Client] Expecting next song (${currentIdx + 1}/$queueLength)',
            );
          }
        } else {
          //end of queue reached
          if (kDebugMode) {
            debugPrint('[SAS Client] End of queue reached');
          }
          _sonoPlayer.pause();
        }
      }
    });
  }

  //handle play command from host
  Future<void> _handlePlayCommand() async {
    try {
      if (!_sonoPlayer.isPlaying.value) {
        await _sonoPlayer.play();
        if (kDebugMode) {
          debugPrint('Play command executed');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Play command error: $e');
      }
    }
  }

  //handle pause command from host
  Future<void> _handlePauseCommand() async {
    try {
      if (_sonoPlayer.isPlaying.value) {
        _sonoPlayer.pause();
        if (kDebugMode) {
          debugPrint('Pause command executed');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Pause command error: $e');
      }
    }
  }

  //handle position updates from host for drift correction
  Future<void> _handlePositionUpdate(Map<String, dynamic> data) async {
    if (!_sonoPlayer.isPlaying.value) return;

    try {
      final hostPosition = Duration(milliseconds: data['position'] as int);
      final timestamp = data['timestamp'] as int;
      final networkDelay = DateTime.now().millisecondsSinceEpoch - timestamp;

      //record latency for health monitoring
      _healthMonitor.recordLatency(networkDelay);

      //compensate for network delay and codec processing
      final compensatedPosition =
          hostPosition +
          Duration(milliseconds: networkDelay) +
          _codecDelayEstimate;

      final clientPosition = _sonoPlayer.position.value;
      final drift = (compensatedPosition - clientPosition).abs();

      if (drift >= _majorDriftThreshold) {
        //major drift: immediate seek (bypass client check for automatic drift correction)
        if (kDebugMode) {
          debugPrint(
            'Major drift detected: ${drift.inMilliseconds}ms - seeking',
          );
        }
        await _sonoPlayer.player.seek(compensatedPosition);
        _sonoPlayer.position.value = compensatedPosition;
      } else if (drift >= _driftThreshold) {
        //minor drift: gradual speed adjustment
        final driftMs = (compensatedPosition - clientPosition).inMilliseconds;
        final speedAdjustment = 1.0 + (driftMs / 10000.0); //btle adjustment
        final targetSpeed = speedAdjustment.clamp(0.95, 1.05);

        if (kDebugMode) {
          debugPrint(
            'Minor drift: ${drift.inMilliseconds}ms - adjusting speed to ${targetSpeed.toStringAsFixed(3)}',
          );
        }

        await _sonoPlayer.setSpeed(targetSpeed);

        //store normal speed after 2 seconds
        Future.delayed(Duration(seconds: 2), () {
          if (_sonoPlayer.isPlaying.value) {
            _sonoPlayer.setSpeed(1.0);
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Position update error: $e');
      }
    }
  }

  //handle queue update from host
  Future<void> _handleQueueUpdate(Map<String, dynamic> data) async {
    try {
      final queueData = data['queue'] as List;
      final currentIndex = data['currentIndex'] as int;

      //update client queue state
      clientQueue.value = queueData.cast<Map<String, dynamic>>();
      clientCurrentIndex.value = currentIndex;

      if (kDebugMode) {
        debugPrint(
          'Queue updated: ${queueData.length} songs, current index: $currentIndex',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Queue update error: $e');
      }
    }
  }

  //=============== UTILITY METHODS =================

  Future<String> _getLocalIP() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();

      if (wifiIP == null) {
        if (kDebugMode) {
          debugPrint('[SAS] Unable to determine WiFi IP address');
          if (_deviceInfo != null) {
            debugPrint(
              '[SAS] Device: ${_deviceInfo?['manufacturer']} ${_deviceInfo?['model']}',
            );
            debugPrint(
              '[SAS] Platform: ${_deviceInfo?['platform']} ${_deviceInfo?['release']}',
            );
          }
        }
        return '127.0.0.1';
      }

      return wifiIP;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS] Failed to get IP: $e');
        if (_deviceInfo != null) {
          debugPrint('[SAS] Device info: $_deviceInfo');
        }
      }
      return '127.0.0.1';
    }
  }

  String _generateSessionId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Collect device information for diagnostic purposes
  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final Map<String, dynamic> info = {};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        info['platform'] = 'Android';
        info['manufacturer'] = androidInfo.manufacturer;
        info['model'] = androidInfo.model;
        info['device'] = androidInfo.device;
        info['brand'] = androidInfo.brand;
        info['sdkInt'] = androidInfo.version.sdkInt;
        info['release'] = androidInfo.version.release;
        info['isPhysicalDevice'] = androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        info['platform'] = 'iOS';
        info['name'] = iosInfo.name;
        info['model'] = iosInfo.model;
        info['systemName'] = iosInfo.systemName;
        info['systemVersion'] = iosInfo.systemVersion;
        info['isPhysicalDevice'] = iosInfo.isPhysicalDevice;
      } else {
        info['platform'] = Platform.operatingSystem;
        info['version'] = Platform.operatingSystemVersion;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS] Failed to collect device info: $e');
      }
      info['error'] = e.toString();
    }

    return info;
  }

  Future<void> dispose() async {
    await stopHost();
    await leaveSession();
  }
}