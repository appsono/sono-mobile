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

  List<double> _spectrum = const [];
  Timer? _pollTimer;
  StreamSubscription<int?>? _sessionSub;

  /// Current FFT magnitudes (0..1), length = captureSize/2 (typically 64)
  List<double> get spectrum => _spectrum;

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    //re-init visualizer whenever audio session ID changes
    _sessionSub = SonoPlayer().player.androidAudioSessionIdStream.listen(
      (sessionId) {
        if (sessionId != null) _initVisualizer(sessionId);
      },
    );

    //also try immediately in case a session is already active
    final current = SonoPlayer().player.androidAudioSessionId;
    if (current != null) _initVisualizer(current);
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
    _pollTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _channel.invokeMethod<List<Object?>>('getSpectrum').then((raw) {
        if (raw != null) _spectrum = raw.cast<double>();
      }).catchError((_) {});
    });
  }

  void dispose() {
    _pollTimer?.cancel();
    _sessionSub?.cancel();
    if (Platform.isAndroid) {
      _channel.invokeMethod<void>('release').catchError((_) {});
    }
  }
}
