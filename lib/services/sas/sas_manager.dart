import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:mime/mime.dart';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Data class for session info
class SASInfo {
  final String host;
  final int port;
  final String sessionId;

  SASInfo({required this.host, required this.port, required this.sessionId});

  String get deepLink => 'sono://sas?host=$host&port=$port&session=$sessionId';
  String get webUrl => 'http://$host:$port';
}

/// Host: SonoPlayer plays local files
/// Client: SonoPlayer loads and plays stream URL from host
class SASManager {
  static final SASManager _instance = SASManager._internal();
  factory SASManager() => _instance;
  SASManager._internal();

  /// Host Server State
  HttpServer? _server;
  int? _port;
  String? _sessionId;
  final List<WebSocket> _clients = [];
  Timer? _clientCleanupTimer; //periodic cleanup of dead clients

  /// Client Connection State
  StreamSubscription? _clientSubscription;
  WebSocket? _clientSocket;
  StreamSubscription<ProcessingState>? _streamCompletionSubscription;
  Timer? _clientPingTimer; //keep client connection alive

  /// Mode Flags
  bool _isHost = false;
  bool _isConnected = false;
  SASInfo? _sessionInfo;

  /// Device Info
  Map<String, dynamic>? _deviceInfo;

  /// Player Reference
  final SonoPlayer _sonoPlayer = SonoPlayer();

  /// Host Listener References
  VoidCallback? _hostPlayingListener;
  VoidCallback? _hostSongListener;
  VoidCallback? _hostQueueListener;

  /// Clock Sync State (client only)
  int _clockOffset = 0; //ms: localTime + _clockOffset ~= hostTime
  Completer<void>? _clockSyncComplete;
  Completer<Map<String, dynamic>>? _pendingClockPong;

  /// Scheduled Playback
  /// Shared: Host uses for seek, client for all commands
  Timer? _scheduledTimer;

  /// Song-change race guard (client only)
  /// True while loadNetworkStream is in progress for a new song
  /// Play/seek commands that arrive during this window are absorbed,
  /// the song_changed handlers scheduled play handles timing instead
  bool _songChangeInProgress = false;

  /// Tracks the most recent play/pause intent from the host so the
  /// song_changed scheduled play can respect a pause that arrived during loading.
  bool _hostWantsPlaying = false;

  /// Public Getters
  bool get isHost => _isHost;
  bool get isConnected => _isConnected;
  SASInfo? get sessionInfo => _sessionInfo;
  int get connectedClientsCount => _clients.length;

  //==========================================================================
  // PLAYBACK PERMISSION HELPERS
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

  /// Error Tracking and Retry State
  final ValueNotifier<String?> connectionError = ValueNotifier(null);
  final ValueNotifier<bool> isRetrying = ValueNotifier(false);

  /// Client-side queue state
  final ValueNotifier<List<Map<String, dynamic>>> clientQueue = ValueNotifier(
    [],
  );
  final ValueNotifier<int> clientCurrentIndex = ValueNotifier(0);

  /// Client-side current song metadata
  final ValueNotifier<String?> clientSongTitle = ValueNotifier(null);
  final ValueNotifier<String?> clientSongArtist = ValueNotifier(null);
  final ValueNotifier<String?> clientSongAlbum = ValueNotifier(null);
  final ValueNotifier<String?> clientArtworkUrl = ValueNotifier(null);
  final ValueNotifier<int?> clientSongDuration = ValueNotifier(null);

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

      //setup listeners to broadcast SonoPlayer changes to clients
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
      _broadcastToClients({'type': 'session_ended'});

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

      //cancel any pending scheduled action
      _scheduledTimer?.cancel();
      _scheduledTimer = null;

      _isHost = false;
      _port = null;
      _sessionId = null;
      _sessionInfo = null;

