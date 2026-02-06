import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment configuration service
class EnvConfig {
  static bool _isInitialized = false;

  /// Initialize the environment configuration
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await dotenv.load(fileName: '.env');
      _isInitialized = true;
      debugPrint('EnvConfig: Environment loaded successfully');
    } catch (e) {
      debugPrint('EnvConfig: Error loading .env file: $e');
      debugPrint('EnvConfig: Using default values');
      _isInitialized = true;
    }
  }

  //=== API Configuration =====

  /// Poduction API base URL
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.sono.wtf';

  /// CDN base URL for assets
  static String get cdnBaseUrl =>
      dotenv.env['CDN_BASE_URL'] ?? 'https://cdn.sono.wtf';

  /// Development API base URL (local server)
  static String get devApiBaseUrl =>
      dotenv.env['DEV_API_BASE_URL'] ?? 'http://localhost:8000';

  /// Update API base URL for app version service
  static String get updateApiUrl =>
      dotenv.env['UPDATE_API_URL'] ?? 'https://update.sono.wtf';

  static String get artistProfileApiUrl =>
      dotenv.env['ARTIST_PROFILE_API_URL'] ?? 'https://images.sono.wtf';

  //=== Last.fm Integration =====

  /// Last.fm API key
  static String get lastfmApiKey => dotenv.env['LASTFM_API_KEY'] ?? '';

  /// Last.fm shared secret
  static String get lastfmSharedSecret =>
      dotenv.env['LASTFM_SHARED_SECRET'] ?? '';

  /// Ceck if Last.fm is configured
  static bool get isLastfmConfigured =>
      lastfmApiKey.isNotEmpty && lastfmApiKey != 'your_lastfm_api_key_here';

  //=== Feature Flags =====

  /// Ebable cloud features (collections, sync)
  static bool get enableCloudFeatures =>
      _getBool('ENABLE_CLOUD_FEATURES', true);

  /// Ebable SAS (Sono Audio Stream - P2P audio streaming)
  static bool get enableSAS => _getBool('ENABLE_SAS', true);

  /// Enable lyrics display
  static bool get enableLyricsDisplay =>
      _getBool('ENABLE_LYRICS_DISPLAY', true);

  /// Enable crossfade between tracks
  static bool get enableCrossfade => _getBool('ENABLE_CROSSFADE', true);

  /// Enable sleep timer feature
  static bool get enableSleepTimer => _getBool('ENABLE_SLEEP_TIMER', true);

  //=== Debug Settings =====

  /// Debug mode flag
  static bool get debugMode => _getBool('DEBUG_MODE', kDebugMode);

  /// Verbose logging flag
  static bool get verboseLogging => _getBool('VERBOSE_LOGGING', false);

  //=== Helper Methods =====

  /// Parse a boolean from environment variable
  static bool _getBool(String key, bool defaultValue) {
    final value = dotenv.env[key];
    if (value == null) return defaultValue;
    return value.toLowerCase() == 'true';
  }

  /// Get any environment variable with optional default
  static String? get(String key, [String? defaultValue]) {
    return dotenv.env[key] ?? defaultValue;
  }

  /// Check if running in development mode
  static bool get isDevelopment => debugMode || kDebugMode;

  /// Get configuration summary for debugging
  static Map<String, dynamic> getConfigSummary() {
    return {
      'initialized': _isInitialized,
      'apiBaseUrl': apiBaseUrl,
      'cdnBaseUrl': cdnBaseUrl,
      'updateApiUrl': updateApiUrl,
      'lastfmConfigured': isLastfmConfigured,
      'cloudFeatures': enableCloudFeatures,
      'sas': enableSAS,
      'lyricsDisplay': enableLyricsDisplay,
      'crossfade': enableCrossfade,
      'sleepTimer': enableSleepTimer,
      'debugMode': debugMode,
    };
  }
}