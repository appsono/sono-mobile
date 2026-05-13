// TODO: Fix errors with it not re-intializing correctly

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sono/services/player/player.dart';

/// Bridges Androids Visualizer to Dart via "sono_visualizer" MethodChannel
/// Maintains a cached [spectrum]; safe to read synchronously
/// No-op on non-Android platforms
class VisualizerService {
  static const _channel = MethodChannel('sono_visualizer');
  static const _pollInterval = Duration(milliseconds: 100);
  static const _idleTimeout = Duration(seconds: 2);

  List<double> _spectrum = const [];
  Timer? _pollTimer;
  StreamSubscription<int?>? _sessionSub;
  bool _isInitialized = false;
  bool _isInitializing = false;
  DateTime? _lastSpectrumAccess;

  /// Current FFT magnitudes (0..1), length = captureSize/2 (typically 64)
  List<double> get spectrum {
    _lastSpectrumAccess = DateTime.now();
    unawaited(_ensureInitialized());
    if (Platform.isAndroid && _pollTimer == null) {
      final current = SonoPlayer().player.androidAudioSessionId;
      if (current != null) {
        unawaited(_initVisualizer(current));
      }
    }
    return _spectrum;
  }

  Future<void> initialize() async {
    await _ensureInitialized();
  }

  Future<void> _ensureInitialized() async {
    if (!Platform.isAndroid) return;
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    try {
      // Re-init visualizer whenever audio session ID changes while FFT is in use.
      _sessionSub = SonoPlayer().player.androidAudioSessionIdStream.listen((
        sessionId,
      ) {
        if (_lastSpectrumAccess == null) return;
        if (sessionId != null) {
          _initVisualizer(sessionId);
        } else {
          _stopPolling();
        }
      });

      // Also try immediately in case a session is already active.
      final current = SonoPlayer().player.androidAudioSessionId;
      if (current != null && _lastSpectrumAccess != null) {
        await _initVisualizer(current);
      }
      _isInitialized = true;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initVisualizer(int sessionId) async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return;
      await _channel.invokeMethod<void>('init', {'sessionId': sessionId});
      _startPolling();
    } catch (_) {}
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      final lastAccess = _lastSpectrumAccess;
      if (lastAccess == null ||
          DateTime.now().difference(lastAccess) > _idleTimeout) {
        _stopPolling();
        return;
      }

      _channel.invokeMethod<List<Object?>>('getSpectrum').then((raw) {
        if (raw != null) _spectrum = raw.cast<double>();
      }).catchError((_) {});
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (Platform.isAndroid) {
      _channel.invokeMethod<void>('release').catchError((_) {});
    }
  }

  void dispose() {
    _stopPolling();
    _sessionSub?.cancel();
    _isInitialized = false;
    _isInitializing = false;
  }
}
