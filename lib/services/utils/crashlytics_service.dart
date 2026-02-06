import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:sono/services/utils/preferences_service.dart';

/// Centralized service for crash reporting
class CrashlyticsService {
  static final CrashlyticsService _instance = CrashlyticsService._internal();
  static CrashlyticsService get instance => _instance;

  CrashlyticsService._internal();

  final PreferencesService _prefsService = PreferencesService();
  bool _isEnabled = true;
  bool _isInitialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isEnabled = await _prefsService.isCrashlyticsEnabled();
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(_isEnabled);
    _isInitialized = true;

    if (kDebugMode) {
      print('CrashlyticsService: Initialized with collection ${_isEnabled ? 'enabled' : 'disabled'}');
    }
  }

  /// Check if crashlytics is currently enabled
  bool get isEnabled => _isEnabled;

  /// Update the enabled state (called from settings)
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _prefsService.setCrashlyticsEnabled(enabled);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);

    if (kDebugMode) {
      print('CrashlyticsService: ${enabled ? 'Enabled' : 'Disabled'} by user');
    }
  }

  /// Record an error => if crashlytics is enabled
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_isEnabled) return;

    try {
      await FirebaseCrashlytics.instance.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
      );

      if (kDebugMode) {
        print('CrashlyticsService: Error recorded${reason != null ? ' - $reason' : ''}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('CrashlyticsService: Failed to record error: $e');
      }
    }
  }

  /// Log a message to crashlytics
  Future<void> log(String message) async {
    if (!_isEnabled) return;

    try {
      await FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      if (kDebugMode) {
        print('CrashlyticsService: Failed to log message: $e');
      }
    }
  }

  /// Set a custom key-value pair for crash reports
  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_isEnabled) return;

    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (e) {
      if (kDebugMode) {
        print('CrashlyticsService: Failed to set custom key: $e');
      }
    }
  }
}