      if (kDebugMode) {
        debugPrint('SAS Session stopped');
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

    //send current state immediately => client will hold it until clock sync completes
    _sendCurrentState(socket);

    socket.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          final type = data['type'] as String?;

          //handle ping keepalive
          if (type == 'ping') {
            try {
              socket.add(jsonEncode({'type': 'pong'}));
            } catch (_) {}
            return;
          }

          //handle clock sync ping: echo t1 back => add hosts t2
          if (type == 'clock_ping') {
            final t1 = data['t1'] as int;
            final t2 = DateTime.now().millisecondsSinceEpoch;
            try {
              socket.add(
                jsonEncode({'type': 'clock_pong', 't1': t1, 't2': t2}),
              );
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

  /// Setup listeners to broadcast SonoPlayer changes to clients
  /// host does NOT delay its own action => ValueNotifiers fire after the action
  /// already happened. execute_at is purely for the client to schedule
  void _setupHostListeners() {
    _hostPlayingListener = () {
      final isPlaying = _sonoPlayer.isPlaying.value;

      _broadcastToClients({
        'type': isPlaying ? 'play' : 'pause',
        //client uses recorded_at + clockOffset to compute the hosts position
        //at the moment it executes => eliminating any fixed scheduling delay
        'recorded_at': DateTime.now().millisecondsSinceEpoch,
        if (isPlaying) 'position_ms': _sonoPlayer.position.value.inMilliseconds,
      });
    };

    _hostSongListener = () {
      final song = _sonoPlayer.currentSong.value;
      if (song == null) return;

      final host = _sessionInfo!.host;
      final port = _sessionInfo!.port;
      final broadcastAt = DateTime.now().millisecondsSinceEpoch;
      final executeAt = broadcastAt;

      _broadcastToClients({
        'type': 'song_changed',
        'song_url': 'http://$host:$port/stream',
        'artwork_url': 'http://$host:$port/artwork?t=$broadcastAt',
        'title': song.title,
        'artist': song.artist ?? 'Unknown Artist',
        'album': song.album ?? 'Unknown Album',
        'duration_ms': song.duration ?? 0,
        'song_id': song.id,
        'execute_at': executeAt,
        //client uses this to dynamically seek to the hosts actual position
        //at execute time, rather than assuming a fixed offset
        'broadcast_at': broadcastAt,
      });
    };

    _hostQueueListener = () {
      _broadcastQueue();
    };

    _sonoPlayer.isPlaying.addListener(_hostPlayingListener!);
    _sonoPlayer.currentSong.addListener(_hostSongListener!);
    _sonoPlayer.queueNotifier.addListener(_hostQueueListener!);
  }

  /// Called by SonoPlayer after user seeks
  /// The host has already seeked by this point. Broadcasts a seek command
  /// with execute_at so the client schedules its seek to match
  void broadcastPosition(Duration position) {
    if (!_isHost) return;

    _broadcastToClients({
      'type': 'seek',
      'position_ms': position.inMilliseconds,
      'recorded_at': DateTime.now().millisecondsSinceEpoch,
    });

    if (kDebugMode) {
      debugPrint('[SAS Host] Broadcast seek: ${position.inMilliseconds}ms');
    }
  }

  /// Start periodic cleanup of dead clients
  void _startClientCleanup() {
    _clientCleanupTimer?.cancel();
    _clientCleanupTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (!_isHost) return;

      final deadClients = <WebSocket>[];
      for (var client in _clients) {
        //try to send a ping message
        try {
          client.add(jsonEncode({'type': 'ping'}));
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
    if (_hostQueueListener != null) {
      _sonoPlayer.queueNotifier.removeListener(_hostQueueListener!);
      _hostQueueListener = null;
    }
  }

  /// Send current state to a newly connected client
  /// no execute_at => client calculates expected position from recorded_at + elapsed
  void _sendCurrentState(WebSocket client) {
    final song = _sonoPlayer.currentSong.value;
    if (song == null) return;

    final host = _sessionInfo!.host;
    final port = _sessionInfo!.port;
    final recordedAt = DateTime.now().millisecondsSinceEpoch;

    try {
      client.add(
        jsonEncode({
          'type': 'state_sync',
          'song_url': 'http://$host:$port/stream',
          'artwork_url': 'http://$host:$port/artwork?t=$recordedAt',
          'title': song.title,
          'artist': song.artist ?? 'Unknown Artist',
          'album': song.album ?? 'Unknown Album',
          'duration_ms': song.duration ?? 0,
          'song_id': song.id,
          'position_ms': _sonoPlayer.position.value.inMilliseconds,
          'is_playing': _sonoPlayer.isPlaying.value,
          'recorded_at': recordedAt,
        }),
      );

      //send the queue to the newly connected client
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
        (item) => item.extras?['songId'] == currentSong.id,
      );
      if (currentIndex == -1) currentIndex = 0;
    }

    final host = _sessionInfo!.host;
    final port = _sessionInfo!.port;

    final queueData =
        queue.map((item) {
          return {
            'songId': item.extras?['songId'],
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
          'queue': queueData,
          'current_index': currentIndex,
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

    int currentIndex = 0;
    if (currentSong != null) {
      currentIndex = queue.indexWhere(
        (item) => item.extras?['songId'] == currentSong.id,
      );
      if (currentIndex == -1) currentIndex = 0;
    }

    final host = _sessionInfo!.host;
    final port = _sessionInfo!.port;

    final queueData =
        queue.map((item) {
          return {
            'songId': item.extras?['songId'],
            'title': item.title,
            'artist': item.artist ?? 'Unknown Artist',
            'album': item.album ?? 'Unknown Album',
            'duration': item.duration?.inMilliseconds ?? 0,
            'artworkUrl': 'http://$host:$port/artwork',
          };
        }).toList();

    _broadcastToClients({
      'type': 'queue_update',
      'queue': queueData,
      'current_index': currentIndex,
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

  /// Join a SAS session hosted by another device
  /// Performs clock sync before processing any messages
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
        debugPrint('[SAS Client] Connecting to: $host:$port');
      }

      _clientSocket = await WebSocket.connect(wsUri.toString());

      /// Create clock sync completer BEFORE attaching listener
      /// => host sends state_sync immediately on connect and must not
      /// process it until clock sync is done
      _clockSyncComplete = Completer<void>();
      _clockOffset = 0;

      _clientSubscription = _clientSocket!.listen(
        (message) => _handleHostMessage(message),
        onError: (error) {
          if (kDebugMode) {
            debugPrint('[SAS Client] WebSocket error: $error');
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
      _sonoPlayer.initialize();

      //start ping timer to keep connection alive
      _startClientPingTimer();

      /// Run clock sync protocol (5 rounds). state_sync and other messages
      /// received in the meantime are held by _handleHostMessage until this completes
      await _performClockSync();

      if (kDebugMode) {
        debugPrint(
          '[SAS Client] Clock sync complete, offset: ${_clockOffset}ms',
        );
        debugPrint(
          '[SAS Client] Successfully connected to session at $host:$port',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS Client] Failed to join session: $e');
      }
      rethrow;
    }
  }

  /// Performs 5-round NTP-style clock sync with the host
  /// Each round: send clock_ping with t1, receive clock_pong with t1+t2,
  /// capture t3 on receipt. offset = t2 - (t1 + RTT/2)
  /// Take median of 5
  Future<void> _performClockSync() async {
    final List<int> offsets = [];
    const int rounds = 5;
    const Duration roundTimeout = Duration(seconds: 2);

    for (int i = 0; i < rounds; i++) {
      final t1 = DateTime.now().millisecondsSinceEpoch;

      final pongCompleter = Completer<Map<String, dynamic>>();
      _pendingClockPong = pongCompleter;

      try {
        _clientSocket!.add(jsonEncode({'type': 'clock_ping', 't1': t1}));

        final pong = await pongCompleter.future.timeout(roundTimeout);

        final t3 = DateTime.now().millisecondsSinceEpoch;
        final t2 = pong['t2'] as int;
        final rtt = t3 - t1;
        final offset = t2 - (t1 + rtt ~/ 2);
        offsets.add(offset);

        if (kDebugMode) {
          debugPrint(
            '[SAS Clock] Round ${i + 1}: t1=$t1, t2=$t2, t3=$t3, RTT=${rtt}ms, offset=${offset}ms',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SAS Clock] Round ${i + 1} failed: $e');
        }
      } finally {
        _pendingClockPong = null;
      }

    }

    //compute median offset
    if (offsets.isNotEmpty) {
      offsets.sort();
      _clockOffset = offsets[offsets.length ~/ 2];
    } else {
      _clockOffset = 0;
      if (kDebugMode) {
        debugPrint('[SAS Clock] WARNING: No successful clock sync rounds');
      }
    }

    //unblock any messages waiting on clock sync
    if (_clockSyncComplete != null && !_clockSyncComplete!.isCompleted) {
      _clockSyncComplete!.complete();
    }
  }

  /// Start periodic ping to keep client connection alive
  void _startClientPingTimer() {
    _clientPingTimer?.cancel();
    _clientPingTimer = Timer.periodic(Duration(seconds: 15), (_) {
      if (_clientSocket != null) {
        try {
          _clientSocket!.add(jsonEncode({'type': 'ping'}));
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

      //stop ping timer
      _clientPingTimer?.cancel();
      _clientPingTimer = null;

      //cancel any pending scheduled action
      _scheduledTimer?.cancel();
      _scheduledTimer = null;

      //reset clock sync state
      _clockOffset = 0;
      _clockSyncComplete = null;
      _pendingClockPong = null;

      //clear client metadata
      clientSongTitle.value = null;
      clientSongArtist.value = null;
      clientSongAlbum.value = null;
      clientSongDuration.value = null;
      clientArtworkUrl.value = null;
      clientQueue.value = [];
      clientCurrentIndex.value = 0;

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

      /// clock_pong must be handled immediately => its part of the sync
      /// protocol that runs before we unblock other messages
      if (type == 'clock_pong') {
        if (_pendingClockPong != null && !_pendingClockPong!.isCompleted) {
          _pendingClockPong!.complete(data);
        }
        return;
      }

      //ping/pong keepalive => ignore
      if (type == 'ping' || type == 'pong') return;

      /// All other message types require clock sync to be complete
      /// state_sync arrives before clock sync finishes (host sends it immediately
      /// on connect) => await holds it here until the offset is known
      if (_clockSyncComplete != null && !_clockSyncComplete!.isCompleted) {
        await _clockSyncComplete!.future;
      }

      switch (type) {
        case 'state_sync':
          await _handleStateSync(data);
          break;
        case 'song_changed':
          await _handleSongChanged(data);
          break;
        case 'play':
          _handlePlayCommand(data);
          break;
        case 'pause':
          _handlePauseCommand(data);
          break;
        case 'seek':
          _handleSeekCommand(data);
          break;
        case 'queue_update':
          _handleQueueUpdate(data);
          break;
        case 'session_ended':
          await leaveSession();
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error handling message: $e');
      }
    }
  }

  /// Schedules action to execute at hostTimeMs (absolute host clock)
  /// Converts to local time using _clockOffset => cancels any previously
  /// pending scheduled action so that rapid-fire commands only execute the last one
  void _executeAt(int hostTimeMs, Future<void> Function() action) {
    _scheduledTimer?.cancel();
    _scheduledTimer = null;

    final localNow = DateTime.now().millisecondsSinceEpoch;
    final localExecuteAt = hostTimeMs - _clockOffset;
    final delayMs = localExecuteAt - localNow;

    if (kDebugMode) {
      debugPrint(
        '[SAS Schedule] hostTime=$hostTimeMs, localExecuteAt=$localExecuteAt, delayMs=$delayMs',
      );
    }

    if (delayMs <= 0) {
      //target time already passed => execute immediately
      action();
    } else {
      _scheduledTimer = Timer(Duration(milliseconds: delayMs), () {
        action();
        _scheduledTimer = null;
      });
    }
  }

  /// Handle initial state sync from host
  /// Calculates expected position using recorded_at + clock offset => no execute_at needed
  Future<void> _handleStateSync(Map<String, dynamic> data) async {
    try {
      final streamUrl = data['song_url'] as String;
      final isPlaying = data['is_playing'] as bool;
      final positionMs = data['position_ms'] as int;
      final recordedAt = data['recorded_at'] as int;
      final title = data['title'] as String?;
      final artist = data['artist'] as String?;
      final album = data['album'] as String?;
      final durationMs = data['duration_ms'] as int?;
      final artworkUrl = data['artwork_url'] as String?;
      final songId = data['song_id'] as int?;

      if (kDebugMode) {
        debugPrint('[SAS Client] State sync - Song: $title by $artist');
      }

      //update metadata immediately so UI shows correct info
      _sonoPlayer.setSASMetadata(
        title: title ?? 'Unknown',
        artist: artist ?? 'Unknown Artist',
        album: album ?? 'Unknown Album',
        durationMs: durationMs ?? 0,
        artworkUrl: artworkUrl,
        songId: songId,
      );

      clientSongTitle.value = title;
      clientSongArtist.value = artist;
      clientSongAlbum.value = album;
      clientSongDuration.value = durationMs;
      clientArtworkUrl.value = artworkUrl;

      /// Calculate expected position NOW
      /// hostNow = localNow + clockOffset (convert local time to host time)
      final hostNow = DateTime.now().millisecondsSinceEpoch + _clockOffset;
      final elapsedMs = hostNow - recordedAt;
      final expectedPositionMs =
          isPlaying
              ? (positionMs + elapsedMs).clamp(0, durationMs ?? 999999999)
              : positionMs;

      if (kDebugMode) {
        debugPrint(
          '[SAS Client] Calculated position: ${expectedPositionMs}ms '
          '(recorded=${positionMs}ms, elapsed=${elapsedMs}ms)',
        );
      }

      //load stream with cache-busting timestamp
      final freshUrl = '$streamUrl?t=$recordedAt';

      try {
        await _sonoPlayer.loadNetworkStream(
          freshUrl,
          initialPosition: Duration(milliseconds: expectedPositionMs),
          autoPlay: false,
        );
        connectionError.value = null;
      } catch (e) {
        connectionError.value = 'Failed to load stream: ${e.toString()}';
        if (kDebugMode) {
          debugPrint('[SAS Client] Stream load failed: $e');
        }
        return;
      }

      //setup completion listener for auto-advance detection
      _setupStreamCompletionListener();

      //start playback if host was playing
      if (isPlaying) {
        await _waitForPlayerReady();
        await _sonoPlayer.playStream();
        if (kDebugMode) {
          debugPrint(
            '[SAS Client] Playback started at ${expectedPositionMs}ms',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS Client] State sync error: $e');
      }
      connectionError.value = 'State sync failed: ${e.toString()}';
    }
  }

  //handle song change from host (scheduled)
  Future<void> _handleSongChanged(Map<String, dynamic> data) async {
    try {
      final streamUrl = data['song_url'] as String;
      final executeAt = data['execute_at'] as int;
      final title = data['title'] as String?;
      final artist = data['artist'] as String?;
      final album = data['album'] as String?;
      final durationMs = data['duration_ms'] as int?;
      final artworkUrl = data['artwork_url'] as String?;
      final songId = data['song_id'] as int?;

      if (kDebugMode) {
        debugPrint(
          '[SAS Client] Song change incoming: $title by $artist, executeAt=$executeAt',
        );
      }

      //update metadata immediately so UI shows new song info
      _sonoPlayer.setSASMetadata(
        title: title ?? 'Unknown',
        artist: artist ?? 'Unknown Artist',
        album: album ?? 'Unknown Album',
        durationMs: durationMs ?? 0,
        artworkUrl: artworkUrl,
        songId: songId,
      );

      clientSongTitle.value = title;
      clientSongArtist.value = artist;
      clientSongAlbum.value = album;
      clientSongDuration.value = durationMs;
      clientArtworkUrl.value = artworkUrl;

      await _sonoPlayer.player.stop();

      final freshUrl = '$streamUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      final broadcastAt = data['broadcast_at'] as int? ?? executeAt;

      //compute approximate position NOW so the load issues a range request
      //at the right offset => avoids a post-load seek and its rebuffer penalty
      final hostNowAtLoad = DateTime.now().millisecondsSinceEpoch + _clockOffset;
      final approxPosition = (hostNowAtLoad - broadcastAt).clamp(
        0,
        durationMs ?? 999999999,
      );

      //guard: play/seek commands arriving while load, will be absorbed
      _songChangeInProgress = true;
      _hostWantsPlaying = true; //song_changed implies the host is playing
      try {
        await _sonoPlayer.loadNetworkStream(
          freshUrl,
          initialPosition: Duration(milliseconds: approxPosition),
          autoPlay: false,
        );
        connectionError.value = null;
      } catch (e) {
        connectionError.value = 'Song change load failed: ${e.toString()}';
        if (kDebugMode) {
          debugPrint('[SAS Client] Song change stream load failed: $e');
        }
        return;
      } finally {
        _songChangeInProgress = false;
      }

      _setupStreamCompletionListener();

      //schedule play at executeAt, seeking to where the host actually is.
      //respect _hostWantsPlaying: a pause that arrived during loading should
      //prevent us from auto-playing here.
      _executeAt(executeAt, () async {
        if (!_hostWantsPlaying) return;

        final hostNow = DateTime.now().millisecondsSinceEpoch + _clockOffset;
        final elapsedMs = (hostNow - broadcastAt).clamp(
          0,
          durationMs ?? 999999999,
        );

        await _sonoPlayer.seekStream(Duration(milliseconds: elapsedMs));
        await _waitForPlayerReady();
        await _sonoPlayer.playStream();
        if (kDebugMode) {
          debugPrint(
            '[SAS Client] Song change: playback started at ${elapsedMs}ms',
          );
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS Client] Song change error: $e');
      }
      connectionError.value = 'Song change failed: ${e.toString()}';
    }
  }

  /// Starts up listener to detect when the clients network stream completes
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

        //check if theres a next song expected in queue
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
          _sonoPlayer.pauseStream();
        }
      }
    });
  }

  //handle play command from host => execute immediately with dynamic sync
  //double-seek: first seek starts buffering the right region, second seek
  //right before play corrects for the buffer-fill time so it doesnt contribute to desync
  Future<void> _handlePlayCommand(Map<String, dynamic> data) async {
    _hostWantsPlaying = true;

    //a song_changed is currently loading the new stream; it will handle play
    //at its scheduled executeAt with the correct position => dont race it
    if (_songChangeInProgress) return;

    final positionMs = data['position_ms'] as int?;
    final recordedAt = data['recorded_at'] as int?;

    _scheduledTimer?.cancel();
    _scheduledTimer = null;

    try {
      if (positionMs != null && recordedAt != null) {
        //first seek: approximate position to start buffering the right region
        final hostNow = DateTime.now().millisecondsSinceEpoch + _clockOffset;
        final approxPosition = (positionMs + (hostNow - recordedAt)).clamp(
          0,
          999999999,
        );
        await _sonoPlayer.seekStream(Duration(milliseconds: approxPosition));

        await _waitForPlayerReady();

        //second seek: re-compute exact position now that buffer is warm;
        //this position is within the already-buffered region so the seek is instant
        final hostNow2 = DateTime.now().millisecondsSinceEpoch + _clockOffset;
        final exactPosition = (positionMs + (hostNow2 - recordedAt)).clamp(
          0,
          999999999,
        );
        await _sonoPlayer.seekStream(Duration(milliseconds: exactPosition));
      } else if (positionMs != null) {
        await _sonoPlayer.seekStream(Duration(milliseconds: positionMs));
      }

      if (!_sonoPlayer.isPlaying.value) {
        await _sonoPlayer.playStream();
      }
      if (kDebugMode) {
        debugPrint('[SAS Client] Play command executed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS Client] Play command error: $e');
      }
    }
  }

  //handle pause command from host => execute immediately
  Future<void> _handlePauseCommand(Map<String, dynamic> data) async {
    _hostWantsPlaying = false;
    _scheduledTimer?.cancel();
    _scheduledTimer = null;

    try {
      if (_sonoPlayer.isPlaying.value) {
        await _sonoPlayer.pauseStream();
      }
      if (kDebugMode) {
        debugPrint('[SAS Client] Pause command executed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS Client] Pause command error: $e');
      }
    }
  }

  //handle seek command from host => execute immediately with dynamic position
  Future<void> _handleSeekCommand(Map<String, dynamic> data) async {
    //same guard as play: song_changed will seek to the right spot at executeAt
    if (_songChangeInProgress) return;

    final positionMs = data['position_ms'] as int;
    final recordedAt = data['recorded_at'] as int?;

    _scheduledTimer?.cancel();
    _scheduledTimer = null;

    try {
      int adjustedPosition = positionMs;
      if (recordedAt != null) {
        final hostNow = DateTime.now().millisecondsSinceEpoch + _clockOffset;
        adjustedPosition = (positionMs + (hostNow - recordedAt)).clamp(
          0,
          999999999,
        );
      }
      await _sonoPlayer.seekStream(Duration(milliseconds: adjustedPosition));
      if (kDebugMode) {
        debugPrint('[SAS Client] Seek to ${adjustedPosition}ms executed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SAS Client] Seek command error: $e');
      }
    }
  }

  //handle queue update from host
  void _handleQueueUpdate(Map<String, dynamic> data) {
    try {
      final queueData = data['queue'] as List;
      final currentIndex = data['current_index'] as int;

      clientQueue.value = queueData.cast<Map<String, dynamic>>();
      clientCurrentIndex.value = currentIndex;

      //sync queue to player so QueueView displays it
      _sonoPlayer.sasCurrentIndex = currentIndex;
      _sonoPlayer.queueNotifier.value = clientQueue.value.map((item) {
        return MediaItem(
          id: item['songId'].toString(),
          title: item['title'] ?? 'Unknown',
          artist: item['artist'],
          album: item['album'],
          duration: Duration(milliseconds: item['duration'] ?? 0),
          extras: {'songId': item['songId']},
        );
      }).toList();

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

  /// Waits up to 8 seconds for the player to reach ready or buffering state
  Future<void> _waitForPlayerReady() async {
    final state = _sonoPlayer.player.processingState;
    if (state == ProcessingState.ready || state == ProcessingState.buffering) {
      return;
    }
    try {
      await _sonoPlayer.player.processingStateStream
          .firstWhere(
            (s) => s == ProcessingState.ready || s == ProcessingState.buffering,
          )
          .timeout(Duration(seconds: 8));
    } catch (_) {
      //timeout => proceed anyway
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
